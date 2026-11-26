#!/usr/bin/env bash
# Builds the pinned upstream driver against the newest kernel headers of a distro.
# Used by .github/workflows/kernel-build.yml inside a distro container.
#
# Usage: kernel-build.sh <omarchy|arch|ubuntu|fedora|local> <main|legacy>
#   local = no package install, build against the running kernel (to try it on your machine).
#
# Copyright (C) 2026 matcarfer and contributors
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

distro=${1:?distro}
branch=${2:?main or legacy}
repo=$(cd "$(dirname "$0")/../.." && pwd)
# Omarchy package repository and its signing key (docs/MAINTAINING.md).
OMARCHY_SERVER='https://pkgs.omarchy.org/stable/$arch'
OMARCHY_KEY=40DFB630FF42BCFFB047046CF0134EE680CAC571

install_pkgs() {
    case "$distro" in
        omarchy)
            pacman-key --init
            pacman-key --recv-keys "$OMARCHY_KEY" --keyserver hkps://keyserver.ubuntu.com \
                || pacman-key --recv-keys "$OMARCHY_KEY" --keyserver hkps://keys.openpgp.org
            pacman-key --lsign-key "$OMARCHY_KEY"
            printf '\n[omarchy]\nServer = %s\n' "$OMARCHY_SERVER" >> /etc/pacman.conf
            pacman -Syu --noconfirm --needed base-devel curl bc linux-omarchy-headers ;;
        arch)
            pacman -Syu --noconfirm --needed base-devel curl bc linux-headers ;;
        ubuntu)
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                build-essential bc curl ca-certificates kmod libelf-dev linux-headers-generic ;;
        fedora)
            dnf install -y gcc make bc curl tar findutils elfutils-libelf-devel kernel-devel ;;
        local) ;;
        *) echo "unknown distro: $distro" >&2; exit 2 ;;
    esac
}

install_clang() {
    case "$distro" in
        omarchy|arch) pacman -S --noconfirm --needed clang lld llvm ;;
        ubuntu) DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends clang lld llvm ;;
        fedora) dnf install -y clang lld llvm ;;
    esac
}

# Newest kernel build tree installed (or the running one for "local").
find_kdir() {
    if [ "$distro" = local ]; then
        echo "/lib/modules/$(uname -r)/build"; return
    fi
    for d in /usr/lib/modules/*/build /lib/modules/*/build /usr/src/kernels/*; do
        [ -f "$d/Makefile" ] && readlink -f "$d"
    done | sort -uV | tail -1
}

install_pkgs

case "$branch" in
    main) var=REF_MAIN ;;
    legacy) var=REF_LEGACY ;;
    *) echo "branch must be main or legacy" >&2; exit 2 ;;
esac
ref=$(sed -n "s/^$var=\"\([0-9a-f]\{40\}\)\".*/\1/p" "$repo/install.sh")
[ -n "$ref" ] || { echo "$var not found in install.sh" >&2; exit 1; }

kdir=$(find_kdir)
[ -n "$kdir" ] && [ -f "$kdir/Makefile" ] || { echo "no kernel build tree found" >&2; exit 1; }
kver=$(make -s -C "$kdir" kernelversion 2>/dev/null || basename "$(dirname "$kdir")")
for f in "$kdir/include/config/auto.conf" "$kdir/.config"; do
    if [ -r "$f" ] && grep -q '^CONFIG_CC_IS_CLANG=y' "$f"; then install_clang; break; fi
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fsSL "https://codeload.github.com/shenmintao/aic8800d80/tar.gz/$ref" | tar -xz -C "$work"
src=$(find "$work" -mindepth 1 -maxdepth 1 -type d | head -1)

echo "== $distro / $branch ${ref:0:7} / kernel $kver ($kdir)"
make -C "$src/drivers/aic8800" KDIR="$kdir" KVER="$kver" -j"$(nproc)"

missing=0
for ko in aic8800_fdrv aic_load_fw aic_zlp_quirk; do
    if find "$src/drivers/aic8800" -name "$ko.ko" | grep -q .; then echo "built $ko.ko"; else echo "MISSING $ko.ko"; missing=1; fi
done

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    if [ "$missing" = 0 ]; then mark="✅"; else mark="❌"; fi
    echo "| $distro | $branch \`${ref:0:7}\` | \`$kver\` | $mark |" >> "$GITHUB_STEP_SUMMARY"
fi
exit "$missing"
