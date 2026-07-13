# Kubernetes Install — kubeadm, Cilium

Covers Phase 4: initialising the control plane, joining worker nodes, and installing the Cilium CNI. All pis must already run from NVMe and pass the k8s-node prerequisite check from `03_ansible.md`.

Run all playbooks from `homekube-main/ansible/` on darth.

See DECISION-006 (Tailscale as management plane) and DECISION-032 (Cilium with Tailscale routing).

---

## Cluster Topology

| Node | Role | Switch IP | Tailscale name |
|------|------|-----------|----------------|
| pi0  | control plane | 10.0.0.20 | pi0 |
| pi1  | worker | 10.0.0.21 | pi1 |
| pi2  | worker | 10.0.0.22 | pi2 |
| pi3  | worker | 10.0.0.23 | pi3 |

Single control-plane node. Workers are `pi1`–`pi3`. No HA control plane.

Networking:
- Pod CIDR: `10.244.0.0/16` (Cilium IPAM mode `kubernetes`)
- Service CIDR: `10.96.0.0/12`
- Cluster DNS: `10.96.0.10` (CoreDNS)

---

## Preconditions

- All four pis are accessible via `ssh homekube@piN` from darth (confirmed by `ansible all -m ping`)
- Node prerequisites are complete: `ansible-playbook 22-k8s-nodes.yml` has been run
- Dry-run passes: `ssh homekube@pi0 "sudo kubeadm init --dry-run --ignore-preflight-errors=Swap"` exits 0
- darth kubeconfig target exists: `~/.kube/homekube.config` (created by playbook 30)

---

## Optional: Reset an Existing Cluster

If a previous install exists and you need to start fresh:

```bash
# On darth: uninstall apps first
cilium uninstall
# Then on each node:
ansible all -b -a "kubeadm reset --force"
ansible all -b -a "rm -rf /etc/cni/net.d /var/lib/etcd /var/lib/kubelet /etc/kubernetes"
ansible all -b -m reboot
# Re-run node prerequisites before re-initialising
ansible-playbook 22-k8s-nodes.yml
```

---

## Step 1 — Initialise the Control Plane (pi0)

```bash
task 30-k8s-control-plane
# or directly:
uv run ansible-playbook 30-k8s-control-plane.yml
```

What the playbook does:

1. **Copies `kubeadm-config.yaml`** to `/home/homekube/` on pi0
2. **Pre-pulls control-plane images** (`kubeadm config images pull`) on first run
3. **Runs `kubeadm init`** with `--ignore-preflight-errors=Swap` (swap is intentional — see Design Decisions)
4. **Sets up kubeconfig** on pi0 at `~/.kube/config`, then fetches it to darth as `~/.kube/homekube.config`, rewriting the server URL from `10.0.0.20:6443` to `pi0:6443` (Tailscale MagicDNS) and renaming the context to `homekube`
5. **Installs kube-bench** at the pinned version for CIS benchmark scanning

The `kubeadm-config.yaml` key settings:

| Setting | Value | Reason |
|---------|-------|--------|
| `advertiseAddress` | `10.0.0.20` | Switch plane IP — Tailscale invisible to k8s |
| `skipPhases: addon/kube-proxy` | — | Cilium replaces kube-proxy |
| `clusterName` | `homekube` | |
| `certSANs` | `pi0`, `10.0.0.20`, `10.96.0.1`, `192.168.86.220` | Covers Tailscale + switch + service CIDRs |
| `failSwapOn: false` | — | Swap is enabled on all nodes (4 GiB) |
| `memorySwap.swapBehavior` | `LimitedSwap` | Allows capped swap use per pod |
| `serverTLSBootstrap: true` | — | Node-serving certs bootstrapped by kubelet |
| `resolvConf` | `/etc/kubernetes/resolv.conf` | Isolates pod DNS to eth0; Tailscale DNS unreachable from pod network |
| `caCertificateValidityPeriod` | `87600h` (10 years) | Avoid cert rotation pain on a home cluster |

### Verify after Step 1

