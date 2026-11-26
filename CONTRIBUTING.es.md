# Cómo colaborar

[English](CONTRIBUTING.md) · **Español**

¡Gracias por ayudar! Todo tipo de aporte suma, y los hechos con ayuda de IA son bienvenidos (ver [AGENTS.es.md](AGENTS.es.md)).

## Sin escribir código

- **¿Te funcionó?** Abrí un [issue "¡Funcionó!"](../../issues/new?template=works.yml) con la distro, el kernel y la placa. Va a la tabla de probadas.
- **¿Falló?** Corré `diagnose.sh` y abrí un [issue "No funcionó"](../../issues/new?template=error.yml).
- **¿Placa nueva?** Usá la [plantilla "Placa nueva"](../../issues/new?template=new-adapter.yml) con `lsusb` de antes y de después.
- **Traducciones y textos:** los arreglos de redacción son muy bienvenidos. El castellano es rioplatense (voseo).

## Dónde va cada cosa

| Problema | Dónde |
|---|---|
| El instalador, la detección, los mensajes, la documentación | acá |
| Cortes, velocidad, cuelgues o errores de compilación **del driver** | [upstream](https://github.com/shenmintao/aic8800d80/issues) |
| Un comando de cambio de modo para una placa nueva | upstream (`usb_modeswitch/`, `aic.rules`) |

## Código

1. Hacé un fork y creá una rama. **Nunca subas directo a `main`**: `curl | bash` lo sirve en vivo.
2. Cambios chicos y explicados. Leé antes [docs/ARCHITECTURE.es.md](docs/ARCHITECTURE.es.md).
3. Antes de abrir el PR: `bash -n *.sh && shellcheck -S warning *.sh && python3 tests/test_install.py`.
4. Cada mensaje nuevo pasa por `t 'es' 'en'`. Cada documento nuevo tiene su gemelo `.es.md`.
5. En el PR contá cómo lo probaste, y separá **compilado**, **simulado** y **hardware** (qué placa, distro y kernel).

Procedimientos (actualizar upstream, sumar una placa, publicar versiones): [docs/MAINTAINING.es.md](docs/MAINTAINING.es.md).

Al colaborar, aceptás que tu aporte quede bajo GPL-3.0-or-later y seguir el [código de conducta](CODE_OF_CONDUCT.es.md).
