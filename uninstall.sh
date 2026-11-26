#!/usr/bin/env bash
# aic8800-wifi6-linux — removes the driver, firmware, udev rule and mode-switch
# config installed by install.sh. License: GPL-3.0-or-later. Author: matcarfer.
set -uo pipefail

PREFIX="/usr/local/src/aic8800-wifi6-linux"
SELF_URL="https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/uninstall.sh"
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in es*) ES=1 ;; *) ES=0 ;; esac
t() { if [ "$ES" = 1 ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

if [ "$(id -u)" -ne 0 ]; then
    if [ -f "$0" ] && [ "$(basename "$0")" = "uninstall.sh" ]; then exec sudo bash "$0" "$@"; fi
    exec sudo bash -c "$(curl -fsSL "$SELF_URL")" uninstall.sh "$@"
fi

if [ ! -x "$PREFIX/upstream/uninstall.sh" ] && [ ! -f "$PREFIX/upstream/uninstall.sh" ]; then
    echo "$(t 'No encontré una instalación hecha con este repo.' 'No installation made with this repo was found.')"
    exit 0
fi

# Same Omarchy/Limine mkinitcpio fix as install.sh.
shim=$(mktemp -d)
cat > "$shim/mkinitcpio" <<EOF
#!/bin/sh
export PATH="$PATH"
if command -v limine-mkinitcpio >/dev/null 2>&1; then exec limine-mkinitcpio < /dev/null; fi
exec /usr/bin/mkinitcpio "\$@" < /dev/null
EOF
chmod +x "$shim/mkinitcpio"

echo "==> $(t 'Desinstalando (1-2 minutos)...' 'Uninstalling (1-2 minutes)...')"
(cd "$PREFIX/upstream" && PATH="$shim:$PATH" bash ./uninstall.sh) < /dev/null
rc=$?
rm -rf "$shim"
if [ "$rc" -eq 0 ]; then
    rm -rf "$PREFIX"
    echo "  ✓ $(t 'Desinstalado. Desenchufá la placa.' 'Uninstalled. Unplug the adapter.')"
else
    echo "  ✗ $(t 'Falló la desinstalación (ver arriba).' 'Uninstall failed (see above).')" >&2
fi
exit "$rc"
