#!/usr/bin/env bash
# Publishes a version (maintainer only) · Publica una versión (solo el mantenedor):
#   1. checks VERSION in install.sh has "## [X.Y.Z]" in CHANGELOG.md and CHANGELOG.es.md
#   2. runs the same checks as CI
#   3. creates tag vX.Y.Z and the GitHub release with both changelogs and the 3 scripts attached
#   4. deletes older releases: only the latest stays published (tags are kept)
#
# Needs: gh (GitHub CLI, logged in), shellcheck, python3. Run from a clean, pushed main.
#
# Copyright (C) 2026 matcarfer and contributors
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(sed -n 's/^VERSION="\([0-9.]*\)"$/\1/p' install.sh)
TAG="v$VERSION"

command -v gh >/dev/null || { echo "Falta gh (https://cli.github.com)"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Corré: gh auth login"; exit 1; }
for f in CHANGELOG.md CHANGELOG.es.md; do
    grep -q "^## \[$VERSION\]" "$f" || { echo "$f no tiene '## [$VERSION]'"; exit 1; }
done
[ -z "$(git status --porcelain)" ] || { echo "Primero hacé commit de los cambios"; exit 1; }
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || { echo "Publicá desde main"; exit 1; }

for f in *.sh .github/scripts/*.sh; do bash -n "$f"; done
python3 tests/test_install.py
if command -v shellcheck >/dev/null; then
    shellcheck -S warning ./*.sh .github/scripts/*.sh
else
    # No local shellcheck: require the CI run of this exact commit to be green.
    sha=$(git rev-parse HEAD)
    ci=$(gh run list --workflow ci --commit "$sha" --json conclusion --jq '.[0].conclusion')
    [ "$ci" = success ] || { echo "Sin shellcheck local y la CI de ${sha:0:7} no está en verde ($ci)"; exit 1; }
fi

section() { awk -v v="## [$VERSION]" 'index($0,v)==1{f=1;next} /^## /{f=0} f' "$1"; }
NOTES="$(section CHANGELOG.md)

---
**Castellano**
$(section CHANGELOG.es.md)

---
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/matcarfer/aic8800-wifi6-linux/main/install.sh | bash
\`\`\`"

git push origin main
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || git tag -a "$TAG" -m "aic8800-wifi6-linux $VERSION"
git push origin "$TAG"

if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" install.sh uninstall.sh diagnose.sh --clobber
    gh release edit "$TAG" --notes "$NOTES" --latest
else
    gh release create "$TAG" install.sh uninstall.sh diagnose.sh --title "aic8800-wifi6-linux $VERSION" --notes "$NOTES" --latest
fi

gh release list --limit 100 --json tagName --jq '.[].tagName' | while read -r t; do
    [ "$t" = "$TAG" ] || gh release delete "$t" --yes
done
echo "Publicado $TAG: $(gh release view "$TAG" --json url --jq .url)"
