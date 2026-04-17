#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release-preflight.sh <tag> [--skip-secrets] [--allow-unsigned]

Examples:
  scripts/release-preflight.sh v0.1.0
  scripts/release-preflight.sh v0.1.0 --skip-secrets
  scripts/release-preflight.sh v0.1.0 --allow-unsigned
EOF
}

TAG=""
SKIP_SECRETS=0
ALLOW_UNSIGNED=0

for arg in "$@"; do
  case "$arg" in
    --skip-secrets)
      SKIP_SECRETS=1
      ;;
    --allow-unsigned)
      ALLOW_UNSIGNED=1
      ;;
    -*)
      echo "Unknown option: $arg" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -z "$TAG" ]]; then
        TAG="$arg"
      else
        echo "Unexpected extra argument: $arg" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$TAG" ]]; then
  usage
  exit 1
fi

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-](alpha|beta|rc)\.[0-9]+)?$ ]]; then
  echo "Invalid tag format: $TAG" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

. "$ROOT_DIR/scripts/load-local-release-env.sh" "$ROOT_DIR"

VERSION="${TAG#v}"
PLIST="Packaging/Tokenmon-Info.plist"

if [[ ! -f "$PLIST" ]]; then
  echo "Missing $PLIST" >&2
  exit 1
fi

PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
if [[ "$PLIST_VERSION" != "$VERSION" ]]; then
  echo "Version mismatch:" >&2
  echo "  tag:   $VERSION" >&2
  echo "  plist: $PLIST_VERSION" >&2
  exit 1
fi

REPOSITORY_TARGET="$(/usr/libexec/PlistBuddy -c 'Print :TokenmonGitHubRepository' "$PLIST")"
if [[ "$REPOSITORY_TARGET" != */* ]]; then
  echo "Packaging/Tokenmon-Info.plist must point to an owner/name GitHub repository." >&2
  exit 1
fi

FEED_URL="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$PLIST")"
EXPECTED_FEED_URL="$("$ROOT_DIR/scripts/tokenmon-release-targets" default-feed-url "$REPOSITORY_TARGET")"
if [[ "$FEED_URL" != "$EXPECTED_FEED_URL" ]]; then
  echo "Sparkle feed URL mismatch:" >&2
  echo "  configured: $FEED_URL" >&2
  echo "  expected:   $EXPECTED_FEED_URL" >&2
  exit 1
fi

for file in \
  "scripts/build-release" \
  "scripts/build-release-archive" \
  "scripts/generate-release-notes" \
  "scripts/generate-sparkle-appcast" \
  "scripts/generate-sparkle-keys" \
  "scripts/generate-homebrew-cask" \
  "scripts/release-preflight.sh" \
  "scripts/sync-homebrew-tap" \
  "scripts/tokenmon-release-targets" \
  ".github/release.yml" \
  ".github/workflows/ci.yml" \
  ".github/workflows/release.yml"
do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
done

if [[ "$SKIP_SECRETS" -eq 1 ]]; then
  echo "Preflight passed (secrets check skipped): $TAG"
  exit 0
fi

for secret_name in CSC_LINK CSC_KEY_PASSWORD SPARKLE_ED_PRIVATE_KEY; do
  if [[ -z "${!secret_name:-}" ]]; then
    if [[ "$ALLOW_UNSIGNED" -eq 1 ]]; then
      echo "Unsigned mode enabled: missing $secret_name is allowed."
      continue
    fi

    echo "Missing required signing secret: $secret_name" >&2
    exit 1
  fi
done

if [[ -z "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
  if [[ "$ALLOW_UNSIGNED" -eq 1 ]]; then
    echo "Unsigned mode enabled: missing SPARKLE_PUBLIC_ED_KEY is allowed."
  else
    echo "Missing Sparkle public key: SPARKLE_PUBLIC_ED_KEY" >&2
    exit 1
  fi
fi

if [[ -n "${APPLE_API_KEY:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER:-}" ]]; then
  :
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_ID_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  :
elif [[ "$ALLOW_UNSIGNED" -eq 1 ]]; then
  echo "Unsigned mode enabled: missing notarization credentials is allowed."
else
  echo "Missing Apple notarization credentials." >&2
  echo "Provide either APPLE_API_KEY / APPLE_API_KEY_ID / APPLE_API_ISSUER" >&2
  echo "or APPLE_ID / APPLE_ID_PASSWORD / APPLE_TEAM_ID" >&2
  exit 1
fi

echo "Preflight passed: $TAG"
