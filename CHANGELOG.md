# Changelog

**English** · [Español](CHANGELOG.es.md)

## [1.1.0] — 2026-11-26
- Project made for the community: architecture and maintenance guides, credits, AGENTS.md for AI assistants, code of conduct, issue forms and PR template (English and Spanish).
- README in Spanish by default (`README.md`) and English in `README.en.md`. License summary in Spanish (`LICENSE`) and the official GPL text in `LICENSE.en`.
- Donation links in a fixed order: Cafecito, Matecito, Mercado Pago, Ko-fi (new), Patreon.
- Installer: stall watchdog (stops after 45 minutes without progress, never waits forever), clear message on immutable systems (Silverblue/Bazzite), `--version`, adapter IDs in one table taken from the upstream driver, more Wi-Fi-mode IDs (Tenda U11/U2, TX1U Nano, TP-Link/Mercury, `368b:*`).
- Tests: `tests/test_install.py` with a fake sysfs (detection, interface, Bluetooth, `chip_mcu_id`, Limine shim, translations).
- CI: shellcheck and tests on every push; weekly build of the pinned driver against the latest Omarchy, Arch, Ubuntu and Fedora kernels (opens an issue if it breaks); weekly upstream watcher.
- `release.sh` for tagged releases.

## [1.0.0] — 2026-11-26
- One-command installer for AIC8800 USB Wi-Fi 6 adapters (`1111:1111` 88M80, `a69c:57xx`, `a69c:8d8x`).
- Uses upstream [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80) `main` @ `1a2ce4e` (2026-11-20), `legacy-mcu1` @ `3e9b91b`.
- Switches the adapter from USB-drive to Wi-Fi mode without unplugging it.
- Picks `legacy-mcu1` automatically when the chip reports `chip_mcu_id = 1`.
- No hidden prompt on Omarchy/Limine (`limine-mkinitcpio` is called directly).
- Final check: Wi-Fi scan and Bluetooth controller.
- `uninstall.sh` and read-only `diagnose.sh`.
- Tested: Omarchy, kernel 7.2.15, generic "WIFI6" 88M80 adapter (Wi-Fi 2.4/5 GHz + BT).
