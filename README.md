# Homekube

Running Upstream Kubernetes on Raspberry Pi.

Cluster topology, network architecture, and component/version tables live in the top-level [`homekube` README](../README.md) — this repo only covers what's specific to provisioning it.

<!-- TOC -->
* [Setup](#setup)
<!-- /TOC -->

---

## Setup

⚠️ The following steps outline the tasks required to install Kubernetes on _my_ Raspberry Pi cluster. It's likely that _your_ cluster is different. Use this repository as a guide, but don't expect every step to work for your system. ⚠️

Follow the phases in order:

1. [Phase 1: Bootstrap](./docs/01_bootstrap.md) — Imager + Tailscale + WiFi
2. [Phase 2: NVMe Migration](./docs/02_nvme.md) — SD → NVMe boot (Ansible automation)
3. [Phase 3: Ansible Provisioning](./docs/03_ansible.md) — Create homekube user, base packages
4. [Phase 4: Kubernetes Install](./docs/04_kubernetes.md) — kubeadm + Cilium
5. [Phase 5: GitOps](./docs/05_gitops.md) — ArgoCD + App-of-Apps
6. [Apps deployment](https://github.com/jangroth/homekube-apps) — ArgoCD applications (Cilium LB, Longhorn, monitoring)

### Quick update

```shell
# Via Task (preferred — runs from homekube-main/)
task update-all

# Or directly
cd ansible
uv run ansible-playbook 20-configure-darth.yml --tags update-only
uv run ansible-playbook 22-k8s-nodes.yml --tags update-only
```

### Renovate PAT (human step)

`.github/workflows/renovate.yml` needs a `RENOVATE_TOKEN` repo secret to open PRs — not creatable by automation. Tracks the Ansible-pinned versions in `ansible/group_vars/all.yml` (argocd, cilium, containerd, etcdctl, kube-bench, longhorn); `kubernetes_version` is excluded (see issue #44).

1. GitHub → Settings → Developer settings → Fine-grained tokens → new token
2. Repository access: only this repo (`jangroth/homekube-main`)
3. Permissions: **Contents** (read/write), **Pull requests** (read/write)
4. Add as repo secret `RENOVATE_TOKEN`: Settings → Secrets and variables → Actions

Trigger a run manually instead of waiting for the weekly cron (Monday 06:00 UTC):

```sh
gh workflow run renovate.yml --repo jangroth/homekube-main
```
