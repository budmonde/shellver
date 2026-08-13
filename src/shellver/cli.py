from __future__ import annotations

import argparse
import os
import re
import stat
import sys
import tempfile
import time
from pathlib import Path

from shellver import __version__
from shellver.integrations import INTEGRATION_FILES, integration_for


GENERATION_NAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]*$")


class ShellverError(Exception):
    pass


def config_directory() -> Path:
    config_home = os.environ.get("XDG_CONFIG_HOME")
    if config_home:
        return Path(config_home) / "shellver"
    return Path.home() / ".config" / "shellver"


def state_directory() -> Path:
    state_home = os.environ.get("XDG_STATE_HOME")
    if state_home:
        return Path(state_home) / "shellver"
    return Path.home() / ".local" / "state" / "shellver"


def read_generation(path: Path) -> str:
    try:
        with path.open(encoding="utf-8") as stream:
            value = stream.readline().strip()
    except OSError:
        return "-"
    if not value:
        return "-"
    if not value.isdigit():
        raise ShellverError(f"generation must contain a non-negative integer: {path}")
    return value


def config_generation_paths() -> list[Path]:
    directory = config_directory()
    reserved_path = directory / "machine"
    if reserved_path.exists() or reserved_path.is_symlink():
        raise ShellverError(
            f"reserved generation name 'machine' is not allowed in {directory}"
        )
    try:
        entries = list(directory.iterdir())
    except FileNotFoundError:
        return []
    except OSError as error:
        raise ShellverError(
            f"cannot read generation directory {directory}: {error}"
        ) from error

    generations: list[Path] = []
    for entry in entries:
        if entry.name.startswith("."):
            continue
        if not GENERATION_NAME_PATTERN.fullmatch(entry.name):
            raise ShellverError(
                f"invalid generation name '{entry.name}' in {directory}"
            )
        if entry.is_dir():
            raise ShellverError(f"generation must be a file: {entry}")
        generations.append(entry)
    return sorted(generations, key=lambda path: path.name)


def current_generation() -> str:
    components = [
        f"{path.name}:{read_generation(path)}" for path in config_generation_paths()
    ]
    components.append(f"machine:{read_generation(state_directory() / 'machine')}")
    return "|".join(components)


def show_status() -> int:
    loaded = os.environ.get("SHELLVER", "")
    current = current_generation()
    stale = loaded != current
    print(f"loaded:  {loaded}")
    print(f"current: {current}")
    print(f"status:  {'stale' if stale else 'current'}")
    return int(stale)


def replace_generation(path: Path, value: int) -> None:
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else None
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent, text=True
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(f"{value}\n")
        if mode is not None:
            os.chmod(temporary_path, mode)
        for attempt in range(5):
            try:
                os.replace(temporary_path, path)
                break
            except PermissionError:
                if attempt == 4:
                    raise
                time.sleep(0.02 * (2**attempt))
    finally:
        temporary_path.unlink(missing_ok=True)


def bump_generation(name: str) -> int:
    config_generation_paths()
    if name == "machine":
        directory = state_directory()
        directory.mkdir(parents=True, exist_ok=True)
        generation_path = directory / "machine"
    else:
        if not GENERATION_NAME_PATTERN.fullmatch(name):
            raise ShellverError(f"invalid generation name '{name}'")
        generation_path = config_directory() / name
        if not generation_path.exists() and not generation_path.is_symlink():
            raise ShellverError(f"generation does not exist: {generation_path}")

    if name == "machine" and generation_path.is_symlink():
        print(
            f"shellver: refusing to replace linked machine generation: {generation_path}",
            file=sys.stderr,
        )
        return 1

    try:
        target_path = generation_path.resolve(strict=True)
    except FileNotFoundError:
        if name != "machine":
            raise ShellverError(f"generation target does not exist: {generation_path}")
        target_path = generation_path
    except OSError as error:
        raise ShellverError(f"cannot resolve generation {generation_path}: {error}") from error
    if target_path.exists() and not target_path.is_file():
        raise ShellverError(f"generation must be a file: {generation_path}")

    try:
        current_value = read_generation(target_path)
    except ShellverError:
        if name != "machine":
            raise
        current_value = "-"
    if current_value == "-":
        next_value = 1
    else:
        next_value = int(current_value) + 1
    replace_generation(target_path, next_value)
    print(next_value)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="shellver")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    subparsers = parser.add_subparsers(dest="action")
    subparsers.add_parser("status", help="compare the loaded and current generations")
    subparsers.add_parser("current", help="print the current composite generation")
    bump_parser = subparsers.add_parser("bump", help="increment a named generation")
    bump_parser.add_argument("name")
    init_parser = subparsers.add_parser("init", help="emit a native shell integration")
    init_parser.add_argument("shell", choices=tuple(INTEGRATION_FILES))
    return parser


def main() -> int:
    arguments = build_parser().parse_args()
    try:
        if arguments.action == "current":
            print(current_generation())
            return 0
        if arguments.action == "bump":
            return bump_generation(arguments.name)
        if arguments.action == "init":
            print(integration_for(arguments.shell), end="")
            return 0
        return show_status()
    except ShellverError as error:
        print(f"shellver: {error}", file=sys.stderr)
        return 2
