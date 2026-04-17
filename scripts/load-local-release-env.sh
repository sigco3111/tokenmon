#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source this script from another shell script" >&2
  exit 2
fi

if [[ -n "${TOKENMON_LOCAL_RELEASE_ENV_LOADED:-}" ]]; then
  return 0
fi

tokenmon_release_env_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

typeset -a tokenmon_release_env_candidates
tokenmon_release_env_candidates=(
  "$tokenmon_release_env_root/../gitlab-vars.env"
  "$HOME/gitlab-vars.env"
)

for tokenmon_release_env_candidate in "${tokenmon_release_env_candidates[@]}"; do
  if [[ -f "$tokenmon_release_env_candidate" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$tokenmon_release_env_candidate"
    set +a
    export TOKENMON_LOCAL_RELEASE_ENV_LOADED=1
    export TOKENMON_LOCAL_RELEASE_ENV_FILE="$tokenmon_release_env_candidate"
    break
  fi
done
