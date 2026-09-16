#!/usr/bin/env bash

set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "$skill_dir/../../.." && pwd)"
app_dir="$repo_root/quickapp/focusloop"
rpk="$app_dir/dist/com.openvela.focusloop.debug.0.1.0.rpk"

if command -v powershell.exe >/dev/null 2>&1 && [[ "$repo_root" == /mnt/* ]]; then
  windows_root="$(wslpath -w "$repo_root")"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File \
    "$windows_root\\.claude\\skills\\focusloop-verify\\scripts\\verify_focusloop.ps1"
  exit $?
fi

cd "$repo_root"
git diff --check
bash -n scripts/*.sh

cd "$app_dir"
npm test
npm run build
npm audit --omit=dev

if [[ ! -s "$rpk" ]]; then
  echo "RPK missing after build: $rpk" >&2
  exit 1
fi

cd "$repo_root"
if rg -l --hidden \
  --glob '!.git/**' \
  --glob '!quickapp/focusloop/node_modules/**' \
  --glob '!quickapp/focusloop/dist/**' \
  'ghp_[A-Za-z0-9]{20,}|tp-[A-Za-z0-9]{20,}' . >/dev/null; then
  echo "Credential-like value found in repository files." >&2
  exit 1
fi

if rg -n '模型说成功|90 秒|8\.1 秒|16/16|58 KB' README.md docs \
  --glob '!docs/preview/**' --glob '!docs/screenshots/**'; then
  echo "Obsolete presentation wording found." >&2
  exit 1
fi

size="$(wc -c < "$rpk")"
echo "FocusLoop verification passed: $rpk ($size bytes)"
