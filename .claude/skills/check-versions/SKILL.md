# check-versions skill

Check pinned component versions in this repo against upstream latest releases and report which are outdated.

---

## What to do

1. **Read pinned versions** from `ansible/group_vars/all.yml`. Extract every `*_version` key and its value. Current tracked components and their upstream GitHub release pages:

   | Variable | Upstream repo |
   |----------|--------------|
   | `argocd_helm_chart_version` | `argoproj/argo-helm` (chart `argo-cd`) — check https://github.com/argoproj/argo-helm/releases |
   | `cilium_version` | `cilium/cilium` — check https://github.com/cilium/cilium/releases |
   | `containerd_version` | `containerd/containerd` — check https://github.com/containerd/containerd/releases |
   | `etcdctl_version` | `etcd-io/etcd` — check https://github.com/etcd-io/etcd/releases |
   | `kube_bench_version` | `aquasecurity/kube-bench` — check https://github.com/aquasecurity/kube-bench/releases |
   | `kubernetes_version` | kubernetes.io/releases — check https://kubernetes.io/releases/ or https://github.com/kubernetes/kubernetes/releases |
   | `longhorn_version` | `longhorn/longhorn` — check https://github.com/longhorn/longhorn/releases |

2. **Fetch the latest release tag** for each component. For GitHub-hosted projects use the GitHub API endpoint `https://api.github.com/repos/<owner>/<repo>/releases/latest` via WebFetch — strip the leading `v` when comparing against the pinned value (the pinned values in all.yml omit the `v` prefix). For ArgoCD's Helm chart the chart version differs from the app version; use the Helm chart tag (`argo-cd-<version>`), not the ArgoCD app release.

3. **Compare** each pinned version against the latest. Flag any where latest > pinned.

4. **Report** a table with columns: Component | Pinned | Latest | Status (`✓ up to date` / `⚠ update available`). If any updates are available, list specific upgrade actions as a follow-up section — e.g. "bump `kubernetes_version` from 1.36.1 → 1.36.4 in ansible/group_vars/all.yml".

5. **Do not apply any changes automatically.** This skill is read-only — it reports, it does not patch. If the user asks to apply a bump after seeing the report, do so as a separate step.

---

## Notes

- Only check `ansible/group_vars/all.yml`. Do not scan `homekube-apps` — that repo has Renovate for chart bumps.
- Ignore `system_arch`, `system_arch_v2`, `ssh_username`, `swap_size_gb`, `pod_cidr`, `service_cidr`, `control_plane_ip`, and URL-valued vars — they are not versioned components.
- For Kubernetes, only compare within the same minor series that is currently pinned (e.g. if pinned to 1.36.x, report the latest 1.36.x patch but do not flag a 1.37.x release as an update — minor upgrades require a deliberate human decision).
- If a fetch fails (network error, rate limit), note it in the report rather than silently skipping.
