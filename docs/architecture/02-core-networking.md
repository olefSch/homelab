---
icon: material/lan
tags:
  - architecture
  - networking
  - load-balancing
  - kube-vip
---

# Core Networking

The networking architecture of the bare-metal homelab is heavily influenced by physical hardware
constraints. Because the cluster operates on a standard consumer home network using an unmanaged
switch, advanced Layer 3 routing protocols (like BGP) are unavailable.

To overcome this, the cluster utilizes a modern, flat Layer 2 networking stack. This stack is
designed to be lightweight enough for the Raspberry Pi hardware while maintaining high availability
for cluster services.

---

## Load Balancing & IP Management (Layer 2)

Before any traffic can be routed into the cluster, there must be a mechanism to claim physical IP
addresses on the local `192.168.0.x` home network. This is handled by **[kube-vip][kv]**, a
networking daemon that uses standard ARP (Address Resolution Protocol) broadcasts to dynamically
attach virtual IPs (VIPs) to the physical nodes.

To protect the cluster's core management layer from application traffic, two separate instances of
`kube-vip` are utilized.

**The Control Plane VIP (`192.168.0.20`):** This IP provides continuous, highly available access to
the Kubernetes API. It is managed strictly by the underlying node provisioning scripts to guarantee
access even if the GitOps engine fails.

**The Data Plane Pool (`192.168.0.25 - 192.168.0.29`):** This pool provides IP addresses for
standard web applications. It is managed entirely via the GitOps repository (`homelab`) and strictly
adheres to the official Kubernetes Cloud Controller Manager (CCM) design by decoupling IP allocation
from physical routing:

- **IP Allocation ([`kube-vip-cloud-provider`][kvc]):** Operating as the cluster's CCM, this
  lightweight controller watches the Kubernetes API for new `LoadBalancer` services and
  automatically assigns them an available IP from the ConfigMap pool.
- **ARP Broadcasting (`kube-vip` DaemonSet):** Operating as the infrastructure data plane, this
  secondary broadcaster takes the assigned IP and physically announces it to the local switch.

This dual-layer approach creates a safe isolation layer between management traffic and public-facing
application traffic.

!!! tip "Design Decision & Source Code"

    For a deep dive into why `kube-vip` was chosen over heavy eBPF solutions like Cilium or legacy tools like MetalLB, see [ADR 004: Layer 2 Service Load Balancer Selection](../adrs/004-layer-2-service-load-balancer.md){ data-preview }.

    [:material-github:  Explore load balancer config from the homelab](https://github.com/olefSch/homelab/tree/main/kubernetes/apps/networking/kube-vip)

---

## Hardware Optimization

A critical component of the networking design is hardware awareness. The homelab consists of
mixed-generation hardware, specifically Raspberry Pi 5 master nodes and a legacy Raspberry Pi 3B+
worker node.

Because network routing is CPU and memory intensive, Kubernetes `nodeAffinity` rules are strictly
enforced on the networking components. These rules guarantee that the `kube-vip` ARP broadcasters
are exclusively scheduled on the superior Gigabit Ethernet and CPU of the Pi 5 nodes. This protects
the resource-constrained 1GB RAM Pi 3B+ from processing heavy network packets and prevents it from
becoming a routing bottleneck.

[kv]: https://github.com/kube-vip/kube-vip
[kvc]: https://github.com/kube-vip/kube-vip-cloud-provider
