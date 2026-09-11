#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
export XDG_CONFIG_HOME="$test_root/config"
export XDG_STATE_HOME="$test_root/state"
mkdir -p "$XDG_CONFIG_HOME/shellver"
mkdir -p "$XDG_STATE_HOME/shellver"
printf '1\n' > "$XDG_CONFIG_HOME/shellver/common"
printf '4\n' > "$XDG_CONFIG_HOME/shellver/local"
printf '7\n' > "$XDG_STATE_HOME/shellver/machine"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

existing_prompt() {
    printf 'existing:%s\n' "$?"
}

PROMPT_COMMAND=existing_prompt
original_prompt_command="$PROMPT_COMMAND"
export SHELLVER='common:0|local:0|machine:0'
hook_code="$(PYTHONPATH="$PROJECT_ROOT/src" python3 -m shellver init bash)"
eval "$hook_code"
eval "$hook_code"

[[ "$SHELLVER" == 'common:1|local:4|machine:7' ]] || fail 'inherited snapshot was not replaced'
[[ "$PROMPT_COMMAND" == "$original_prompt_command" ]] || fail 'init changed PROMPT_COMMAND'
[[ "$(shellver_current)" == "$SHELLVER" ]] || fail 'current-generation function mismatch'
if shellver_is_stale; then
    fail 'current shell reported stale'
fi
current_output="$(false; eval "$PROMPT_COMMAND")"
[[ "$current_output" == 'existing:1' ]] || fail "existing prompt or status changed: $current_output"

printf '2\n' > "$XDG_CONFIG_HOME/shellver/common"
stale_output="$(shellver_is_stale)"
[[ -z "$stale_output" ]] || fail "staleness predicate produced output: $stale_output"
shellver_is_stale || fail 'stale shell reported current'
[[ "$(shellver_current)" == 'common:2|local:4|machine:7' ]] || fail 'updated generation mismatch'

printf '99\n' > "$XDG_CONFIG_HOME/shellver/machine"
reserved_error="$(shellver_current 2>&1 >/dev/null)" && fail 'reserved machine generation was accepted'
[[ "$reserved_error" == *"reserved generation name 'machine'"* ]] || fail 'reserved-name error mismatch'

printf 'PASS: shellver Bash capabilities\n'
