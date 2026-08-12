from __future__ import annotations

import argparse
import os
import sys
import tempfile
import time
import uuid
from pathlib import Path

from shellver import __version__
from shellver.integrations import INTEGRATION_FILES, integration_for


def state_directory() -> Path:
    state_home = os.environ.get("XDG_STATE_HOME")
    if state_home:
        return Path(state_home) / "shellver"
    return Path.home() / ".local" / "state" / "shellver"


def read_component(path: Path) -> str:
    try:
        with path.open(encoding="utf-8") as stream:
            value = stream.readline().strip()
    except OSError:
        return "-"
    return value or "-"


def current_generation() -> str:
    directory = state_directory()
    return "|".join(
        f"{name}:{read_component(directory / name)}"
        for name in ("common", "local", "machine")
    )


def show_status() -> int:
    loaded = os.environ.get("SHELLVER", "")
    current = current_generation()
    stale = loaded != current
    print(f"loaded:  {loaded}")
    print(f"current: {current}")
    print(f"status:  {'stale' if stale else 'current'}")
    return int(stale)


def bump_machine() -> int:
    directory = state_directory()
    directory.mkdir(parents=True, exist_ok=True)
    machine_path = directory / "machine"
    if machine_path.is_symlink():
        print(
            f"shellver: refusing to replace linked machine generation: {machine_path}",
            file=sys.stderr,
        )
        return 1

    token = str(uuid.uuid4())
    descriptor, temporary_name = tempfile.mkstemp(prefix=".machine.", dir=directory, text=True)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(f"{token}\n")
        for attempt in range(5):
            try:
                os.replace(temporary_path, machine_path)
                break
            except PermissionError:
                if attempt == 4:
                    raise
                time.sleep(0.02 * (2**attempt))
    finally:
        temporary_path.unlink(missing_ok=True)
    print(token)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="shellver")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    subparsers = parser.add_subparsers(dest="action")
    subparsers.add_parser("status", help="compare the loaded and current generations")
    subparsers.add_parser("current", help="print the current composite generation")
    subparsers.add_parser("bump-machine", help="replace the host-local machine generation")
    init_parser = subparsers.add_parser("init", help="emit a native shell integration")
    init_parser.add_argument("shell", choices=tuple(INTEGRATION_FILES))
    return parser


def main() -> int:
    arguments = build_parser().parse_args()
    if arguments.action == "current":
        print(current_generation())
        return 0
    if arguments.action == "bump-machine":
        return bump_machine()
    if arguments.action == "init":
        print(integration_for(arguments.shell), end="")
        return 0
    return show_status()
