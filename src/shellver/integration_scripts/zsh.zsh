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

_shellver_is_stale() {
    _shellver_load_current
    if [[ "${SHELLVER-}" == "$_SHELLVER_CURRENT" ]]; then
        unset _SHELLVER_CURRENT
        return 1
    fi
    unset _SHELLVER_CURRENT
    return 0
}

_shellver_print_warning() {
    if [[ -n "${NO_COLOR-}" || ! -t 1 ]]; then
        print -r -- '[shellver stale]'
    else
        print -r -- $'\e[31m[shellver stale]\e[0m'
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
if [[ "${_SHELLVER_ZSH_HOOKED-}" != 1 ]]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _shellver_prompt_hook
    typeset -g _SHELLVER_ZSH_HOOKED=1
fi
