# Instrucciones para asistentes de IA (agentes)

[English](AGENTS.md) · **Español**

Este archivo es para Claude, Codex, Copilot, Gemini u otro asistente que edite este repositorio. Las personas también pueden leerlo: resume [CONTRIBUTING.es.md](CONTRIBUTING.es.md), [docs/ARCHITECTURE.es.md](docs/ARCHITECTURE.es.md) y [docs/MAINTAINING.es.md](docs/MAINTAINING.es.md). **Leelos antes de cambiar código.**

aic8800-wifi6-linux es un **envoltorio**. No contiene el driver: descarga [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80) en un commit fijo y corre su instalador. Lo que importa acá es que sea **fácil, corto y honesto**.

## Antes de terminar cualquier cambio

```bash
bash -n *.sh && shellcheck -S warning *.sh && python3 tests/test_install.py
```

Los tres tienen que pasar. La CI corre lo mismo.

## Reglas

1. **Nunca copiar código del driver ni del firmware a este repo.** Los arreglos al driver van a upstream como PR. Upstream tiene su propio `AGENTS.md`: allá se sigue ese.
2. **Nunca mover `REF_MAIN` / `REF_LEGACY` sin probarlo en hardware** (docs/MAINTAINING.es.md). Si no podés probar en hardware, abrí el PR y decilo claro. Nunca digas "probado" de algo que solo se compiló o se simuló.
3. **`main` está en vivo:** `curl | bash` lo sirve al instante. Los cambios van en una rama y por PR.
4. **Todo mensaje visible es bilingüe:** `t 'castellano' 'english'`. El castellano es rioplatense, con voseo ("enchufá", "corré"). Un test rechaza los mensajes `step` / `ok` / `warn` / `die` sin traducir.
5. **Salida corta:** `step` para las etapas; `ok` / `warn` / `die` para los resultados. La salida de upstream va a `$LOG`, no a la pantalla.
6. **Nunca leer respuestas de stdin.** Con `curl | bash`, stdin es el script. Usá `$TTY` (`/dev/tty` o `/dev/null`).
7. **Nada puede esperar para siempre.** Toda espera larga necesita un límite (bucles con `seq N`, el vigía de traba).
8. **`main "$@"` queda en la última línea**, detrás del control `AIC_TESTING`. No agregues código suelto que haga cosas.
9. **Cada función nueva lleva un comentario corto** y, si interpreta algo, un test en `tests/test_install.py`. Usá `$SYSFS`, nunca `/sys` escrito a mano, para que los tests lo puedan simular.
10. **`diagnose.sh` es de solo lectura** y tapa las MAC. Nunca agregues números de serie, SSID, IP ni nombres de usuario.
11. **Documentos en los dos idiomas:** cada `X.md` tiene su gemelo `X.es.md` (los README son la excepción: `README.md` en castellano y `README.en.md` en inglés). Actualizá los dos en el mismo cambio.
12. **Créditos:** si usás un hallazgo, arreglo o código de alguien, sumalo a `CREDITS.md` y `CREDITS.es.md`.
13. **Encabezado** en cada script: `Copyright (C) 2026 matcarfer and contributors` y `SPDX-License-Identifier: GPL-3.0-or-later`.
14. **Links de donación**, donde aparezcan: Cafecito, Matecito, Mercado Pago, Ko-fi, Patreon, GitHub Sponsors, en ese orden (docs/MAINTAINING.es.md).

## Mapa rápido

- IDs de placas: `STORAGE_IDS` / `WIFI_IDS`, arriba de todo en `install.sh`.
- Detección: `find_adapter()`, `aic_iface()`, `aic_hci()`, `parse_mcu_id()`.
- Arreglo de Omarchy/Limine: `write_mkinitcpio_shim()`, más los PRs #156 y #157 a upstream.
- Corrida de upstream, indicador de progreso y vigía: `run_upstream_quiet()`. Descarga: `install_branch()`.
- Flujo: `main()`, paso a paso en docs/ARCHITECTURE.es.md.
