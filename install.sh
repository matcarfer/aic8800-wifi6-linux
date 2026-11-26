#!/usr/bin/env bash
# aic8800-wifi6-linux — one-command installer for AIC8800 USB Wi-Fi 6 (+Bluetooth)
# adapters that show up as a fake USB drive (1111:1111 "88M80", a69c:57xx).
#
# It wraps the driver maintained at https://github.com/shenmintao/aic8800d80
# (GPL-2.0) pinned to a tested commit, and adds:
#   - one command, no cloning, short bilingual output (es/en)
#   - no hidden prompt on Omarchy / Limine (mkinitcpio wrapper)
#   - switches the adapter from "USB drive" to Wi-Fi without unplugging it
#   - picks the right driver branch (main / legacy-mcu1) from chip_mcu_id
#   - checks that Wi-Fi really scans and Bluetooth really appears
#
# Usage:  curl -fsSL https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/install.sh | bash
#    or:  sudo ./install.sh [--legacy] [--help]
#
# License: GPL-3.0-or-later. Author: matcarfer.

set -uo pipefail

VERSION="1.0.0"
SELF_URL="https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/install.sh"
UPSTREAM="shenmintao/aic8800d80"
# Tested commits. Update together with CHANGELOG after testing.
REF_MAIN="1a2ce4e38e678a0c0d7f6071be415ab74f488240"     # main, 2026-11-20
REF_LEGACY="3e9b91be1da35cb4d11556288b44c1b4d04f0670"   # legacy-mcu1
PREFIX="/usr/local/src/aic8800-wifi6-linux"
LOG="/var/log/aic8800-wifi6-linux.log"

# ---------------------------------------------------------------- language
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
    es*) ES=1 ;;
    *) ES=0 ;;
