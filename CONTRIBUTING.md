# Contributing

**English** · [Español](CONTRIBUTING.es.md)

Thanks for helping! Every kind of contribution counts, and AI-assisted ones are welcome (see [AGENTS.md](AGENTS.md)).

## Without writing code

- **It worked?** Open an ["It works!" issue](../../issues/new?template=works.yml): distro, kernel, adapter. It goes into the tested table.
- **It failed?** Run `diagnose.sh` and open an ["It didn't work" issue](../../issues/new?template=error.yml).
- **New adapter?** Use the ["New adapter" template](../../issues/new?template=new-adapter.yml) with `lsusb` before and after.
- **Translations and docs:** fixes to wording are very welcome. Spanish is Rioplatense (*voseo*).

## Where things go

| Problem | Where |
|---|---|
| The installer, detection, messages, docs | here |
| Drops, speed, crashes or build errors **of the driver** | [upstream](https://github.com/shenmintao/aic8800d80/issues) |
| A mode-switch command for a new adapter | upstream (`usb_modeswitch/`, `aic.rules`) |

## Code

1. Fork, then create a branch. **Never push to `main` directly**: `curl | bash` serves it live.
2. Keep changes small and explained. Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) first.
3. Before you open the PR: `bash -n *.sh && shellcheck -S warning *.sh && python3 tests/test_install.py`.
4. Every new message goes through `t 'es' 'en'`. Every new doc has its `.es.md` twin.
5. In the PR, say how you tested it, and separate **built**, **mocked** and **hardware** (which adapter, distro, kernel).

Procedures (bumping upstream, adding an adapter, releases): [docs/MAINTAINING.md](docs/MAINTAINING.md).

By contributing you agree to license your work under GPL-3.0-or-later and to follow the [code of conduct](CODE_OF_CONDUCT.md).
