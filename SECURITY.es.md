# Seguridad

[English](SECURITY.md) · **Español**

El instalador corre como root, descarga el driver de GitHub en un **commit fijo** (no una rama que cambia), compila un módulo del kernel y agrega una regla udev. Si preferís, leé `install.sh` antes de pasarlo a `bash`: es corto.

Si encontrás un problema de seguridad, **no abras un issue público**: usá el [reporte privado de GitHub](../../security/advisories/new).
