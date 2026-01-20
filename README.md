# linux-fresh-apples

Personal Linux setup script (Arch / CachyOS focused) for getting a fresh install into a usable daily-driver state.

## What this script does
- Updates pacman databases
- Installs core CLI and system packages
- Enables Flatpak and Flathub
- Installs desktop apps via Flatpak (prevents duplicates)
- Configures firewalld for KDE Connect
- Optional cleanup to remove common duplicate pacman GUI apps
- Ensures ProtonPlus is installed and ProtonUp-Qt is removed

## Recommended usage
Clone the repo, then run the script:

```bash
git clone https://github.com/garduru/linux-fresh-apples.git
cd linux-fresh-apples
sudo bash setup.sh
