# NVMe Setup — SD Card to NVMe Boot

Clones the running SD card to NVMe using rsync. Creates fresh PARTUUIDs on the NVMe (avoiding PARTUUID collision when both disks are present), then updates fstab and cmdline.txt to match.

Run after pi is on Tailscale and NVMe is physically attached (see `01_bootstrap.md` Step 6). See DECISION-005 (rsync over dd/rpi-clone).

---

## Steps

### Step 1 — Update all packages

```bash
ssh boot@piN
sudo apt-get update && sudo apt-get full-upgrade -y
sudo reboot
```

### Step 2 — Enable PCIe and update bootloader

```bash
sudo apt-get install -y rpi-eeprom
sudo rpi-eeprom-update -a
```

Add to `/boot/firmware/config.txt` under `[all]`:
```
dtparam=pciex1
dtparam=pciex1_gen=3
```

```bash
sudo reboot
```

### Step 3 — [HUMAN CHECKPOINT] Attach NVMe

```bash
sudo shutdown now
```

Physically attach NVMe to Pimoroni base, power back on.

### Step 4 — Verify NVMe detected

```bash
lsblk   # must show nvme0n1 before proceeding
```

### Step 5 — Partition and format NVMe

```bash
# Wipe any existing partition table
sudo wipefs -a /dev/nvme0n1

# Create partitions: 512M vfat boot, rest ext4 root
# MBR (msdos) — Pi5 firmware boots cleanly from MBR; matches SD format
sudo parted -s /dev/nvme0n1 mklabel msdos
sudo parted -s /dev/nvme0n1 mkpart primary fat32 1MiB 513MiB
sudo parted -s /dev/nvme0n1 set 1 boot on
sudo parted -s /dev/nvme0n1 mkpart primary ext4 513MiB 100%

# Format
sudo mkfs.vfat -F 32 /dev/nvme0n1p1
sudo mkfs.ext4 /dev/nvme0n1p2
```

### Step 6 — Clone SD → NVMe via rsync

```bash
sudo mkdir -p /mnt/clone/boot/firmware
sudo mount /dev/nvme0n1p2 /mnt/clone
sudo mount /dev/nvme0n1p1 /mnt/clone/boot/firmware

# Sync root (excludes /proc, /sys, /dev, /run, /boot/firmware via -x)
sudo rsync -axH --delete --exclude=/mnt / /mnt/clone/

# Sync boot partition
sudo rsync -axH --delete /boot/firmware/ /mnt/clone/boot/firmware/
```

### Step 7 — Fix UUIDs

```bash
BOOT_PARTUUID=$(sudo blkid -s PARTUUID -o value /dev/nvme0n1p1)
ROOT_PARTUUID=$(sudo blkid -s PARTUUID -o value /dev/nvme0n1p2)

sudo sed -i "s|PARTUUID=.*-01|PARTUUID=${BOOT_PARTUUID}|g" /mnt/clone/etc/fstab
sudo sed -i "s|PARTUUID=.*-02|PARTUUID=${ROOT_PARTUUID}|g" /mnt/clone/etc/fstab
sudo sed -i "s|root=PARTUUID=[^ ]*|root=PARTUUID=${ROOT_PARTUUID}|" /mnt/clone/boot/firmware/cmdline.txt

# Verify
cat /mnt/clone/etc/fstab
cat /mnt/clone/boot/firmware/cmdline.txt

sudo umount /mnt/clone/boot/firmware && sudo umount /mnt/clone
```

### Step 8 — Set boot order: NVMe first, SD fallback

```bash
sudo rpi-eeprom-config > /tmp/bootconf.txt
sudo sed -i 's/BOOT_ORDER=.*/BOOT_ORDER=0xf16/' /tmp/bootconf.txt
sudo rpi-eeprom-config --apply /tmp/bootconf.txt
sudo reboot
```

### Step 9 — Verify NVMe boot

```bash
sudo shutdown now
```

Remove SD card, power on. Verify:

```bash
findmnt /   # must show /dev/nvme0n1p2
```

### Step 10 — Verify SD fallback

Insert SD card, power on. Verify:

```bash
findmnt /   # must show /dev/mmcblk0p2
```

---

## Status

| Pi  | NVMe cloned | Boots from NVMe | SD fallback verified |
|-----|-------------|-----------------|----------------------|
| pi0 | done        | done            | done                 |
| pi1 | done        | done            | done                 |
| pi2 | done        | done            | done                 |
| pi3 | done        | done            | done                 |
