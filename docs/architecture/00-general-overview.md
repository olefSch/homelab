---
title: Homelab Project Overview
description: A general overview of the highly available, GitOps-driven bare-metal homelab.
icon: material/server
tags:
  - overview
  - homelab
  - gitops
  - hardware
---

# Homelab Project Overview

My homelab project is a highly available, bare-metal Kubernetes environment built on ARM64
architecture (at least for now). The core objective of this project is to create a resilient,
scalable, and fully automated infrastructure utilizing modern GitOps and Infrastructure as Code
principles.

---

## Physical Cluster Setup

The physical foundation of the cluster is housed in a compact, custom rack enclosure specifically
for Raspberry Pis to bundle those with SSDs.

![Physical Homelab Cluster Setup](./../assets/real-cluster.jpg)

The hardware layer is designed for efficiency and minimal cable clutter:

- **Power and Networking:** All nodes are connected to a managed PoE (Power over Ethernet) switch.
  Power is supplied directly through the Ethernet cables, eliminating the need for individual power
  adapters.
- **Compute Nodes:** The cluster utilizes Raspberry Pi single-board computers (Raspberry Pi 5s for
  the control plane and a Raspberry Pi 3B+ for dedicated workloads).
- **Storage:** Each Raspberry Pi is equipped with a dedicated SSD connected via USB, ensuring
  reliable and fast localized storage for the container runtime and databases. This also
  automatically solves common SD card pain points and is significantly faster.

---

## GitOps & Infrastructure as Code

The entire cluster lifecycle, from initial hardware provisioning to application deployment, is
managed through public code repositories. This ensures the setup is reproducible,
version-controlled, and self-documenting. Having it public also forces me to apply to best security
standards the moment I have public facing endpoints.

### Node Provisioning

The base operating system and K3s cluster initialization are fully automated. The automated setup
and image builder code used to provision the Raspberry Pis can be found here:

- **Provisioning Repository:**
  [rpi-k3s-cluster-image-builder](https://github.com/olefSch/rpi-k3s-cluster-image-builder)

### GitOps State Management

Once the cluster is bootstrapped, all internal cluster configurations, networking, and applications
are synchronized automatically from a central GitOps repository.

- **GitOps Repository:** [homelab](https://github.com/olefSch/homelab)

### Cloud Integration (Hybrid Cloud)

While the compute cluster is entirely bare-metal and hosted locally, certain highly sensitive
infrastructure components will be offloaded to the cloud. For example, services such as secrets
management and authentication are delegated to external providers rather than being hosted
on-premises. Software-as-a-Service (SaaS) solutions often provide greater convenience and security
for these specific tasks, although the architecture retains the flexibility to migrate to
self-hosted alternatives. A primary example of this hybrid approach is the use of a Key Vault hosted
in Google Cloud Platform (GCP). The configuration and lifecycle of these cloud resources are
strictly managed using Terraform.

---

## Core Design Goals

The architecture is built around the following primary technical principles:

??? success "GitOps & IaC"

    The entire infrastructure lifecycle is managed through version-controlled code rather than manual configuration. By utilizing Git as the single source of truth, cluster configurations, application deployments, and infrastructure state are continuously synchronized. This eliminates configuration drift and ensures that the entire system can be rapidly and predictably rebuilt from scratch if necessary.

??? success "DORA Capabilities for a 'Team of One' :p"

    While [DORA (DevOps Research and Assessment)](https://dora.dev/research/) frameworks are traditionally applied to large enterprise organizations, core **DORA capabilities** are strictly implemented here to eliminate manual toil. By focusing on foundational technical capabilities—such as comprehensive version control (GitOps), continuous delivery, and resilient architecture—the system is designed to drive elite performance metrics (like rapid mean-time-to-recovery and high deployment frequency) as a single administrator.

??? success "Theoretical High Availability"

    The control plane is distributed across three master nodes. In the event of a hardware failure, power loss, or network interruption on any single node, the cluster automatically maintains quorum and re-routes traffic. No manual intervention is required to keep the cluster operational. The term "theoretical" acknowledges that true absolute HA is limited by the physical constraints of a homelab environment—specifically the reliance on a single PoE switch and a single home router, which remain physical single points of failure.

??? success "Theoretical Scalability"

    Because the system is driven by GitOps and standardized node provisioning scripts, the architecture is horizontally scalable. Expanding the cluster's compute capacity theoretically only requires plugging a new node into the PoE switch and applying the automated provisioning image. This is considered "theoretical" simply because physical expansion is ultimately constrained by the physical limits of the Raspberry Pi enclosure and the number of available ports on the network switch.
