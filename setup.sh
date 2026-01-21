#!/usr/bin/env bash
# Linux Fresh Apples – Setup Script
# Arch/CachyOS-focused (pacman)

SCRIPT_NAME="linux-fresh-apples"
SCRIPT_VERSION="v1.1.0"

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
# Terminal UI (gum) + fallback
# -------------------------------

# Default toggles (if user cancels UI, everything runs)
DO_PACMAN=true
DO_FLATPAK=true
DO_FLATHUB=true
DO_SUNSHINE=true
DO_FIREWALL=true
DO_DEDUPE=true
DO_PROTON_ENFORCE=true

maybe_install_gum() {
  if command -v gum >/dev/null 2>&1; then
    return 0
  fi

  # Only attempt if pacman exists and we're root
  if command -v pacman >/dev/null 2>&1 && [[ "${EUID}" -eq 0 ]]; then
    # minimal refresh; ignore failures so script stays resilient
    pacman -Sy --noconfirm >/dev/null 2>&1 || true
    pacman -S --noconfirm --needed gum >/dev/null 2>&1 || true
  fi

  command -v gum >/dev/null 2>&1
}

ask_yn() {
  local prompt="$1"
  local default="${2:-yes}" # yes/no
  local ans=""
  while true; do
    if [[ "$default" == "yes" ]]; then
      read -rp "$prompt [Y/n]: " ans
      ans="${ans:-y}"
    else
      read -rp "$prompt [y/N]: " ans
      ans="${ans:-n}"
    fi
    case "${ans,,}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
}

run_tui() {
  # Reset to defaults each run
  DO_PACMAN=true
  DO_FLATPAK=true
  DO_FLATHUB=true
  DO_SUNSHINE=true
  DO_FIREWALL=true
  DO_DEDUPE=true
  DO_PROTON_ENFORCE=true

  echo "=========================================="
  echo " Linux Fresh Apples – Setup Script ($SCRIPT_VERSION)"
  echo "=========================================="
  echo

  echo "This script can run these steps:"
  echo "  - Pacman packages (system + CLI tools)"
  echo "  - Flatpak + Flathub + Flatpak apps"
  echo "  - Sunshine setup (Moonlight host)"
  echo "  - Firewall rules (KDE Connect)"
  echo "  - Remove duplicate pacman GUI apps"
  echo "  - Proton tools enforcement (ProtonPlus only)"
  echo

  if maybe_install_gum; then
    gum style --border normal --padding "1 2" --margin "1 0" \
      "Select what you want to run" \
      "Space = toggle • Enter = confirm • Esc = run defaults (everything)"

    local selections
    selections="$(gum choose --no-limit \
      "Pacman: core system + CLI packages" \
      "Flatpak: enable Flathub + install apps" \
      "Sunshine: setcap + user service + RTSP port fix" \
      "Firewall: KDE Connect rules (firewalld)" \
      "Cleanup: remove duplicate pacman GUI apps" \
      "Proton: enforce ProtonPlus + remove ProtonUp-Qt")" || true

    # If user made selections (non-empty), run only selected
    if [[ -n "${selections:-}" ]]; then
      DO_PACMAN=false
      DO_FLATPAK=false
      DO_FLATHUB=false
      DO_SUNSHINE=false
      DO_FIREWALL=false
      DO_DEDUPE=false
      DO_PROTON_ENFORCE=false

      while IFS= read -r line; do
        case "$line" in
          "Pacman: core system + CLI packages") DO_PACMAN=true ;;
          "Flatpak: enable Flathub + install apps") DO_FLATPAK=true; DO_FLATHUB=true ;;
          "Sunshine: setcap + user service + RTSP port fix") DO_SUNSHINE=true ;;
          "Firewall: KDE Connect rules (firewalld)") DO_FIREWALL=true ;;
          "Cleanup: remove duplicate pacman GUI apps") DO_DEDUPE=true ;;
          "Proton: enforce ProtonPlus + remove ProtonUp-Qt") DO_PROTON_ENFORCE=true ;;
        esac
      done <<< "$selections"
    fi

    gum style --margin "1 0" --foreground 212 "Selections:"
    printf "  Pacman:   %s\n" "$DO_PACMAN"
    printf "  Flatpak:  %s\n" "$DO_FLATPAK"
    printf "  Sunshine: %s\n" "$DO_SUNSHINE"
    printf "  Firewall: %s\n" "$DO_FIREWALL"
    printf "  Cleanup:  %s\n" "$DO_DEDUPE"
    printf "  Proton:   %s\n" "$DO_PROTON_ENFORCE"
    echo

    gum confirm "Continue?" || { echo "Aborted."; exit 1; }
  else
    echo "gum not available. Using simple prompts."
    if ! ask_yn "Run pacman system/CLI package install?" yes; then DO_PACMAN=false; fi
    if ! ask_yn "Run Flatpak + Flathub + Flatpak app installs?" yes; then DO_FLATPAK=false; DO_FLATHUB=false; fi
    if ! ask_yn "Run Sunshine setup (Moonlight host)?" yes; then DO_SUNSHINE=false; fi
    if ! ask_yn "Configure firewalld for KDE Connect?" yes; then DO_FIREWALL=false; fi
    if ! ask_yn "Remove duplicate pacman GUI apps (if present)?" yes; then DO_DEDUPE=false; fi
    if ! ask_yn "Enforce ProtonPlus + remove ProtonUp-Qt?" yes; then DO_PROTON_ENFORCE=false; fi
    echo
    if ! ask_yn "Continue with selected steps?" yes; then echo "Aborted."; exit 1; fi
  fi

  echo
  echo "Starting setup..."
  echo
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

