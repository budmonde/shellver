#!/usr/bin/env zsh

set -e

PROJECT_ROOT="${0:A:h:h}"
test_state_root="$(mktemp -d)"
trap 'rm -rf -- "$test_state_root"' EXIT
export XDG_STATE_HOME="$test_state_root"
export NO_COLOR=1
mkdir -p "$XDG_STATE_HOME/shellver"
printf '1\n' > "$XDG_STATE_HOME/shellver/common"

function precmd() {
    print 'existing'
}

unset SHELLVER
hook_code="$(PYTHONPATH="$PROJECT_ROOT/src" python3 -m shellver init zsh)"
eval "$hook_code"
eval "$hook_code"

[[ "$SHELLVER" == 'common:1|local:-|machine:-' ]] || {
    print -u2 'FAIL: initial snapshot mismatch'
    exit 1
}
[[ "$(precmd)" == 'existing' ]] || {
    print -u2 'FAIL: existing precmd changed'
    exit 1
}
[[ "${#precmd_functions[(I)_shellver_prompt_hook]}" -eq 1 ]] || {
    print -u2 'FAIL: hook was registered more than once'
    exit 1
}

printf '2\n' > "$XDG_STATE_HOME/shellver/common"
set +e
stale_output="$(false; _shellver_prompt_hook)"
hook_status=$?
set -e
[[ "$stale_output" == '[shellver stale]' ]] || {
    print -u2 "FAIL: stale hook mismatch: $stale_output"
    exit 1
}
[[ "$hook_status" -eq 1 ]] || {
    print -u2 "FAIL: prior status was not preserved: $hook_status"
    exit 1
}

print 'PASS: shellver Zsh hook'
