#!/usr/bin/env python3
"""Tests for install.sh using a fake sysfs tree and stub commands.

No root, no hardware, no network: install.sh is sourced with AIC_TESTING=1 so
only its functions load, and AIC_SYSFS points at a temporary directory.

Run:  python3 tests/test_install.py
Copyright (C) 2026 matcarfer and contributors
SPDX-License-Identifier: GPL-3.0-or-later
"""

import os
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
INSTALLER = REPO / "install.sh"
BASH = shutil.which("bash")


class FakeSysfs:
    """Builds the bits of /sys that install.sh reads."""

    def __init__(self, root: Path):
        self.root = root
        (root / "bus/usb/devices").mkdir(parents=True)
        (root / "class/net").mkdir(parents=True)
        (root / "class/bluetooth").mkdir(parents=True)

    def usb(self, name, vid, pid, product=""):
        dev = self.root / "devices/pci0000:00/usb1" / name
        dev.mkdir(parents=True)
        (dev / "idVendor").write_text(vid + "\n")
        (dev / "idProduct").write_text(pid + "\n")
        if product:
            (dev / "product").write_text(product + "\n")
        (self.root / "bus/usb/devices" / name).symlink_to(dev)
        return dev

    def wlan(self, dev, name):
        net = dev / "net" / name
        (net / "phy80211").mkdir(parents=True)
        (self.root / "class/net" / name).symlink_to(net)

    def ethernet(self, dev, name):
        net = dev / "net" / name
        net.mkdir(parents=True)
        (self.root / "class/net" / name).symlink_to(net)

    def hci(self, dev, name):
        intf = dev / (dev.name + ":1.0")
        h = intf / "bluetooth" / name
        h.mkdir(parents=True)
        (h / "device").symlink_to(intf)
        (self.root / "class/bluetooth" / name).symlink_to(h)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="aic-test-")
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.sys = FakeSysfs(self.tmp / "sys")

    def bash(self, code, env=None, stdin=""):
        full_env = {"PATH": os.environ["PATH"], "LANG": "C", "AIC_TESTING": "1",
                    "AIC_SYSFS": str(self.sys.root)}
        full_env.update(env or {})
        script = f"source {shlex.quote(str(INSTALLER))}\n{code}"
        return subprocess.run([BASH, "-c", script], input=stdin, text=True,
                              capture_output=True, env=full_env, timeout=30)

    def out(self, code, **kw):
        result = self.bash(code, **kw)
        return result.stdout.strip()

    # ---------------------------------------------------------- loading
    def test_sourcing_does_not_run_main(self):
        result = self.bash("echo LOADED")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "LOADED")

    def test_pinned_refs_are_full_commit_hashes(self):
        # CI and docs read these lines; keep them parseable.
        text = INSTALLER.read_text()
        for name in ("REF_MAIN", "REF_LEGACY"):
            self.assertRegex(text, rf'(?m)^{name}="[0-9a-f]{{40}}"')

    def test_version_is_semver_and_in_both_changelogs(self):
        version = re.search(r'(?m)^VERSION="(\d+\.\d+\.\d+)"', INSTALLER.read_text()).group(1)
        for changelog in ("CHANGELOG.md", "CHANGELOG.es.md"):
            self.assertIn(f"## [{version}]", (REPO / changelog).read_text(), changelog)

    # ---------------------------------------------------------- find_adapter
    def test_pandora_88m80_in_storage_mode(self):
        dev = self.sys.usb("1-1", "1111", "1111", "88M80")
        self.assertEqual(self.out("find_adapter"), f"storage {self.sys.root}/bus/usb/devices/1-1 1111:1111")
        self.assertTrue(dev.exists())

    def test_other_1111_devices_are_ignored(self):
        # 1111:1111 is a placeholder some AIC dongles use for a separate "FLASH" disk.
        self.sys.usb("1-1", "1111", "1111", "FLASH")
        self.assertEqual(self.bash("find_adapter").returncode, 1)

    def test_aic_storage_ids(self):
        self.sys.usb("1-2", "a69c", "5721", "Aic MSC")
        self.assertTrue(self.out("find_adapter").startswith("storage "))

    def test_wifi_mode_ids(self):
        for vid, pid in [("a69c", "8d80"), ("a69c", "8d81"), ("368b", "8d91"),
                         ("2604", "001f"), ("3625", "0110"), ("2357", "014e")]:
            with self.subTest(id=f"{vid}:{pid}"):
                sysfs = FakeSysfs(self.tmp / f"sys-{vid}-{pid}")
                sysfs.usb("1-1", vid, pid)
                result = self.bash("find_adapter", env={"AIC_SYSFS": str(sysfs.root)})
                self.assertEqual(result.stdout.split()[0], "wifi", result.stderr)

    def test_unrelated_devices_are_ignored(self):
        self.sys.usb("1-1", "8087", "07dc")   # Intel Bluetooth
        self.sys.usb("1-2", "2357", "010c")   # TP-Link Realtek adapter, not AIC
        self.sys.usb("1-3", "0bda", "8179")
        self.assertEqual(self.bash("find_adapter").returncode, 1)

    # ---------------------------------------------------------- iface / hci
    def test_iface_and_hci_on_the_adapter(self):
        dev = self.sys.usb("1-1", "a69c", "8d81", "AIC 8800D80")
        self.sys.wlan(dev, "wlan0")
        self.sys.hci(dev, "hci1")
        other = self.sys.usb("1-5", "8087", "07dc")
        self.sys.wlan(other, "wlp2s0")
        self.sys.hci(other, "hci0")
        path = f"{self.sys.root}/bus/usb/devices/1-1"
        self.assertEqual(self.out(f"aic_iface {path}"), "wlan0")
        self.assertEqual(self.out(f"aic_hci {path}"), "hci1")

    def test_iface_ignores_non_wireless_netdevs(self):
        dev = self.sys.usb("1-1", "a69c", "8d81")
        self.sys.ethernet(dev, "usb0")
        self.assertEqual(self.bash(f"aic_iface {self.sys.root}/bus/usb/devices/1-1").returncode, 1)

    def test_no_iface_no_hci(self):
        self.sys.usb("1-1", "a69c", "8d81")
        path = f"{self.sys.root}/bus/usb/devices/1-1"
        self.assertEqual(self.bash(f"aic_iface {path}").returncode, 1)
        self.assertEqual(self.bash(f"aic_hci {path}").returncode, 1)

    # ---------------------------------------------------------- chip_mcu_id
    def test_parse_mcu_id(self):
        cases = {
            "chip_id=7, chip_mcu_id = 0\n": "0",
            "x\nchip_id=7, chip_mcu_id = 0\nlater\nchip_id=7, chip_mcu_id = 1\n": "1",
            "chip_mcu_id=1\n": "1",
            "nothing here\n": "",
        }
        for log, expected in cases.items():
            with self.subTest(log=log):
                self.assertEqual(self.out("parse_mcu_id", stdin=log), expected)

    # ---------------------------------------------------------- mkinitcpio shim
    def make_shim(self, tools):
        shim = self.tmp / "shim"
        bin_dir = self.tmp / "bin"
        shim.mkdir()
        bin_dir.mkdir()
        calls = self.tmp / "calls"
        for name in tools:
            tool = bin_dir / name
            # Records its args; fails if stdin could block (terminal or data).
            tool.write_text("#!/bin/sh\n[ -t 0 ] && exit 9\nread -r x && exit 8\n"
                            f'echo "{name} $*" >> {shlex.quote(str(calls))}\n')
            tool.chmod(0o755)
        real = bin_dir / "real-mkinitcpio"
        real.write_text(f'#!/bin/sh\nread -r x && exit 8\necho "real-mkinitcpio $*" >> {shlex.quote(str(calls))}\n')
        real.chmod(0o755)
        # Only stubs plus cat/chmod: the real limine-mkinitcpio must never be reachable.
        for name in ("cat", "chmod"):
            (bin_dir / name).symlink_to(shutil.which(name))
        env = {"PATH": str(bin_dir), "AIC_MKINITCPIO": str(real)}
        result = self.bash(f"write_mkinitcpio_shim {shim}", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        return shim, calls, env

    def test_shim_uses_limine_mkinitcpio_when_present(self):
        shim, calls, env = self.make_shim(["limine-mkinitcpio"])
        run = subprocess.run([str(shim / "mkinitcpio"), "-P"], input="y\n", text=True,
                             capture_output=True, env={"PATH": str(shim)})
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(calls.read_text().strip(), "limine-mkinitcpio")

    def test_shim_passes_through_without_limine(self):
        shim, calls, env = self.make_shim([])
        run = subprocess.run([str(shim / "mkinitcpio"), "-P"], input="y\n", text=True,
                             capture_output=True, env={"PATH": str(shim)})
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(calls.read_text().strip(), "real-mkinitcpio -P")

    def test_shim_never_calls_itself(self):
        shim, calls, env = self.make_shim(["limine-mkinitcpio"])
        text = (shim / "mkinitcpio").read_text()
        self.assertNotIn(str(shim), text)

    # ---------------------------------------------------------- language
    def test_language(self):
        self.assertEqual(self.out("t hola hello", env={"LANG": "es_AR.UTF-8"}), "hola")
        self.assertEqual(self.out("t hola hello", env={"LANG": "en_US.UTF-8"}), "hello")
        self.assertEqual(self.out("t hola hello", env={"LANG": "C", "LC_ALL": "es_ES.UTF-8"}), "hola")

    def test_every_visible_message_is_bilingual(self):
        # step/ok/warn/die/printf with a literal message must go through t '…' '…'.
        text = INSTALLER.read_text()
        for match in re.finditer(r'(?m)^\s*(step|ok|warn|die) "([^"$][^"]*)"', text):
            self.fail(f"untranslated message: {match.group(0).strip()}")

    def test_version_flag(self):
        result = subprocess.run(["bash", str(INSTALLER), "--version"], text=True, capture_output=True,
                                env={"PATH": os.environ["PATH"]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout, r"^aic8800-wifi6-linux \d+\.\d+\.\d+ \(upstream main [0-9a-f]{7}")


if __name__ == "__main__":
    unittest.main()
