# Cambios

[English](CHANGELOG.md) · **Español**

## 1.0.0 — 2026-11-26
- Instalador de un solo comando para placas USB WiFi 6 AIC8800 (`1111:1111` 88M80, `a69c:57xx`, `a69c:8d8x`).
- Usa upstream [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80): `main` en `1a2ce4e` (2026-11-20) y `legacy-mcu1` en `3e9b91b`.
- Pasa la placa de modo pendrive a modo WiFi sin desenchufarla.
- Elige `legacy-mcu1` solo cuando el chip informa `chip_mcu_id = 1`.
- Sin pregunta oculta en Omarchy/Limine: llama directo a `limine-mkinitcpio`.
- Verificación final: escaneo WiFi y controlador Bluetooth.
- `uninstall.sh` y `diagnose.sh` (solo lectura).
- Probado: Omarchy, kernel 7.2.15, placa genérica "WIFI6" 88M80 (WiFi 2.4/5 GHz + BT).