###############################################################################
# Linux Setup Script (Arch/CachyOS-focused)
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

# Selection UI / prompts
run_tui

if [[ "$DO_PACMAN" == "true" ]]; then
  log "1) Updating package databases"
  pacman -Sy --noconfirm

  log "2) Installing core pacman packages (system + CLI tools)"
  pacman_install "${PACMAN_PKGS[@]}"
else
  warn "Skipping pacman database update + pacman package install"
fi

if [[ "$DO_FLATPAK" == "true" ]]; then
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
else
  warn "Skipping Flatpak/Flathub/app installs"
fi

# ------------------------------
# Sunshine (Moonlight host)
# ------------------------------
if [[ "$DO_SUNSHINE" == "true" ]]; then
  log "5) Installing & configuring Sunshine (Moonlight host)"

  if ! have_cmd sunshine; then
    warn "Sunshine not found in PATH (install may have failed). Skipping Sunshine setup."
  else
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

    DEFAULT_RTSP_PORT="48010"
    RTSP_PORT="$DEFAULT_RTSP_PORT"
    if ss -ltn | awk '{print $4}' | grep -q ":${DEFAULT_RTSP_PORT}$"; then
      RTSP_PORT="$(get_free_tcp_port)"
      warn "Default RTSP port $DEFAULT_RTSP_PORT is already in use. Using $RTSP_PORT instead."
    else
      log "RTSP port $DEFAULT_RTSP_PORT appears free."
    fi

    if [[ -n "$TARGET_USER" && -n "${TARGET_UID:-}" ]]; then
      ensure_sunshine_rtsp_port "$TARGET_USER" "$RTSP_PORT"
    else
      warn "Could not determine TARGET_USER / TARGET_UID; skipping Sunshine config write."
    fi

    if [[ -n "$TARGET_USER" ]]; then
      log "Enabling Sunshine as a user service for: $TARGET_USER"

      run_user_systemctl "$TARGET_USER" daemon-reload || true

      log "Restarting user portal/pipewire services (helps Wayland capture)"
      run_user_systemctl "$TARGET_USER" restart pipewire pipewire-pulse wireplumber 2>/dev/null || true
      run_user_systemctl "$TARGET_USER" restart xdg-desktop-portal xdg-desktop-portal-kde 2>/dev/null || true

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
else
  warn "Skipping Sunshine setup"
fi

# --------------------------- FIREWALL + KDE CONNECT --------------------------
if [[ "$DO_FIREWALL" == "true" ]]; then
  if [[ "$USE_FIREWALLD" == "true" ]]; then
    log "6) Configuring firewalld for KDE Connect"
    enable_service firewalld

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
else
  warn "Skipping firewall config"
fi

# --------------------------- OPTIONAL DEDUPE CLEANUP --------------------------
if [[ "$DO_DEDUPE" == "true" ]]; then
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
else
  warn "Skipping duplicate cleanup"
fi

# --------------------------- PROTON ENFORCEMENT ------------------------------
if [[ "$DO_PROTON_ENFORCE" == "true" ]]; then
  echo
  echo "Ensuring ProtonPlus is installed and ProtonUp-Qt is removed..."

  flatpak uninstall -y net.davidotek.pupgui2 2>/dev/null || true
  flatpak install -y flathub com.vysp3r.ProtonPlus || true

  echo "Proton setup complete (ProtonPlus only)."
else
  warn "Skipping Proton enforcement"
fi

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
