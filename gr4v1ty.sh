#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
#  gr4v1ty — Pi-hole Setup Tool for Termux (Android)
#  Developer : 0xb0rn3 | oxbv1
#  Repository: https://github.com/0xb0rn3/gr4v1ty
#  License   : MIT
# =============================================================================
#
#  USAGE:
#    chmod +x gr4v1ty.sh && ./gr4v1ty.sh
#
#  REQUIREMENTS:
#    - Rooted Android device (Magisk recommended)
#    - Termux installed
#    - Internet connection
# =============================================================================

set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
R='\033[0;31m'   # Red
G='\033[0;32m'   # Green
Y='\033[0;33m'   # Yellow
B='\033[0;34m'   # Blue
C='\033[0;36m'   # Cyan
W='\033[1;37m'   # White bold
M='\033[0;35m'   # Magenta
NC='\033[0m'     # Reset

# ─── Paths ────────────────────────────────────────────────────────────────────
TERMUX_BIN="/data/data/com.termux/files/usr/bin"
TERMUX_HOME="/data/data/com.termux/files/home"
STARTUP_SCRIPT="$TERMUX_HOME/start_pihole.sh"
ZSHRC="$TERMUX_HOME/.zshrc"
BASHRC="$TERMUX_HOME/.bashrc"

# ─── Globals ──────────────────────────────────────────────────────────────────
DISTRO=""
PIHOLE_PASS=""
TABLET_IP=""
PROOT_DISTRO_NAME=""

# ─── Helpers ──────────────────────────────────────────────────────────────────
banner() {
  clear
  echo -e "${C}"
  cat << 'BANNER'
  ██████╗ ██████╗ ██╗  ██╗██╗   ██╗██╗████████╗██╗   ██╗
 ██╔════╝ ██╔══██╗██║  ██║██║   ██║██║╚══██╔══╝╚██╗ ██╔╝
 ██║  ███╗██████╔╝███████║██║   ██║██║   ██║    ╚████╔╝
 ██║   ██║██╔══██╗╚════██║╚██╗ ██╔╝██║   ██║     ╚██╔╝
 ╚██████╔╝██║  ██║     ██║ ╚████╔╝ ██║   ██║      ██║
  ╚═════╝ ╚═╝  ╚═╝     ╚═╝  ╚═══╝  ╚═╝   ╚═╝      ╚═╝
BANNER
  echo -e "${NC}"
  echo -e "  ${W}Pi-hole Setup Tool for Termux${NC}   ${M}by 0xb0rn3 | oxbv1${NC}"
  echo -e "  ${B}https://github.com/0xb0rn3/gr4v1ty${NC}"
  echo -e "  ${Y}─────────────────────────────────────────────────${NC}"
  echo ""
}

info()    { echo -e "  ${B}[*]${NC} $1"; }
ok()      { echo -e "  ${G}[✓]${NC} $1"; }
warn()    { echo -e "  ${Y}[!]${NC} $1"; }
err()     { echo -e "  ${R}[✗]${NC} $1"; }
step()    { echo -e "\n  ${C}[>]${NC} ${W}$1${NC}"; }
ask()     { echo -e "  ${M}[?]${NC} $1"; }

die() {
  err "$1"
  exit 1
}

# Run command inside proot as root
proot_exec() {
  su -c "PATH=${TERMUX_BIN}:\$PATH \
    proot-distro login ${PROOT_DISTRO_NAME} --user root -- \
    bash -c '$1'" 2>/dev/null
}

# Run command inside proot with heredoc
proot_script() {
  local script="$1"
  su -c "PATH=${TERMUX_BIN}:\$PATH \
    proot-distro login ${PROOT_DISTRO_NAME} --user root -- \
    bash -s" 2>/dev/null << PSCRIPT
${script}
PSCRIPT
}

# ─── Step 0: Root Check ───────────────────────────────────────────────────────
check_root() {
  step "Checking for root access"

  if ! command -v su &>/dev/null; then
    die "su binary not found. Is Magisk installed?"
  fi

  local uid
  uid=$(su -c "id -u" 2>/dev/null) || uid=""

  if [[ "$uid" != "0" ]]; then
    err "Root access denied or unavailable."
    echo ""
    echo -e "  ${Y}Troubleshooting:${NC}"
    echo -e "  1. Open ${W}Magisk${NC} → Superuser tab"
    echo -e "  2. Grant Termux root access"
    echo -e "  3. Re-run this script"
    exit 1
  fi

  ok "Root confirmed (Magisk)"
}

