# Bootstrap — Imager + Tailscale + WiFi

Each pi is bootstrapped individually: flash with Raspberry Pi Imager, join Tailscale, add permanent WiFi networks. No automation runs until all pis are reachable over Tailscale.

See DECISION-006 (Tailscale as management plane) and DECISION-007 (Imager + manual nmcli).

---

## Per-Pi Steps

### Step 1 — Flash SD card (Raspberry Pi Imager)

- Device: Raspberry Pi 5
- OS: Raspberry Pi OS Lite (64-bit)
- Hostname: `piN` (pi0–pi3)
- Username: `boot`, Password: `boot`
- SSH: enabled
- WiFi: current network (hotel/home/hotspot — wherever you are at flash time)

### Step 2 — First boot

Insert SD, power on. Wait ~5 min for cloud-init to complete.

### Step 3 — SSH in

```
ssh boot@piN.local
```

If mDNS doesn't resolve yet: `arp -a` to find the IP.

### Step 4 — Install Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --authkey=<key> --hostname=piN
```

Auth key is in ansible-vault (`ansible/group_vars/raspberry_pis.yml`). Verify with `tailscale ip` — should show a `100.x.x.x` address and appear in the Tailscale admin console.

### Step 5 — Add permanent WiFi networks

```bash
# Home WiFi — highest priority
sudo nmcli con add type wifi ifname wlan0 con-name "home" \
  ssid "<HOME_SSID>" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "<HOME_PSK>" \
  connection.autoconnect yes connection.autoconnect-priority 100

# Phone hotspot — permanent fallback
sudo nmcli con add type wifi ifname wlan0 con-name "phone-hotspot" \
  ssid "<HOTSPOT_SSID>" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "<HOTSPOT_PSK>" \
  connection.autoconnect yes connection.autoconnect-priority 10
```

Pi will now reconnect to home WiFi (or hotspot) whenever the bootstrap network is unavailable.

### Step 6 — Attach NVMe (physical)

```
sudo shutdown now
```

Physically attach 1TB NVMe to Pimoroni base, then power back on. Pi stays on SD card until `02_nvme.md` steps run.

---

## Status

| Pi  | Tailscale | WiFi | NVMe attached |
|-----|-----------|------|---------------|
| pi0 | done      | done |               |
| pi1 | done      | done |               |
| pi2 | done      | done |               |
| pi3 | pending   |      |               |
