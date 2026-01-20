#!/usr/bin/env bash

SCRIPT_NAME="linux-fresh-apples"
SCRIPT_VERSION="v1.0.0"

# Version flag
if [[ "$1" == "--version" || "${1:-}" == "-v" ]]; then
  echo "$SCRIPT_NAME $SCRIPT_VERSION"
  exit 0
fi

set -euo pipefail

echo "=========================================="
echo " Linux Fresh Apples – Setup Script ($SCRIPT_VERSION)"
echo "=========================================="
echo
echo "This script will:"
echo " - Install system and desktop packages"
echo " - Enable Flatpak + Flathub"
echo " - Configure firewalld (KDE Connect)"
echo " - Optionally remove duplicate GUI packages"
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

# Your user (for mounts/permissions if needed later; not used heavily right now)
USER_NAME="${SUDO_USER:-$USER}"


# Firewall backend
USE_FIREWALLD=true


# Flatpak apps (Flathub IDs). These are preferred GUI apps to avoid duplicates
FLATPAK_APPS=(
  "com.discordapp.Discord"
  "com.valvesoftware.Steam"
  "com.obsproject.Studio"
  "org.videolan.VLC"
  "org.libreoffice.LibreOffice"
  "org.localsend.localsend_app"
  "dev.lizardbyte.app.Sunshine"
  "com.vysp3r.ProtonPlus"              # ProtonPlus (if available on your Flathub)
  "it.mijorus.gearlever"               # Gear Lever (AppImage manager)
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
)


# ----------------------------- HELPER FUNCS ----------------------------------

log() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m!!\033[0m %s\n" "$*"; }
die() { printf "\n\033[1;31mXX\033[0m %s\n" "$*"; exit 1; }

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


# --------------------------- FIREWALL + KDE CONNECT --------------------------
# KDE Connect needs ports:
# - TCP 1714-1764
# - UDP 1714-1764
#
# You already confirmed firewalld fixed your KDE Connect pairing/connectivity.
# We'll ensure firewalld is enabled and allow the KDE Connect service/ports.

if [[ "$USE_FIREWALLD" == "true" ]]; then
  log "5) Configuring firewalld for KDE Connect"
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
log "6) Optional cleanup: remove common duplicate pacman GUI apps"
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

echo "Ensuring ProtonPlus is installed and ProtonUp-Qt is removed..."

# Remove ProtonUp-Qt Flatpak if present
flatpak uninstall -y net.davidotek.pupgui2 2>/dev/null || true

# Ensure ProtonPlus is installed
flatpak install -y flathub com.vysp3r.ProtonPlus

echo "Proton setup complete (ProtonPlus only)."


# --------------------------- FINAL NOTES --------------------------------------

echo
echo "==================== DONE ===================="
echo
echo "What you should do next:"
echo "  1) Reboot if any desktop integrations look odd"
echo "  2) Open Flatpak apps once to populate menus"
echo "  3) Launch ProtonPlus to manage Steam compatibility tools"
echo
echo "Tips:"
echo "  - flatpak list            → see installed Flatpaks"
echo "  - pacman -Q               → see installed pacman packages"
echo
echo "Setup complete."
