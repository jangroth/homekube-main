# Ansible Provisioning

Covers Phase 3: user provisioning and Kubernetes prerequisites. All pis must already boot from NVMe over Tailscale (`02_nvme.md`).

Run all playbooks from `homekube-main/ansible/` on darth.

---

## Preconditions

Complete these before running any playbook.

### 1. Darth keypair

```bash
ls ~/.ssh/id_darth_homekube \
  || ssh-keygen -t ed25519 -f ~/.ssh/id_darth_homekube -C "darth@homekube"
```

Commit the public key to the repo:

```bash
cp ~/.ssh/id_darth_homekube.pub roles/raspberry-pi/files/pub_keys/id_darth_homekube.pub
git add roles/raspberry-pi/files/pub_keys/id_darth_homekube.pub
git commit -m "Add darth homekube public key"
```

### 2. Kylo keypair

On kylo:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_kylo_homekube -C "kylo@homekube"
```

Copy the public key to darth and commit it:

```bash
# from darth:
scp kylo:~/.ssh/id_kylo_homekube.pub roles/raspberry-pi/files/pub_keys/id_kylo_homekube.pub
git add roles/raspberry-pi/files/pub_keys/id_kylo_homekube.pub
git commit -m "Add kylo homekube public key"
```

### 3. Verify Tailscale connectivity from darth

```bash
ssh boot@pi0   # must succeed (password: boot)
```

---

## Playbook Run Order

### Step 1 — Configure darth

```bash
ansible-playbook 20-configure-darth.yml
```

Populates darth's `~/.ssh/config` with MagicDNS stanzas for pi0–pi3 and updates `~/.ssh/known_hosts`. After this, `ssh homekube@pi0` works from darth without host-key prompts (once `homekube` is created in Step 2).

### Step 2 — Provision pis (init run)

```bash
ansible-playbook 21-provision-pis.yml --tags init
```

Connects as `boot` (probes for `homekube` first; falls back to `boot/boot` if not found). Creates the `homekube` user, generates a node keypair per pi, fetches `pub_keys/piN.pub` back to darth, deploys all `pub_keys/*.pub` to `authorized_keys`, configures sudoers, disables password auth, locks the `boot` user.

After the run, commit the generated node keys:

```bash
git add roles/raspberry-pi/files/pub_keys/pi*.pub
git commit -m "Add generated pi node keys (post-NVMe)"
```

### Step 3 — Provision pis (idempotency check)

```bash
ansible-playbook 21-provision-pis.yml
```

Connects as `homekube`. Runs `sync_authorized_keys` and `verify_sshd_config` — should report zero changes.

### Step 4 — K8s node prerequisites

```bash
ansible-playbook 22-k8s-nodes.yml
```

Configures all four pis:

- Static IP on the switch plane (`10.0.0.2x`) via nmcli
- Inter-node `/etc/hosts` for k8s internal resolution
- cgroup v2 + memory cgroup in `cmdline.txt`
- `overlay` and `br_netfilter` kernel modules + sysctl params
- containerd at pinned version
- `kubeadm` / `kubelet` / `kubectl` at pinned version
- 4 GiB swapfile at `/var/swap.img` (persisted in fstab)

### Step 5 — Acceptance check

```bash
ssh homekube@pi0 "sudo kubeadm init --dry-run --ignore-preflight-errors=Swap"
```

Should exit 0 with no FATAL preflight errors. Swap is ignored deliberately — kubelet swap config is provided in Phase 4 via `kubeadm-config.yaml`.

---

## Kylo SSH Access

Kylo gets key-based access to the pis but Ansible is not run from kylo. Add this one-time stanza to `~/.ssh/config` on kylo:

```
Host pi0
  HostName pi0
  User homekube
  IdentityFile ~/.ssh/id_kylo_homekube
  StrictHostKeyChecking accept-new

Host pi1
  HostName pi1
  User homekube
  IdentityFile ~/.ssh/id_kylo_homekube
  StrictHostKeyChecking accept-new

Host pi2
  HostName pi2
  User homekube
  IdentityFile ~/.ssh/id_kylo_homekube
  StrictHostKeyChecking accept-new

Host pi3
  HostName pi3
  User homekube
  IdentityFile ~/.ssh/id_kylo_homekube
  StrictHostKeyChecking accept-new
```

---

## Vault

`ansible/group_vars/raspberry_pis.yml` contains a vault-encrypted `tailscale_auth_key`.

```bash
# Decrypt for editing
ansible-vault decrypt ansible/group_vars/raspberry_pis.yml

# Re-encrypt after editing
ansible-vault encrypt ansible/group_vars/raspberry_pis.yml
```

---

## Verification

After Step 4, confirm the cluster is ready for `kubeadm init`:

```bash
# Connectivity
ansible all -m ping

# User + auth state
ansible all -b -a 'passwd -S boot'                             # L on all pis
ansible all -b -a 'grep PasswordAuthentication /etc/ssh/sshd_config'  # no

# Swap
ansible all -a 'swapon --show'                                 # /var/swap.img 4G

# K8s packages
ansible all -a 'kubelet --version'
ansible all -a 'containerd --version'
ansible all -b -a 'systemctl is-active containerd'             # active

# Key inventory
ls roles/raspberry-pi/files/pub_keys/                          # 6 files
```
