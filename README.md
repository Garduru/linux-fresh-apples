# 🍎 Linux Fresh Apples 🍎

Personal Linux setup script (Arch / CachyOS focused) for turning a fresh install into a usable daily-driver system.

This is a **post-install bootstrap script** I use after installing Arch-based distros (especially CachyOS) to get my system configured quickly, cleanly, and consistently.

---

## ✨ What this script does

- Updates pacman package databases
- Installs core CLI and system packages
- Enables Flatpak and Flathub
- Installs desktop applications via Flatpak (prevents duplicates)
- Installs and configures **Sunshine** (Moonlight game streaming host)
  - Applies required capabilities for KMS capture
  - Enables Sunshine as a **user service**
  - Starts Sunshine automatically on login
  - Displays Sunshine Web UI URL for first-time setup
- Configures firewalld for KDE Connect
- Optionally removes duplicate pacman GUI applications
- Ensures **ProtonPlus** is installed
- Removes **ProtonUp-Qt** to prevent duplicate Proton managers
- Prompts for confirmation before making any system changes

---

## 🖥 Supported systems

- Arch Linux
- CachyOS
- Other Arch-based distros *may work* but are not guaranteed

⚠️ This script uses:
- `pacman`
- `flatpak`
- `firewalld`

---

## 🔐 Safety confirmation

Before doing anything, the script:

- Prints **exactly what it will do**
- Requires typing **`yes`** to continue

Anything else safely aborts.

---

## Installation & usage

You can run the script **directly from GitHub** or **clone the repo**.  
Use **whichever method you prefer**.

### Run directly (no repo kept)

curl -fsSL https://raw.githubusercontent.com/garduru/linux-fresh-apples/refs/tags/v1.0.0/setup.sh -o setup.sh

chmod +x setup.sh

sudo ./setup.sh

### OR Clone the repo

git clone https://github.com/garduru/linux-fresh-apples.git

cd linux-fresh-apples

sudo ./setup.sh
