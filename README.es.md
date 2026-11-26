# aic8800-wifi6-linux

[English](README.md) · **Español**

**Hacé andar en Linux la placa USB WiFi 6 "que aparece como pendrive", con un solo comando.**

```bash
curl -fsSL https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/install.sh | bash
```

Te pide tu contraseña, compila el driver (3 a 6 minutos) y termina así:

```
==> Buscando la placa...
  ✓ Placa en modo WiFi (a69c:8d81)
  ✓ WiFi: wlan0 ve 31 redes
  ✓ Bluetooth: hci1

Listo. La placa se activa sola cada vez que la enchufes.
```

## ¿Es mi placa?

Probablemente sí, si al enchufarla:

- aparece un **pendrive o CD llamado "WiFi Driver"** con un `.exe` adentro, y
- `lsusb` muestra alguno de estos IDs:

| `lsusb` muestra | Qué es |
|---|---|
| `1111:1111 Pandora International Ltd. 88M80` | AIC8800D80 en modo pendrive (genérica "WIFI6", Lukton, etc.) |
| `a69c:5721` … `a69c:5732` | AIC8800 en modo pendrive (Tenda, UGREEN, Cudy, BrosTrend…) |
| `a69c:8d80`, `a69c:8d81`, `368b:8d81` | La misma placa ya en modo WiFi |

Las marcas suelen ser **AX300, AX900, AX1800, "WiFi 6 + BT 5.x"**, Tenda U11, UGREEN AX900, BrosTrend AX300/AX900 y genéricas de AliExpress o Mercado Libre.

## Qué hace (y por qué existe)

El driver es el de [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80) (GPL-2.0), adaptado del driver de Tenda/AICSemi, y anda muy bien. Este repo **no lo modifica**: lo descarga en una versión probada y le agrega lo que faltaba para que sea fácil:

| | A mano con upstream | Con este repo |
|---|---|---|
| Pasos | clonar, `chmod`, `sudo`, desenchufar y enchufar | un comando |
| Omarchy / Limine | se queda en una pregunta oculta y parece colgado | resuelto |
| Cambiar de pendrive a WiFi | "desenchufá y volvé a enchufar" | lo hace solo, sin desenchufar |
| Rama `main` o `legacy-mcu1` | elegís vos | lee `chip_mcu_id` y elige |
| Verificación final | "módulo cargado" | prueba que el WiFi vea redes y que el Bluetooth aparezca |
| Salida | unas 150 líneas en inglés | 6 líneas, en español o inglés |

Por dentro, el instalador:

1. Descarga upstream en un commit fijo y probado en `/usr/local/src/aic8800-wifi6-linux`.
2. Corre el instalador de upstream: dependencias según la distro, compilación de prueba, DKMS, firmware, regla udev y `usb_modeswitch`.
3. Si la placa está en modo pendrive, la pasa a modo WiFi con udev y `usb_modeswitch`, que le mandan los comandos SCSI `F3`/`F2` de AIC.
4. Si el chip es la variante MCU1, reinstala solo con la rama `legacy-mcu1`.
5. Escanea redes y busca el controlador Bluetooth para confirmar que todo anda de verdad.

DKMS recompila el driver solo con cada kernel nuevo.

## Distros probadas

| Distro | Kernel | WiFi | BT | Placa |
|---|---|---|---|---|
| Omarchy (Arch) | 7.2.15 | ✓ 2.4 + 5 GHz | ✓ | genérica "WIFI6" `1111:1111` 88M80 |

Upstream informa que también funciona en Ubuntu, Debian, Fedora, CachyOS y openSUSE. ¿La probaste en otra distro? [Contalo en un issue](../../issues/new/choose) y la sumamos a la tabla.

## Requisitos

- Internet durante la instalación: el WiFi de la notebook, cable o el celular compartiendo por USB.
- Secure Boot **desactivado**. Si está activado, el instalador te avisa y te explica qué hacer.

Los headers del kernel, `dkms` y `usb_modeswitch` los instala solo.

## Desinstalar

```bash
curl -fsSL https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/uninstall.sh | bash
```

## Si algo falla

```bash
curl -fsSL https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/diagnose.sh | sudo bash
```

Genera `aic8800-diagnose.txt`, de solo lectura y con las MAC tapadas. [Abrí un issue](../../issues/new/choose) y adjuntalo.

Problemas comunes:

- **"No cambió de modo"**: desenchufala, esperá 3 segundos y volvé a enchufarla. Algunos puertos o hubs USB cortan la corriente en el cambio.
- **Anda después de reenchufar, pero no al arrancar**: reiniciá una vez; el initramfs ya incluye el firmware.
- **Bluetooth no aparece**: algunas placas son solo WiFi.
- El log completo de la instalación está en `/var/log/aic8800-wifi6-linux.log`.

## Créditos y licencia

- Driver: [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80), GPL-2.0, basado en el driver de Tenda U11 / AICSemi.
- Instalador: matcarfer, [GPL-3.0](LICENSE).

Si te sirvió: [Matecito](https://www.matecito.co/matcarfer) · [Cafecito](https://cafecito.app/matcarfer) · [Mercado Pago](https://link.mercadopago.com.ar/matcarfer) · [Patreon](https://www.patreon.com/matcarfer)
