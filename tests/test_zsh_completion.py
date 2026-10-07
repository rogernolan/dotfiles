#!/usr/bin/env python3
"""Exercise Tab completion in a fresh Zsh with an isolated home."""

import os
import pty
import select
import shlex
import signal
import tempfile
import time
from pathlib import Path


def read_until(fd, expected):
    output = bytearray()
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        readable, _, _ = select.select([fd], [], [], 0.1)
        if readable:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            output.extend(chunk)
            if expected in output:
                return
    raise AssertionError(
        f"Expected {expected!r} in terminal output:\n{output.decode(errors='replace')}"
    )


def main():
    zshrc = Path(__file__).resolve().parent.parent / "config/zshrc"
    with tempfile.TemporaryDirectory(prefix="dotfiles-completion-") as fixture:
        home = Path(fixture) / "home"
        home.mkdir()
        for name in ("MixedCaseDirectory", "lowercase-directory"):
            (home / name).mkdir()
        pid, fd = pty.fork()
        if pid == 0:
            environment = os.environ.copy()
            environment.update(HOME=str(home), ZDOTDIR=str(home), PATH="/usr/bin:/bin", TERM="xterm")
            os.execvpe("zsh", ["zsh", "-d", "-f"], environment)
        try:
            setup = (
                f"source {shlex.quote(str(zshrc))}; "
                f"cd {shlex.quote(str(home))}; "
                "PROMPT='DOTFILES_READY> '; RPROMPT=''; print -r -- STARTED\n"
            )
            os.write(fd, setup.encode())
            read_until(fd, b"\r\nSTARTED\r\n")
            for prefix, directory in (
                ("mixed", "MixedCaseDirectory"),
                ("LOW", "lowercase-directory"),
            ):
                os.write(fd, f"cd {prefix}\t\n".encode())
                os.write(fd, b'print -r -- "COMPLETED:$PWD"\n')
                read_until(fd, f"COMPLETED:{home / directory}\r\n".encode())
                os.write(fd, f"cd {shlex.quote(str(home))}\n".encode())
            print("PASS: case-insensitive Tab completion in both directions")
        finally:
            os.kill(pid, signal.SIGTERM)
            os.close(fd)
            os.waitpid(pid, 0)


if __name__ == "__main__":
    main()
