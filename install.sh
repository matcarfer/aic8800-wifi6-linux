#!/usr/bin/env bash
# aic8800-wifi6-linux — one-command installer for AIC8800 USB Wi-Fi 6 (+Bluetooth)
# adapters, including the ones that first show up as a fake "WiFi Driver" USB drive.
#
# It does NOT contain the driver. It downloads https://github.com/shenmintao/aic8800d80
# (GPL-2.0) at a pinned, hardware-tested commit, runs its installer, and adds:
#   - one command, short bilingual output (es/en)
#   - no hidden prompt on Omarchy / Limine (mkinitcpio shim) and a stall watchdog
#   - switches the adapter from "USB drive" to Wi-Fi without unplugging it
#   - picks the right driver branch (main / legacy-mcu1) from chip_mcu_id
#   - checks that Wi-Fi really scans and Bluetooth really appears
# How it works: docs/ARCHITECTURE.md
#
# Usage:  curl -fsSL https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/install.sh | bash
#    or:  ./install.sh [--legacy] [--version] [--help]
#
# Copyright (C) 2026 matcarfer and contributors
# SPDX-License-Identifier: GPL-3.0-or-later

set -uo pipefail

VERSION="1.1.0"
SELF_URL="https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/install.sh"
UPSTREAM="shenmintao/aic8800d80"
# Hardware-tested upstream commits. Change only after testing with a real
# adapter (docs/MAINTAINING.md). CI reads these two lines.
REF_MAIN="1a2ce4e38e678a0c0d7f6071be415ab74f488240"     # main, 2026-11-20
REF_LEGACY="3e9b91be1da35cb4d11556288b44c1b4d04f0670"   # legacy-mcu1
PREFIX="/usr/local/src/aic8800-wifi6-linux"
LOG="/var/log/aic8800-wifi6-linux.log"
SYSFS="${AIC_SYSFS:-/sys}"                  # tests point this at a fake tree
STALL_MINUTES="${AIC_STALL_MINUTES:-45}"    # no log progress for this long = stuck

# ---------------------------------------------------------------- adapter IDs
# Shell glob patterns "vid:pid". To add an adapter, see docs/MAINTAINING.md.
# Mass-storage ("WiFi Driver" USB drive) mode. 1111:1111 is a placeholder ID
# that other devices also use, so it is only accepted with product "88M80*".
STORAGE_IDS=("1111:1111" "a69c:57??")
# Wi-Fi mode: every ID the upstream driver binds to (aic_load_fw + aic8800_fdrv).
WIFI_IDS=("a69c:88??" "a69c:8d4?" "a69c:8d8?" "368b:*"
          "2604:0013" "2604:0014" "2604:001f" "2604:0020"   # Tenda U11 / U11 Pro / U2
          "3625:0110"                                       # Tenda TX1U Nano
          "2357:014b" "2357:014e")                          # TP-Link / Mercury

# ---------------------------------------------------------------- output
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
    es*) ES=1 ;;
    *) ES=0 ;;
