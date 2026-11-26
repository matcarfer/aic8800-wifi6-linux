# Changelog

**English** · [Español](CHANGELOG.es.md)

## 1.0.0 — 2026-11-26
- One-command installer for AIC8800 USB Wi-Fi 6 adapters (`1111:1111` 88M80, `a69c:57xx`, `a69c:8d8x`).
- Uses upstream [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80) `main` @ `1a2ce4e` (2026-11-20), `legacy-mcu1` @ `3e9b91b`.
- Switches the adapter from USB-drive to Wi-Fi mode without unplugging it.
- Picks `legacy-mcu1` automatically when the chip reports `chip_mcu_id = 1`.
- No hidden prompt on Omarchy/Limine (`limine-mkinitcpio` is called directly).
- Final check: Wi-Fi scan and Bluetooth controller.
- `uninstall.sh` and read-only `diagnose.sh`.
- Tested: Omarchy, kernel 7.2.15, generic "WIFI6" 88M80 adapter (Wi-Fi 2.4/5 GHz + BT).
