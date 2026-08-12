from __future__ import annotations

from importlib.resources import files


INTEGRATION_FILES = {
    "bash": "bash.sh",
    "zsh": "zsh.zsh",
    "powershell": "powershell.ps1",
}


def integration_for(shell: str) -> str:
    resource = files("shellver.integration_scripts").joinpath(INTEGRATION_FILES[shell])
    return resource.read_text(encoding="utf-8")
