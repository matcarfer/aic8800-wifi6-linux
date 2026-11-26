---
name: No funcionó / It didn't work
about: El instalador falló o la placa no anda · The installer failed or the adapter doesn't work
labels: error
---

<!-- Podés escribir en castellano o en inglés · You can write in Spanish or English -->

**Distro y kernel** · **Distro and kernel** (`uname -r`):

**Marca/modelo de la placa** · **Adapter brand/model:**

**Qué pasó** · **What happened:**

**Diagnóstico** · **Diagnostics** — adjuntá `aic8800-diagnose.txt` · attach `aic8800-diagnose.txt`:
```
curl -fsSL https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/diagnose.sh | sudo bash
```
