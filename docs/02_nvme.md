# NVMe Setup — SD Card to NVMe Boot

Clones the running SD card to NVMe using rsync. Mostly automated with Ansible; two steps require physical hardware access.

Run one pi at a time using `--limit piN`. The pi must already be on Tailscale (`01_bootstrap.md`).

See DECISION-005 (rsync over dd/rpi-clone).

---

## Steps

### Step 1 — [Manual] Update packages and bootloader

```bash
ssh boot@piN
sudo apt-get update && sudo apt-get full-upgrade -y
sudo apt-get install -y rpi-eeprom
sudo rpi-eeprom-update -a
sudo reboot
```

Wait for the pi to come back up before continuing.

### Step 2 — [Ansible] Enable PCIe

From `homekube-main/ansible/`:

```bash
ansible-playbook 10-nvme.yml --tags nvme_pre --limit piN -u boot -k
```

Adds `dtparam=pciex1` and `dtparam=pciex1_gen=3` to `/boot/firmware/config.txt`. The `-u boot -k` flags are required — `homekube` user doesn't exist yet.

### Step 3 — [Manual] Reboot, then shut down for NVMe attach

```bash
ssh boot@piN sudo reboot
```

Wait for the pi to come back up (PCIe now active). Then shut down for the physical step:

```bash
ssh boot@piN sudo shutdown now
```

### Step 4 — [HUMAN CHECKPOINT] Attach NVMe

Physically attach the NVMe to the Pimoroni base, then power on. Wait for the pi to come back up over Tailscale.

Verify NVMe is detected:
```bash
ssh boot@piN lsblk   # must show nvme0n1
```

### Step 5 — [Ansible] Clone SD → NVMe

From `homekube-main/ansible/`:

```bash
ansible-playbook 10-nvme.yml --tags nvme_post --limit piN -u boot -k
```

This run: partitions and formats the NVMe, clones SD → NVMe via rsync, patches `fstab` and `cmdline.txt` with fresh NVMe PARTUUIDs, verifies the patches, sets boot order to NVMe-first with SD fallback (`0xf16`), then reboots. Ansible waits for the pi to come back up.

If the pi was already migrated (e.g. re-running after a successful clone), the task short-circuits cleanly.

### Step 6 — [HUMAN CHECKPOINT] Remove SD card and verify

```bash
ssh boot@piN sudo shutdown now
```

Remove the SD card. Power on. Verify:

```bash
ssh boot@piN findmnt /   # must show /dev/nvme0n1p2
```

---

## Recovery

| Failure | Recovery |
|---------|----------|
| `nvme_post` fails mid-clone (rsync interrupted) | Re-run — rsync resumes, UUID patches are idempotent |
| NVMe has unexpected existing partitions | Re-run with `-e nvme_force_wipe=true` |
| Pi doesn't boot after SD removal | Reinsert SD (boot order has SD fallback); check `findmnt /` on SD boot |

---

## Status

| Pi  | NVMe cloned | Boots from NVMe | SD fallback verified |
|-----|-------------|-----------------|----------------------|
| pi0 | done        | done            | done                 |
| pi1 | done        | done            | done                 |
| pi2 | done        | done            | done                 |
| pi3 | done        | done            | done                 |
