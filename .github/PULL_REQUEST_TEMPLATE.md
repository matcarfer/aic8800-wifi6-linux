## Qué cambia · What changes
<!-- En una o dos frases, para quien usa el instalador · In one or two sentences, for the installer's users. -->

## Cómo lo probaste · How you tested it
<!-- Separá · Separate: compilado/built, simulado/mocked (tests), hardware (placa, distro, kernel · adapter, distro, kernel). -->
- Compilado · Built:
- Tests:
- Hardware:

## Lista de control · Checklist
- [ ] `bash -n *.sh && shellcheck -S warning *.sh && python3 tests/test_install.py` pasan · pass
- [ ] Mensajes nuevos con `t 'es' 'en'` · New messages use `t 'es' 'en'`
- [ ] Docs actualizados en los dos idiomas · Docs updated in both languages
- [ ] Sin código del driver (eso va a upstream) · No driver code (that goes upstream)
- [ ] Si cambia `REF_MAIN`/`REF_LEGACY`: probado en hardware · If `REF_*` changes: tested on hardware
- [ ] CHANGELOG (es/en) si es visible para el usuario · CHANGELOG (es/en) if user-visible
- [ ] Créditos (CREDITS) si usaste trabajo de alguien · Credits if you used someone's work