```bash
export KUBECONFIG=~/.kube/homekube.config

kubectl get nodes
# NAME   STATUS   ROLES           AGE   VERSION
# pi0    Ready    control-plane   ...   v1.36.1

kubectl get pods -n kube-system
# CoreDNS pods will be Pending until CNI is installed (Step 3)
```

---

## Step 2 — Join Worker Nodes (pi1–pi3)

```bash
task 31-k8s-workers
# or directly:
uv run ansible-playbook 31-k8s-workers.yml
```

What the playbook does (per worker, in parallel):

1. **Generates a fresh bootstrap token** on pi0 (`kubeadm token create`) — tokens expire after 24 h
2. **Derives the CA cert hash** from pi0's `/etc/kubernetes/pki/ca.crt` via openssl
3. **Pre-pulls worker images** on each node
4. **Templates `join-config.yaml`** from `roles/k8s-worker/templates/join-config.yaml.j2` with the token, CA hash, and per-node switch IP
5. **Runs `kubeadm join`** with `--ignore-preflight-errors=Swap`
6. **Verifies** each node appears in `kubectl get node` within 60 seconds

### Verify after Step 2

```bash
kubectl get nodes
# NAME   STATUS     ROLES           AGE   VERSION
# pi0    Ready      control-plane   ...   v1.36.1
# pi1    NotReady   <none>          ...   v1.36.1  ← NotReady until CNI installed
# pi2    NotReady   <none>          ...   v1.36.1
# pi3    NotReady   <none>          ...   v1.36.1

# Approve pending kubelet serving CSRs (auto-bootstrapped via serverTLSBootstrap)
kubectl get csr
kubectl certificate approve <csr-name>   # repeat for each Pending CSR
```

---

## Step 3 — Install Cilium CNI

```bash
task 40-cni
# or directly:
uv run ansible-playbook 40-cni.yml
```

