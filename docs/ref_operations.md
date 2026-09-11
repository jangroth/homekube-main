## Configuration & Logs

### kubernetes
- conf
  - `/etc/kubernetes`
  
### api-server
- conf
  - `service-cluster-ip-range`: `10.96.0.0/12` # 1,048,574 (10.96.0.0 -> 10.111.255.255)
- log
  - `k logs -n kube-system -f kube-apiserver-pi0`
  - `sudo crictl logs -f $(sudo crictl ps | grep kube-apiserver | awk '{print $1}')`

### etcd
- log
  - `sudo crictl logs $(sudo crictl ps | grep etcd | awk '{print $1}')`

### controller-manager
- log
  - `sudo crictl logs $(sudo crictl ps | grep kube-controller-manager | awk '{print $1}')`

### scheduler
- log
  - `k logs -n kube-system -f kube-scheduler-pi0`
  - `sudo crictl logs $(sudo crictl ps | grep kube-scheduler | awk '{print $1}')`

### kube-proxy
- log
  - `k logs -n kube-system -f kube-proxy-pi0`
  - `sudo crictl logs $(sudo crictl ps | grep kube-proxy | awk '{print $1}')`

### kubelet
- conf
  - `/var/lib/kubelet`  
  - `/var/lib/kubelet/pki`
  - `/var/lib/kubelet/config.yaml`
  - `/lib/systemd/system/kubelet.service`

- via API server:
```shell
kubectl proxy
curl -X GET http://127.0.0.1:8001/api/v1/nodes/pi0/proxy/configz | jq # pi0,1,2
```

- logs
  - `journalctl -b -f -u kubelet.service`

### containerd
- conf
  - `/etc/containerd/config.toml`
  - `/etc/systemd/system/containerd.service`
- logs
  - `journalctl -b -u containerd.service`

### CNI-plugins
- conf
  - `/etc/cni/net.d/`
- bin
  - `/opt/cni/bin`

### CNI
- `pod-network-cidr`: `10.244.0.0/16` # 65,536 (10.244.0.0 -> 10.244.255.255)

---

## Hardware Watchdog

The Raspberry Pi hardware watchdog resets the node if systemd doesn't pet it within `RuntimeWatchdogSec`. Under heavy sustained load (e.g. ArgoCD install churning many pods on pi0), the 1-minute vendor default can trip, causing an unclean node reset.

**Configuration** (all nodes via `k8s-node` role, playbook 22):

| File | Location |
|------|----------|
| Drop-in | `/etc/systemd/system.conf.d/50-homekube-watchdog.conf` |
| Setting | `RuntimeWatchdogSec=10min` |
| Applied by | `configure_watchdog.yml` → `systemctl daemon-reexec` |

**Verify the active setting on a node:**

```bash
# Check the effective RuntimeWatchdogSec (should show 10min)
ssh homekube@pi0 "systemctl show | grep -E 'RuntimeWatchdog|ShutdownWatchdog'"

# Confirm the drop-in is present
ssh homekube@pi0 "cat /etc/systemd/system.conf.d/50-homekube-watchdog.conf"

# Check if the watchdog device is open (systemd holds it when enabled)
ssh homekube@pi0 "sudo wdctl"
```

**After a suspected watchdog reset** (distinguishing hardware watchdog from other resets):

```bash
# Look for 'watchdog' in the previous boot's kernel log
ssh homekube@pi0 "journalctl -b -1 -k | grep -i watchdog"

# Check systemd journal for the previous boot — absence of a clean shutdown message
# alongside a watchdog reset in dmesg is the definitive sign
ssh homekube@pi0 "journalctl -b -1 | tail -30"
```

**Running heavy Helm upgrades** (to reduce watchdog risk on pi0):

- Run `task 50-gitops` during low-traffic periods when fewer reconciliation loops are active.
- Monitor pi0 load during the install: `ssh homekube@pi0 "watch -n2 uptime"`.
- If pi0 resets mid-install, ArgoCD and Helm state may be partial — re-run `task 50-gitops` after recovery; the playbook is idempotent.