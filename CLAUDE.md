# homekube-main

Ansible provisioning for the homekube Raspberry Pi cluster.

See parent `CLAUDE.md` (one level up) for cluster topology, SSH access, and working conventions.

---

## Playbook Sequence

Run in order for a full cluster setup. After fresh SD card boot, start from step 2.

| # | Playbook | What it does |
|---|----------|-------------|
| 01 | `01-update-control-node.yml` | Configures darth: installs tooling, updates `/etc/hosts`, `~/.ssh/config`, `known_hosts` |
| 02 | `02-prepare-pis.yml` | Creates `homekube` user (from `boot` user), installs base packages, configures OS |
| 03 | `03-setup-k8s-nodes.yml` | All nodes: cgroups, kernel params, containerd, k8s packages, storage |
| 04 | `04-setup-k8s-control-plane.yml` | pi0: kubeadm init, copies kubeconfig |
| 05 | `05-setup-cni.yml` | Installs Cilium via helm |
| 06 | `06-setup-gitops.yml` | Installs ArgoCD via helm, deploys App-of-Apps |

**NVMe boot** is handled by the `raspberry-pi` role (enable_pciex → configure_nvme → copy_mmc_to_nvme), but requires a **physical hardware step first** — see parent CLAUDE.md.

---

## Running Playbooks

```shell
# Via Task (preferred)
cd homekube-main
task setup-cni
task setup-gitops
task update-all

# Directly
cd homekube-main/ansible
ansible-playbook 02-prepare-pis.yml
ansible-playbook 03-setup-k8s-nodes.yml --tags update-only
```

---

## Key Configuration

| File | Purpose |
|------|---------|
| `ansible/inventory/hosts.ini` | pi0–pi3, grouped by control_plane / data_plane |
| `ansible/group_vars/all.yml` | All versions, `ssh_username: homekube`, ArgoCD repo URL |
| `ansible/group_vars/raspberry_pis.yml` | Pi IP addresses (internal + external) |
| `ansible/ansible.cfg` | Inventory path, become settings |

---

## Bootstrap Flow (fresh SD card)

1. Pi boots with user `boot` / password `boot` (configured in Pi Imager)
2. Ansible connects as `boot` (hardcoded in `create_user_account.yml`)
3. Creates `homekube` user, copies pub keys, configures sudo
4. From here on: all access via `ssh homekube@piN` with key auth
5. `boot` user is effectively abandoned (password auth disabled)

---

## Roles

| Role | Purpose |
|------|---------|
| `control-node` | Configures darth (SSH, /etc/hosts, packages) |
| `raspberry-pi` | Base pi setup: user, NVMe, PCIe |
| `k8s-node` | K8s prerequisites: cgroups, kernel, containerd, packages, swap |
| `k8s-control-plane` | kubeadm init, kubeconfig, kube-bench |
| `cni` | Cilium install |
| `gitops` | ArgoCD install |

---

## Ansible Collections

```shell
./setup-collections.sh  # install required collections
```
