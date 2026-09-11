_shellver_load_current() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/shellver"
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/shellver"
    local generation_path name value
    local LC_ALL=C
    _SHELLVER_CURRENT=""

    if [ -e "$config_dir/machine" ] || [ -L "$config_dir/machine" ]; then
        printf "%s\n" "shellver: reserved generation name 'machine' is not allowed in $config_dir" >&2
        return 2
    fi

    if [ -d "$config_dir" ]; then
        for generation_path in "$config_dir"/*; do
            if [ ! -e "$generation_path" ] && [ ! -L "$generation_path" ]; then
                continue
            fi
            name="${generation_path##*/}"
            case "$name" in
                [a-z0-9]*) ;;
                *)
                    printf "%s\n" "shellver: invalid generation name '$name' in $config_dir" >&2
                    return 2
                    ;;
            esac
            case "$name" in
                *[!a-z0-9._-]*)
                    printf "%s\n" "shellver: invalid generation name '$name' in $config_dir" >&2
                    return 2
                    ;;
            esac
            if [ -d "$generation_path" ]; then
                printf "%s\n" "shellver: generation must be a file: $generation_path" >&2
                return 2
            fi
            value=""
            if [ -r "$generation_path" ]; then
                IFS= read -r value 2>/dev/null < "$generation_path" || :
            fi
            if [ -z "$value" ]; then
                value="-"
            else
                case "$value" in
                    *[!0-9]*)
                        printf "%s\n" "shellver: generation must contain a non-negative integer: $generation_path" >&2
                        return 2
                        ;;
                esac
            fi
            if [ -n "$_SHELLVER_CURRENT" ]; then
                _SHELLVER_CURRENT="$_SHELLVER_CURRENT|"
            fi
            _SHELLVER_CURRENT="$_SHELLVER_CURRENT$name:$value"
        done
    fi

    value=""
    if [ -r "$state_dir/machine" ]; then
        IFS= read -r value 2>/dev/null < "$state_dir/machine" || :
    fi
    if [ -z "$value" ]; then
        value="-"
    else
        case "$value" in
            *[!0-9]*)
                printf "%s\n" "shellver: generation must contain a non-negative integer: $state_dir/machine" >&2
                return 2
                ;;
        esac
    fi
    if [ -n "$_SHELLVER_CURRENT" ]; then
        _SHELLVER_CURRENT="$_SHELLVER_CURRENT|"
    fi
    _SHELLVER_CURRENT="${_SHELLVER_CURRENT}machine:$value"
}

_shellver_initialize() {
    _shellver_load_current || return
    SHELLVER="$_SHELLVER_CURRENT"
    unset _SHELLVER_CURRENT
    export SHELLVER
}

shellver_current() {
    _shellver_load_current || return
    printf '%s\n' "$_SHELLVER_CURRENT"
    unset _SHELLVER_CURRENT
}

shellver_is_stale() {
    _shellver_load_current || return
    if [ "${SHELLVER-}" = "$_SHELLVER_CURRENT" ]; then
        unset _SHELLVER_CURRENT
        return 1
    fi
    unset _SHELLVER_CURRENT
    return 0
}

_shellver_initialize