# ─── Step 1: Check/Install proot-distro ───────────────────────────────────────
check_proot() {
  step "Checking Termux dependencies"

  pkg update -y &>/dev/null || warn "Package update had errors (continuing)"

  local need_install=()
  for pkg in proot-distro curl wget; do
    if ! command -v "$pkg" &>/dev/null 2>&1; then
      need_install+=("$pkg")
    fi
  done

  if [[ ${#need_install[@]} -gt 0 ]]; then
    info "Installing: ${need_install[*]}"
    pkg install -y "${need_install[@]}" &>/dev/null
  fi

  ok "Dependencies satisfied"
}

# ─── Step 2: Distro Selection ─────────────────────────────────────────────────
select_distro() {
  step "Select Linux distribution for Pi-hole"
  echo ""
  echo -e "  ${W}  1)${NC} ${G}Arch Linux${NC}  ${Y}(recommended — lightweight)${NC}"
  echo -e "  ${W}  2)${NC} ${B}Debian${NC}      ${Y}(official Pi-hole support)${NC}"
  echo ""

  while true; do
    ask "Enter choice [1/2]: "
    read -r choice
    case "$choice" in
      1)
        DISTRO="arch"
        PROOT_DISTRO_NAME="archlinux"
        ok "Selected: Arch Linux"
        break
        ;;
      2)
        DISTRO="debian"
        PROOT_DISTRO_NAME="debian"
        ok "Selected: Debian"
        break
        ;;
      *)
        warn "Invalid choice. Enter 1 or 2."
        ;;
    esac
  done
}

# ─── Step 3: Install/Verify Distro ────────────────────────────────────────────
install_distro() {
  step "Setting up $PROOT_DISTRO_NAME container"

  local installed
  installed=$(proot-distro list 2>/dev/null | grep -c "$PROOT_DISTRO_NAME" || echo "0")

  if [[ "$installed" -gt 0 ]]; then
    ok "$PROOT_DISTRO_NAME already installed"
    return
  fi

  info "Installing $PROOT_DISTRO_NAME (this may take a few minutes)..."
  proot-distro install "$PROOT_DISTRO_NAME" || die "Failed to install $PROOT_DISTRO_NAME"
  ok "$PROOT_DISTRO_NAME installed"
}

# ─── Step 4: Arch-specific setup ──────────────────────────────────────────────
setup_arch() {
  step "Configuring Arch Linux environment"

  info "Updating packages..."
  proot_exec "pacman -Syu --noconfirm" &>/dev/null || warn "pacman update had errors"

  info "Installing dependencies..."
  proot_exec "pacman -S --noconfirm --needed \
    git curl wget iproute2 procps-ng lighttpd \
    php php-sqlite php-cgi php-gd sudo grep sed \
    findutils coreutils net-tools bind python sqlite" &>/dev/null \
    || warn "Some packages may have failed"

  info "Faking Debian OS identity for Pi-hole installer..."
  proot_script "cat > /etc/os-release << 'EOF'
ID=debian
ID_LIKE=debian
NAME=\"Debian GNU/Linux\"
PRETTY_NAME=\"Debian GNU/Linux 11 (bullseye)\"
VERSION_ID=\"11\"
EOF"

  info "Installing systemctl shim..."
  proot_script "cat > /usr/local/bin/systemctl << 'EOF'
#!/bin/bash
ARGS=()
for arg in \"\$@\"; do
  [[ \"\$arg\" != \"-q\" ]] && ARGS+=(\"\$arg\")
done
CMD=\"\${ARGS[0]:-}\"; SERVICE=\"\${ARGS[1]:-}\"
case \"\$CMD\" in
  start|restart|enable|stop|disable|daemon-reload|reload-or-restart)
    echo \"[shim] \$CMD \$SERVICE — no-op\"
    exit 0 ;;
  is-active|is-enabled|status)
    echo \"active\"
    exit 0 ;;
  *)
    exit 0 ;;
esac
EOF
chmod +x /usr/local/bin/systemctl
ln -sf /usr/local/bin/systemctl /usr/local/bin/service"

  info "Installing apt-get shim..."
  proot_script "cat > /usr/local/bin/apt-get << 'EOF'
#!/bin/bash
case \"\$1\" in
  update)
    pacman -Sy --noconfirm 2>/dev/null ;;
  install)
    shift
    PKGS=\$(echo \"\$@\" | sed 's/-[a-zA-Z]//g; s/--[a-z-]*//g')
    pacman -S --noconfirm --needed \$PKGS 2>/dev/null || true ;;
  upgrade)
    pacman -Su --noconfirm 2>/dev/null ;;
  remove|purge)
    shift
    pacman -R --noconfirm \"\$@\" 2>/dev/null || true ;;
  *)
    exit 0 ;;
