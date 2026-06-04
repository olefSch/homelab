---
tags:
  - adr
  - architecture
  - k3s
---

# ADR 001: Use K3s HA with Kube-vip on Bare Metal Raspberry Pis

!!! abstract "Metadata"

    - **Status:** 🟢 Accepted
    - **Date:** 2026-02-21
    - **Author:** Ole Schildt

## Context & Motivation

**The Problem:**

I have 4 Raspberry Pis (three RPi 5s and one RPi 3b+) and I want to combine them into a High
Availability (HA) homelab cluster. Because this hardware is older or has limited memory and CPU, I
need a very lightweight Kubernetes distribution.

I want to use my hardware efficiently. I cannot afford to have nodes sitting idle just to manage the
cluster; they need to run my actual applications too. I also like to tinker, upgrade, and swap nodes
in and out, so the setup needs to be flexible. My main challenge is finding a way to get a stable,
highly available cluster that maximizes my limited resources.

**Constraints:**

- **Hardware:** 4x Raspberry Pis (ARM64 architecture) running off local storage (USB SSDs). Limited
  CPU and RAM compared to standard cloud servers.
- **Networking:** My home network uses a very simple router provided by my internet service
  provider, which lacks advanced routing features.

---

## Options Considered

### Option 1: MicroK8s {: data-toc-label="MicroK8s" }

_Using Canonical's [MicroK8s][mk], which is installed via the snap package manager._

MicroK8s is built to simulate a full enterprise Kubernetes environment. Under the hood, it runs many
separate, isolated components to act like a big datacenter setup. While it provides good High
Availability using its own dqlite database, this architecture consumes a lot of memory. It also
requires you to set up a completely separate machine (like an NGINX proxy) just to balance network
traffic to the master nodes, which breaks the goal of having a self-contained 4-node cluster.

- :material-plus-circle-outline: Highly standardized and well-documented for enterprise
  environments.
- :material-minus-circle-outline: High RAM and CPU consumption due to running many separate
  components.
- :material-minus-circle-outline: Package management is locked into Canonical's snap system (I don't
  like snap).
- :material-minus-circle-outline: Requires an external physical or virtual machine to act as a load
  balancer for the master nodes.

### Option 2: K3s HA with Kube-vip {: data-toc-label="K3s HA with Kube-vip" }

_Using [K3s][k3s], a lightweight, single-binary Kubernetes distribution built specifically for edge
computing and small devices._

K3s is packaged as one single file. It supports HA natively by using an embedded etcd database
across 3 master nodes. In its [architecture][ka], master nodes are not isolated—they run cluster
management processes and worker processes at the same time. This means master nodes can run your
applications, which saves hardware, though it requires opening more network ports on the masters. To
handle load balancing without an external router, you can use [Kube-vip][kv]. Kube-vip broadcasts a
Virtual IP (VIP) directly on the local network so traffic always finds the active master node.

- :material-plus-circle-outline: Extremely low resource footprint (uses less than 1GB of RAM for the
  control plane).
- :material-plus-circle-outline: Built-in manifests folder allows for true zero-touch GitOps
  bootstrapping (auto-deploying ArgoCD/Flux on boot).
- :material-plus-circle-outline: Ships with a built-in Local Path Provisioner for instant persistent
  storage on Day 1.
- :material-plus-circle-outline: Massive homelab community support for troubleshooting on ARM64 and
  Raspberry Pis.
- :material-plus-circle-outline: Kube-vip removes the need for an external load balancer by managing
  the IP directly on the Raspberry Pi network interfaces.
- :material-minus-circle-outline: Embedded `etcd` is sensitive to disk speed (IOPS); standard SD
  cards can fail, requiring USB SSDs.
- :material-minus-circle-outline: Masters running workloads require more ports to be open between
  nodes.

### Option 3: k0s with Kube-vip {: data-toc-label="k0s with Kube-vip" }

_Using [k0s][k0s] (by Mirantis), a modern, single-binary Kubernetes distribution designed
specifically with strict security and High Availability in mind from day one._

Unlike K3s (which originally used SQLite by default and added HA later), k0s was built for HA from
the ground up. Its architecture enforces a strict separation between master (control plane) and
worker nodes. Master nodes only run the Kubernetes API and database, ensuring maximum security and
stability. Because of this clean design, it is often faster and more secure out of the box than
other distributions. However, this strict separation means master nodes do not run user applications
by default. Furthermore, k0s takes a "bring your own batteries" approach, requiring manual
deployment of storage and load balancers.

- :material-plus-circle-outline: Built purely for High Availability and modern Kubernetes standards.
- :material-plus-circle-outline: Clear separation of tasks between masters and workers, providing an
  excellent security concept.
- :material-plus-circle-outline: Shipped as a single binary with very fast startup times.
- :material-minus-circle-outline: Strict separation wastes hardware in a small homelab, as 3 of the
  4 nodes would sit idle not running applications (unless manually reconfigured).
