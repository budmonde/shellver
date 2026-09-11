# shellver

Shellver tells long-lived interactive shells when the shell configuration generation they loaded is older than the currently installed shell configuration.
It does not reload the caller's shell configuration or mutate other environment state.

## State Agreement

Shellver reads named generation files under `${XDG_CONFIG_HOME:-$HOME/.config}/shellver/`.
Generation names are lowercase letters, digits, periods, underscores, and hyphens; the first character must be a letter or digit.
Each visible entry must be a file or a link to a file whose first line is a non-negative integer.
Shellver discovers the entries generically and orders them by name.

`machine` is reserved and must not appear in the configuration directory.
Shellver reads that generation exclusively from the regular file `${XDG_STATE_HOME:-$HOME/.local/state}/shellver/machine`.
A configuration entry named `machine` is reported as a misconfiguration.

Shell initialization exports the sorted named generations followed by the machine generation as `SHELLVER`, replacing any value inherited from a parent process.
Evaluating the integration establishes a freshness boundary for the current interactive shell, so a new shell records the current generation even when its parent shell or terminal multiplexer loaded an older generation.
An existing shell retains its loaded generation and becomes stale when the configured generations change.
Missing, empty, or unreadable generation files contribute `-`.

The generation records which configuration version initialized the shell.
It does not prove that the shell's complete environment equals a clean environment or detect arbitrary environment-variable changes.

Shellver does not assign meaning to configuration generation names.
The caller owns their files and links, decides when to bump them, and chooses how to present staleness.

## Installation

Install the command from the public repository:

```bash
uv tool install git+https://github.com/budmonde/shellver.git
```

Shellver requires Python 3.10 or newer.

## Development Installation

Install the current checkout as an editable command:

```bash
uv tool install --editable .
```

Ordinary Python installation is also supported:

```bash
python -m pip install .
```

## Shell Integration

Evaluate the generated integration once during interactive shell setup, after the caller's environment configuration has loaded.
The generated code records the current configuration generation for that shell and exposes native query functions.
It does not install a prompt hook, wrap an existing prompt, or render a warning.

```bash
eval "$(shellver init bash)"
```

```zsh
eval "$(shellver init zsh)"
```

```powershell
Invoke-Expression (& shellver init powershell | Out-String)
```

The Bash and Zsh integrations expose `shellver_current` and `shellver_is_stale`.
The PowerShell integration exposes `Get-ShellverCurrent` and `Test-ShellverStale`.
The current-generation functions print or return the current composite value.
The staleness predicates succeed or return `$true` when the shell's loaded generation differs from current state.

Prompt presentation belongs to the calling configuration.
For example, a Bash prompt may choose its own text, color, and placement:

```bash
if shellver_is_stale; then
    printf '\033[31mrestart shell\033[0m\n'
fi
```

A PowerShell prompt can make the same choice independently:

```powershell
if (Test-ShellverStale) {
    '[restart shell]'
}
```

The native query functions read the configuration and state files in-process and do not launch Python or Git.

## Commands

`shellver` and `shellver status` print the loaded generation, current generation, and status.
The status command exits with code `1` when stale.
Pass a generation name to compare only that component, such as `shellver status common` or `shellver status machine`.
The component form prints its generation name, loaded value, current value, and `current` or `stale` status.

`shellver current` prints only the current composite generation.

`shellver bump <name>` increments a generation atomically.
For configuration generations, Shellver updates the resolved file while preserving a configuration link.
`shellver bump machine` creates or increments the regular state file and refuses to replace a symbolic link at that path.
Its first run converts the opaque machine token written by Shellver 0.2 to integer generation `1`.

## Tests

Run the standard-library tests and native integration contracts:

```bash
PYTHONPATH=src python -m unittest discover -s tests -p 'test_*.py'
bash tests/shell_hooks.bash
zsh tests/shell_hooks.zsh
```

```powershell
$env:PYTHONPATH = Join-Path $PWD 'src'
python -m unittest discover -s tests -p 'test_*.py'
pwsh -NoProfile -File tests/shell_hooks.Tests.ps1
```
