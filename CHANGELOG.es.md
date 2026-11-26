# Cambios

[English](CHANGELOG.md) · **Español**

## [1.1.0] — 2026-11-26
- Proyecto pensado para la comunidad: guías de arquitectura y mantenimiento, créditos, AGENTS.md para asistentes de IA, código de conducta, formularios de issues y plantilla de PR (en castellano y en inglés).
- README en castellano por defecto (`README.md`) y en inglés en `README.en.md`. Resumen de la licencia en castellano (`LICENSE`) y el texto oficial de la GPL en `LICENSE.en`.
- Links de donación en un orden fijo: Cafecito, Matecito, Mercado Pago, Ko-fi (nuevo), Patreon.
- Instalador: vigía de trabas (corta después de 45 minutos sin avances y nunca espera para siempre), aviso claro en sistemas inmutables (Silverblue/Bazzite), `--version`, IDs de placas en una sola tabla sacada del driver de upstream, más IDs en modo WiFi (Tenda U11/U2, TX1U Nano, TP-Link/Mercury, `368b:*`).
- Tests: `tests/test_install.py` con un sysfs simulado (detección, interfaz, Bluetooth, `chip_mcu_id`, shim de Limine, traducciones).
- CI: shellcheck y tests en cada push; compilación semanal del driver fijado contra los últimos kernels de Omarchy, Arch, Ubuntu y Fedora (abre un issue si se rompe); vigía semanal de upstream.
- `release.sh` para publicar versiones con tag.

## [1.0.0] — 2026-11-26
- Instalador de un solo comando para placas USB WiFi 6 AIC8800 (`1111:1111` 88M80, `a69c:57xx`, `a69c:8d8x`).
- Usa upstream [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80): `main` en `1a2ce4e` (2026-11-20) y `legacy-mcu1` en `3e9b91b`.
- Pasa la placa de modo pendrive a modo WiFi sin desenchufarla.
- Elige `legacy-mcu1` solo cuando el chip informa `chip_mcu_id = 1`.
- Sin pregunta oculta en Omarchy/Limine: llama directo a `limine-mkinitcpio`.
- Verificación final: escaneo WiFi y controlador Bluetooth.
- `uninstall.sh` y `diagnose.sh` (solo lectura).
- Probado: Omarchy, kernel 7.2.15, placa genérica "WIFI6" 88M80 (WiFi 2.4/5 GHz + BT).
