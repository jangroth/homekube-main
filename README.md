# Homekube

Running Upstream Kubernetes on Raspberry Pi.

Cluster topology, network architecture, and component/version tables live in the top-level [`homekube` README](../README.md) — this repo only covers what's specific to provisioning it.

<!-- TOC -->
* [Setup](#setup)
* [Nightly routine](#nightly-routine)
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

### Power outage (human step)

Shut the whole cluster down and bring it back with [Full cluster shutdown and power-up](./docs/shutdown-power-outage.md).

### Renovate PAT (human step)

`.github/workflows/renovate.yml` needs a `RENOVATE_TOKEN` repo secret to open PRs — not creatable by automation. Tracks the Ansible-pinned versions in `ansible/group_vars/all.yml` (argocd, cilium, containerd, etcdctl, longhorn, kubernetes patch releases only; minors are upgraded deliberately).

1. GitHub → Settings → Developer settings → Fine-grained tokens → new token
2. Repository access: only this repo (`jangroth/homekube-main`)
3. Permissions: **Contents** (read/write), **Pull requests** (read/write), **Issues** (read/write) for the Dependency Dashboard, **Workflows** (read/write) for the `github-actions` manager's updates
4. Add as repo secret `RENOVATE_TOKEN`: Settings → Secrets and variables → Actions

Trigger a run manually instead of waiting for the weekly cron (Monday 02:00 UTC; GitHub often starts it hours late):

```sh
gh workflow run renovate.yml --repo jangroth/homekube-main
```

### Infisical admin identity (human step)

`terraform/infisical/` configures Infisical's projects, machine identities and their Kubernetes Auth (ADR-0010 (Terraform owns AWS-account infrastructure and Infisical configuration)). It authenticates as an admin identity that only exists in Infisical and the password manager. Create it once, and again after an Infisical rebuild:

1. Infisical UI (`https://192.168.86.247`) → Organization → Access Control → Identities → Create Identity: name `terraform-admin`, organization role **Admin**
2. On the identity: Authentication → Universal Auth (defaults) → Client Secrets → Create; the secret is shown once
3. Store in the password manager, item `Infisical terraform-admin`: client ID, client secret, and the organization ID (Organization Settings → General)

### Infisical configuration (human step)

Needs `ALLOW_INTERNAL_IP_CONNECTIONS` on Infisical (`homekube-apps`): Kubernetes Auth calls the API server on a private IP, which Infisical refuses otherwise. Terraform talks to Infisical's plain-HTTP backend through a port-forward, so it works from any network and needs no trust in homekube-ca. Secret values are never in Terraform: they are entered in the Infisical UI by each app's cutover step in the `homekube-apps` README.

```sh
kubectl -n infisical port-forward deploy/infisical 8080:8080 &

export INFISICAL_UNIVERSAL_AUTH_CLIENT_ID=<client ID>        # password manager: Infisical terraform-admin
export INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET=<client secret>
export TF_VAR_org_id=<organization ID>
export TF_VAR_kubernetes_ca_certificate="$(kubectl -n default get cm kube-root-ca.crt -o jsonpath='{.data.ca\.crt}')"

cd terraform/infisical
terraform init
terraform plan     # first apply: 5 resources per app (project, prod environment, identity, Kubernetes Auth, Viewer membership)
terraform apply
terraform plan     # must report no changes
terraform output   # identity ID and project slug per app, for its InfisicalSecret

kill %1
```

Projects have delete protection: remove it in the UI before a `terraform destroy`. A cluster rebuild changes the cluster CA, so re-run the apply with the new `TF_VAR_kubernetes_ca_certificate`.

---

## Nightly routine

A Claude Code cloud routine ("homekube-main - nightly todo", daily 14:00 UTC / 00:00 AEST) picks up one open tracker issue labelled `agent-safe` + `repo:homekube-main` and opens a PR for review. Its config lives in the repo:

- `.claude/routines/nightly-todo.md` — the routine's instructions and settings, including the exact routine prompt, which points to this file and authorises the branch, commit, push and PR
- `.claude/routines/cloud-environment.md` — the cloud environment's settings: name, network allowlist, setup script
- `scripts/cloud/setup.sh` — the cloud environment's setup script; the environment's script only runs `bash /home/user/homekube-main/scripts/cloud/setup.sh`
