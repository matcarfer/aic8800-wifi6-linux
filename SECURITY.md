# Security

**English** · [Español](SECURITY.es.md)

The installer runs as root, downloads the driver from GitHub at a **pinned commit** (not a moving branch), builds a kernel module, and adds a udev rule. Read `install.sh` before piping it to `bash` if you prefer: it is short.

If you find a security problem, **don't open a public issue**: use [GitHub's private reporting](../../security/advisories/new).
