_shellver_load_current() {
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/shellver"
    local common="" local_generation="" machine=""

    if [ -r "$state_dir/common" ]; then
        IFS= read -r common 2>/dev/null < "$state_dir/common" || :
    fi
    if [ -r "$state_dir/local" ]; then
        IFS= read -r local_generation 2>/dev/null < "$state_dir/local" || :
    fi
    if [ -r "$state_dir/machine" ]; then
        IFS= read -r machine 2>/dev/null < "$state_dir/machine" || :
    fi

    [[ -n "$common" ]] || common='-'
    [[ -n "$local_generation" ]] || local_generation='-'
    [[ -n "$machine" ]] || machine='-'
    _SHELLVER_CURRENT="common:$common|local:$local_generation|machine:$machine"
}

_shellver_initialize() {
    if (( ! ${+SHELLVER} )); then
        _shellver_load_current
        export SHELLVER="$_SHELLVER_CURRENT"
        unset _SHELLVER_CURRENT
    fi
}

shellver_current() {
    _shellver_load_current
    print -r -- "$_SHELLVER_CURRENT"
    unset _SHELLVER_CURRENT
}

shellver_is_stale() {
    _shellver_load_current
    if [[ "${SHELLVER-}" == "$_SHELLVER_CURRENT" ]]; then
        unset _SHELLVER_CURRENT
        return 1
    fi
    unset _SHELLVER_CURRENT
    return 0
}

_shellver_initialize