esac
EOF
chmod +x /usr/local/bin/apt-get
ln -sf /usr/local/bin/apt-get /usr/local/bin/apt"

  proot_exec "mkdir -p /etc/init.d"
  ok "Arch Linux environment ready"
}

# ─── Step 5: Debian-specific setup ────────────────────────────────────────────
setup_debian() {
  step "Configuring Debian environment"

  info "Updating packages..."
  proot_exec "apt-get update -y" &>/dev/null || warn "apt update had errors"
  proot_exec "apt-get install -y curl wget git sudo" &>/dev/null || warn "Some packages failed"

  info "Installing systemctl shim..."
  proot_script "cat > /usr/local/bin/systemctl << 'EOF'
#!/bin/bash
ARGS=()
for arg in \"\$@\"; do
  [[ \"\$arg\" != \"-q\" ]] && ARGS+=(\"\$arg\")
done
CMD=\"\${ARGS[0]:-}\"; SERVICE=\"\${ARGS[1]:-}\"
case \"\$CMD\" in
  start|restart|enable|stop|disable|daemon-reload|reload-or-restart)
    echo \"[shim] \$CMD \$SERVICE — no-op\"
    exit 0 ;;
  is-active|is-enabled|status)
    echo \"active\"
    exit 0 ;;
  *)
    exit 0 ;;
esac
EOF
chmod +x /usr/local/bin/systemctl
ln -sf /usr/local/bin/systemctl /usr/local/bin/service"

  proot_exec "mkdir -p /etc/init.d"
  ok "Debian environment ready"
}

# ─── Step 6: Install Pi-hole ──────────────────────────────────────────────────
install_pihole() {
  step "Installing Pi-hole"
  info "Downloading Pi-hole installer..."

  proot_exec "curl -sSL https://install.pi-hole.net -o /tmp/install.sh" \
    || die "Failed to download Pi-hole installer"

  info "Running Pi-hole installer (interactive)..."
  echo ""
  warn "The Pi-hole installer will now run interactively."
  echo -e "  ${W}When prompted:${NC}"
  echo -e "  • Upstream DNS  → ${G}Cloudflare (option 3)${NC} or your preference"
  echo -e "  • Blocklists    → ${G}Keep defaults${NC}"
  echo -e "  • IPv6          → ${Y}No${NC}"
  echo -e "  • Web interface → ${G}Yes${NC}"
  echo -e "  • Logging       → ${G}Yes${NC}"
  echo -e "  • Privacy level → ${G}0 (show everything)${NC}"
  echo ""
  ask "Press ENTER to launch the installer..."
  read -r

  su -c "PATH=${TERMUX_BIN}:\$PATH \
    proot-distro login ${PROOT_DISTRO_NAME} --user root -- \
    bash -c 'PIHOLE_SKIP_OS_CHECK=true bash /tmp/install.sh'"

  ok "Pi-hole installation complete"
}

# ─── Step 7: Post-install fixes ───────────────────────────────────────────────
fix_pihole() {
  step "Applying post-install configuration"

  info "Creating log directories..."
  proot_exec "mkdir -p /var/log/pihole && \
    touch /var/log/pihole/FTL.log \
          /var/log/pihole/pihole.log \
          /var/log/pihole/webserver.log && \
    chown -R pihole:pihole /var/log/pihole 2>/dev/null || true"

  info "Fixing pihole.toml interface config..."
  proot_exec "sed -i 's/^  interface = \"lo\"/  interface = \"\"/' /etc/pihole/pihole.toml 2>/dev/null || true"
  proot_exec "sed -i 's/^  port = \"8080o\"/  port = \"80o,443os,\[::]:80o,\[::]:443os\"/' /etc/pihole/pihole.toml 2>/dev/null || true"

  info "Installing bind-tools (dig)..."
  if [[ "$DISTRO" == "arch" ]]; then
    proot_exec "pacman -S --noconfirm bind 2>/dev/null || true" &>/dev/null
  else
    proot_exec "apt-get install -y dnsutils 2>/dev/null || true" &>/dev/null
  fi

  ok "Configuration applied"
}

