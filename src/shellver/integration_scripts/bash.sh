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

    [ -n "$common" ] || common='-'
    [ -n "$local_generation" ] || local_generation='-'
    [ -n "$machine" ] || machine='-'
    _SHELLVER_CURRENT="common:$common|local:$local_generation|machine:$machine"
}

_shellver_initialize() {
    if [ "${SHELLVER+x}" != x ]; then
        _shellver_load_current
        SHELLVER="$_SHELLVER_CURRENT"
        unset _SHELLVER_CURRENT
        export SHELLVER
    fi
}

_shellver_is_stale() {
    _shellver_load_current
    if [ "${SHELLVER-}" = "$_SHELLVER_CURRENT" ]; then
        unset _SHELLVER_CURRENT
        return 1
    fi
    unset _SHELLVER_CURRENT
    return 0
}

_shellver_print_warning() {
    if [ -n "${NO_COLOR-}" ] || [ ! -t 1 ]; then
        printf '[shellver stale]\n'
    else
        printf '\033[31m[shellver stale]\033[0m\n'
    fi
}

_shellver_prompt_hook() {
    local shellver_status=$?
    if _shellver_is_stale; then
        _shellver_print_warning
    fi
    return "$shellver_status"
}

_shellver_initialize
if [ "${_SHELLVER_BASH_HOOKED-}" != 1 ]; then
    case "$(declare -p PROMPT_COMMAND 2>/dev/null)" in
        'declare -a '*|'declare -A '*)
            PROMPT_COMMAND=(_shellver_prompt_hook "${PROMPT_COMMAND[@]}")
            ;;
        *)
            PROMPT_COMMAND="_shellver_prompt_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
            ;;
    esac
    _SHELLVER_BASH_HOOKED=1
fi