- :material-minus-circle-outline: Completely lacks built-in local storage provisioners or
  auto-deploy directories, requiring more manual intervention on Day 1.
- :material-minus-circle-outline: Smaller homelab community compared to K3s when looking for ARM64
  troubleshooting help.

### Option 4: Talos Linux {: data-toc-label="Talos Linux" }

_Using Talos Linux, an immutable and minimal operating system built specifically to run Kubernetes
securely and efficiently._

[Talos Linux][tl] is fundamentally different because it is both the operating system and the
Kubernetes distribution. There is no SSH, no console, and no standard Linux shell. Everything is
managed through an API. This allows for a completely declarative, GitOps-ready infrastructure where
even the OS configuration is stored as code. While it handles High Availability and Virtual IP
management perfectly out of the box, it does not include built-in storage or auto-deploy tools.

- :material-plus-circle-outline: Extremely secure and lightweight due to the removal of unnecessary
  OS components.
- :material-plus-circle-outline: True "Infrastructure as Code" since the entire OS is configured via
  a single YAML file.
- :material-plus-circle-outline: Virtual IP (VIP) is managed natively by the OS before Kubernetes
  even starts, making networking highly reliable.
- :material-minus-circle-outline: No traditional access (SSH) makes troubleshooting hardware issues
  (like USB SSD connections with the JMicron controller ^-^) on a Raspberry Pi very difficult.
- :material-minus-circle-outline: Requires manual installation of a storage provisioner and GitOps
  tools (no built-in manifests folder).
- :material-minus-circle-outline: Default strict separation of master and worker nodes wastes
  hardware unless manually reconfigured.

---

## Decision

!!! success "Final Decision: K3s HA with Embedded etcd and Kube-vip"

    **Option 2** will be implemented. The 4 Raspberry Pis will be set up as 3 Control Plane (master) nodes and 1 Worker node. Because K3s allows master nodes to run workloads by default, I will fully utilize the hardware of all 4 devices.

### Rationale

When the four options are compared, K3s is considered the best fit for the specific constraints.

MicroK8s is deemed too heavy, and an external load balancer is required by it, which is not
available in this setup.

A beautiful, secure architecture is provided by both k0s and Talos Linux through a strict separation
of master and worker nodes by default. While these taints and isolations can be manually removed to
allow master nodes to run user workloads, doing so requires extra configuration files and overrides
on Day 1. Furthermore, even if master nodes are configured to run workloads, native local storage
provisioners are still completely missing from both k0s and Talos Linux out of the box.
Troubleshooting hardware on Raspberry Pis is also made much harder by Talos Linux because
traditional SSH access is completely removed by it, which is a major disadvantage when extra USB
hardware or specialized tooling is attached to the Pis.

The perfect middle ground is offered by K3s. It is recognized as the undisputed standard for ARM64
homelabs. By utilizing embedded etcd, High Availability is achieved without external databases being
needed. Because K3s master nodes act as workers as well, the cluster can be managed and heavy
applications can be run by the three Raspberry Pi 5s, while lighter worker tasks are handled by the
older RPi 3b+.

Crucially, zero-touch GitOps bootstrapping is facilitated by the K3s manifests auto-deploy folder.
By this feature, the cluster is allowed to start pulling from Git the moment it boots. Immediate
disk usage is also guaranteed by the built-in Local Path Provisioner.

To solve the networking constraint, network routing is managed internally by Kube-vip, which is run
inside the cluster. If master node 1 fails, the connection is instantly moved to master node 2 by
Kube-vip. By this action, the cluster is kept reachable at one single IP address without a smart
router being required.

Finally, during installation, the default K3s network tools (`--disable=traefik,servicelb`) will be
intentionally disabled. A clean slate is provided by this, so that a modern load balancer and
gateway can be installed later via the GitOps pipeline.

---

## Alignment

By choosing a self-contained HA architecture without external network dependencies, this design
fulfills a very strong baseline for zero-touch provisioning. This is covered in more detail here in
[ADR-003](./003-zero-touch-provisioning.md){ data-preview }.

---

## Future Outlook: Staging and Production Environments

A future expansion of this architecture would be a cool project. The current Raspberry Pi K3s
cluster will eventually be transitioned into a Staging (QA) environment. A new Production
environment will be built later using x86_64 hardware, such as three HP EliteDesk Mini PCs, running
Talos Linux.

By this approach, the pure Infrastructure-as-Code capabilities of Talos Linux can be utilized for
production, while the flexibility of K3s is retained for testing. The differences between the
Kubernetes distributions are handled seamlessly by the GitOps pipeline, since standard upstream
Kubernetes is run by both. All in all, this is something for far in the future :)

[k3s]: https://k3s.io/
[ka]: https://docs.k3s.io/architecture
[kv]: https://kube-vip.io/docs/usage/k3s/
[mk]: https://canonical.com/microk8s
[k0s]: https://docs.k0sproject.io/stable/
[tl]: https://www.siderolabs.com/talos-linux
