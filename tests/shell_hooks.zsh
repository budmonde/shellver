#!/usr/bin/env zsh

set -e

PROJECT_ROOT="${0:A:h:h}"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
export XDG_CONFIG_HOME="$test_root/config"
export XDG_STATE_HOME="$test_root/state"
export NO_COLOR=1
mkdir -p "$XDG_CONFIG_HOME/shellver"
mkdir -p "$XDG_STATE_HOME/shellver"
printf '1\n' > "$XDG_CONFIG_HOME/shellver/common"
printf '7\n' > "$XDG_STATE_HOME/shellver/machine"

function precmd() {
    print 'existing'
}

export SHELLVER='common:0|machine:0'
hook_code="$(PYTHONPATH="$PROJECT_ROOT/src" python3 -m shellver init zsh)"
eval "$hook_code"
eval "$hook_code"

[[ "$SHELLVER" == 'common:1|machine:7' ]] || {
    print -u2 'FAIL: inherited snapshot was not replaced'
    exit 1
}
[[ "$(precmd)" == 'existing' ]] || {
    print -u2 'FAIL: existing precmd changed'
    exit 1
}
[[ "${#precmd_functions[(I)_shellver_prompt_hook]}" -eq 0 ]] || {
    print -u2 'FAIL: init registered a prompt hook'
    exit 1
}
[[ "$(shellver_current)" == "$SHELLVER" ]] || {
    print -u2 'FAIL: current-generation function mismatch'
    exit 1
}
if shellver_is_stale; then
    print -u2 'FAIL: current shell reported stale'
    exit 1
fi

printf '2\n' > "$XDG_CONFIG_HOME/shellver/common"
set +e
stale_output="$(shellver_is_stale)"
stale_status=$?
set -e
[[ -z "$stale_output" ]] || {
    print -u2 "FAIL: staleness predicate produced output: $stale_output"
    exit 1
}
[[ "$stale_status" -eq 0 ]] || {
    print -u2 'FAIL: stale shell reported current'
    exit 1
}

printf '99\n' > "$XDG_CONFIG_HOME/shellver/machine"
set +e
reserved_error="$(shellver_current 2>&1 >/dev/null)"
reserved_status=$?
set -e
[[ "$reserved_status" -ne 0 ]] || {
    print -u2 'FAIL: reserved machine generation was accepted'
    exit 1
}
[[ "$reserved_error" == *"reserved generation name 'machine'"* ]] || {
    print -u2 'FAIL: reserved-name error mismatch'
    exit 1
}

print 'PASS: shellver Zsh capabilities'
