# Mantenimiento

[English](MAINTAINING.md) · **Español**

Procedimientos paso a paso para quienes mantienen y colaboran, personas o IAs. Si algo de acá está mal o falta, arreglá este archivo en el mismo PR.

## Regla de oro: primero el hardware

Mover `REF_MAIN` / `REF_LEGACY` en `install.sh` cambia lo que corre todo el mundo. Hacelo **solo después de instalar ese commit en una placa real** y ver ✓ WiFi y ✓ Bluetooth (o "solo WiFi" en placas sin Bluetooth). Que compile en la CI hace falta, pero no alcanza.

Cuando cuentes resultados, separá los tres tipos de evidencia: **compilado**, **simulado** (tests) y **hardware** (placa real: cuál, en qué distro y con qué kernel).

## Actualizar el commit de upstream

Lo dispara un issue `upstream-update` del vigía, o un arreglo que te haga falta.

1. Leé los commits de upstream entre el ref fijado y el nuevo: `https://github.com/shenmintao/aic8800d80/compare/<viejo>...<nuevo>`. Fijate si cambió el instalador, porque el indicador de progreso depende de `==> ` y el ✓ de `DKMS module registered`.
2. Cambiá `REF_MAIN` (o `REF_LEGACY`, o los dos) en `install.sh` por el hash completo de 40 caracteres, con la fecha en el comentario.
3. Corré `python3 tests/test_install.py` y `shellcheck -S warning *.sh`.
4. Subilo a una rama y corré el workflow **kernel-build** sobre ella (Actions → kernel-build → Run workflow).
5. **En hardware:** `sudo ./uninstall.sh`, desenchufar y enchufar (tiene que volver el modo pendrive), y después `./install.sh` de la rama.
6. Sumá el resultado a la tabla de probadas de los dos README, y una entrada en `CHANGELOG.md` y `CHANGELOG.es.md`.
7. Versión: parche si solo cambia el commit, menor si cambia el comportamiento.

## Sumar una placa

Casi siempre a partir de un issue `new-adapter` que trae `lsusb` de antes y de después.

1. **¿Es AIC?** En modo WiFi, el ID tiene que ser uno que el driver de upstream reconozca: buscá las entradas `USB_DEVICE` en `drivers/aic8800/aic_load_fw/*.c` y `aic8800_fdrv/*.c` de upstream. Si no está ahí, primero hay que pedirlo en upstream.
2. **ID en modo pendrive:** va en `STORAGE_IDS`. **ID en modo WiFi:** va en `WIFI_IDS`. Usá `vid:pid` exacto cuando la marca también vende placas que no son AIC (TP-Link `2357`, Tenda `2604`). `vid:*` solo para los vendor ID propios de AIC.
3. Si necesita **otro comando de cambio de modo** que upstream no conoce, eso va a upstream (`usb_modeswitch/` y `aic.rules` de allá), no acá.
4. Agregá un caso a `test_wifi_mode_ids` / `test_aic_storage_ids` en `tests/test_install.py`.
5. Si el ID es común, actualizá la tabla "¿Es mi placa?" de los dos README.

## Cuando kernel-build abre un issue `kernel-break`

1. Abrí la ejecución que falló y buscá el primer `error:` en el log de compilación.
2. Revisá los issues y PRs de upstream: muchas veces alguien ya lo reportó.
3. Si upstream ya lo arregló, probá ese commit en hardware y actualizá.
4. Si no, reportalo en upstream con el log. Mejor todavía, un PR con el arreglo: los arreglos al driver siempre van a upstream.
5. Mientras tanto, quienes usen ese kernel quedan afectados: poné un aviso arriba en los dos README.

## Cuando cambia Omarchy (u otra distro)

Qué revisar después de una versión grande de Omarchy, o cuando alguien reporta un cuelgue o un problema de arranque:

- [ ] ¿Sigue existiendo `limine-mkinitcpio`? (`command -v limine-mkinitcpio`)
- [ ] ¿`/usr/local/bin/mkinitcpio` sigue envolviendo con una pregunta? Si cambió, ¿el shim la sigue evitando?
- [ ] ¿El kernel sigue siendo `linux-omarchy`, con headers `linux-omarchy-headers`? (Upstream saca el nombre del paquete de headers de `/usr/lib/modules/$(uname -r)/pkgbase`.)
- [ ] ¿El repo de paquetes de Omarchy sigue siendo `https://pkgs.omarchy.org/stable/$arch`, con la llave de firma `40DFB630FF42BCFFB047046CF0134EE680CAC571`? `kernel-build.yml` usa los dos.
- [ ] Red: hoy Omarchy usa NetworkManager. La prueba final usa `iw` y, si no está, `nmcli`.
- [ ] Hacé una pasada completa en hardware: desinstalar, reenchufar, instalar.

## Publicar una versión

1. Todo lo de arriba en verde. `CHANGELOG.md` y `CHANGELOG.es.md` con `## [X.Y.Z] — AAAA-MM-DD`.
2. `VERSION="X.Y.Z"` en `install.sh` (los tests verifican que coincida con los CHANGELOG).
3. `./release.sh` crea el tag `vX.Y.Z` y el release de GitHub con los dos CHANGELOG, y deja publicado solo el último release.

`main` es lo que sirve `curl | bash`, así que **nunca subas a `main` cambios del instalador sin probar**. Usá ramas y PRs.

## Links de donación

Siempre en este orden, en los dos README y en `.github/FUNDING.yml`:

1. Cafecito: https://cafecito.app/matcarfer
2. Matecito: https://www.matecito.co/matcarfer
3. Mercado Pago: https://link.mercadopago.com.ar/matcarfer
4. Ko-fi: https://ko-fi.com/matcarfer
5. Patreon: https://www.patreon.com/matcarfer
6. GitHub Sponsors: https://github.com/sponsors/matcarfer

## PRs a upstream desde este repo

| PR | Qué | Estado al escribir esto |
|---|---|---|
| [#156](https://github.com/shenmintao/aic8800d80/pull/156) | Usar `limine-mkinitcpio` en sistemas con UKI de Limine (`main`) | abierto |
| [#157](https://github.com/shenmintao/aic8800d80/pull/157) | El mismo arreglo para `legacy-mcu1` | abierto |

Cuando los dos estén aceptados y fijados acá, se puede sacar `write_mkinitcpio_shim()` (el vigía queda).
