# Changelog

All notable changes to this project will be documented in this file.

This project loosely follows **Semantic Versioning (SemVer)**.

## [1.1.0] – 2026-01-21

### Added
- (Planned/Initial) Terminal UI groundwork for toggling install options (packages/services/apps)
- Improved Sunshine setup reliability for Wayland + user services
- More defensive checks for user-session availability when enabling `systemctl --user`

### Improved
- Script organization and readability
- Safer reruns (idempotent behavior)

### Notes
- v1.1.0 is the start of the “toggleable installer” direction (TUI-based selection)

---

## [1.0.1] – 2026-01-21

### Fixed
- Corrected Sunshine user service enablement under Wayland
- Ensured Sunshine capability (`cap_sys_admin+p`) is applied to the real binary (symlink-safe)
- Fixed first-run Sunshine startup reliability by restarting PipeWire and xdg-desktop-portal services
- Corrected curl-based installer instructions to point at valid GitHub raw paths
- Prevented false Sunshine install failures caused by Flatpak-only installs
- Improved detection and handling of existing packages for safe re-runs

### Improved
- Reorganized script execution order for better safety and clarity
- Clearer setup output and status messages
- More reliable KDE Connect firewall configuration via firewalld
- Safer duplicate GUI package cleanup logic
- Script can now be run repeatedly without breaking the system

---

## [1.0.0] – 2026-01-19

### Added
- Initial public release
- Arch / CachyOS–focused post-install setup script
- Pacman database updates
- Core CLI and system package installation
- Flatpak and Flathub enablement
- Desktop applications installed via Flatpak to avoid duplicates
- FirewallD configuration for KDE Connect
- Optional cleanup to remove common duplicate pacman GUI applications
- ProtonPlus installation enforced
- ProtonUp-Qt removal to prevent duplication
- Safety confirmation prompt before any system changes
- `--version` / `-v` flag output
- Curl-based installer support (run without cloning repo)

### Notes
- Designed for personal daily-driver setups
- Intended to be simple, readable, and safe
- Tested on Arch Linux and CachyOS
