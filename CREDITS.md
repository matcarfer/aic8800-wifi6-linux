# Credits

**English** · [Español](CREDITS.es.md)

This repository is an installer. **The driver and firmware are the work of other people**, and nothing here would exist without them. Thank you.

## Driver and firmware

| Who | What |
|---|---|
| **AICSemi** (AIC Semiconductor) | The AIC8800 chip, its Linux driver and firmware. |
| **Tenda** | The Tenda U11 Linux driver release that the current code descends from. |
| **[Radxa](https://github.com/radxa-pkg/aic8800)** | Packaged and maintained the AIC8800 driver for Debian and ARM boards, including many fixes. Source of the license text and copyright metadata. |
| **[Shen Mintao (shenmintao)](https://github.com/shenmintao/aic8800d80)** and its contributors | Keeps the driver building on new kernels (3.x to 7.x), the DKMS installer, udev and `usb_modeswitch` rules, the `btusb` Bluetooth path, and the `legacy-mcu1` branch. **This repo downloads and runs their work.** |

## Discoveries this repo depends on

| Who | What |
|---|---|
| **[a5a5aa555oo](https://github.com/radxa-pkg/aic8800/issues/68)** | Found the two-step `F3` → `F2` SCSI sequence that switches the `1111:1111` "Pandora 88M80" adapter out of USB-drive mode. |
| **[thatberd](https://github.com/shenmintao/aic8800d80/issues/81)**, **enrand22** and other reporters | Tested the mode switch on real adapters and reported the results. |
| Lukton DQ-211 contributor (upstream `INSTALL_ARCH.md`) | First documented test of this exact adapter on Arch/CachyOS with kernel 7.2. |

## Other projects for this chip

They are not used here, but they helped people before this existed and are worth knowing about:

- [kilam994/aic8800d80-linux-driver](https://github.com/kilam994/aic8800d80-linux-driver), a packaged fork of shenmintao's driver.
- [asanrivas/aic8800-linux-driver](https://github.com/asanrivas/aic8800-linux-driver), a driver for several AIC8800 variants.
- [wilodxd/aic8800d81-linux-bluetooth](https://github.com/wilodxd/aic8800d81-linux-bluetooth), a guide for D81 Bluetooth.
- AUR packages [`aic8800d80-dkms`](https://aur.archlinux.org/packages/aic8800d80-dkms) and [`aic8800-dkms`](https://aur.archlinux.org/packages/aic8800-dkms).

## Tools

- [usb_modeswitch](https://www.draisberghof.de/usb_modeswitch/) by Josua Dietze: sends the mode-switch commands.
- [DKMS](https://github.com/dell/dkms): rebuilds the driver for every kernel.
- [Omarchy](https://omarchy.org): where this was first tested, and the reason for the Limine fix.

## This installer

matcarfer and [contributors](../../graphs/contributors). Developed with help from Claude (Anthropic).

Missing someone? Open an issue or a PR: credit is easy to add, and important.
