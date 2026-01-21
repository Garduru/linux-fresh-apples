#!/usr/bin/env bash
# Linux Fresh Apples – Setup Script
# Arch/CachyOS-focused (pacman)

SCRIPT_NAME="linux-fresh-apples"
SCRIPT_VERSION="v1.0.1"

# Version flag
if [[ "${1:-}" == "--version" || "${1:-}" == "-v" ]]; then
  echo "$SCRIPT_NAME $SCRIPT_VERSION"
  exit 0
fi

set -euo pipefail

# ----------------------------- HELPER FUNCS ----------------------------------

log()  { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m!!\033[0m %s\n" "$*"; }
die()  { printf "\n\033[1;31mXX\033[0m %s\n" "$*"; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Please run with sudo:  sudo bash $0"
  fi
}

pacman_install() {
  # Installs packages only if missing (safe to rerun)
  local pkgs=("$@")
  local missing=()
  for p in "${pkgs[@]}"; do
    if ! pacman -Q "$p" >/dev/null 2>&1; then
      missing+=("$p")
    fi
  done

  if (( ${#missing[@]} )); then
    log "Installing pacman packages: ${missing[*]}"
    pacman -S --needed --noconfirm "${missing[@]}"
  else
    log "All pacman packages already installed. Skipping."
  fi
}

flatpak_install() {
  local app="$1"
  if flatpak info "$app" >/dev/null 2>&1; then
    log "Flatpak already installed: $app"
  else
    log "Installing Flatpak: $app"
    flatpak install -y flathub "$app" || warn "Failed to install $app (may not exist on Flathub for your system)."
  fi
}

enable_service() {
  local svc="$1"
  log "Enabling service: $svc"
  systemctl enable --now "$svc" || warn "Could not enable $svc (service may not exist)."
}

# -------------------------------
# Sunshine helpers
# -------------------------------

get_free_tcp_port() {
  # Picks a free TCP port by checking current listeners
  local port
  while :; do
    port="$(shuf -i 48000-49000 -n 1)"
    ss -ltn | awk '{print $4}' | grep -q ":$port$" || break
  done
  echo "$port"
}

# Run systemctl --user for a target user in a way that usually works from a sudo script
run_user_systemctl() {
  local target_user="$1"; shift
  local uid runtime bus

  uid="$(id -u "$target_user" 2>/dev/null || true)"
  if [[ -z "$uid" ]]; then
    warn "Could not determine UID for user '$target_user'."
    return 1
  fi

  runtime="/run/user/$uid"
  bus="unix:path=$runtime/bus"

  # If there is no user runtime dir, they are not logged in (or linger not enabled)
  if [[ ! -d "$runtime" ]]; then
    warn "No $runtime found (user session not active). Sunshine user service steps will be deferred."
    return 1
  fi

  sudo -u "$target_user" \
    XDG_RUNTIME_DIR="$runtime" \
    DBUS_SESSION_BUS_ADDRESS="$bus" \
    systemctl --user "$@"
}

# Write/update Sunshine config to avoid RTSP port collision (common issue)
# NOTE: Sunshine supports a simple key=value style config file at:
#   ~/.config/sunshine/sunshine.conf
# We only touch rtsp_port here (safe/minimal).
ensure_sunshine_rtsp_port() {
  local target_user="$1"
  local rtsp_port="$2"
  local cfg_dir cfg_file

  cfg_dir="$(sudo -u "$target_user" bash -lc 'echo "$HOME/.config/sunshine"' 2>/dev/null || true)"
  cfg_file="$cfg_dir/sunshine.conf"

  sudo -u "$target_user" mkdir -p "$cfg_dir"

  # If file exists, replace rtsp_port=... line; else append it.
  if sudo -u "$target_user" test -f "$cfg_file"; then
    sudo -u "$target_user" bash -lc "
      if grep -qE '^[[:space:]]*rtsp_port[[:space:]]*=' \"$cfg_file\"; then
        sed -i -E 's/^[[:space:]]*rtsp_port[[:space:]]*=.*/rtsp_port=$rtsp_port/' \"$cfg_file\"
      else
        printf '\nrtsp_port=%s\n' '$rtsp_port' >> \"$cfg_file\"
      fi
    "
  else
    sudo -u "$target_user" bash -lc "printf 'rtsp_port=%s\n' '$rtsp_port' > \"$cfg_file\""
  fi

  log "Sunshine config updated: rtsp_port=$rtsp_port (in $cfg_file)"
}

# ----------------------------- UI / INTRO ------------------------------------

echo "=========================================="
echo " Linux Fresh Apples – Setup Script ($SCRIPT_VERSION)"
echo "=========================================="
echo
echo "This script will:"
echo "  1) Update package databases"
echo "  2) Install core pacman packages (system + CLI tools)"
echo "  3) Enable Flatpak + Flathub"
echo "  4) Install your desktop apps via Flatpak (prevents duplicates)"
echo "  5) Install & configure Sunshine (Moonlight host)"
echo "     • Apply required capability (setcap) for KMS capture"
echo "     • Auto-pick a free RTSP port if the default is taken"
echo "     • Enable + start Sunshine as a user service"
echo "     • Show Sunshine Web UI URL for first-time setup"
echo "  6) Configure firewall (KDE Connect)"
echo "  7) Optionally remove duplicate pacman GUI packages"
echo
read -rp "Continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

echo
echo "Starting setup..."
echo

###############################################################################
# Linux Setup Script (Arch/CachyOS-focused)
#
# Goals:
# - Flatpak for desktop apps (avoid duplicates, works across distros)
# - Pacman for system + CLI tools
# - Optional cleanup: remove common pacman GUI apps if you prefer Flatpaks
#
# NOTE:
# - This is written for Arch/CachyOS (pacman)
###############################################################################

# ----------------------------- CONFIG SECTION --------------------------------

# Target user for user-level services/config
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || true)"

# Firewall backend
USE_FIREWALLD=true

# Flatpak apps (Flathub IDs). Preferred GUI apps to avoid duplicates
FLATPAK_APPS=(
  "com.discordapp.Discord"
  "com.valvesoftware.Steam"
  "com.obsproject.Studio"
  "org.videolan.VLC"
  "org.libreoffice.LibreOffice"
  "org.localsend.localsend_app"
  "com.vysp3r.ProtonPlus"
  "it.mijorus.gearlever"
)

# Pacman packages (CLI/system tools)
PACMAN_PKGS=(
  git
  curl
  wget
  openssh
  rsync
  timeshift
  unzip
  p7zip
  btop
  htop
  fastfetch
  firewalld
  flatpak
  libcap          # for setcap/getcap (Sunshine KMS capture)
  sunshine
)

# ----------------------------- MAIN SCRIPT -----------------------------------

ensure_sudo

log "1) Updating package databases"
pacman -Sy --noconfirm

log "2) Installing core pacman packages (system + CLI tools)"
pacman_install "${PACMAN_PKGS[@]}"

log "3) Ensuring Flatpak has Flathub enabled"
if ! flatpak remote-list | awk '{print $1}' | grep -qx "flathub"; then
  log "Adding Flathub remote"
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
else
  log "Flathub already configured"
fi

log "4) Installing your desktop apps via Flatpak (prevents duplicates)"
for app in "${FLATPAK_APPS[@]}"; do
  flatpak_install "$app"
done

# ------------------------------
# Sunshine (Moonlight host)
# ------------------------------
log "5) Installing & configuring Sunshine (Moonlight host)"

if ! have_cmd sunshine; then
  warn "Sunshine not found in PATH (install may have failed). Skipping Sunshine setup."
else
  # Resolve real binary path for setcap (sunshine is often a symlink)
  SUNSHINE_CMD="$(command -v sunshine)"
  SUNSHINE_BIN="$(readlink -f "$SUNSHINE_CMD" 2>/dev/null || echo "$SUNSHINE_CMD")"

  log "Sunshine command: $SUNSHINE_CMD"
  log "Sunshine binary:  $SUNSHINE_BIN"

  if have_cmd setcap; then
    log "Applying cap_sys_admin+p to Sunshine binary (for KMS capture support)"
    setcap cap_sys_admin+p "$SUNSHINE_BIN" || warn "setcap failed (you can retry later)."
    getcap "$SUNSHINE_BIN" || true
  else
    warn "setcap not available. (Install libcap). KMS capture may not work."
  fi

  # Auto-pick a free RTSP port to avoid the common "RTSP port 48010 already in use" error
  # Sunshine default RTSP port is commonly 48010; if something is already using it, pick another.
  DEFAULT_RTSP_PORT="48010"
  RTSP_PORT="$DEFAULT_RTSP_PORT"
  if ss -ltn | awk '{print $4}' | grep -q ":${DEFAULT_RTSP_PORT}$"; then
    RTSP_PORT="$(get_free_tcp_port)"
    warn "Default RTSP port $DEFAULT_RTSP_PORT is already in use. Using $RTSP_PORT instead."
  else
    log "RTSP port $DEFAULT_RTSP_PORT appears free."
  fi

  # Update config for the logged-in user (Sunshine user service reads user config)
  if [[ -n "$TARGET_USER" && -n "${TARGET_UID:-}" ]]; then
    ensure_sunshine_rtsp_port "$TARGET_USER" "$RTSP_PORT"
  else
    warn "Could not determine TARGET_USER / TARGET_UID; skipping Sunshine config write."
  fi

  # Enable/start Sunshine user service
  # This can fail if the user session bus isn't available yet; in that case we warn and tell them to reboot/relogin.
  if [[ -n "$TARGET_USER" ]]; then
    log "Enabling Sunshine as a user service for: $TARGET_USER"

    # Reload user units
    run_user_systemctl "$TARGET_USER" daemon-reload || true

    # Restart portal/pipewire stack to reduce first-run Wayland weirdness
    log "Restarting user portal/pipewire services (helps Wayland capture)"
    run_user_systemctl "$TARGET_USER" restart pipewire pipewire-pulse wireplumber 2>/dev/null || true
    run_user_systemctl "$TARGET_USER" restart xdg-desktop-portal xdg-desktop-portal-kde 2>/dev/null || true

    # Enable + start Sunshine
    run_user_systemctl "$TARGET_USER" enable --now sunshine || true

    log "Sunshine user-service status:"
    run_user_systemctl "$TARGET_USER" status sunshine --no-pager || true
  else
    warn "TARGET_USER not set. Can't enable Sunshine user service automatically."
  fi

  echo
  echo "Sunshine Web UI (first-time setup): https://localhost:47990"
  echo "NOTE: If Sunshine shows a red banner on first install, a reboot or re-login often fixes the session/portal bits."
fi

# --------------------------- FIREWALL + KDE CONNECT --------------------------
# KDE Connect needs ports:
# - TCP 1714-1764
# - UDP 1714-1764
if [[ "$USE_FIREWALLD" == "true" ]]; then
  log "6) Configuring firewalld for KDE Connect"
  enable_service firewalld

  # Prefer the built-in kdeconnect service if available
  if firewall-cmd --get-services | tr ' ' '\n' | grep -qx "kdeconnect"; then
    log "Adding firewalld service: kdeconnect"
    firewall-cmd --permanent --zone=public --add-service=kdeconnect || true
  else
    warn "firewalld 'kdeconnect' service not found; adding ports manually"
    firewall-cmd --permanent --zone=public --add-port=1714-1764/tcp || true
    firewall-cmd --permanent --zone=public --add-port=1714-1764/udp || true
  fi

  firewall-cmd --reload || true
  log "firewalld rules updated for KDE Connect"
else
  warn "Skipping firewalld config (USE_FIREWALLD=false)"
fi

# --------------------------- OPTIONAL DEDUPE CLEANUP --------------------------
# If you use Flatpaks for these apps, you usually DON'T want the pacman versions too.
# This removes common duplicates if installed via pacman.
#
# NOTE: This only touches pacman packages (not Flatpaks).
log "7) Optional cleanup: remove common duplicate pacman GUI apps"
DUPLICATE_PACMAN_APPS=(
  discord
  steam
  vlc
  libreoffice-fresh
  libreoffice-still
  obs-studio
)

installed_dupes=()
for p in "${DUPLICATE_PACMAN_APPS[@]}"; do
  if pacman -Q "$p" >/dev/null 2>&1; then
    installed_dupes+=("$p")
  fi
done

if (( ${#installed_dupes[@]} )); then
  warn "Found pacman-installed GUI duplicates: ${installed_dupes[*]}"
  warn "Removing them keeps your app list clean (Flatpak versions remain)."
  pacman -Rns --noconfirm "${installed_dupes[@]}" || true
else
  log "No pacman GUI duplicates found. Skipping."
fi

# ============================================================
# Proton tools enforcement
# Enforce ProtonPlus and forbid ProtonUp-Qt
# ============================================================

echo
echo "Ensuring ProtonPlus is installed and ProtonUp-Qt is removed..."

# Remove ProtonUp-Qt Flatpak if present
flatpak uninstall -y net.davidotek.pupgui2 2>/dev/null || true

# Ensure ProtonPlus is installed
flatpak install -y flathub com.vysp3r.ProtonPlus || true

echo "Proton setup complete (ProtonPlus only)."

# --------------------------- FINAL NOTES --------------------------------------

echo
echo "==================== DONE ===================="
echo
echo "What you should do next:"
echo "  1) Reboot if any desktop integrations look odd (or if Sunshine shows a first-run red banner)"
echo "  2) Open Flatpak apps once to populate menus"
echo "  3) Launch ProtonPlus to manage Steam compatibility tools"
echo "  4) Sunshine Web UI: https://localhost:47990"
echo
echo "Tips:"
echo "  - flatpak list            → see installed Flatpaks"
echo "  - pacman -Q               → see installed pacman packages"
echo
echo "Setup complete."
