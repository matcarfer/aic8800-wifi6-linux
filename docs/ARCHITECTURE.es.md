# Arquitectura

[English](ARCHITECTURE.md) · **Español**

Cómo funciona el instalador, qué hace el hardware y por qué se tomó cada decisión. Leelo antes de cambiar código.

## Objetivos y lo que no es objetivo

**Objetivos**
- Un comando que haga andar una placa USB AIC8800 en cualquier distro común.
- Salida corta y honesta, en castellano o en inglés. Un ✓ significa que se verificó, no que se supone.
- Sobrevivir a actualizaciones del kernel y de la distro sin que nadie toque nada.

**No es objetivo**
- **Mantener un driver.** El driver vive en upstream, [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80). Los arreglos al driver van allá como PR, nunca a este repo.
- Soportar sistemas inmutables (Silverblue, Bazzite). Upstream tiene su propia guía.

## Archivos

| Archivo | Para qué |
|---|---|
| `install.sh` | El instalador. Bash puro; solo necesita `curl`, `tar` y `setsid`. |
| `uninstall.sh` | Corre el `uninstall.sh` de upstream con el mismo arreglo de Limine y borra `/usr/local/src/aic8800-wifi6-linux`. |
| `diagnose.sh` | Informe de solo lectura para issues. Tapa las MAC. |
| `tests/test_install.py` | Tests con un sysfs simulado. No necesitan root, hardware ni red. |
| `.github/workflows/ci.yml` | shellcheck y tests en cada push y PR. |
| `.github/workflows/kernel-build.yml` | Compila el driver fijado contra los kernels más nuevos, cada semana. |
| `.github/workflows/upstream-watch.yml` | Revisa cada semana si upstream tiene commits nuevos. |
| `release.sh` | Crea el tag de una versión y publica el release en GitHub. Solo para el mantenedor. |

## El hardware, en corto

```
enchufar ──► 1111:1111 "88M80"  (almacenamiento USB, disco "WiFi Driver" con Wifi6_install.exe)
               │  usb_modeswitch manda 2 CBW SCSI: CDB …10fd…f3 y después …10fd…f2
               ▼
            a69c:8d80 "AIC Wlan"   (aic_load_fw sube el firmware de /lib/firmware/aic8800D80/)
               │  el chip se reinicia con el firmware
               ▼
            a69c:8d81 "AIC 8800D80" (aic8800_fdrv → wlanN; btusb → hciN)
```

- **IDs de pendrive:** `1111:1111` es un ID de relleno que también usan otros dispositivos. Solo se acepta si el nombre de producto USB empieza con `88M80`. Los IDs de pendrive propios de AIC son `a69c:57xx`, y para esos la regla udev de upstream hace `eject`.
- **`chip_mcu_id`:** el cargador de firmware imprime `chip_id=7, chip_mcu_id = N`. Con `1`, la placa necesita la rama `legacy-mcu1` de upstream, que tiene otro firmware. El instalador lo lee de `dmesg` y reinstala solo con esa rama.
- **La interfaz de red cuelga del dispositivo USB, no de una interfaz USB.** `/sys/class/net/wlan0/device` apunta a `…/1-1` y su driver figura como `usb`. Por eso `aic_iface()` busca por ruta de sysfs y no por nombre de driver.
- **El Bluetooth** aparece como una interfaz `btusb` del mismo dispositivo USB cuando ya cargó el firmware. Para algunos IDs, upstream agrega un módulo chico, `aic_zlp_quirk`.

## Flujo de instalación

`main()` de `install.sh`, en orden:

1. **Root.** Si corre desde un archivo, se vuelve a ejecutar con `sudo`. Si viene de `curl`, se descarga de nuevo y corre esa copia con `sudo bash -c`, porque una tubería no se puede volver a ejecutar.
2. **Las preguntas salen del teclado, nunca de stdin.** Con `curl | bash`, stdin es el propio script, así que `TTY` queda en `/dev/tty` o `/dev/null`.
3. **Chequeos previos:** que existan `curl`, `tar` y `setsid`; se rechazan los sistemas ostree (inmutables); Secure Boot se detecta con `secure_boot_enabled()`.
4. **`install_branch()`:** descarga el tarball fijado de upstream desde `codeload.github.com` a `/usr/local/src/aic8800-wifi6-linux/upstream`, escribe `installed` (versión, rama y ref), crea el shim de mkinitcpio y corre el `install.sh` de upstream.
   - Caso normal, `run_upstream_quiet()`: stdin es `/dev/null`, así que upstream nunca puede quedarse esperando una pregunta oculta. La salida va al log y se ve un indicador con el paso `==>` actual de upstream. Un **vigía** frena todo el grupo de procesos (`setsid`) si el log no crece durante `AIC_STALL_MINUTES` (45 por defecto).
   - Con Secure Boot: upstream tiene que preguntarle a la persona, así que corre en primer plano con la terminal y la salida visible.
