# aic8800-wifi6-linux

**English** · [Español](README.es.md)

**Get the "shows up as a USB drive" Wi-Fi 6 USB adapter working on Linux with one command.**

```bash
curl -fsSL https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/install.sh | bash
```

It asks for your password, builds the driver (3–6 minutes), and ends like this:

```
==> Looking for the adapter...
  ✓ Adapter in Wi-Fi mode (a69c:8d81)
  ✓ Wi-Fi: wlan0 sees 31 networks
  ✓ Bluetooth: hci1

Done. The adapter activates by itself every time you plug it in.
```

## Is this my adapter?

Probably, if when you plug it in:

- a **USB drive or CD called "WiFi Driver"** appears with a `.exe` inside, and
- `lsusb` shows one of these IDs:

| `lsusb` shows | What it is |
|---|---|
| `1111:1111 Pandora International Ltd. 88M80` | AIC8800D80 in USB-drive mode (generic "WIFI6", Lukton, …) |
| `a69c:5721` … `a69c:5732` | AIC8800 in USB-drive mode (Tenda, UGREEN, Cudy, BrosTrend…) |
| `a69c:8d80`, `a69c:8d81`, `368b:8d81` | The same adapter already in Wi-Fi mode |

Usually sold as **AX300, AX900, AX1800, "WiFi 6 + BT 5.x"**: Tenda U11, UGREEN AX900, BrosTrend AX300/AX900, and many generic AliExpress/Amazon adapters.

## What it does (and why it exists)

The driver is [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80) (GPL-2.0), adapted from the Tenda/AICSemi driver, and it works very well. This repo **does not modify it**. It downloads a tested version and adds what was missing to make it easy:

| | By hand with upstream | With this repo |
|---|---|---|
| Steps | clone, `chmod`, `sudo`, unplug and replug | one command |
| Omarchy / Limine | stops at a hidden prompt and looks frozen | handled |
| USB drive to Wi-Fi switch | "unplug and plug it back in" | done for you, no unplugging |
| `main` vs `legacy-mcu1` branch | you choose | reads `chip_mcu_id` and picks |
| Final check | "module loaded" | checks that Wi-Fi sees networks and Bluetooth shows up |
| Output | about 150 lines | 6 lines, English or Spanish |

Under the hood, the installer:

1. Downloads upstream at a pinned, tested commit into `/usr/local/src/aic8800-wifi6-linux`.
2. Runs upstream's installer: distro dependencies, test build, DKMS, firmware, udev rule and `usb_modeswitch`.
3. If the adapter is in USB-drive mode, switches it to Wi-Fi mode with udev and `usb_modeswitch`, which send AIC's `F3`/`F2` SCSI commands.
4. If the chip is the MCU1 variant, reinstalls automatically from the `legacy-mcu1` branch.
5. Scans for networks and looks for the Bluetooth controller to confirm everything really works.

DKMS rebuilds the driver automatically on every new kernel.

## Tested distros

| Distro | Kernel | Wi-Fi | BT | Adapter |
|---|---|---|---|---|
| Omarchy (Arch) | 7.2.15 | ✓ 2.4 + 5 GHz | ✓ | generic "WIFI6" `1111:1111` 88M80 |

Upstream reports it also works on Ubuntu, Debian, Fedora, CachyOS and openSUSE. Tried it on another distro? [Tell us in an issue](../../issues/new/choose) and we'll add it to the table.

## Requirements

- Internet during install: built-in Wi-Fi, cable, or USB tethering from your phone.
- Secure Boot **disabled**. If it is enabled, the installer warns you and explains what to do.

Kernel headers, `dkms` and `usb_modeswitch` are installed for you.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/uninstall.sh | bash
```

## If something fails

```bash
curl -fsSL https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/diagnose.sh | sudo bash
```

This writes `aic8800-diagnose.txt`. The script is read-only and hides MAC addresses. [Open an issue](../../issues/new/choose) and attach the file.

Common issues:

- **"It did not switch"**: unplug it, wait 3 seconds, and plug it back in. Some USB ports or hubs cut power during the switch.
- **Works after replug but not at boot**: reboot once; the initramfs already includes the firmware.
- **No Bluetooth**: some adapters are Wi-Fi only.
- The full install log is in `/var/log/aic8800-wifi6-linux.log`.

## Credits and license

- Driver: [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80), GPL-2.0, based on the Tenda U11 / AICSemi driver.
- Installer: matcarfer, [GPL-3.0](LICENSE).

If it helped you: [Matecito](https://www.matecito.co/matcarfer) · [Cafecito](https://cafecito.app/matcarfer) · [Mercado Pago](https://link.mercadopago.com.ar/matcarfer) · [Patreon](https://www.patreon.com/matcarfer)
