---
title: Homelab K3s High Availability Architecture
description: Homelab documentation detailing the bare-metal K3s HA cluster architecture.
icon: material/kubernetes
tags:
  - k3s
  - kubernetes
  - architecture
---

# K3s High Availability Cluster Design

This document describes the core architecture of my bare-metal homelab Kubernetes cluster. The
cluster uses **K3s**, as decided in [ADR-001](./../adrs/001-k3s-ha-bare-metal.md){ data-preview }.

You can find the automated setup and code used to build this setup in my repository:
[rpi-k3s-cluster-image-builder](https://github.com/olefSch/rpi-k3s-cluster-image-builder).

High Availability (HA) is the main goal. If a machine loses power or hardware fails, the control
plane must keep running automatically without any manual fixing.

---

## K3s Architecture Explained

This diagram illustrates the complete data flow and component structure of the HA K3s homelab
cluster. The system is designed so that no single hardware failure will bring down the control
plane.

![My K3s High Availability Setup](./../assets/architecture/k3s-architecture-light.png#only-light)
![My K3s High Availability Setup](./../assets/architecture/k3s-architecture-dark.png#only-dark)

### The Virtual IP (VIP) Entry Point

At the very top, all cluster management commands (such as running `kubectl get nodes` from a laptop)
are sent to a single VIP. This VIP is managed by kube-vip, which runs as a Pod on all three master
nodes. Kube-vip continuously monitors the cluster, elects a "Leader" master node, and directs all
incoming management traffic strictly to that active leader.

### The Control Plane

The middle section shows the K3s Control Plane, powered by three Raspberry Pi 5 nodes. Each node
runs a bundled set of K3s services (all out of single-binary):

- API Server, Scheduler, and Controller Manager: The core logic of the cluster.
- _Embedded etcd_: The database that stores the cluster's state. The horizontal arrows connecting
  the embedded etcd blocks represent the Raft consensus algorithm. These three databases
  continuously talk to each other to synchronize their data. If one node dies, the other two still
  hold a perfect copy of the cluster state.
- _Worker Components_: Unlike standard Kubernetes, the K3s masters also run kubelet, kube-proxy, and
  containerd. This allows the Raspberry Pi 5 nodes to host standard application Pods (shown as blue
  hexagons) alongside the control plane, maximizing hardware usage.

### The Worker Node

At the bottom is the dedicated Worker Node (my old Raspberry Pi 3B+). Notice that the connection
line from the worker node points up to the VIP, not to a specific master node. This is a critical HA
feature: if the leader master node loses power, the VIP automatically moves to a surviving master,
and the worker node seamlessly stays connected to the cluster. The worker node is stripped down to
only run worker services, providing dedicated compute power for application Pods.

!!! info "Official K3s Documentation"

    For deeper technical specifications regarding the single-binary design, embedded etcd, and
    networking, refer to the [official K3s Architecture documentation](https://docs.k3s.io/architecture).
    This overview also doesn’t cover all services (for example, Flannel), so please refer to the official docs for details.

---

## VIP via kube-vip

To provide a single, highly available point of contact across three separate master nodes, VIP is
established using kube-vip.

Because there are three physical master nodes, there are three different physical IP addresses.
Kube-vip creates a single, floating IP address that external clients (like your laptop's `kubectl`)
and internal worker nodes use to talk to the cluster.

```yaml title="/var/lib/rancher/k3s/server/manifests/kube-vip.yaml"
# Conceptual deployment mechanism
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-vip-ds
  namespace: kube-system
# ... configured to bind to hostNetwork and elect a leader
```

The theoretical routing and failover behavior operates using these mechanisms:

- **DaemonSet Deployment**: Exactly one pod is executed on every master node. By placing the
  configuration file in the K3s manifests directory, K3s automatically deploys kube-vip before the
  cluster is even fully booted.

- **Leader Election via Leases**: All three kube-vip pods are active, but they hold an election
  using the Kubernetes Lease API (stored in the embedded etcd database). The first pod to grab the
  lease becomes the "Leader." The other two pods become "Standbys" and constantly monitor this
  lease.

- **Layer 2 Networking (ARP)**: Kube-vip in this architecture operates in Layer 2 mode. The winning
  Leader binds the VIP to its physical network interface. It then sends a broadcast message to the
  homelab router saying, "Send all traffic for the VIP to my specific MAC address." All cluster
  management traffic is now processed by this Leader's API server.

- **Instant Failover (Gratuitous ARP)**: If the Leader node loses power, it stops renewing its
  lease. Within seconds, the lease expires. The surviving standby pods detect this, and a new leader
  grabs the lease. The new leader instantly broadcasts a Gratuitous ARP message to the network
  switch. This tells the switch, "The VIP has moved; update your tables and send the traffic to my
  MAC address now." Traffic is rerouted instantly, keeping the control plane online.
