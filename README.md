# Homekube

Running Upstream Kubernetes on Raspberry Pi.

---

![Homekube](./docs/images/homekube2.png)

---

<div style="display: flex; justify-content: space-around;">
  <img src="./docs/images/logo-kubernetes.svg.png" alt="kubernetes" style="height: 50px;">
  <img src="./docs/images/logo-cilium.png" alt="cilium" style="height: 50px;">
  <img src="./docs/images/logo-longhorn.png" alt="longhorn" style="height: 50px;">
</div>

---

<div style="display: flex; justify-content: space-around;">
  <img src="./docs/images/logo-prometheus.png" alt="prometheus" style="height: 50px;">
  <img src="./docs/images/logo-grafana.png" alt="grafana" style="height: 50px;">
  <img src="./docs/images/logo-loki.png" alt="loki" style="height: 50px;">
</div>

---
<div style="display: flex; justify-content: space-around;">
  <img src="./docs/images/logo-ansible.png" alt="ansible" style="height: 50px;">
  <img src="./docs/images/logo-argocd.png" alt="argocd" style="height: 50px;">
</div>

---

![Homekube](./docs/images/k9s.png)

---

<!-- TOC -->
* [Overview](#overview)
* [Setup](#setup)
* [References / Inspiration](#references--inspiration)
<!-- /TOC -->

---

## Overview

### Components

| Component | Package | Version |
|-|-|-|
| Kubernetes | `k8s` | _1.34.1_ |
| CRI | `containerd` | _2.1.4_ |
| | `runc` | _1.1.5_ |
| CNI | `cilium` | _1.18.2_ |
| | `containernetworking-plugins` | _1.1.1_ |
| CSI | `longhorn` | _1.9.1_ |

### Nodes

| Hostname | Device         | OS                         | Architecture | Boot | Tailscale | k8s IP     |
|----------|----------------|-----------------------------|--------------|------|-----------|------------|
| pi0      | RPi 5, 8GB     | Raspberry Pi OS Lite 64bit | aarch64      | NVMe | pi0       | 10.0.0.20  |
| pi1      | RPi 5, 8GB     | Raspberry Pi OS Lite 64bit | aarch64      | NVMe | pi1       | 10.0.0.21  |
| pi2      | RPi 5, 8GB     | Raspberry Pi OS Lite 64bit | aarch64      | NVMe | pi2       | 10.0.0.22  |
| pi3      | RPi 5, 8GB     | Raspberry Pi OS Lite 64bit | aarch64      | NVMe | pi3       | 10.0.0.23  |

**Management access:** Tailscale (100.x.x.x MagicDNS) from darth. **k8s networking:** Physical switch (10.0.0.x); Tailscale invisible to Kubernetes.

### Kubernetes Network Architecture

| Network | CIDR | Component |
|-|-|-|
| Pod Network | 10.244.0.0/16 | kubeadm / ClusterConfiguration |
| Service Network | 10.96.0.0/12 | kubeadm / ClusterConfiguration |
| Cluster DNS | 10.96.0.10 | kubeadm / KubeletConfiguration |
| Cilium Pod Network | 10.244.0.0/16 | cilium |

### Kubernetes Cluster Architecture

```mermaid
graph TD
    subgraph Kubernetes Cluster
        subgraph ControlPlane [pi0: Control Plane]
            API[kube-apiserver]
            Cont_manager[kube-controller-manager]
            Scheduler[kube-scheduler]
            Etcd[etcd]
        end
        
        subgraph DataPlane [pi1, pi2: Data Plane]
            subgraph NsArgo[ArgoCD]
                argocd[ArgoCD]
                argocd_svc[ArgoCD Service</br> NodePort</br> 30000]
                aoa[Root App]
                app1[MetalLB]
                app2[Metrics-Server]
            end
        end
    end

    argocd_svc -- Exposes --> argocd
    argocd -- Deploys --> aoa
    aoa --> app1
    aoa --> app2

```

## Setup

⚠️ The following steps outline the tasks required to install Kubernetes on _my_ Raspberry Pi cluster. It's likely that _your_ cluster is different. Use this repository as a guide, but don't expect every step to work for your system. ⚠️

Follow the phases in order:

1. [Phase 1: Bootstrap](./docs/01_bootstrap.md) — Imager + Tailscale + WiFi
2. [Phase 2: NVMe Migration](./docs/02_nvme.md) — SD → NVMe boot (Ansible automation)
3. [Phase 3: Ansible Provisioning](./docs/03_ansible.md) — Create homekube user, base packages
4. [Phase 4: Kubernetes Install](./docs/04_kubernetes.md) — kubeadm + Cilium
5. [Phase 5: GitOps](./docs/05_gitops.md) — ArgoCD + App-of-Apps
6. [Apps deployment](https://github.com/jangroth/homekube-apps) — ArgoCD applications (MetalLB, Longhorn, monitoring)

### Quick update

```shell
ansible-playbook 01-update-control-node.yml --tags update-only
ansible-playbook 03-setup-k8s-nodes.yml --tags update-only
```

## References / Inspiration

* [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way/tree/master) - Kelsey Hightower
* [Pi Kubernetes Cluster](https://picluster.ricsanfre.com/docs/home/) - Ricardo Sanchez
* [k8s-gitops](https://github.com/xunholy/k8s-gitops) - Michael Fornaro
