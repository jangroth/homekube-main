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

### watchdog
- conf
  - `/etc/systemd/system.conf.d/50-homekube-watchdog.conf`, `RuntimeWatchdogSec=10min`, applied by `configure_watchdog.yml`
- verify
  - `ssh homekube@pi0 "systemctl show | grep -E 'RuntimeWatchdog|ShutdownWatchdog'"`
  - `ssh homekube@pi0 "sudo wdctl"`
- detect a watchdog reset
  - `ssh homekube@pi0 "journalctl -b -1 -k | grep -i watchdog"`
- heavy Helm upgrades (`task 50-gitops`) on pi0
  - monitor: `ssh homekube@pi0 "watch -n2 uptime"`
  - idempotent — re-run after a reset