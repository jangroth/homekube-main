# Bootstrap — Imager + Tailscale + WiFi

Each pi is bootstrapped individually: flash with Raspberry Pi Imager, join Tailscale, add permanent WiFi networks. No automation runs until all pis are reachable over Tailscale.

This is entirely manual — Ansible can't connect until Tailscale is up and the `boot` user is reachable.

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

Insert SD, power on. Wait ~2 min for first boot to complete.

### Step 3 — SSH in

```bash
ssh boot@piN.local
```

If mDNS doesn't resolve: `arp -a` to find the IP, or check your router's DHCP leases.

### Step 4 — Install Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --authkey=<key> --hostname=piN
```

Auth key is vault-encrypted in `ansible/group_vars/raspberry_pis.yml`. Decrypt with:
```bash
ansible-vault decrypt ansible/group_vars/raspberry_pis.yml
```

Verify with `tailscale ip` — should show a `100.x.x.x` address and appear in the Tailscale admin console. From darth: `ssh boot@piN` should now work over Tailscale.

### Step 5 — Add permanent WiFi networks

```bash
sudo nmcli con add type wifi ifname wlan0 con-name "home" \
  ssid "<HOME_SSID>" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "<HOME_PSK>" \
  connection.autoconnect yes

sudo nmcli con add type wifi ifname wlan0 con-name "phone-hotspot" \
  ssid "<HOTSPOT_SSID>" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "<HOTSPOT_PSK>" \
  connection.autoconnect yes
```

The pi will reconnect to any saved network on boot.

Bootstrap complete. Proceed to `02_nvme.md`.

---

## Status

| Pi  | Tailscale | WiFi |
|-----|-----------|------|
| pi0 | done      | done |
| pi1 | done      | done |
| pi2 | done      | done |
| pi3 | done      | done |