5. **`find_adapter()`** recorre `/sys/bus/usb/devices` y compara con `STORAGE_IDS` / `WIFI_IDS`. Si no hay ninguna placa enchufada, espera hasta 2 minutos.
6. **Cambio de modo sin desenchufar:** `udevadm trigger --action=add --parent-match=<dispositivo>` repite el evento de enchufado, y así la regla udev de upstream corre `usb_modeswitch` o `eject`.
7. **Interfaz:** espera a `aic_iface()`. Si no aparece ninguna, re-enumera el dispositivo una vez con `authorized` 0/1, que equivale por software a desenchufarlo.
8. **Rama:** `parse_mcu_id()`. Si da `1` y la rama es `main`, reinstala con `legacy-mcu1` y re-enumera el dispositivo.
9. **Pruebas reales:** `iw dev <if> scan` (o `nmcli` si no hay `iw`) cuenta las redes, y `aic_hci()` busca el controlador Bluetooth en ese mismo dispositivo USB.

## El arreglo de Omarchy / Limine

En sistemas con UKI de Limine (Omarchy, algunas instalaciones de CachyOS), `mkinitcpio -P` no encuentra presets. Omarchy además trae `/usr/local/bin/mkinitcpio`, que entonces pregunta `Would you like to run 'limine-mkinitcpio' now? [Y/n]`. Upstream oculta esa salida, así que la instalación parecía colgada. Pasó en la primera prueba, durante 20 minutos.

`write_mkinitcpio_shim()` pone un `mkinitcpio` primero en el `PATH` mientras corre upstream:
- si existe `limine-mkinitcpio`, ejecuta ese con stdin desde `/dev/null`;
- si no, pasa la llamada al `/usr/bin/mkinitcpio` normal;
- el `PATH` original queda escrito dentro del shim, así que nunca puede llamarse a sí mismo.

El mismo arreglo se mandó a upstream: [#156](https://github.com/shenmintao/aic8800d80/pull/156) y [#157](https://github.com/shenmintao/aic8800d80/pull/157). Cuando se acepten y se fijen acá, el shim deja de hacer falta y se puede sacar.

## Por qué estas decisiones

| Decisión | Por qué |
|---|---|
| Envolver upstream en vez de hacer un fork | Upstream se actualiza todas las semanas y conoce el driver. Una copia quedaría vieja. |
| Commits fijos (`REF_MAIN`, `REF_LEGACY`) | La gente corre lo que se probó con hardware, no lo que se subió anoche. La CI y el vigía avisan cuándo actualizar. |
| Tarball de codeload, no `git clone` | No depende de `git` y descarga más rápido. |
| `main()` se llama en la última línea | Una descarga de `curl` cortada a la mitad no ejecuta nada. Además, los tests pueden hacer `source` con `AIC_TESTING=1`. |
| stdin `/dev/null` + vigía | Una pregunta oculta nunca más puede colgar la instalación, agregue lo que agregue upstream o la distro. |
| `t 'es' 'en'` bilingüe | El primer público habla castellano; el inglés llega a todos los demás. Un test rechaza los mensajes sin traducir. |

## Cosas que pueden cambiar por fuera

| Si cambia… | …se rompe | Dónde mirar |
|---|---|---|
| Una API nueva del kernel | la compilación del driver (la CI `kernel-build` abre un issue) | reportar o arreglar en upstream y subir `REF_*` |
| Omarchy deja Limine o renombra `limine-mkinitcpio` | el paso del initramfs | `write_mkinitcpio_shim()` |
| Upstream renombra `install.sh` o sus mensajes `==>` / `DKMS module registered` | el indicador de progreso y la línea ✓ | `run_upstream_quiet()`, `install_branch()` |
| Upstream cambia la línea `chip_mcu_id` del log | la elección automática de rama | `parse_mcu_id()` y su test |
| Un ID de placa nuevo | la detección | `STORAGE_IDS` / `WIFI_IDS` ([MAINTAINING.es.md](MAINTAINING.es.md#sumar-una-placa)) |
