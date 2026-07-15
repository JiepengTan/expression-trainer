#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../../.." && pwd)"
ios_root="$root/clients/ios/exp-trainer"
pattern='(sk-[A-Za-z0-9_-]{20,}|(DEEPSEEK|OPENAI|ANTHROPIC|GEMINI)_(API_)?KEY[[:space:]]*=[[:space:]]*[^$[:space:]][^[:space:]]+)'

if command -v rg >/dev/null 2>&1; then
  if rg --hidden --glob '!Configuration/Local.xcconfig' --glob '!*.xcuserstate' --glob '!DerivedData/**' "$pattern" "$ios_root"; then
    echo "Potential provider secret found in the iOS source tree." >&2
    exit 1
  fi
else
  if grep -REn "$pattern" "$ios_root" --exclude='Local.xcconfig' --exclude='*.xcuserstate'; then
    echo "Potential provider secret found in the iOS source tree." >&2
    exit 1
  fi
fi

echo "iOS provider-secret scan passed."
