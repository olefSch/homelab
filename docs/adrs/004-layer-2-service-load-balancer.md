---
title: Layer 2 Service Load Balancer Selection
description: Layer 2 service load balancer selection for a bare-metal Raspberry Pi homelab.
tags:
  - adr
  - networking
  - load-balancer
---

# ADR 004: Layer 2 Service Load Balancer Selection

!!! abstract "Metadata"

    - **Status:** 🟢 Accepted
    - **Date:** 2026-06-07
    - **Author:** Ole Schildt

## Context & Motivation

**The Problem:**

To host web applications and route traffic properly using an Ingress Controller or Gateway API, the
cluster needs a real IP address from the home network. By default, K3s uses a simple tool called
ServiceLB (Klipper). Instead of providing a dedicated Virtual IP (VIP), ServiceLB binds application
ports directly to the nodes' physical IP addresses. This causes port conflicts and does not provide
proper high availability for incoming web traffic.

Furthermore, the homelab is already using a VIP (`192.168.0.20`) for the Kubernetes Control Plane. A
solution is required that assigns IPs to applications without interfering with the cluster's
management API.

**Constraints:**

- **Physical Network:** The home network is a flat Layer 2 broadcast domain. The cluster is
  connected via an unmanaged switch and a standard consumer router.
- **No Layer 3 Routing:** Advanced routing protocols like BGP are not supported by the physical
  network hardware, rendering ECMP (Equal-Cost Multi-Path) load balancing impossible.
- **No External SDN Integration:** Unlike cloud environments (AWS/GCP), the homelab setup lacks an
  external Software-Defined Networking controller to dynamically provision network-level load
  balancers. Therefore, node-level Layer 2 ARP announcements must be utilized.
- **GitOps Integrity:** The load balancing solution must be deployed entirely via the GitOps
  repository (`homelab`), without requiring any manual SSH intervention or changes to the underlying
  node provisioning scripts.

---

## Options Considered

### Option 1: K3s Default ServiceLB (Klipper) {: data-toc-label="ServiceLB" }

This is the default load balancer bundled with K3s. It operates as a DaemonSet that binds the
requested service ports directly to the physical network interface of the nodes hosting the pods.

- :material-plus-circle-outline: Built-in, requiring zero extra configuration or external images.
- :material-minus-circle-outline: Does not assign a true, floating VIP to services.
- :material-minus-circle-outline: **High Risk for K3s:** Because K3s master nodes also run worker
  pods, ServiceLB will hijack host ports (e.g., 80/443) on the control plane nodes. This causes port
  exhaustion and severe collisions if other host-networked services are deployed.

### Option 2: MetalLB {: data-toc-label="MetalLB" }

MetalLB is the traditional industry standard for bare-metal Kubernetes. It utilizes a controller to
assign IPs and a node-level "speaker" daemon to announce the IPs to the local network using ARP.

- :material-plus-circle-outline: Extremely mature, stable, and boasts excellent CRDs for managing IP
  pools.
- :material-minus-circle-outline: Introduces redundant daemonsets. The cluster already utilizes an
  ARP-announcement tool (`kube-vip`) for the Control Plane.
- :material-minus-circle-outline: Adding MetalLB's memory footprint to the highly constrained 1GB
  RAM of the Raspberry Pi 3B+ worker is an unnecessary architectural risk.

### Option 3: Cilium L2 Announcements (eBPF) {: data-toc-label="Cilium" }

Cilium replaces the default K3s CNI (Flannel) and uses eBPF (Extended Berkeley Packet Filter) to
bypass traditional iptables. It includes native Layer 2 IPAM and ARP announcements.

- :material-plus-circle-outline: The modern enterprise gold standard, offering unmatched network
  performance, security, and observability.
- :material-plus-circle-outline: Completely eliminates theoretical `kube-proxy` and `iptables`
  routing bottlenecks, though the low number of total services in this specific setup makes iptables
  overloading unlikely (impossible in this case).
