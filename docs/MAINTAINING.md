# Maintaining

**English** · [Español](MAINTAINING.es.md)

Step-by-step procedures for maintainers and contributors, human or AI. If a procedure here is wrong or missing, fix this file in the same PR.

## Golden rule: hardware before trust

Moving `REF_MAIN` / `REF_LEGACY` in `install.sh` changes what every user runs. Do it **only after installing that commit on a real adapter** and seeing ✓ Wi-Fi and ✓ Bluetooth (or "Wi-Fi only" for Wi-Fi-only adapters). Building in CI is necessary, but it is not enough.

When you report results, separate the three kinds of evidence: **built** (compiled), **mocked** (tests), **hardware** (real adapter: which one, which distro and kernel).

## Bumping the upstream commit

Triggered by an `upstream-update` issue from the watcher, or by a fix you need.

1. Read the upstream commits between the pinned ref and the new one: `https://github.com/shenmintao/aic8800d80/compare/<old>...<new>`. Watch for installer changes, because the spinner relies on `==> ` and the ✓ on `DKMS module registered`.
2. Change `REF_MAIN` (and/or `REF_LEGACY`) in `install.sh` to the full 40-character hash, with its date in the comment.
3. Run `python3 tests/test_install.py` and `shellcheck -S warning *.sh`.
4. Push to a branch and run the **kernel-build** workflow on it (Actions → kernel-build → Run workflow).
5. **On hardware:** `sudo ./uninstall.sh`, unplug and replug (USB-drive mode should come back), then `./install.sh` from the branch.
6. Add the result to the tested table in both READMEs, and a `CHANGELOG.md` + `CHANGELOG.es.md` entry.
7. Version: patch for a bump only, minor if behavior changes.

## Adding an adapter

Usually from a `new-adapter` issue that includes `lsusb` before and after.

1. **Is it AIC?** In Wi-Fi mode, the ID must be one the upstream driver binds to: check `USB_DEVICE` entries in `drivers/aic8800/aic_load_fw/*.c` and `aic8800_fdrv/*.c` upstream. If it is not there, it is an upstream request first.
2. **Storage-mode ID:** add it to `STORAGE_IDS`. **Wi-Fi-mode ID:** add it to `WIFI_IDS`. Use exact `vid:pid` when the vendor also makes non-AIC adapters (TP-Link `2357`, Tenda `2604`); `vid:*` is only for AIC's own vendor IDs.
3. If it needs a **different mode-switch command** than upstream knows, that goes upstream (`usb_modeswitch/` and `aic.rules` there), not here.
4. Add a case to `test_wifi_mode_ids` / `test_aic_storage_ids` in `tests/test_install.py`.
5. Update the "Is this my adapter?" table in both READMEs if the ID is common.

## When kernel-build opens a `kernel-break` issue

1. Open the failed run and find the first `error:` in the build log.
2. Check upstream issues and PRs: someone has often reported it already.
3. If upstream already fixed it, test that commit on hardware and bump.
4. If not, report it upstream with the log. A fix PR is better still: driver fixes always go upstream.
5. Users on that kernel are affected until then: pin a note at the top of both READMEs.

## When Omarchy (or another distro) changes

Things to check after a big Omarchy release, or when a user reports a hang or a boot problem:

- [ ] Does `limine-mkinitcpio` still exist? (`command -v limine-mkinitcpio`)
- [ ] Does `/usr/local/bin/mkinitcpio` still wrap with a prompt? If it changed, does the shim still avoid it?
- [ ] Is the kernel still `linux-omarchy`, with headers `linux-omarchy-headers`? (Upstream derives the headers package from `/usr/lib/modules/$(uname -r)/pkgbase`.)
- [ ] Is the Omarchy package repository still `https://pkgs.omarchy.org/stable/$arch`, with signing key `40DFB630FF42BCFFB047046CF0134EE680CAC571`? `kernel-build.yml` uses both.
- [ ] Network stack: Omarchy currently uses NetworkManager. The final check uses `iw`, then `nmcli`.
- [ ] Do a full hardware run: uninstall, replug, install.

## Releasing

1. All of the above is green. `CHANGELOG.md` and `CHANGELOG.es.md` have `## [X.Y.Z] — YYYY-MM-DD`.
2. `VERSION="X.Y.Z"` in `install.sh` (the tests check that it matches the changelogs).
3. `./release.sh` creates tag `vX.Y.Z` and the GitHub release with both changelogs, and leaves only the latest release published.

`main` is what `curl | bash` serves, so **never push untested installer changes to `main`**. Use branches and PRs.

## Donation links

Always in this order, in both READMEs and in `.github/FUNDING.yml`:

1. Cafecito: https://cafecito.app/matcarfer
2. Matecito: https://www.matecito.co/matcarfer
3. Mercado Pago: https://link.mercadopago.com.ar/matcarfer
4. Ko-fi: https://ko-fi.com/matcarfer
5. Patreon: https://www.patreon.com/matcarfer

## Upstream PRs from this repo

| PR | What | State when written |
|---|---|---|
| [#156](https://github.com/shenmintao/aic8800d80/pull/156) | Use `limine-mkinitcpio` on Limine UKI systems (`main`) | open |
| [#157](https://github.com/shenmintao/aic8800d80/pull/157) | Same fix for `legacy-mcu1` | open |

Once both are merged and pinned, `write_mkinitcpio_shim()` can go (keep the stall watchdog).
