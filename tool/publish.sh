#!/usr/bin/env bash
# Lockstep publish of every package for the tag in GITHUB_REF_NAME (vX.Y.Z).
# Run by .github/workflows/publish.yml. Re-running after a partial failure is
# safe: versions already on pub.dev are skipped.
#
# Local checks (never publishes, never touches pubspec_overrides.yaml):
#   CHECK_ONLY=1 GITHUB_REF_NAME=v1.0.0 bash tool/publish.sh
#   PUBLISH_DRY_RUN=1 GITHUB_REF_NAME=v1.0.0 bash tool/publish.sh
set -euo pipefail
cd "$(dirname "$0")/.."

v="${GITHUB_REF_NAME#v}"
adapters=(signals_translator alien_signals_translator solidart_translator)
dry="${PUBLISH_DRY_RUN:-}"

# Every version and every adapter's core constraint must match the tag;
# pubspec_overrides.yaml hides a stale constraint locally, so check here.
fail=0
for p in packages/*/pubspec.yaml; do
  grep -q "^version: $v$" "$p" || { echo "$p: version is not $v"; fail=1; }
done
for a in "${adapters[@]}"; do
  grep -q "^  signals_translator_core: \^$v$" "packages/$a/pubspec.yaml" ||
    { echo "packages/$a/pubspec.yaml: signals_translator_core is not ^$v"; fail=1; }
done
[ "$fail" = 0 ] || exit 1
if [ "${CHECK_ONLY:-}" = 1 ]; then echo "versions match $v"; exit 0; fi

published() { curl -sf "https://pub.dev/api/packages/$1/versions/$v" > /dev/null; }

# GitHub OIDC tokens are short-lived; fetch a fresh one for every publish.
fresh_token() {
  PUB_TOKEN="$(curl -sf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
    "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=https://pub.dev" | jq -r .value)"
  echo "::add-mask::$PUB_TOKEN"
  export PUB_TOKEN
}

publish() { # <package>, run from its directory
  if published "$1"; then
    echo "$1 $v is already on pub.dev; skipping"
  elif [ -n "$dry" ]; then
    dart pub publish --dry-run
  else
    fresh_token
    dart pub token add https://pub.dev --env-var PUB_TOKEN
    local status=0
    dart pub publish --force || status=$?
    # The saved token reads PUB_TOKEN, which is only exported in this
    # subshell; left in place, it breaks the next package's pub get. Remove
    # it even when publishing failed.
    dart pub token remove https://pub.dev
    return "$status"
  fi
}

(cd packages/signals_translator_core && publish signals_translator_core)

if [ -z "$dry" ]; then
  for _ in $(seq 1 30); do published signals_translator_core && break; sleep 10; done
  published signals_translator_core ||
    { echo "signals_translator_core $v not visible on pub.dev"; exit 1; }
fi

for a in "${adapters[@]}"; do
  (
    cd "packages/$a"
    # Publish against the hosted core, not the local override.
    if [ -z "$dry" ]; then rm -f pubspec_overrides.yaml; fi
    flutter pub get
    publish "$a"
  )
done
