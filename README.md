# 🍎 linux-fresh-apples 🍎

Personal Linux setup script (Arch / CachyOS focused) for getting a fresh install into a usable daily-driver state.

This is a **post-install bootstrap script** I use to quickly set up my system the way I like it after installing Arch-based distros (especially CachyOS).

---

## What this script does

- Updates pacman databases
- Installs core CLI and system packages
- Enables Flatpak and Flathub
- Installs desktop apps via Flatpak (prevents duplicates)
- Configures firewalld for KDE Connect
- Optional cleanup to remove common duplicate pacman GUI apps
- Ensures **ProtonPlus** is installed and **ProtonUp-Qt** is removed

---

## Supported systems

- Arch Linux  
- CachyOS  
- Other Arch-based distros **may work**, but are not guaranteed

⚠️ This script uses `pacman`, `flatpak`, and `firewalld`.

---

## Safety confirmation

Before doing anything, the script **prints what it will do** and asks for confirmation.

Anything other than `yes` will abort safely.

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
