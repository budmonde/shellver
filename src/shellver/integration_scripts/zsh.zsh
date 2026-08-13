_shellver_load_current() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/shellver"
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/shellver"
    local generation_path name value
    local LC_ALL=C
    _SHELLVER_CURRENT=""

    if [[ -e "$config_dir/machine" || -L "$config_dir/machine" ]]; then
        print -u2 -r -- "shellver: reserved generation name 'machine' is not allowed in $config_dir"
        return 2
    fi

    if [[ -d "$config_dir" ]]; then
        for generation_path in "$config_dir"/*(N); do
            name="${generation_path:t}"
            if [[ "$name" != [a-z0-9]* || "$name" == *[^a-z0-9._-]* ]]; then
                print -u2 -r -- "shellver: invalid generation name '$name' in $config_dir"
                return 2
            fi
            if [[ -d "$generation_path" ]]; then
                print -u2 -r -- "shellver: generation must be a file: $generation_path"
                return 2
            fi
            value=""
            if [[ -r "$generation_path" ]]; then
                IFS= read -r value 2>/dev/null < "$generation_path" || :
            fi
            if [[ -z "$value" ]]; then
                value="-"
            elif [[ "$value" == *[^0-9]* ]]; then
                print -u2 -r -- "shellver: generation must contain a non-negative integer: $generation_path"
                return 2
            fi
            [[ -z "$_SHELLVER_CURRENT" ]] || _SHELLVER_CURRENT="$_SHELLVER_CURRENT|"
            _SHELLVER_CURRENT="$_SHELLVER_CURRENT$name:$value"
        done
    fi

    value=""
    if [[ -r "$state_dir/machine" ]]; then
        IFS= read -r value 2>/dev/null < "$state_dir/machine" || :
    fi
    if [[ -z "$value" ]]; then
        value="-"
    elif [[ "$value" == *[^0-9]* ]]; then
        print -u2 -r -- "shellver: generation must contain a non-negative integer: $state_dir/machine"
        return 2
    fi
    [[ -z "$_SHELLVER_CURRENT" ]] || _SHELLVER_CURRENT="$_SHELLVER_CURRENT|"
    _SHELLVER_CURRENT="${_SHELLVER_CURRENT}machine:$value"
}

_shellver_initialize() {
    if (( ! ${+SHELLVER} )); then
        _shellver_load_current || return
        export SHELLVER="$_SHELLVER_CURRENT"
        unset _SHELLVER_CURRENT
    fi
}

shellver_current() {
    _shellver_load_current || return
    print -r -- "$_SHELLVER_CURRENT"
    unset _SHELLVER_CURRENT
}

shellver_is_stale() {
    _shellver_load_current || return
    if [[ "${SHELLVER-}" == "$_SHELLVER_CURRENT" ]]; then
        unset _SHELLVER_CURRENT
        return 1
    fi
    unset _SHELLVER_CURRENT
    return 0
}

_shellver_initialize
