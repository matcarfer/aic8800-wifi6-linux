# Créditos

[English](CREDITS.md) · **Español**

Este repositorio es un instalador. **El driver y el firmware son trabajo de otras personas**, y sin ellas nada de esto existiría. Gracias.

## Driver y firmware

| Quién | Qué |
|---|---|
| **AICSemi** (AIC Semiconductor) | El chip AIC8800, su driver para Linux y el firmware. |
| **Tenda** | La versión del driver para Linux de la Tenda U11, de la que viene el código actual. |
| **[Radxa](https://github.com/radxa-pkg/aic8800)** | Empaquetó y mantuvo el driver AIC8800 para Debian y placas ARM, con muchos arreglos. De ahí salen el texto de la licencia y los datos de copyright. |
| **[Shen Mintao (shenmintao)](https://github.com/shenmintao/aic8800d80)** y sus colaboradores | Mantienen el driver compilando en kernels nuevos (de 3.x a 7.x), el instalador con DKMS, las reglas de udev y `usb_modeswitch`, el Bluetooth por `btusb` y la rama `legacy-mcu1`. **Este repo descarga y ejecuta su trabajo.** |

## Descubrimientos de los que depende este repo

| Quién | Qué |
|---|---|
| **[a5a5aa555oo](https://github.com/radxa-pkg/aic8800/issues/68)** | Encontró la secuencia SCSI de dos pasos `F3` → `F2` que saca del modo pendrive a la placa `1111:1111` "Pandora 88M80". |
| **[thatberd](https://github.com/shenmintao/aic8800d80/issues/81)**, **enrand22** y otras personas que reportaron | Probaron el cambio de modo con placas reales y contaron los resultados. |
| Quien aportó la Lukton DQ-211 (`INSTALL_ARCH.md` de upstream) | Primera prueba documentada de esta misma placa en Arch/CachyOS con kernel 7.2. |

## Otros proyectos para este chip

Acá no se usan, pero ayudaron a mucha gente antes de que esto existiera y vale la pena conocerlos:

- [kilam994/aic8800d80-linux-driver](https://github.com/kilam994/aic8800d80-linux-driver), un fork empaquetado del driver de shenmintao.
- [asanrivas/aic8800-linux-driver](https://github.com/asanrivas/aic8800-linux-driver), un driver para varias variantes de AIC8800.
- [wilodxd/aic8800d81-linux-bluetooth](https://github.com/wilodxd/aic8800d81-linux-bluetooth), una guía para el Bluetooth de la D81.
- Paquetes del AUR [`aic8800d80-dkms`](https://aur.archlinux.org/packages/aic8800d80-dkms) y [`aic8800-dkms`](https://aur.archlinux.org/packages/aic8800-dkms).

## Herramientas

- [usb_modeswitch](https://www.draisberghof.de/usb_modeswitch/), de Josua Dietze: manda los comandos de cambio de modo.
- [DKMS](https://github.com/dell/dkms): recompila el driver con cada kernel.
- [Omarchy](https://omarchy.org): donde se probó primero, y el motivo del arreglo de Limine.

## Este instalador

matcarfer y [colaboradores](../../graphs/contributors). Desarrollado con ayuda de Claude (Anthropic).

¿Falta alguien? Abrí un issue o un PR: sumar un crédito es fácil, e importante.
