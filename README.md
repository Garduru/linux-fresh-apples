![Release](https://img.shields.io/github/v/release/garduru/linux-fresh-apples?label=release)
![License](https://img.shields.io/github/license/garduru/linux-fresh-apples)
![Platform](https://img.shields.io/badge/platform-Arch%20%7C%20CachyOS-blue)

# 🍎 Linux Fresh Apples 🍎

**Personal Linux post-install setup script**  
*Arch Linux / CachyOS focused*

Turn a fresh Arch-based install into a clean, usable daily-driver **safely and repeatably**.

---

## What is this?

**Linux Fresh Apples** is a **post-install bootstrap script** I use after installing Arch-based distros (especially CachyOS) to configure my system quickly, consistently, and without clutter.

It is designed to be:

- ✅ Safe to re-run (idempotent)
- ✅ Flatpak-first for GUI apps (avoids duplicates)
- ✅ Wayland-aware
- ✅ Explicit and readable (no magic)
- 🚧 Evolving toward a toggleable terminal UI (TUI)

---

## ✨ What this script does

### System & CLI
- Updates pacman package databases
- Installs core system + CLI tools
- Uses `--needed` installs to avoid unnecessary changes

### Flatpak & Apps
- Enables Flatpak and Flathub
- Installs desktop apps via Flatpak to prevent duplication
- Ensures **ProtonPlus** is installed
- Removes **ProtonUp-Qt** to avoid multiple Proton managers

### Sunshine (Moonlight host)
- Installs Sunshine via pacman
- Applies required capabilities for **KMS capture** (symlink-safe)
- Auto-selects a free RTSP port if the default is already in use
- Writes minimal user config (`rtsp_port`) safely
- Enables Sunshine as a **user service**
- Restarts PipeWire + portals for Wayland reliability
- Displays Sunshine Web UI URL for first-time setup

### Firewall
- Configures `firewalld` for KDE Connect
- Uses built-in `kdeconnect` service if available
- Falls back to explicit port rules if needed

### Cleanup
- Removes duplicate **pacman GUI apps** when Flatpak versions are present
- Never touches Flatpaks during cleanup

### Safety
- Prints exactly what will happen
- Requires typing **yes** before making changes
- Aborts cleanly otherwise

---

## 🖥️ Supported systems

- Arch Linux
- CachyOS
- Other Arch-based distros *may work* but are not guaranteed

⚠️ Uses:
- pacman
- flatpak
- firewalld

---

## 🔐 Safety model

Before doing anything, the script:

- Explains all major actions
- Requires explicit confirmation
- Uses defensive checks for:
  - Installed packages
  - Active user sessions
  - Existing services
  - Wayland quirks

You can re-run the script at any time without breaking your system.

---

## 🚀 Installation & usage

### Run directly (no repo kept)

curl -fsSL https://raw.githubusercontent.com/garduru/linux-fresh-apples/refs/tags/v1.1.0/setup.sh -o setup.sh

chmod +x setup.sh

sudo ./setup.sh

### OR Clone the repo

git clone https://github.com/garduru/linux-fresh-apples.git

cd linux-fresh-apples

sudo ./setup.sh
