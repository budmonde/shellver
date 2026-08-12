#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_state_root="$(mktemp -d)"
trap 'rm -rf -- "$test_state_root"' EXIT
export XDG_STATE_HOME="$test_state_root"
export NO_COLOR=1
mkdir -p "$XDG_STATE_HOME/shellver"
printf '1\n' > "$XDG_STATE_HOME/shellver/common"
printf '4\n' > "$XDG_STATE_HOME/shellver/local"
printf 'machine-a\n' > "$XDG_STATE_HOME/shellver/machine"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

existing_prompt() {
    printf 'existing:%s\n' "$?"
}

PROMPT_COMMAND=existing_prompt
unset SHELLVER
hook_code="$(PYTHONPATH="$PROJECT_ROOT/src" python3 -m shellver init bash)"
eval "$hook_code"
eval "$hook_code"

[[ "$SHELLVER" == 'common:1|local:4|machine:machine-a' ]] || fail 'initial snapshot mismatch'
current_output="$(false; eval "$PROMPT_COMMAND")"
[[ "$current_output" == 'existing:1' ]] || fail "existing prompt or status changed: $current_output"

printf '2\n' > "$XDG_STATE_HOME/shellver/common"
stale_output="$(false; eval "$PROMPT_COMMAND")"
[[ "$stale_output" == $'[shellver stale]\nexisting:1' ]] || fail "stale hook mismatch: $stale_output"
[[ "$(grep -o '\[shellver stale\]' <<< "$stale_output" | wc -l)" -eq 1 ]] || fail 'hook was registered twice'

printf 'PASS: shellver Bash hook\n'
