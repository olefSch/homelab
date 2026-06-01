# 🚀 GitOps Homelab

<div align="center">

_My fully automated, GitOps-driven infrastructure repository managing my K3s Raspberry Pi homelab_

</div>

## 🛠️ Built with

![K3S](https://img.shields.io/badge/-K3s-FFC61C?style=for-the-badge&logo=k3s&logoColor=white)
![argo_cd](https://img.shields.io/badge/-Argo-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Kubernetes](https://img.shields.io/badge/-Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/-Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white)
![RPI](https://img.shields.io/badge/-RaspberryPi-A22846?style=for-the-badge&logo=raspberrypi&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![GCP](https://img.shields.io/badge/GCP-0d1117?style=for-the-badge&logo=googlecloud&logoColor=white)

## **📖 Overview**

This repository is the single source of truth for my Homelab infrastructure. It utilizes
Infrastructure-as-Code (IaC) to provision foundational resources that I do not want to host (e.g.,
KeyVault) and GitOps principles to manage all Kubernetes cluster configurations and workloads.

The base for the repo is my zero touch provisioning repo
[here](https://github.com/olefSch/rpi-k3s-cluster-image-builder)

## **🧰 Tech Stack**

| Component      | Technology                                             | Description                                             |
| :------------- | :----------------------------------------------------- | :------------------------------------------------------ |
| **Kubernetes** | [K3s](https://k3s.io/)                                 | Lightweight, edge-optimized Kubernetes                  |
| **GitOps**     | [ArgoCD](https://argo-cd.readthedocs.io/en/stable/)    | App-of-Apps cluster workload bootstrapping              |
| **IaC**        | [Terraform](https://developer.hashicorp.com/terraform) | Manages external infrastructure state and provisioning. |
| **Docs**       | [Zensical](https://zensical.org/)                      | Successor to Material for MkDocs                        |

## **📂 Repository Structure**

```text
├── .github/                 # CI/CD pipelines (Docs, Security scans, CI Check for PRs)
├── docs/                    # MkDocs source files (ADRs, Runbooks)
├── kubernetes/              # GitOps declarative state following the app of apps pattern
├── terraform/               # To setup SaaS solutions I don't want to host myself
└── ...                      # Small helper tooling and root files
```

## **🚀 Getting Started (Local Development)**

If you fork the repository or test configurations locally, ensure you have the required developer
tooling installed.

### **1\. Prerequisites**

- [Docker](https://www.docker.com/) (Required for local CI simulation)
- [Just](https://github.com/casey/just): The primary command runner (brew install just).
- [uv](https://docs.astral.sh/uv/): Simply best Python package manager (brew install uv).
- [Pre-commit](https://pre-commit.com/): Git hook framework (brew install pre-commit).
- [act](https://github.com/nektos/act): Run GitHub Actions locally (brew install act).
- [Google Cloud CLI](https://docs.cloud.google.com/sdk/gcloud) (gcloud): For local GCP
  authentication and dirty config ^-^
- Technology tooling obviously too

### **2\. Initialization**

Clone the repository and initialize the local development environment:

```bash
git clone https://github.com/olefSch/homelab.git
cd homelab

pre-commit install

# option to run the docs
uv sync
```

## **📄 License**

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.
