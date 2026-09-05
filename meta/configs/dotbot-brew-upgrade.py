import os
import shutil
import subprocess
from typing import Any

import dotbot


class BrewUpgrade(dotbot.Plugin):
    """
    Dotbot plugin for upgrading Homebrew packages.
    """

    supports_dry_run = True

    _directives = ["brew-upgrade", "brew-update"]

    def can_handle(self, directive: str) -> bool:
        return directive in self._directives

    def _find_brew(self) -> str | None:
        candidates = [
            shutil.which("brew"),
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            os.path.expanduser("~/.brew/bin/brew"),
        ]
        for c in candidates:
            if c and os.path.isfile(c) and os.access(c, os.X_OK):
                return c
        return None

    def handle(self, directive: str, data: Any) -> bool:
        if directive not in self._directives:
            msg = f"BrewUpgrade plugin cannot handle directive {directive}"
            raise ValueError(msg)

        if not data:
            return True

        brew = self._find_brew()
        if not brew:
            self._log.error("brew is not installed or not in PATH")
            return False

        flags = ["-y"]
        if isinstance(data, dict):
            if not data.get("yes", True):
                flags.remove("-y")
            if data.get("greedy", False):
                flags.append("--greedy")
        elif isinstance(data, list):
            for item in data:
                if isinstance(item, str) and item.startswith("-"):
                    if item not in flags:
                        flags.append(item)

        cmd = [brew, "upgrade"] + flags
        cmd_str = " ".join(cmd)

        if self._context.dry_run():
            self._log.action(f"Would run: {cmd_str}")
            return True

        self._log.action(f"Upgrading Homebrew packages ({cmd_str})")
        try:
            subprocess.check_call(cmd, cwd=os.path.expanduser("~"))
            self._log.info("Successfully upgraded Homebrew packages")
            return True
        except subprocess.CalledProcessError as e:
            self._log.error(f"Failed to upgrade Homebrew packages: {e}")
            return False
