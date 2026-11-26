# Instructions for AI assistants (agents)

**English** · [Español](AGENTS.es.md)

This file is for Claude, Codex, Copilot, Gemini, or any other assistant editing this repository. Humans can read it too: it summarizes [CONTRIBUTING.md](CONTRIBUTING.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/MAINTAINING.md](docs/MAINTAINING.md). **Read those before changing code.**

aic8800-wifi6-linux is a **wrapper**. It does not contain the driver: it downloads [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80) at a pinned commit and runs its installer. What matters here is that it is **easy, short and honest**.

## Before finishing any change

```bash
bash -n *.sh && shellcheck -S warning *.sh && python3 tests/test_install.py
```

All three must pass. CI runs the same checks.

## Rules

1. **Never copy driver or firmware code into this repo.** Driver fixes go upstream as PRs. Upstream has its own `AGENTS.md`: follow it there.
2. **Never move `REF_MAIN` / `REF_LEGACY` without a hardware test** (docs/MAINTAINING.md). If you cannot test on hardware, open the PR and say so plainly. Never claim "tested" for something that was only built or mocked.
3. **`main` is live:** `curl | bash` serves it immediately. Make changes on a branch through a PR.
4. **Every user-visible message is bilingual:** `t 'castellano' 'english'`. Spanish is Rioplatense with *voseo* ("enchufá", "corré"). A test rejects untranslated `step` / `ok` / `warn` / `die` messages.
5. **Short output:** `step` for phases, `ok` / `warn` / `die` for results. Upstream's output goes to `$LOG`, not the screen.
6. **Never read answers from stdin.** With `curl | bash`, stdin is the script. Use `$TTY` (`/dev/tty` or `/dev/null`).
7. **Nothing may wait forever.** Long waits need a limit (`seq N` loops, the stall watchdog).
8. **`main "$@"` stays on the last line**, behind the `AIC_TESTING` guard. Do not add top-level code that does work.
9. **New functions get a short comment** and, when they parse something, a test in `tests/test_install.py`. Use `$SYSFS`, never a hard-coded `/sys`, so tests can fake it.
10. **`diagnose.sh` is read-only** and hides MAC addresses. Never add serial numbers, SSIDs, IPs or user names.
11. **Docs in both languages:** each `X.md` has an `X.es.md` twin (READMEs are the exception: `README.md` is Spanish and `README.en.md` is English). Update both in the same change.
12. **Credits:** when you use someone's finding, fix or code, add them to `CREDITS.md` and `CREDITS.es.md`.
13. **Header** in every script: `Copyright (C) 2026 matcarfer and contributors` and `SPDX-License-Identifier: GPL-3.0-or-later`.
14. **Donation links**, when they appear: Cafecito, Matecito, Mercado Pago, Ko-fi, Patreon, in that order (docs/MAINTAINING.md).

## Quick map

- Adapter IDs: `STORAGE_IDS` / `WIFI_IDS` at the top of `install.sh`.
- Detection: `find_adapter()`, `aic_iface()`, `aic_hci()`, `parse_mcu_id()`.
- Omarchy/Limine fix: `write_mkinitcpio_shim()`, plus upstream PRs #156 and #157.
- Upstream run, spinner and watchdog: `run_upstream_quiet()`. Download: `install_branch()`.
- Flow: `main()`, step by step in docs/ARCHITECTURE.md.