esac
# t 'castellano' 'english' — every user-visible text goes through this.
t() { if [ "$ES" = 1 ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

if [ -t 1 ]; then
    B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'
else
    B=; G=; Y=; R=; C=; N=
fi
step() { printf '%s==>%s %s\n' "$C$B" "$N" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  {
    printf '  %s✗%s %s\n' "$R" "$N" "$*" >&2
    printf '    %s %s\n' "$(t 'Log completo:' 'Full log:')" "$LOG" >&2
    printf '    %s\n' "$(t 'Ayuda: https://github.com/matcarfer/aic8800-wifi6-linux#si-algo-falla' 'Help: https://github.com/matcarfer/aic8800-wifi6-linux#if-something-fails')" >&2
    exit 1
}

usage() {
    cat <<EOF
aic8800-wifi6-linux $VERSION
$(t 'Instala el driver de placas USB WiFi 6 AIC8800 (y su Bluetooth).' 'Installs the driver for AIC8800 USB Wi-Fi 6 adapters (and their Bluetooth).')

  ./install.sh            $(t 'instalar (elige la rama sola)' 'install (picks the branch automatically)')
  ./install.sh --legacy   $(t 'forzar la rama legacy-mcu1' 'force the legacy-mcu1 branch')
  ./uninstall.sh          $(t 'desinstalar' 'uninstall')
  ./diagnose.sh           $(t 'informe para pedir ayuda' 'report to ask for help')
EOF
}

# ---------------------------------------------------------------- detection
# id_in "vid:pid" pattern... — true if the ID matches one of the glob patterns.
id_in() {
    local id=$1 p; shift
    for p in "$@"; do
        # shellcheck disable=SC2254  # $p is a glob pattern on purpose
        case "$id" in $p) return 0 ;; esac
    done
    return 1
}

# Prints "<state> <sysfs-path> <vid:pid>" for the first AIC adapter found.
# state: storage (still a fake USB drive) | wifi (in Wi-Fi mode)
find_adapter() {
    local d id prod
    for d in "$SYSFS"/bus/usb/devices/*; do
        [ -r "$d/idVendor" ] && [ -r "$d/idProduct" ] || continue
        id="$(cat "$d/idVendor"):$(cat "$d/idProduct")"
        prod=$(cat "$d/product" 2>/dev/null || true)
        if id_in "$id" "${STORAGE_IDS[@]}"; then
            if [ "$id" != "1111:1111" ] || [[ "$prod" == 88M80* ]]; then
                echo "storage $d $id"; return 0
            fi
        elif id_in "$id" "${WIFI_IDS[@]}"; then
            echo "wifi $d $id"; return 0
        fi
    done
    return 1
}

# Wi-Fi interface living on the given USB device. The AIC driver attaches its
# netdev to the USB device itself (driver "usb"), not to an interface, so match
# by sysfs path instead of driver name.
aic_iface() {
    local dev n
    dev=$(readlink -f "$1")
    for n in "$SYSFS"/class/net/*; do
        [ -e "$n/phy80211" ] || continue
        case "$(readlink -f "$n")" in "$dev"/*) basename "$n"; return 0 ;; esac
    done
    return 1
}

# Bluetooth controller (btusb) living on the given USB device.
aic_hci() {
    local dev h
    dev=$(readlink -f "$1")
    for h in "$SYSFS"/class/bluetooth/hci*; do
        [ -e "$h" ] || continue
        case "$(readlink -f "$h/device" 2>/dev/null)" in "$dev"/*) basename "$h"; return 0 ;; esac
    done
    return 1
}

# Reads a kernel log on stdin, prints the last chip_mcu_id (0/1) or nothing.
parse_mcu_id() {
    grep -ao 'chip_mcu_id *= *[0-9]' | tail -1 | grep -o '[0-9]$' || true
}

secure_boot_enabled() {
    local f
    if command -v mokutil >/dev/null 2>&1; then
        mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled' && return 0
        return 1
    fi
    for f in "$SYSFS"/firmware/efi/efivars/SecureBoot-*; do
        [ -r "$f" ] || continue
        [ "$(od -An -t u1 "$f" | awk '{print $NF}')" = 1 ] && return 0
    done
    return 1
}

# ---------------------------------------------------------------- mkinitcpio shim
# Omarchy/Limine: plain "mkinitcpio -P" finds no presets, and Omarchy's wrapper
# /usr/local/bin/mkinitcpio asks "run limine-mkinitcpio? [Y/n]" on stdin while
# upstream hides the output: it looks frozen. This shim, first in PATH while
# upstream runs, calls limine-mkinitcpio directly. Elsewhere it just passes
# through. The real PATH is baked in so the shim never calls itself.
# Upstream PR: https://github.com/shenmintao/aic8800d80/pull/156
write_mkinitcpio_shim() {
    local dir=$1
    cat > "$dir/mkinitcpio" <<EOF
#!/bin/sh
export PATH="$PATH"
if command -v limine-mkinitcpio >/dev/null 2>&1; then exec limine-mkinitcpio < /dev/null; fi
exec "${AIC_MKINITCPIO:-/usr/bin/mkinitcpio}" "\$@" < /dev/null
EOF
    chmod +x "$dir/mkinitcpio"
}

# ---------------------------------------------------------------- install
# Runs upstream install.sh in the background with stdin closed (it can never
# wait on a hidden question), a spinner, and a watchdog: if the log does not
# grow for STALL_MINUTES, the whole process group is stopped.
run_upstream_quiet() {
    local shim=$1 pid i=0 spin='|/-\' size last_size=-1 still=0 line
    (cd "$PREFIX/upstream" && PATH="$shim:$PATH" exec setsid bash ./install.sh) < /dev/null >> "$LOG" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        if [ -t 1 ]; then
            line=$(grep -a '==> ' "$LOG" | tail -1 | sed 's/\x1b\[[0-9;]*m//g; s/.*==> //' | cut -c1-60)
            printf '\r  %s %s\e[K' "${spin:i++%4:1}" "$line"
        fi
        size=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
        if [ "$size" = "$last_size" ]; then still=$((still + 1)); else still=0; last_size=$size; fi
        if [ "$still" -ge $((STALL_MINUTES * 60)) ]; then
            kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
            [ -t 1 ] && printf '\r\e[K'
            die "$(t "Sin avances durante $STALL_MINUTES minutos: lo frené. Abrí un issue con ./diagnose.sh." "No progress for $STALL_MINUTES minutes: stopped it. Open an issue with ./diagnose.sh.")"
        fi
        sleep 1
    done
    [ -t 1 ] && printf '\r\e[K'
    wait "$pid"
}

install_branch() {
    local branch=$1 ref src tmp shim rc
    [ "$branch" = "main" ] && ref=$REF_MAIN || ref=$REF_LEGACY

    step "$(t "Descargando el driver ($branch, ${ref:0:7})..." "Downloading the driver ($branch, ${ref:0:7})...")"
    tmp=$(mktemp -d)
    if ! curl -fsSL "https://codeload.github.com/$UPSTREAM/tar.gz/$ref" | tar -xz -C "$tmp" >> "$LOG" 2>&1; then
        rm -rf "$tmp"
        die "$(t 'No se pudo descargar. ¿Hay internet? (WiFi de la notebook, cable o el celular por USB)' 'Download failed. Is there internet? (built-in Wi-Fi, cable or USB tethering)')"
    fi
    src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
    mkdir -p "$PREFIX"
    rm -rf "$PREFIX/upstream"
    mv "$src" "$PREFIX/upstream"
    rm -rf "$tmp"
    printf 'version=%s\nbranch=%s\nref=%s\n' "$VERSION" "$branch" "$ref" > "$PREFIX/installed"
    ok "$(t 'Descargado' 'Downloaded')"

    shim=$(mktemp -d)
    write_mkinitcpio_shim "$shim"

    step "$(t 'Compilando e instalando (3-6 minutos, no cierres esta ventana)...' 'Building and installing (3-6 minutes, keep this window open)...')"
    if [ "$SECURE_BOOT" = 1 ]; then
        # Upstream must ask about Secure Boot itself: show everything.
        (cd "$PREFIX/upstream" && PATH="$shim:$PATH" bash ./install.sh) < "$TTY" 2>&1 | tee -a "$LOG"
        rc=${PIPESTATUS[0]}
    else
        run_upstream_quiet "$shim"; rc=$?
    fi
    rm -rf "$shim"
    if [ "$rc" -ne 0 ]; then
        sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -aE '\[ERROR\]|error:' | tail -5 | sed 's/^/    /' >&2
        die "$(t 'La instalación del driver falló.' 'Driver installation failed.')"
    fi
    grep -aq 'DKMS module registered' "$LOG" && ok "$(t 'Driver instalado con DKMS (se recompila solo con cada kernel nuevo)' 'Driver installed with DKMS (rebuilds itself on every new kernel)')"
}

# Re-enumerate a USB device without unplugging it.
replug() {
    echo 0 > "$1/authorized" 2>/dev/null; sleep 2; echo 1 > "$1/authorized" 2>/dev/null
}

wait_iface() {
    local _ iface
    for _ in $(seq "$2"); do iface=$(aic_iface "$1" || true); [ -n "$iface" ] && { echo "$iface"; return 0; }; sleep 1; done
    return 1
}

# ---------------------------------------------------------------- main
main() {
    BRANCH="main"
    local a
    for a in "$@"; do
        case "$a" in
            --legacy) BRANCH="legacy-mcu1" ;;
            --version) echo "aic8800-wifi6-linux $VERSION (upstream main ${REF_MAIN:0:7}, legacy-mcu1 ${REF_LEGACY:0:7})"; exit 0 ;;
            -h|--help) usage; exit 0 ;;
            *) usage; exit 1 ;;
        esac
    done

    if [ "$(id -u)" -ne 0 ]; then
        if [ -f "$0" ] && [ "$(basename "$0")" = "install.sh" ]; then
            exec sudo bash "$0" "$@"
        fi
        # Running from "curl | bash": download again and run with sudo.
        exec sudo bash -c "$(curl -fsSL "$SELF_URL")" install.sh "$@"
    fi

    # Answers to questions (if any) come from the keyboard, never from the pipe
    # that carries this script.
    if (: < /dev/tty) 2>/dev/null; then TTY=/dev/tty; else TTY=/dev/null; fi

    : > "$LOG" 2>/dev/null || LOG=/tmp/aic8800-wifi6-linux.log
    echo "aic8800-wifi6-linux $VERSION $(date -Is) kernel $(uname -r)" >> "$LOG"

    printf '\n%saic8800-wifi6-linux %s%s — %s\n\n' "$B" "$VERSION" "$N" \
        "$(t 'placa USB WiFi 6 AIC8800' 'AIC8800 USB Wi-Fi 6 adapter')"

    local cmd
    for cmd in curl tar setsid; do
        command -v "$cmd" >/dev/null || die "$(t "Falta el programa '$cmd'. Instalalo y volvé a probar." "Missing '$cmd'. Install it and try again.")"
    done
    if [ -e /run/ostree-booted ]; then
        die "$(t 'Sistema inmutable (Fedora Silverblue/Bazzite): no se pueden instalar módulos así. Ver https://github.com/shenmintao/aic8800d80/tree/main/bazzite' 'Immutable system (Fedora Silverblue/Bazzite): modules cannot be installed this way. See https://github.com/shenmintao/aic8800d80/tree/main/bazzite')"
    fi

    SECURE_BOOT=0
    if secure_boot_enabled; then
        SECURE_BOOT=1
        warn "$(t 'Secure Boot está ACTIVADO: el driver no va a cargar hasta que lo desactives en la BIOS o firmes el módulo. El instalador te va a preguntar.' 'Secure Boot is ENABLED: the driver will not load until you disable it in the firmware or sign the module. The installer will ask you.')"
    fi

    install_branch "$BRANCH"

    step "$(t 'Buscando la placa...' 'Looking for the adapter...')"
    local info state dev id _
    info=$(find_adapter || true)
    if [ -z "$info" ] && [ "$TTY" = /dev/tty ]; then
        printf '  %s\n' "$(t 'Enchufá la placa USB ahora (espero 2 minutos)...' 'Plug in the USB adapter now (waiting 2 minutes)...')"
        for _ in $(seq 120); do info=$(find_adapter || true); [ -n "$info" ] && break; sleep 1; done
    fi
    if [ -z "$info" ]; then
        ok "$(t 'Driver listo. Enchufá la placa cuando quieras: se activa sola.' 'Driver ready. Plug in the adapter any time: it activates by itself.')"
        exit 0
    fi
    read -r state dev id <<< "$info"

    if [ "$state" = storage ]; then
        printf '  %s\n' "$(t "Está en modo pendrive ($id). Cambiando a modo WiFi..." "It is in USB-drive mode ($id). Switching to Wi-Fi mode...")"
        udevadm control --reload 2>/dev/null || true
        udevadm trigger --action=add --parent-match="$dev" 2>>"$LOG" || true
        for _ in $(seq 30); do
            sleep 1
            info=$(find_adapter || true); read -r state dev id <<< "$info"
            [ "$state" = wifi ] && break
        done
        [ "$state" = wifi ] || die "$(t 'No cambió de modo. Desenchufala, esperá 3 segundos y volvé a enchufarla.' 'It did not switch. Unplug it, wait 3 seconds and plug it back in.')"
    fi
    ok "$(t "Placa en modo WiFi ($id)" "Adapter in Wi-Fi mode ($id)")"

    # Wait for the driver to load firmware and create the interface. If an older
    # driver already loaded firmware, re-enumerate the device once.
    local iface
    iface=$(wait_iface "$dev" 25) || { replug "$dev"; iface=$(wait_iface "$dev" 25) || true; }

    local mcu
    mcu=$(dmesg 2>/dev/null | parse_mcu_id)
    echo "chip_mcu_id=$mcu iface=$iface" >> "$LOG"
    if [ "$mcu" = 1 ] && [ "$BRANCH" = main ]; then
        warn "$(t 'Tu placa es la variante MCU1: cambio a la rama legacy-mcu1 y reinstalo.' 'Your adapter is the MCU1 variant: switching to the legacy-mcu1 branch and reinstalling.')"
        BRANCH=legacy-mcu1
        install_branch "$BRANCH"
        replug "$dev"
        iface=$(wait_iface "$dev" 30) || true
    fi

    [ -n "$iface" ] || die "$(t 'El driver no creó la interfaz WiFi. Corré ./diagnose.sh y abrí un issue con el resultado.' 'The driver did not create a Wi-Fi interface. Run ./diagnose.sh and open an issue with its output.')"

    # Real check: can it see networks?
    ip link set "$iface" up 2>/dev/null || true
    local nets=0
    for _ in 1 2 3; do
        if command -v iw >/dev/null; then
            nets=$(iw dev "$iface" scan 2>/dev/null | grep -c '^BSS' || true)
        elif command -v nmcli >/dev/null; then
            nets=$(nmcli -t -f BSSID device wifi list ifname "$iface" --rescan yes 2>/dev/null | grep -c . || true)
        fi
        [ "${nets:-0}" -gt 0 ] && break
        sleep 3
    done
    if [ "${nets:-0}" -gt 0 ]; then
        ok "$(t "WiFi: $iface ve $nets redes" "Wi-Fi: $iface sees $nets networks")"
    else
        warn "$(t "WiFi: $iface creada, pero no encontré redes (¿hay alguna cerca?)" "Wi-Fi: $iface created, but no networks found (any nearby?)")"
    fi

    local hci=""
    for _ in $(seq 10); do hci=$(aic_hci "$dev" || true); [ -n "$hci" ] && break; sleep 1; done
    if [ -n "$hci" ]; then
        ok "$(t "Bluetooth: $hci" "Bluetooth: $hci")"
    else
        warn "$(t 'Bluetooth: no apareció (algunas placas son solo WiFi)' 'Bluetooth: not found (some adapters are Wi-Fi only)')"
    fi

    printf '\n%s%s%s\n' "$G$B" "$(t 'Listo. La placa se activa sola cada vez que la enchufes.' 'Done. The adapter activates by itself every time you plug it in.')" "$N"
    printf '%s\n  nmcli device wifi connect "%s" ifname %s --ask\n\n' \
        "$(t 'Conectate desde el menú de red, o:' 'Connect from your network menu, or:')" "$(t 'NOMBRE-DE-RED' 'NETWORK-NAME')" "$iface"
    printf '%s\n  https://github.com/matcarfer/aic8800-wifi6-linux/issues/new?template=works.yml\n\n' \
        "$(t '¿Te funcionó? Contalo para sumar tu distro a la lista (1 minuto):' 'Did it work? Tell us so your distro joins the list (1 minute):')"
}

# Tests source this file with AIC_TESTING=1 to reach the functions only.
[ "${AIC_TESTING:-0}" = 1 ] || main "$@"
