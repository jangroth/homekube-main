# GitOps — ArgoCD

Covers Phase 5: installing ArgoCD and bootstrapping the App-of-Apps that manages all cluster workloads. The cluster must already be running with Cilium installed (`04_kubernetes.md`).

Run from `homekube-main/ansible/` on darth.

---

## Overview

The cluster uses ArgoCD's **App-of-Apps** pattern: a single root Application (`root-app`) in the `argocd` namespace watches the `jangroth/homekube-apps` Git repository. `applications/kustomization.yaml` explicitly lists every child Application manifest as a Kustomize resource — root-app builds that file, and ArgoCD deploys whatever it resolves to. Adding a new app means adding it to `kustomization.yaml`, not just dropping a file in a subdirectory. Changes pushed to `homekube-apps` are synced continuously; no manual `kubectl apply` is needed after initial bootstrap.

```
homekube-main (Ansible bootstrap)
  └── root-app (ArgoCD Application)
        └── homekube-apps/applications/  (kustomization.yaml)
              └── wave-NN-<name>/   (argocd.argoproj.io/sync-wave: "<N>")
```

---

## Deploy ArgoCD

```bash
task 50-gitops
# or directly:
uv run ansible-playbook 50-gitops.yml
```

What the playbook does, in order:

1. Verifies the cluster is ready (pi0 node must be in `Ready` state)
2. Adds the `argo` Helm repository (`https://argoproj.github.io/argo-helm`)
3. Installs or upgrades ArgoCD via Helm:
   - Chart: `argo/argo-cd` version `9.5.15` (pinned in `ansible/group_vars/all.yml`)
   - Namespace: `argocd` (created if absent)
   - Values: `ansible/roles/gitops/files/argocd-helm-values.yaml`
4. Waits for `argocd-server` Deployment to reach `Available`
5. Creates (or updates) the `root-app` Application manifest in the `argocd` namespace

After the playbook completes, ArgoCD picks up `homekube-apps/applications/` and begins syncing all child Applications.

---

## App-of-Apps Structure

Applications are grouped into `wave-NN-<name>/` directories under `homekube-apps/applications/`, each carrying an `argocd.argoproj.io/sync-wave` annotation. Lower-numbered waves deploy first (cluster-level infra: storage, networking, cert management); higher waves deploy application and observability workloads that depend on earlier waves being healthy.

The current set of waves and applications lives entirely in [`homekube-apps/applications/`](https://github.com/jangroth/homekube-apps/tree/main/applications) — not duplicated here, since it changes independently of this doc.

---

## Sync Policy

The root app is created with:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

- **Automated**: ArgoCD polls and syncs without manual approval
- **Prune**: resources removed from Git are deleted from the cluster
- **Self-heal**: out-of-band changes to cluster state are reverted on the next sync

Child Applications inherit their own sync policies from their respective YAML files in `homekube-apps`.

---

## Access

### Admin password (first login)

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Username: `admin`

### UI (port-forward)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open `https://localhost:8080` (accept the self-signed cert).

### OIDC

ArgoCD is configured for Google OIDC via an external Dex instance at
`https://pi0.taild13083.ts.net/dex`. RBAC policy:

| Identity | Role |
|----------|------|
| `jan.groth.de@gmail.com` | `role:admin` |
| `homepage` (API key) | `role:readonly` |

The `homepage` account is used by the Homepage dashboard widget (spec 007) with an API key — no password login.

---

## Configuration

| File | Purpose |
|------|---------|
| `ansible/roles/gitops/files/argocd-helm-values.yaml` | ArgoCD Helm values (replicas, OIDC, RBAC, metrics) |
| `ansible/group_vars/all.yml` | Pinned `argocd_helm_chart_version`, root app repo URL and path |
| `https://github.com/jangroth/homekube-apps` | All Application manifests and Helm values |

---

## Day-2 Operations

### Upgrade ArgoCD

Bump `argocd_helm_chart_version` in `ansible/group_vars/all.yml`, then re-run `task 50-gitops`. The playbook is idempotent — it upgrades if ArgoCD is already installed.

### Check sync status

```bash
kubectl get applications -n argocd
# or via CLI:
argocd app list   # requires argocd CLI and login
```

### Force a sync

```bash
kubectl -n argocd patch application <name> \
  --type merge -p '{"operation":{"sync":{}}}'
```

### Verify root-app is watching the correct repo

```bash
kubectl -n argocd get application root-app -o jsonpath='{.spec.source}'
```

Expected output: `repoURL: https://github.com/jangroth/homekube-apps.git`, `path: applications`.

