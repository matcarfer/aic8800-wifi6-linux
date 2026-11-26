# Security

**English** · [Español](SECURITY.es.md)

The installer runs as root, downloads the driver from GitHub at a **pinned commit** (not a moving branch), builds a kernel module, and adds a udev rule. Read `install.sh` before piping it to `bash` if you prefer: it is short.

If you find a security problem, **don't open a public issue**: use [GitHub's private reporting](../../security/advisories/new).

## What protects you

- The driver is downloaded at a **pinned commit** over HTTPS from GitHub, never from a moving branch.
- `main()` runs on the last line, so a truncated download executes nothing.
- Nothing reads answers from stdin, and a watchdog stops a stalled install.
- `diagnose.sh` only reads and hides MAC addresses.