Runs from darth against pi0 (but `delegate_to: localhost` for all Helm calls — the playbook drives the cluster via darth's kubeconfig).

What the playbook does:

1. Verifies pi0 is `Ready` in `kubectl get nodes`
2. Adds the `cilium` Helm repository (`https://helm.cilium.io/`)
3. Runs `helm diff upgrade` to detect changes
4. Installs or upgrades Cilium `{{ cilium_version }}` in the `kube-system` namespace if differences exist
5. Waits for all `cilium-*` pods to reach `Running`
6. Confirms pi0 transitions to `Ready`

Cilium `cilium-helm-values.yaml` key settings:

| Setting | Value | Reason |
|---------|-------|--------|
| `kubeProxyReplacement: true` | — | Full kube-proxy replacement (kubeadm skipped kube-proxy) |
| `k8sServiceHost` | `10.0.0.20` | Switch IP — not a Tailscale address |
| `routingMode: tunnel` / `tunnelProtocol: vxlan` | — | VXLAN overlay for pod-to-pod traffic |
| `ipam.mode: kubernetes` | — | Node CIDR assignment delegated to kube-controller-manager |
| `l2announcements.enabled: true` | — | L2 ARP announcements for LoadBalancer VIPs |
| `k8sClientRateLimit: {qps:50, burst:100}` | — | Raised because L2 leader-election leases are API-chatty |
| `devices: eth0,wlan0,tailscale0` | — | `tailscale0` included so Cilium intercepts VIP traffic arriving via Tailscale subnet routing (DECISION-032) |
| `hubble.enabled: true` | — | Network observability (relay + UI enabled) |

### Verify after Step 3

```bash
# All nodes Ready
kubectl get nodes
# NAME   STATUS   ROLES           AGE   VERSION
# pi0    Ready    control-plane   ...   v1.36.1
# pi1    Ready    <none>          ...   v1.36.1
# pi2    Ready    <none>          ...   v1.36.1
# pi3    Ready    <none>          ...   v1.36.1

# Cilium pods running on each node
kubectl get pods -n kube-system -l k8s-app=cilium

# CoreDNS should now be Running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Hubble relay + UI
kubectl get pods -n kube-system -l app.kubernetes.io/name=hubble-relay
kubectl get pods -n kube-system -l app.kubernetes.io/name=hubble-ui

# Approve any remaining kubelet serving CSRs
kubectl get csr | grep Pending
```

---

## Design Decisions

### Swap enabled (`failSwapOn: false`, `LimitedSwap`)

All nodes carry a 4 GiB swapfile at `/var/swap.img`. Kubernetes 1.36 supports swap via `memorySwap.swapBehavior: LimitedSwap` — pods may use swap up to their memory limit. Accepted for a home cluster where RAM is the main constraint on a 4-node Raspberry Pi 5 setup.

### No kube-proxy (`skipPhases: addon/kube-proxy`)

Cilium runs in full kube-proxy replacement mode. `kubeadm init` skips the kube-proxy DaemonSet entirely. Service routing (ClusterIP, NodePort, LoadBalancer) is handled by Cilium's eBPF data plane.

### Pod DNS isolated to switch plane (`resolvConf: /etc/kubernetes/resolv.conf`)

The kubelet is given a separate `resolv.conf` that only references the switch-plane DNS, not the Tailscale DNS. Tailscale's DNS server is not reachable from the pod network, so using it would cause pod DNS timeouts.

### Tailscale device included in Cilium (`devices: eth0,wlan0,tailscale0`)

By default Cilium only attaches to non-virtual interfaces. Adding `tailscale0` ensures Cilium's `cil_from_netdev` hook intercepts LoadBalancer VIP traffic that arrives via Tailscale subnet routing, so services are reachable from off-cluster Tailscale peers.

### Certificate validity (10 years)

`caCertificateValidityPeriod: 87600h` avoids the need to rotate the cluster CA on a home cluster. Normal leaf certs auto-rotate via `serverTLSBootstrap: true`.

---

## Day-2 Operations

### Approve pending CSRs (kubelet serving certs)

After a node restart or on first join, kubelet bootstraps a serving cert that requires manual approval:

```bash
kubectl get csr
kubectl certificate approve <name>
```

### Upgrade Kubernetes version

1. Bump `kubernetes_version` in `ansible/group_vars/all.yml`
2. Re-run `ansible-playbook 22-k8s-nodes.yml --tags update-only` to install new packages
3. Cordon and drain pi0, then `kubeadm upgrade apply vX.Y.Z` on pi0
4. For each worker: drain → `kubeadm upgrade node` → uncordon

### Upgrade Cilium

Bump `cilium_version` in `ansible/group_vars/all.yml`, then re-run `task 40-cni`. The playbook runs `helm diff` before applying and is idempotent.

### Run kube-bench (CIS benchmark)

```bash
ssh homekube@pi0 "sudo kube-bench run --targets node,master"
```

### etcdctl

`etcdctl` is installed at version `3.6.4` on all nodes (pinned in `ansible/group_vars/all.yml`). To snapshot etcd manually:

```bash
ssh homekube@pi0 "sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-snapshot.db"
```

---

## Configuration Reference

| File | Purpose |
|------|---------|
| `ansible/roles/k8s-control-plane/files/kubeadm-config.yaml` | Full kubeadm init/cluster/kubelet config |
| `ansible/roles/cni/files/cilium-helm-values.yaml` | Cilium Helm values |
| `ansible/roles/k8s-worker/templates/join-config.yaml.j2` | Worker join config template |
| `ansible/group_vars/all.yml` | Pinned versions: `kubernetes_version`, `cilium_version`, `containerd_version`, `etcdctl_version` |
| `ansible/inventory/hosts.ini` | `control_plane` (pi0) and `data_plane` (pi1–pi3) groups |

---

## Status

| Component | Version | Status |
|-----------|---------|--------|
| kubeadm / kubelet / kubectl | 1.36.1 | installed, held |
| containerd | 2.3.0 | installed |
| Cilium | 1.19.4 | running |
| Hubble relay + UI | 1.19.4 | running |
| kube-bench | 0.13.0 | installed on pi0 |
| etcdctl | 3.6.4 | installed on all nodes |

Proceed to `05_gitops.md` for ArgoCD bootstrap.