- :material-minus-circle-outline: The memory overhead required to compile eBPF maps and run the
  Cilium operator/agents will overwhelm the legacy Raspberry Pi 3B+ worker node, leading to
  Out-Of-Memory (OOM) pod evictions.

### Option 4: Kube-vip "Two Broadcasters" via GitOps {: data-toc-label="Kube-vip Two Broadcasters" }

Since `kube-vip` is already securing the Control Plane, a secondary `kube-vip` stack is deployed
purely for workloads. The `kube-vip-cloud-provider` assigns IPs from a config pool, and a second
`kube-vip` DaemonSet broadcasts those IPs. This second DaemonSet is explicitly configured to ignore
the Control Plane.

- :material-plus-circle-outline: **Highly resource-efficient:** Reuses a lightweight container image
  already cached on the nodes, protecting the Pi 3B+'s limited RAM.
- :material-plus-circle-outline: **Leverages K3s Architecture:** Because master nodes run workloads,
  the service VIP can gracefully elect a Pi 5 as the traffic entry point, utilizing its superior
  network throughput.
- :material-plus-circle-outline: Creates a safe "air gap" between management traffic and web
  traffic. A flood of web requests on the application VIP will not impact the Control Plane VIP
  (`.20`).
- :material-minus-circle-outline: Layer 2 ARP failover relies on Gratuitous ARP, which can take
  several seconds to update switch MAC tables if a leader node abruptly loses power.

---

## Decision

!!! success "Final Decision: Option 4 (Kube-vip Two Broadcasters)"

    **Kube-vip "Two Broadcasters" via GitOps** will be implemented to provide Layer 2 service IP allocation.

### Rationale

In an ARM64 homelab utilizing mixed-generation hardware (Raspberry Pi 5s and a Pi 3B+), resource
efficiency dictates the architecture. While modern eBPF solutions like Cilium are ideal for
enterprise, they are too heavy for this specific hardware profile. Similarly, MetalLB introduces
redundant ARP speakers. By choosing the "Two Broadcasters" architecture, the cluster achieves
enterprise-grade separation of concerns without adding new networking tools. Furthermore, because
K3s allows the Pi 5 control plane nodes to process application workloads, `kube-vip` can efficiently
route traffic directly through the highest-performing nodes in the cluster, completely avoiding the
host-port collision traps of the default `ServiceLB`.

---

## Alignment

This decision directly aligns with our core design goals and architectural guidelines:

- **Resource Efficiency on ARM64:** Reusing the lightweight `kube-vip` image respects the strict
  bare-metal resource limits established in
  [ADR 001: K3s HA Bare Metal](./001-k3s-ha-bare-metal.md){ data-preview }.
- **Strict GitOps Management:** The entire Data Plane load balancer configuration is maintained in
  our configuration repository and deployed automatically, matching the Single Source of Truth
  mandate in [ADR 002: ArgoCD for GitOps](./002-argocd-for-gitops.md){ data-preview }.
- **Separation of Provisioning and State:** Deploying purely via Kubernetes manifests requires zero
  modifications to base OS images or hardware-level logic, supporting the architecture defined in
  [ADR 003: Zero-Touch Provisioning](./003-zero-touch-provisioning.md){ data-preview }.

**The RBAC Cross-Repository Coupling Trade-off:** A notable drawback to this approach is the loose,
unvalidated RBAC coupling introduced between separate repositories. The node-level provisioning
scripts initialize the initial `kube-vip` `ClusterRole`, `ClusterRoleBinding`, and `ServiceAccount`
to protect the control plane. This second GitOps-managed workload DaemonSet directly mounts and
inherits that existing `ServiceAccount`. Because the RBAC resources are managed by the provisioning
layer while the consumer DaemonSet lives in the `homelab` GitOps repository, a breaking RBAC change
in the provisioning layer will silent-fail the GitOps-managed workload broadcaster during execution.
This cross-repository dependency is accepted to avoid duplicate permission management within the
same `kube-system` namespace and because I am a Team of One.
