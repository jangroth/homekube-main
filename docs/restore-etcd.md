# Restore etcd from Snapshot

Covers the disaster-recovery procedure for restoring the etcd database from a snapshot on a rebuilt pi0. pi0 is the sole control-plane node; losing it without a snapshot means losing all cluster state.

Run the manual steps on pi0 as `homekube` (sudo as needed). Run Ansible commands from `homekube-main/ansible/` on darth.

---

## Backup Strategy

A full restore requires two independent backups taken at the same point in time:

| Artifact | What it contains | Where |
|----------|-----------------|-------|
| `snapshot.db` | All etcd key-value state (workloads, config, secrets) | offsite / S3 |
| `/etc/kubernetes/pki/` | CA, API server, etcd, and service-account keys | offsite / S3 |

**The PKI must match the snapshot.** etcd data is referenced by the API server using the certificates that were active when the snapshot was taken. Restoring etcd without the matching PKI causes authentication failures at start-up.

---

## Taking a Snapshot (Reference)

Run on pi0. `etcdctl` v3.6.4 is installed at `/usr/local/bin/etcdctl` by `22-k8s-nodes.yml`.

```bash
SNAPSHOT="/var/backup/etcd/snapshot-$(date +%Y%m%d-%H%M%S).db"

sudo ETCDCTL_API=3 /usr/local/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save "$SNAPSHOT"

sudo ETCDCTL_API=3 /usr/local/bin/etcdctl \
  snapshot status "$SNAPSHOT" --write-out=table
```

Copy the snapshot and PKI offsite immediately after.

---

## Prerequisites for Restore

Before starting the restore:

1. **pi0 is rebuilt** — fresh OS, provisioned with Ansible playbooks `21-provision-pis.yml` and `22-k8s-nodes.yml`. Do **not** run `30-k8s-control-plane.yml` yet.
2. **`etcdctl` is installed** — confirmed by `22-k8s-nodes.yml`; verify with `/usr/local/bin/etcdctl version`.
3. **Snapshot is accessible** — on darth or retrievable from offsite storage.
4. **PKI backup is accessible** — the `/etc/kubernetes/pki/` tree from the pre-failure cluster.

---

## Restore Procedure

### Step 1 — Restore Kubernetes PKI

Copy the PKI backup to pi0. The directory structure under `/etc/kubernetes/pki/` must be preserved exactly.

```bash
# From darth — copy PKI backup to pi0
rsync -av /path/to/pki-backup/ homekube@pi0:/tmp/pki-restore/

# On pi0
sudo mkdir -p /etc/kubernetes/pki/etcd
sudo cp -r /tmp/pki-restore/* /etc/kubernetes/pki/
sudo find /etc/kubernetes/pki -name "*.key" -exec chmod 600 {} \;
sudo find /etc/kubernetes/pki -name "*.crt" -exec chmod 644 {} \;
sudo chown -R root:root /etc/kubernetes/pki
rm -rf /tmp/pki-restore
```

Verify:

```bash
sudo ls /etc/kubernetes/pki/etcd/
# Expected: ca.crt  ca.key  healthcheck-client.crt  healthcheck-client.key
#           peer.crt  peer.key  server.crt  server.key
```

### Step 2 — Copy snapshot to pi0

```bash
# From darth
scp /path/to/snapshot.db homekube@pi0:/tmp/snapshot.db
```

### Step 3 — Restore snapshot

The `etcd.local.dataDir` in `kubeadm-config.yaml` is `/var/lib/etcd`. Restore directly into that path so the static pod manifest requires no changes.

On pi0:

```bash
# Restore snapshot into /var/lib/etcd
sudo ETCDCTL_API=3 /usr/local/bin/etcdctl snapshot restore /tmp/snapshot.db \
  --data-dir /var/lib/etcd \
  --name pi0 \
  --initial-cluster "pi0=https://10.0.0.20:2380" \
  --initial-cluster-token "etcd-cluster-homekube-restore" \
  --initial-advertise-peer-urls "https://10.0.0.20:2380"

sudo chown -R root:root /var/lib/etcd
rm /tmp/snapshot.db
```

The `--initial-cluster-token` value is intentionally different from the original (`etcd-cluster-1` used by kubeadm) to prevent the restored member from accidentally peering with any remnant of the old cluster.

### Step 4 — Bring up the control plane

Run the control-plane playbook from darth. The playbook's `init_control_plane.yml` checks for `/etc/kubernetes/admin.conf` and skips `kubeadm init` if it already exists; since pi0 is freshly built, it will run `kubeadm init`.

`kubeadm init` re-uses the PKI already in `/etc/kubernetes/pki/` and starts etcd using the data directory restored in Step 3. The resulting etcd static pod manifest at `/etc/kubernetes/manifests/etcd.yaml` will reference `/var/lib/etcd` — the restored data is picked up automatically.

```bash
# From darth
ansible-playbook 30-k8s-control-plane.yml
```

If `kubeadm init` completes but you see etcd not reaching quorum, check that the `--initial-cluster-token` in the static pod manifest (`/etc/kubernetes/manifests/etcd.yaml` on pi0) matches the token used in Step 3. If it does not, edit the manifest directly and kubelet will restart the static pod.

### Step 5 — Re-join worker nodes

Workers already have their node certificates from before the rebuild, but their API server connection will fail because pi0 has a new bootstrap token. Re-join them:

```bash
# From darth — generates a new join token and re-joins pi1–pi3
ansible-playbook 31-k8s-workers.yml
```

---

## Verification

### etcd membership

On pi0:

```bash
sudo ETCDCTL_API=3 /usr/local/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list
```

Expected: a single member (`pi0`) with status `started`.

```bash
sudo ETCDCTL_API=3 /usr/local/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```

Expected: `https://127.0.0.1:2379 is healthy`.

### Cluster state

```bash
kubectl get nodes         # pi0 Ready; pi1–pi3 NotReady until re-joined
kubectl get pods -A       # control-plane pods in kube-system Running
```

After `31-k8s-workers.yml` completes:

```bash
kubectl get nodes         # all four nodes Ready
kubectl get pods -A       # ArgoCD and workloads reconciled by GitOps
```

### Approve pending CSRs

Worker kubelet certificate rotation generates CSRs that must be approved:

```bash
kubectl get csr           # lists Pending CSRs
kubectl certificate approve <csr-name>
# Or approve all pending at once:
kubectl get csr -o name | grep Pending | xargs kubectl certificate approve
```

---

## Configuration Reference

| Item | Value |
|------|-------|
| etcdctl binary | `/usr/local/bin/etcdctl` |
| etcdctl version | `3.6.4` (pinned in `ansible/group_vars/all.yml`) |
| etcd data directory | `/var/lib/etcd` |
| etcd static pod manifest | `/etc/kubernetes/manifests/etcd.yaml` |
| etcd CA cert | `/etc/kubernetes/pki/etcd/ca.crt` |
| etcd server cert | `/etc/kubernetes/pki/etcd/server.crt` |
| etcd server key | `/etc/kubernetes/pki/etcd/server.key` |
| etcd client endpoint | `https://127.0.0.1:2379` |
| etcd peer endpoint | `https://10.0.0.20:2380` |
| pi0 control-plane IP | `10.0.0.20` |
