function global:_ShellverGetConfigDirectory {
    $configHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
    return Join-Path $configHome 'shellver'
}

function global:_ShellverGetStateDirectory {
    $stateHome = if ($env:XDG_STATE_HOME) { $env:XDG_STATE_HOME } else { Join-Path $HOME '.local\state' }
    return Join-Path $stateHome 'shellver'
}

function global:_ShellverGetGeneration {
    param([string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        return '-'
    }

    try {
        $reader = [IO.File]::OpenText($Path)
        try {
            $line = $reader.ReadLine()
            $value = if ($null -eq $line) { '' } else { $line.Trim() }
        } finally {
            $reader.Dispose()
        }
    } catch {
        return '-'
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        return '-'
    }
    if ($value -cnotmatch '^[0-9]+$') {
        throw "shellver: generation must contain a non-negative integer: $Path"
    }
    return $value
}

function global:Get-ShellverCurrent {
    $configDirectory = _ShellverGetConfigDirectory
    if ($null -ne (Get-Item -LiteralPath (Join-Path $configDirectory 'machine') -Force -ErrorAction SilentlyContinue)) {
        throw "shellver: reserved generation name 'machine' is not allowed in $configDirectory"
    }

    $components = [System.Collections.Generic.List[string]]::new()
    if ([IO.Directory]::Exists($configDirectory)) {
        $names = @(
            Get-ChildItem -LiteralPath $configDirectory -Force |
                Where-Object { -not $_.Name.StartsWith('.') } |
                ForEach-Object { $_.Name }
        )
        [Array]::Sort($names, [StringComparer]::Ordinal)
        foreach ($name in $names) {
            if ($name -cnotmatch '^[a-z0-9][a-z0-9._-]*$') {
                throw "shellver: invalid generation name '$name' in $configDirectory"
            }
            $path = Join-Path $configDirectory $name
            if ([IO.Directory]::Exists($path)) {
                throw "shellver: generation must be a file: $path"
            }
            $components.Add("${name}:$(_ShellverGetGeneration $path)")
        }
    }

    $stateDirectory = _ShellverGetStateDirectory
    $components.Add("machine:$(_ShellverGetGeneration (Join-Path $stateDirectory 'machine'))")
    return $components -join '|'
}

function global:Test-ShellverStale {
    return $env:SHELLVER -cne (Get-ShellverCurrent)
}

$env:SHELLVER = Get-ShellverCurrent
