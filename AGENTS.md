# Instrucciones para asistentes de IA (agentes)

Este archivo es para Claude, Codex, Copilot, Gemini u otro asistente que edite este repositorio.

aic8800-wifi6-linux es un **envoltorio**: no contiene el driver. Descarga
[shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80) en un commit fijo y corre su instalador.
Lo que importa acá es que sea **fácil, corto y honesto**.

## Reglas
1. **No copiar el driver al repo.** Arreglos al driver van como PR a upstream.
2. **Cambiar de commit de upstream** (`REF_MAIN` / `REF_LEGACY` en `install.sh`) solo después de probarlo
   con una placa real, y anotarlo en `CHANGELOG.md` + `CHANGELOG.es.md` y en la tabla de distros probadas.
3. **Todo mensaje visible en los dos idiomas** con `t 'castellano' 'english'` (castellano rioplatense, voseo).
4. **Salida corta:** pasos con `step`, resultados con `ok`/`warn`/`die`. Lo de upstream va a `$LOG`.
5. **Nunca leer respuestas de stdin**: con `curl | bash` stdin es el script. Usar `/dev/tty` o `/dev/null`.
6. **`diagnose.sh` es de solo lectura** y tapa las MAC.
7. Antes de terminar: `bash -n *.sh` y `shellcheck -S warning *.sh`.
8. Encabezado: `License: GPL-3.0-or-later. Author: matcarfer.`
