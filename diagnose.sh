#!/usr/bin/env bash
# aic8800-wifi6-linux — read-only report to attach to a GitHub issue.
# It changes nothing. MAC addresses are partially hidden.
# Copyright (C) 2026 matcarfer and contributors
# SPDX-License-Identifier: GPL-3.0-or-later
set -u
OUT="${1:-aic8800-diagnose.txt}"
mask() { sed -E 's/([0-9a-fA-F]{2}:){3}([0-9a-fA-F]{2}:){2}[0-9a-fA-F]{2}/xx:xx:xx:\2xx/g'; }
sec() { printf '\n### %s\n' "$1"; }

{
    echo "aic8800-wifi6-linux diagnose $(date -Is)"
    sec "system";   uname -r; grep -E '^(PRETTY_NAME|ID)=' /etc/os-release 2>/dev/null
    sec "installed"; cat /usr/local/src/aic8800-wifi6-linux/installed 2>/dev/null || echo "not installed by this repo"
    sec "secure boot"; mokutil --sb-state 2>/dev/null || echo "mokutil n/a"
    sec "usb";      lsusb 2>/dev/null | grep -iE '1111:1111|a69c|368b|aic' || echo "no AIC device"
    sec "dkms";     dkms status 2>/dev/null | grep -i aic || echo "no dkms entry"
    sec "modules";  lsmod | grep -E '^(aic|btusb|cfg80211)' || true
    sec "headers";  ls -d "/usr/lib/modules/$(uname -r)/build" 2>&1
    sec "firmware"; ls -d /lib/firmware/aic8800* 2>/dev/null || echo "none"
    sec "udev";     ls /etc/udev/rules.d/aic.rules /etc/usb_modeswitch.d/1111:1111 2>&1
    sec "net";      ip -br link | mask
    sec "bluetooth"; ls /sys/class/bluetooth 2>/dev/null
    sec "kernel log"; (dmesg 2>/dev/null || journalctl -k -b --no-pager 2>/dev/null) \
        | grep -aiE 'aic|chip_id|mcu|usb_modeswitch|1111:1111|a69c|btusb|hci[0-9]' | grep -v 'UFW' | tail -60 | mask
} > "$OUT" 2>&1

cat "$OUT"
echo
echo ">> $OUT"
[ "$(id -u)" -ne 0 ] && echo "(sudo ./diagnose.sh shows the full kernel log / muestra el log completo)"
