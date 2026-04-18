# gr4v1ty

> **Network-wide ad blocking on Android via Pi-hole + Termux**
> Automated setup tool for rooted Android devices.

```
  ██████╗ ██████╗ ██╗  ██╗██╗   ██╗██╗████████╗██╗   ██╗
 ██╔════╝ ██╔══██╗██║  ██║██║   ██║██║╚══██╔══╝╚██╗ ██╔╝
 ██║  ███╗██████╔╝███████║██║   ██║██║   ██║    ╚████╔╝
 ██║   ██║██╔══██╗╚════██║╚██╗ ██╔╝██║   ██║     ╚██╔╝
 ╚██████╔╝██║  ██║     ██║ ╚████╔╝ ██║   ██║      ██║
  ╚═════╝ ╚═╝  ╚═╝     ╚═╝  ╚═══╝  ╚═╝   ╚═╝      ╚═╝
```

**Developer:** 0xb0rn3 | oxbv1  
**Repository:** [github.com/0xb0rn3/gr4v1ty](https://github.com/0xb0rn3/gr4v1ty)  
**License:** MIT

---

## What is this?

`gr4v1ty` deploys a fully functional [Pi-hole](https://pi-hole.net) instance on a **rooted Android device** using Termux and proot-distro. Once running, your Android device acts as a DNS server for your entire network — blocking ads, trackers, and malicious domains before they ever reach any device.

It handles everything: container setup, OS shimming, Pi-hole installation, FTL configuration, and autostart — all from a single script.

---

## Requirements

| Requirement | Details |
|---|---|
| Android | 10+ (tested on Android 14) |
| Root | Magisk (required for port 53 binding + netlink) |
| Termux | Latest from [F-Droid](https://f-droid.org/en/packages/com.termux/) |
| Termux:API | Optional (for `termux-wake-lock`) |
| Architecture | arm64 / aarch64 |
| Internet | Required during setup |

> ⚠️ **Do NOT install Termux from the Google Play Store.** Use F-Droid. The Play Store version is outdated and unsupported.

---

## Installation

### 1. Grant Termux root access

Open **Magisk** → **Superuser** tab → find **Termux** → grant root access.

### 2. Clone and run

```bash
pkg update && pkg install -y git
git clone https://github.com/0xb0rn3/gr4v1ty
cd gr4v1ty
chmod +x gr4v1ty.sh
./gr4v1ty.sh
```

### 3. Follow the prompts

The script will ask:

- **Distro:** Arch Linux (recommended) or Debian
- **Pi-hole installer:** runs interactively — use defaults unless you know what you're doing
- **Launch now?:** Start Pi-hole immediately after setup

---

## What the Script Does

```
[*] Root check         — Verifies Magisk su access
[*] Install deps       — proot-distro, curl, wget
[*] Select distro      — Arch Linux or Debian
[*] Setup container    — proot-distro login environment
[*] Shim systemctl     — Fake systemd for Pi-hole installer
[*] Shim apt-get       — Maps to pacman (Arch only)
[*] Fake OS identity   — Pi-hole thinks it's on Debian 11
[*] Run installer      — PIHOLE_SKIP_OS_CHECK=true
[*] Fix pihole.toml    — Correct interface + port config
[*] Create startup     — ~/start_pihole.sh
[*] Configure shell    — .zshrc/.bashrc autostart block
[*] Test DNS           — Verify blocking is working
[*] Print summary      — IP, password, router instructions
```

---

## Pi-hole Installer Prompts

When the interactive Pi-hole installer runs, use these settings:

| Prompt | Recommended Choice |
|---|---|
| Upstream DNS | Cloudflare (option 3) — `1.1.1.1` / `1.0.0.1` |
| Blocklists | Keep defaults (StevenBlack Unified Hosts) |
| IPv6 | **No** |
| Web admin interface | **Yes** |
| Query logging | **Yes** |
| Privacy level | **0** — Show everything |

---

## After Setup

### Access the Web Dashboard

```
http://<your-tablet-ip>/admin
```

Password is printed at the end of setup. To change it:

```bash
# Inside proot (enter with the command below)
su -c "PATH=/data/data/com.termux/files/usr/bin:$PATH \
  proot-distro login archlinux --user root -- \
  pihole setpassword"
```

### Start / Stop Pi-hole

```bash
# Start (from Termux)
~/start_pihole.sh

# Enter proot manually
su -c "PATH=/data/data/com.termux/files/usr/bin:$PATH \
  proot-distro login archlinux --user root"

# Inside proot
pihole status
pihole -g          # Update gravity (blocklists)
pihole -up         # Update Pi-hole itself
pihole enable
pihole disable 60  # Disable for 60 seconds
```

### Keep Termux Alive

```bash
termux-wake-lock
```

Run this after opening Termux to prevent Android from killing the process.

---

## Router Setup

Point your router's DHCP DNS server at the Android device running Pi-hole. All devices on the network will automatically use Pi-hole without any per-device configuration.

### Step 1: Find your device's IP

```bash
# In Termux or proot
ifconfig | grep 'inet ' | grep -v '127.0.0.1'
```

Note the IP — typically something like `192.168.1.x` or `192.168.0.x`. Give it a static lease in your router's DHCP settings so the IP doesn't change.

### Step 2: Access your router admin panel

Most routers are reachable at one of these addresses:

```
http://192.168.0.1
http://192.168.1.1
http://192.168.2.1
http://10.0.0.1
```

Default credentials are usually printed on the router label. Common defaults: `admin` / `admin` or `admin` / `password`.

### Step 3: Set DNS in DHCP settings

Every router UI is different. Look for a section called **LAN**, **DHCP**, **DNS**, or **Network**. Common paths:

| Router / Firmware | Path |
|---|---|
| Most generic routers | LAN Settings → DHCP Server → DNS |
| TP-Link | DHCP → DHCP Settings → Primary DNS |
| Netgear | Advanced → Setup → LAN Setup → DNS |
| ASUS | LAN → DHCP Server → DNS Server 1 |
| OpenWrt | Network → Interfaces → LAN → DHCP Server → Advanced → DNS |
| DD-WRT | Setup → Basic Setup → Static DNS 1 |
| MikroTik | IP → DHCP Server → Networks → DNS Servers |
| ZLT W304VA Pro | LAN Settings → DHCP Server → Primary DNS |
| Huawei HG/B series | LAN → DHCP → Primary DNS Server |
| Vodafone/ZTE | Home Network → DNS |

Set:

| Field | Value |
|---|---|
| Primary DNS | `<your-android-ip>` |
| Secondary DNS | `1.1.1.1` ← fallback if Pi-hole goes down |

Save and apply.

### Step 4: Reboot router

Reboot so all devices get the new DNS settings via DHCP renewal.

### Step 5: Verify

```bash
# From any device on the network
nslookup doubleclick.net <android-ip>
# Should return: 0.0.0.0 (blocked)

nslookup google.com <android-ip>
# Should return: real IP (resolves normally)
```

Or open `http://<android-ip>/admin` — the query log will show all DNS requests from every device on the network.

### Note on 4G/LTE Routers (e.g. ZLT W304VA Pro + ZLT X17U ODU)

If you're using a 4G router with an external ODU/antenna unit, the ODU handles the uplink — **make DNS changes on the router's LAN/DHCP settings, not on the ODU management interface.** The ODU is just a modem; the router handles your local network and DHCP.

---

## Per-Device Setup (Alternative)

If you can't change router DNS, configure each device individually:

**Android:**
WiFi → Long press network → Modify → Advanced → IP settings: Static → DNS 1: `<tablet-ip>`

**Windows:**
Control Panel → Network Adapter → IPv4 → Use the following DNS: `<tablet-ip>`

**Linux:**
```bash
echo 'nameserver <tablet-ip>' | sudo tee /etc/resolv.conf
```

**macOS:**
System Preferences → Network → Advanced → DNS → `+` → `<tablet-ip>`

---

## Autostart

The script configures Pi-hole to start automatically when you open Termux. The autostart block added to `~/.zshrc` / `~/.bashrc`:

```bash
if [ -z "$PIHOLE_STARTED" ]; then
  export PIHOLE_STARTED=1
  ~/start_pihole.sh &>/dev/null &
fi
```

To disable autostart, remove this block from your shell rc file.

---

## Updating Blocklists

Pi-hole's blocklist (gravity) updates automatically via cron if cron is running. Manually:

```bash
# Enter proot
su -c "PATH=/data/data/com.termux/files/usr/bin:$PATH \
  proot-distro login archlinux --user root"

# Inside proot
pihole -g
```

Default blocklist: **StevenBlack Unified Hosts** (~87,000 domains)

To add more lists: **Web UI** → **Adlists** → Add URL

Recommended additional lists:

```
https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt
https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts
```

---

## Troubleshooting

### Pi-hole won't start / port 53 in use

```bash
# Check what's holding port 53
su -c "cat /proc/net/tcp6" | awk 'NR>1{printf "%d\n", "0x"substr($2,index($2,":")+1)}' | grep "^53$"

# Kill existing FTL
su -c "PATH=/data/data/com.termux/files/usr/bin:$PATH \
  proot-distro login archlinux --user root -- \
  pkill -f pihole-FTL"

# Restart
~/start_pihole.sh
```

### Root not detected

1. Open **Magisk** → **Superuser**
2. Find **Termux** and grant root
3. Run `su -c id` — should print `uid=0`

### DNS not blocking on devices

1. Confirm Pi-hole is running: `dig @<tablet-ip> doubleclick.net +short` → should return `0.0.0.0`
2. Confirm devices are using the correct DNS: check DHCP lease or manually verify DNS settings
3. Flush DNS cache on devices:
   - Windows: `ipconfig /flushdns`
   - Android: Toggle WiFi off/on
   - macOS: `sudo dscacheutil -flushcache`

### Web UI not loading

Pi-hole v6 FTL serves the web UI directly (no lighttpd needed). Check FTL is running:

```bash
su -c "PATH=/data/data/com.termux/files/usr/bin:$PATH \
  proot-distro login archlinux --user root -- \
  pgrep -a pihole-FTL"
```

If not running, start it:

```bash
~/start_pihole.sh
```

### Arch: package not found errors

```bash
su -c "PATH=/data/data/com.termux/files/usr/bin:$PATH \
  proot-distro login archlinux --user root -- \
  pacman -Sy"
```

---

## Technical Notes

### Why proot instead of chroot?

Standard `chroot` requires kernel-level root and namespace capabilities that Android restricts even on rooted devices. `proot` emulates these via `ptrace`, giving a full Linux environment without kernel modifications.

### Why does Pi-hole need Magisk root?

Pi-hole's FTL daemon (dnsmasq under the hood) requires:
- `AF_NETLINK` socket for interface enumeration
- Binding to port 53 (privileged port, requires `uid=0`)

proot's fake root (`uid=0` inside the container) is not real root — it can't open netlink sockets or bind privileged ports. Magisk provides actual kernel-level root, which proot inherits when launched via `su -c`.

### Why the systemctl shim?

Pi-hole's installer calls `systemctl` to start/enable services. Android has no systemd. The shim intercepts these calls and returns success, allowing the installer to complete. FTL is then started manually as a background process.

### Why fake `/etc/os-release`?

Pi-hole's installer checks the OS and exits if it's not a supported distro. Arch Linux is not officially supported. Faking Debian 11 identity bypasses this check. The installer's actual package operations are handled by the `apt-get → pacman` shim.

---

## File Locations

| File | Purpose |
|---|---|
| `~/start_pihole.sh` | Start/restart Pi-hole |
| `~/.zshrc` / `~/.bashrc` | Autostart block |
| `/etc/pihole/pihole.toml` | Pi-hole FTL config (inside proot) |
| `/etc/pihole/gravity.db` | Blocklist database (inside proot) |
| `/var/log/pihole/FTL.log` | FTL daemon log (inside proot) |
| `/etc/pihole/install.log` | Installation log with password |

---

## License

MIT License — use it, modify it, break things with it.

---

*Built on a Lenovo P11 Gen 2 running NetHunter, Tanzania. Respect the grind.*

**0xb0rn3 | oxbv1** — [github.com/0xb0rn3](https://github.com/0xb0rn3)