# ─── Step 8: Build startup script ─────────────────────────────────────────────
build_startup() {
  step "Creating startup script"

  cat > "$STARTUP_SCRIPT" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# gr4v1ty — Pi-hole Auto-Start
# Generated by gr4v1ty.sh

TERMUX_BIN="/data/data/com.termux/files/usr/bin"
PROOT_DISTRO="${PROOT_DISTRO_NAME}"

# Kill any existing FTL instance
su -c "PATH=\${TERMUX_BIN}:\$PATH \\
  proot-distro login \${PROOT_DISTRO} --user root -- \\
  bash -c 'pkill -f pihole-FTL 2>/dev/null; sleep 1'" 2>/dev/null || true

sleep 1

# Start FTL
su -c "PATH=\${TERMUX_BIN}:\$PATH \\
  proot-distro login \${PROOT_DISTRO} --user root -- \\
  /usr/bin/pihole-FTL no-daemon" > /dev/null 2>&1 &

disown \$!
termux-wake-lock 2>/dev/null || true

echo "[gr4v1ty] Pi-hole started on \$(date '+%H:%M:%S')"
EOF

  chmod +x "$STARTUP_SCRIPT"
  ok "Startup script: $STARTUP_SCRIPT"
}

# ─── Step 9: Configure shell autostart ────────────────────────────────────────
configure_autostart() {
  step "Configuring shell autostart"

  local autostart_block="
# ── gr4v1ty Pi-hole autostart ──
if [ -z \"\$PIHOLE_STARTED\" ]; then
  export PIHOLE_STARTED=1
  \$HOME/start_pihole.sh &>/dev/null &
fi
# ── end gr4v1ty ──"

  # Add to both .zshrc and .bashrc if they exist
  for rc in "$ZSHRC" "$BASHRC"; do
    if [[ -f "$rc" ]]; then
      # Remove old gr4v1ty block if present
      sed -i '/── gr4v1ty Pi-hole autostart ──/,/── end gr4v1ty ──/d' "$rc" 2>/dev/null || true
      echo "$autostart_block" >> "$rc"
      ok "Autostart added to $rc"
    fi
  done

  # If neither exists, create .bashrc
  if [[ ! -f "$ZSHRC" && ! -f "$BASHRC" ]]; then
    echo "$autostart_block" > "$BASHRC"
    ok "Created $BASHRC with autostart"
  fi
}

# ─── Step 10: Get LAN IP ──────────────────────────────────────────────────────
get_ip() {
  TABLET_IP=$(proot_exec "ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print \$2}' | head -1") \
    || TABLET_IP=""

  if [[ -z "$TABLET_IP" ]]; then
    TABLET_IP=$(ip route 2>/dev/null | grep -oP 'src \K[\d.]+' | head -1) || TABLET_IP="<your-tablet-ip>"
  fi
}

# ─── Step 11: Get Pi-hole password ────────────────────────────────────────────
get_password() {
  PIHOLE_PASS=$(proot_exec "grep -oP 'Web Interface password: \K\S+' /etc/pihole/install.log 2>/dev/null || \
    grep -oP 'password: \K\S+' /var/log/pihole/FTL.log 2>/dev/null") || PIHOLE_PASS="(check /etc/pihole/install.log)"
}

# ─── Step 12: Test launch ─────────────────────────────────────────────────────
test_launch() {
  step "Starting Pi-hole"
  info "Launching FTL..."

  bash "$STARTUP_SCRIPT"
  sleep 6

  info "Testing DNS resolution..."
  local google_ip
  google_ip=$(dig @127.0.0.1 google.com +short 2>/dev/null | head -1) || google_ip=""

  local dc_ip
  dc_ip=$(dig @127.0.0.1 doubleclick.net +short 2>/dev/null | head -1) || dc_ip=""

  echo ""
  if [[ -n "$google_ip" ]]; then
    ok "DNS resolution working  (google.com → $google_ip)"
  else
    warn "DNS test inconclusive — Pi-hole may still be starting"
  fi

  if [[ "$dc_ip" == "0.0.0.0" ]] || [[ -z "$dc_ip" ]]; then
    ok "Ad blocking active      (doubleclick.net → BLOCKED)"
  else
    warn "Blocking test inconclusive"
  fi
}

# ─── Step 13: Print summary ───────────────────────────────────────────────────
print_summary() {
  get_ip
  get_password

  echo ""
  echo -e "  ${C}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "  ${C}║${NC}  ${G}gr4v1ty — Pi-hole Setup Complete${NC}                    ${C}║${NC}"
  echo -e "  ${C}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "  ${C}║${NC}  ${W}Web Dashboard${NC}                                         ${C}║${NC}"
  echo -e "  ${C}║${NC}    http://${TABLET_IP}/admin                              ${C}║${NC}"
  echo -e "  ${C}║${NC}    Password: ${Y}${PIHOLE_PASS}${NC}                              ${C}║${NC}"
  echo -e "  ${C}║${NC}                                                        ${C}║${NC}"
  echo -e "  ${C}║${NC}  ${W}DNS Server${NC}                                            ${C}║${NC}"
  echo -e "  ${C}║${NC}    ${G}${TABLET_IP}${NC} (port 53)                         ${C}║${NC}"
  echo -e "  ${C}║${NC}                                                        ${C}║${NC}"
  echo -e "  ${C}║${NC}  ${W}Startup Script${NC}                                        ${C}║${NC}"
  echo -e "  ${C}║${NC}    ~/start_pihole.sh                                   ${C}║${NC}"
  echo -e "  ${C}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${Y}─── Router Setup (Network-wide) ──────────────────────${NC}"
  echo -e "  ${W}1.${NC} Open router admin: ${C}http://192.168.0.1${NC} or ${C}http://192.168.1.1${NC}"
  echo -e "  ${W}2.${NC} Login with your router credentials"
  echo -e "  ${W}3.${NC} Find: ${C}LAN / DHCP / DNS Settings${NC} (varies by router)"
  echo -e "      ${Y}Common paths:${NC}"
  echo -e "      • Most routers:  LAN Settings → DHCP → DNS"
  echo -e "      • TP-Link:       DHCP → DHCP Settings → Primary DNS"
  echo -e "      • Netgear:       Advanced → Setup → LAN Setup → DNS"
  echo -e "      • OpenWrt:       Network → Interfaces → LAN → DHCP → DNS"
  echo -e "      • ZLT W304VA Pro: LAN Settings → DHCP Server → DNS"
  echo -e "  ${W}4.${NC} Set Primary DNS → ${G}${TABLET_IP}${NC}"
  echo -e "  ${W}5.${NC} Set Secondary DNS → ${Y}1.1.1.1${NC} (fallback if Pi-hole is down)"
  echo -e "  ${W}6.${NC} Save → Reboot router → Reconnect all devices"
  echo ""
  echo -e "  ${Y}─── Per-Device Setup (if router DNS unsupported) ─────${NC}"
  echo -e "  ${W}Android:${NC} WiFi → long-press → Modify → Advanced → DNS1 = ${G}${TABLET_IP}${NC}"
  echo -e "  ${W}Windows:${NC} Network Adapter → IPv4 Properties → DNS = ${G}${TABLET_IP}${NC}"
  echo -e "  ${W}Linux:${NC}   echo 'nameserver ${TABLET_IP}' | sudo tee /etc/resolv.conf"
  echo -e "  ${W}macOS:${NC}   System Settings → Network → DNS → + → ${G}${TABLET_IP}${NC}"
  echo ""
  echo -e "  ${Y}─── Management Commands (inside proot) ───────────────${NC}"
  echo -e "  ${W}Start:${NC}    ~/start_pihole.sh"
  echo -e "  ${W}Update:${NC}   pihole -up"
  echo -e "  ${W}Gravity:${NC}  pihole -g"
  echo -e "  ${W}Status:${NC}   pihole status"
  echo -e "  ${W}Password:${NC} pihole setpassword"
  echo ""
  echo -e "  ${G}Pi-hole is running and blocking ads network-wide.${NC}"
  echo -e "  ${B}github.com/0xb0rn3/gr4v1ty${NC}"
  echo ""
}

# ─── Ask user whether to run now ──────────────────────────────────────────────
ask_run() {
  echo ""
  step "Ready to launch"
  ask "Start Pi-hole now? [Y/n]: "
  read -r run_now

  case "${run_now,,}" in
    n|no)
      info "Skipping launch. Run manually with: ${W}~/start_pihole.sh${NC}"
      ;;
    *)
      test_launch
      ;;
  esac
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  banner

  echo -e "  ${W}This tool will:${NC}"
  echo -e "  • Verify root access"
  echo -e "  • Install a Linux container via proot-distro"
  echo -e "  • Deploy Pi-hole as a network-wide DNS ad blocker"
  echo -e "  • Configure autostart on Termux launch"
  echo ""
  ask "Press ENTER to begin or Ctrl+C to cancel..."
  read -r

  check_root
  check_proot
  select_distro
  install_distro

  if [[ "$DISTRO" == "arch" ]]; then
    setup_arch
  else
    setup_debian
  fi

  install_pihole
  fix_pihole
  build_startup
  configure_autostart
  ask_run
  print_summary
}

main "$@"
