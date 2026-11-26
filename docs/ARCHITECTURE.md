# Architecture

**English** · [Español](ARCHITECTURE.es.md)

How the installer works, what the hardware does, and why each decision was made. Read this before changing code.

## Goals and non-goals

**Goals**
- One command that gets an AIC8800 USB adapter working on any mainstream distro.
- Short, honest output in English or Spanish. A ✓ means it was checked, not assumed.
- Survive kernel and distro updates without anyone touching it.

**Non-goals**
- **Maintaining a driver.** The driver lives upstream at [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80). Driver fixes go there as PRs, never into this repo.
- Supporting immutable systems (Silverblue, Bazzite). Upstream has its own guide.

## Files

| File | Role |
|---|---|
| `install.sh` | The installer. Pure Bash, no dependencies beyond `curl`, `tar` and `setsid`. |
| `uninstall.sh` | Runs upstream's `uninstall.sh` with the same Limine fix, then removes `/usr/local/src/aic8800-wifi6-linux`. |
| `diagnose.sh` | Read-only report for issues. Hides MAC addresses. |
| `tests/test_install.py` | Unit tests with a fake sysfs. No root, hardware or network needed. |
| `.github/workflows/ci.yml` | shellcheck and tests on every push and PR. |
| `.github/workflows/kernel-build.yml` | Weekly build of the pinned driver against the newest kernels. |
| `.github/workflows/upstream-watch.yml` | Weekly check for new upstream commits. |
| `release.sh` | Tags a version and publishes the GitHub release. Maintainer only. |

## The hardware, in short

```
plug in ──► 1111:1111 "88M80"  (USB mass storage, "WiFi Driver" disk with Wifi6_install.exe)
               │  usb_modeswitch sends 2 SCSI CBWs: CDB …10fd…f3, then …10fd…f2
               ▼
            a69c:8d80 "AIC Wlan"   (aic_load_fw uploads firmware from /lib/firmware/aic8800D80/)
               │  the chip reboots into the firmware
               ▼
            a69c:8d81 "AIC 8800D80" (aic8800_fdrv → wlanN; btusb → hciN)
```

- **Storage IDs:** `1111:1111` is a placeholder ID that other devices use too. It is only accepted when the USB product string starts with `88M80`. AIC's own storage IDs are `a69c:57xx`, and for those upstream's udev rule calls `eject`.
- **`chip_mcu_id`:** the firmware loader prints `chip_id=7, chip_mcu_id = N`. With `1`, the adapter needs upstream's `legacy-mcu1` branch, which has different firmware. The installer reads it from `dmesg` and reinstalls from that branch automatically.
- **The netdev hangs off the USB device, not an interface.** `/sys/class/net/wlan0/device` points to `…/1-1` and its driver shows as `usb`. That is why `aic_iface()` matches by sysfs path instead of driver name.
- **Bluetooth** appears as a `btusb` interface on the same USB device once the firmware has loaded. For some IDs, upstream adds a small `aic_zlp_quirk` module.

## Install flow

`main()` in `install.sh`, in order:

1. **Root.** If it runs from a file, it re-runs itself with `sudo`. When piped from `curl`, it downloads itself again and runs that copy under `sudo bash -c`, because a pipe cannot be re-executed.
2. **Questions come from the keyboard, never from stdin.** With `curl | bash`, stdin is the script itself, so `TTY` is set to `/dev/tty` or `/dev/null`.
3. **Pre-checks:** `curl`, `tar` and `setsid` must exist; ostree (immutable) systems are rejected; Secure Boot is detected by `secure_boot_enabled()`.
4. **`install_branch()`:** downloads the pinned upstream tarball from `codeload.github.com` into `/usr/local/src/aic8800-wifi6-linux/upstream`, writes `installed` (version, branch, ref), creates the mkinitcpio shim, and runs upstream's `install.sh`.
   - Normal case, `run_upstream_quiet()`: stdin is `/dev/null`, so upstream can never block on a hidden question. Output goes to the log while a spinner shows upstream's current `==>` step. A **watchdog** stops the whole process group (`setsid`) if the log does not grow for `AIC_STALL_MINUTES` (default 45).
   - Secure Boot case: upstream has to ask the user, so it runs in the foreground with the terminal and its output visible.
5. **`find_adapter()`** walks `/sys/bus/usb/devices` and matches `STORAGE_IDS` / `WIFI_IDS`. If no adapter is plugged in, it waits up to 2 minutes.
6. **Mode switch without unplugging:** `udevadm trigger --action=add --parent-match=<device>` replays the plug-in event, so upstream's udev rule runs `usb_modeswitch` or `eject`.
7. **Interface:** waits for `aic_iface()`. If no interface appears, the device is re-enumerated once through `authorized` 0/1, the software equivalent of unplugging it.
8. **Branch check:** `parse_mcu_id()`. If it reports `1` and the branch is `main`, the installer reinstalls from `legacy-mcu1` and re-enumerates the device.
9. **Real checks:** `iw dev <if> scan` (or `nmcli` as a fallback) counts networks, and `aic_hci()` looks for the Bluetooth controller on that same USB device.

## The Omarchy / Limine fix

On Limine UKI systems (Omarchy, some CachyOS installs), `mkinitcpio -P` finds no presets. Omarchy also ships `/usr/local/bin/mkinitcpio`, which then asks `Would you like to run 'limine-mkinitcpio' now? [Y/n]`. Upstream hides that output, so the installer looked frozen. This happened on the first test, for 20 minutes.

`write_mkinitcpio_shim()` puts a `mkinitcpio` first in `PATH` while upstream runs:
- if `limine-mkinitcpio` exists, it runs that with stdin from `/dev/null`;
- otherwise it passes through to `/usr/bin/mkinitcpio`;
- the original `PATH` is baked into the shim, so it can never call itself.

The same fix was sent upstream: [#156](https://github.com/shenmintao/aic8800d80/pull/156) and [#157](https://github.com/shenmintao/aic8800d80/pull/157). Once they are merged and pinned here, the shim is harmless and can be removed.

## Why these decisions

| Decision | Why |
|---|---|
| Wrap upstream instead of forking | Upstream updates weekly and knows the driver. A copy would rot. |
| Pinned commits (`REF_MAIN`, `REF_LEGACY`) | Users run what was tested on hardware, not whatever landed last night. CI and the watcher tell us when to move. |
| Tarball from codeload, not `git clone` | No `git` dependency, and the download is faster. |
| `main()` called on the last line | A truncated `curl` download runs nothing. Tests can also `source` the file with `AIC_TESTING=1`. |
| stdin `/dev/null` + watchdog | A hidden prompt can never hang the install again, whatever upstream or the distro adds later. |
| Bilingual `t 'es' 'en'` | Spanish-speaking users were the first audience; English reaches everyone else. A test rejects untranslated messages. |

## Things that can change under us

| If this changes… | …this breaks | Where to look |
|---|---|---|
| A new kernel API | the driver build (CI `kernel-build` opens an issue) | report or fix upstream, then bump `REF_*` |
| Omarchy drops Limine or renames `limine-mkinitcpio` | the initramfs step | `write_mkinitcpio_shim()` |
| Upstream renames `install.sh` or its `==>` / `DKMS module registered` messages | the spinner and the ✓ line | `run_upstream_quiet()`, `install_branch()` |
| Upstream changes the `chip_mcu_id` log line | automatic branch choice | `parse_mcu_id()` plus its test |
| A new adapter ID | detection | `STORAGE_IDS` / `WIFI_IDS` ([MAINTAINING.md](MAINTAINING.md#adding-an-adapter)) |
