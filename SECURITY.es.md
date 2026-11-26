# Seguridad

[English](SECURITY.md) · **Español**

El instalador corre como root, descarga el driver de GitHub en un **commit fijo** (no una rama que cambia), compila un módulo del kernel y agrega una regla udev. Si preferís, leé `install.sh` antes de pasarlo a `bash`: es corto.

Si encontrás un problema de seguridad, **no abras un issue público**: usá el [reporte privado de GitHub](../../security/advisories/new).

## Qué te protege

- El driver se descarga en un **commit fijo** por HTTPS desde GitHub, nunca de una rama que cambia.
- `main()` corre en la última línea, así que una descarga cortada no ejecuta nada.
- Nada lee respuestas de stdin, y un vigía frena una instalación trabada.
- `diagnose.sh` solo lee y tapa las MAC.