esac
t() { if [ "$ES" = 1 ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

if [ -t 1 ]; then
    B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'
else
    B=; G=; Y=; R=; C=; N=
fi
step() { printf '%s==>%s %s\n' "$C$B" "$N" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '  %s✗%s %s\n' "$R" "$N" "$*" >&2; printf '    %s %s\n' "$(t 'Log completo:' 'Full log:')" "$LOG" >&2; exit 1; }

usage() {
    cat <<EOF
aic8800-wifi6-linux $VERSION
$(t 'Instala el driver de placas USB WiFi 6 AIC8800 (y su Bluetooth).' 'Installs the driver for AIC8800 USB Wi-Fi 6 adapters (and their Bluetooth).')

  sudo ./install.sh            $(t 'instalar (elige la rama sola)' 'install (picks the branch automatically)')
  sudo ./install.sh --legacy   $(t 'forzar rama legacy-mcu1' 'force legacy-mcu1 branch')
  sudo ./uninstall.sh          $(t 'desinstalar' 'uninstall')
EOF
}

BRANCH="main"
for a in "$@"; do
    case "$a" in
        --legacy) BRANCH="legacy-mcu1" ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# ---------------------------------------------------------------- root
if [ "$(id -u)" -ne 0 ]; then
    if [ -f "$0" ] && [ "$(basename "$0")" = "install.sh" ]; then
        exec sudo bash "$0" "$@"
    fi
    # Running from "curl | bash": download again and run with sudo.
    command -v curl >/dev/null || { echo "curl?"; exit 1; }
    exec sudo bash -c "$(curl -fsSL "$SELF_URL")" install.sh "$@"
fi

# Answers to interactive questions (if any) come from the keyboard, never
# from the pipe that carries this script.
if [ -r /dev/tty ] && (: < /dev/tty) 2>/dev/null; then TTY=/dev/tty; else TTY=/dev/null; fi

: > "$LOG" 2>/dev/null || LOG=/tmp/aic8800-wifi6-linux.log
echo "aic8800-wifi6-linux $VERSION $(date -Is) kernel $(uname -r)" >> "$LOG"

printf '\n%saic8800-wifi6-linux %s%s — %s\n\n' "$B" "$VERSION" "$N" \
    "$(t 'placa USB WiFi 6 AIC8800' 'AIC8800 USB Wi-Fi 6 adapter')"

for cmd in curl tar; do
    command -v "$cmd" >/dev/null || die "$(t "Falta el programa '$cmd'. Instalalo y volvé a probar." "Missing '$cmd'. Install it and try again.")"
done

# ---------------------------------------------------------------- USB helpers
# Prints "<state> <sysfs-path> <vid:pid>" for the first AIC adapter found.
# state: storage (still a fake USB drive) | wifi (in Wi-Fi mode)
find_adapter() {
    local d vid pid prod
    for d in /sys/bus/usb/devices/*; do
        [ -r "$d/idVendor" ] || continue
        vid=$(cat "$d/idVendor"); pid=$(cat "$d/idProduct")
        prod=$(cat "$d/product" 2>/dev/null || true)
        case "$vid:$pid" in
            1111:1111) case "$prod" in 88M80*) echo "storage $d $vid:$pid"; return 0 ;; esac ;;
            a69c:57??) echo "storage $d $vid:$pid"; return 0 ;;
            a69c:8d8?|a69c:88d?|368b:*|2604:00??|2357:014?) echo "wifi $d $vid:$pid"; return 0 ;;
        esac
    done
    return 1
}

# Wi-Fi interface living on the given USB device, if any.
# (The AIC driver attaches its netdev to the USB device itself, not to an
# interface, so match by sysfs path instead of driver name.)
aic_iface() {
    local dev n
    dev=$(readlink -f "$1")
    for n in /sys/class/net/*; do
        [ -e "$n/phy80211" ] || continue
        case "$(readlink -f "$n")" in "$dev"/*) basename "$n"; return 0 ;; esac
    done
    return 1
}

# Bluetooth controller living on the given USB device.
aic_hci() {
    local dev=$1 h
    for h in /sys/class/bluetooth/hci*; do
        [ -e "$h" ] || continue
        case "$(readlink -f "$h/device" 2>/dev/null)" in "$(readlink -f "$dev")"/*) basename "$h"; return 0 ;; esac
    done
    return 1
}

# ---------------------------------------------------------------- install
install_branch() {
    local branch=$1 ref src tmp shim rc
    [ "$branch" = "main" ] && ref=$REF_MAIN || ref=$REF_LEGACY

    step "$(t "Descargando el driver ($branch, ${ref:0:7})..." "Downloading the driver ($branch, ${ref:0:7})...")"
    tmp=$(mktemp -d)
    if ! curl -fsSL "https://codeload.github.com/$UPSTREAM/tar.gz/$ref" | tar -xz -C "$tmp" >> "$LOG" 2>&1; then
        rm -rf "$tmp"; die "$(t 'No se pudo descargar. ¿Hay internet? (podés usar el WiFi de la notebook o el celular por USB)' 'Download failed. Is there internet? (use built-in Wi-Fi or USB tethering)')"
    fi
    src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
    mkdir -p "$PREFIX"
    rm -rf "$PREFIX/upstream"
    mv "$src" "$PREFIX/upstream"
    rm -rf "$tmp"
    printf 'branch=%s\nref=%s\n' "$branch" "$ref" > "$PREFIX/installed"
    ok "$(t 'Descargado' 'Downloaded')"

    # Omarchy/Limine: /usr/local/bin/mkinitcpio asks "run limine-mkinitcpio? [Y/n]"
    # but upstream hides that output, so it looks frozen. Answer it for them.
    shim=$(mktemp -d)
    cat > "$shim/mkinitcpio" <<EOF
#!/bin/sh
export PATH="$PATH"
if command -v limine-mkinitcpio >/dev/null 2>&1; then exec limine-mkinitcpio < /dev/null; fi
exec /usr/bin/mkinitcpio "\$@" < /dev/null
EOF
    chmod +x "$shim/mkinitcpio"

    step "$(t 'Compilando e instalando (3-6 minutos, no cierres esta ventana)...' 'Building and installing (3-6 minutes, keep this window open)...')"
    if [ "$SECURE_BOOT" = 1 ]; then
        # Upstream must ask about Secure Boot itself: show everything.
        (cd "$PREFIX/upstream" && PATH="$shim:$PATH" bash ./install.sh) < "$TTY" 2>&1 | tee -a "$LOG"
        rc=${PIPESTATUS[0]}
    else
        (cd "$PREFIX/upstream" && PATH="$shim:$PATH" bash ./install.sh) < /dev/null >> "$LOG" 2>&1 &
        local pid=$! i=0 spin='|/-\'
        while kill -0 "$pid" 2>/dev/null; do
            if [ -t 1 ]; then
                printf '\r  %s %s ' "${spin:i++%4:1}" "$(grep -a '^.*==> ' "$LOG" | tail -1 | sed 's/\x1b\[[0-9;]*m//g; s/.*==> //' | cut -c1-60)"
                printf '\e[K'
            fi
            sleep 1
        done
        wait "$pid"; rc=$?
        [ -t 1 ] && printf '\r\e[K'
    fi
    rm -rf "$shim"
    if [ "$rc" -ne 0 ]; then
        sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -aE '\[ERROR\]|error:' | tail -5 | sed 's/^/    /' >&2
        die "$(t 'La instalación del driver falló.' 'Driver installation failed.')"
    fi
    grep -aq 'DKMS module registered' "$LOG" && ok "$(t 'Driver instalado con DKMS (se recompila solo con cada kernel nuevo)' 'Driver installed with DKMS (rebuilds itself on every new kernel)')"
}

# ---------------------------------------------------------------- main
SECURE_BOOT=0
if command -v mokutil >/dev/null && mokutil --sb-state 2>/dev/null | grep -qi 'enabled'; then
    SECURE_BOOT=1
elif f=$(ls /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -1) && [ -n "$f" ] && \
     [ "$(od -An -t u1 "$f" | awk '{print $NF}')" = 1 ]; then
    SECURE_BOOT=1
fi
if [ "$SECURE_BOOT" = 1 ]; then
    warn "$(t 'Secure Boot está ACTIVADO: el driver no va a cargar hasta que lo desactives en la BIOS o firmes el módulo. El instalador te va a preguntar.' 'Secure Boot is ENABLED: the driver will not load until you disable it in the firmware or sign the module. The installer will ask you.')"
fi

install_branch "$BRANCH"

step "$(t 'Buscando la placa...' 'Looking for the adapter...')"
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

# Wait for the driver to load firmware and create the interface.
iface=""
for _ in $(seq 25); do iface=$(aic_iface "$dev" || true); [ -n "$iface" ] && break; sleep 1; done
if [ -z "$iface" ]; then
    # Firmware may have been loaded by an older driver: re-enumerate the device.
    echo 0 > "$dev/authorized" 2>/dev/null; sleep 2; echo 1 > "$dev/authorized" 2>/dev/null
    for _ in $(seq 25); do iface=$(aic_iface "$dev" || true); [ -n "$iface" ] && break; sleep 1; done
fi

mcu=$(dmesg 2>/dev/null | grep -ao 'chip_mcu_id = [0-9]' | tail -1 | grep -o '[0-9]$' || true)
echo "chip_mcu_id=$mcu iface=$iface" >> "$LOG"
if [ "$mcu" = 1 ] && [ "$BRANCH" = main ]; then
    warn "$(t 'Tu placa es la variante MCU1: cambio a la rama legacy-mcu1 y reinstalo.' 'Your adapter is the MCU1 variant: switching to the legacy-mcu1 branch and reinstalling.')"
    BRANCH=legacy-mcu1
    install_branch "$BRANCH"
    echo 0 > "$dev/authorized" 2>/dev/null; sleep 2; echo 1 > "$dev/authorized" 2>/dev/null
    iface=""
    for _ in $(seq 30); do iface=$(aic_iface "$dev" || true); [ -n "$iface" ] && break; sleep 1; done
fi

[ -n "$iface" ] || die "$(t 'El driver no creó la interfaz WiFi. Corré ./diagnose.sh y abrí un issue con el resultado.' 'The driver did not create a Wi-Fi interface. Run ./diagnose.sh and open an issue with its output.')"

# Real check: can it see networks?
ip link set "$iface" up 2>/dev/null || true
nets=0
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

hci=""
for _ in $(seq 10); do hci=$(aic_hci "$dev" || true); [ -n "$hci" ] && break; sleep 1; done
if [ -n "$hci" ]; then
    ok "$(t "Bluetooth: $hci" "Bluetooth: $hci")"
else
    warn "$(t 'Bluetooth: no apareció (algunas placas son solo WiFi)' 'Bluetooth: not found (some adapters are Wi-Fi only)')"
fi

printf '\n%s%s%s\n' "$G$B" "$(t 'Listo. La placa se activa sola cada vez que la enchufes.' 'Done. The adapter activates by itself every time you plug it in.')" "$N"
printf '%s\n  nmcli device wifi connect "%s" ifname %s --ask\n\n' \
    "$(t 'Conectate desde el menú de red, o:' 'Connect from your network menu, or:')" "$(t 'NOMBRE-DE-RED' 'NETWORK-NAME')" "$iface"
