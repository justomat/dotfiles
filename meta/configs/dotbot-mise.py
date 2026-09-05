import os
import shutil
import subprocess
from typing import Any

import dotbot


class Mise(dotbot.Plugin):
    """
    Dotbot plugin for managing mise tools and self-updates.
    """

    supports_dry_run = True

    _directive = "mise"

    def can_handle(self, directive: str) -> bool:
        return directive == self._directive

    def _find_mise(self) -> str | None:
        candidates = [
            shutil.which("mise"),
            os.path.expanduser("~/.local/bin/mise"),
            "/opt/homebrew/bin/mise",
            "/usr/local/bin/mise",
        ]
        for c in candidates:
            if c and os.path.isfile(c) and os.access(c, os.X_OK):
                return c
        return None

    def handle(self, directive: str, data: Any) -> bool:
        if directive != self._directive:
            msg = f"Mise plugin cannot handle directive {directive}"
            raise ValueError(msg)

        mise = self._find_mise()
        if not mise:
            self._log.error("mise is not installed or not in PATH")
            return False

        home_dir = os.path.expanduser("~")
        success = True

        commands = [
            ([mise, "self-update", "-y"], "Updating mise (mise self-update -y)"),
            ([mise, "install"], "Installing mise tools (mise install)"),
            ([mise, "up", "--bump"], "Upgrading mise tools (mise up --bump)"),
        ]

        for cmd, desc in commands:
            cmd_str = " ".join(cmd)
            if self._context.dry_run():
                self._log.action(f"Would run: {cmd_str}")
                continue

            self._log.action(f"{desc}...")
            try:
                subprocess.check_call(cmd, cwd=home_dir)
                self._log.info(f"Successfully completed: {cmd_str}")
            except subprocess.CalledProcessError as e:
                self._log.error(f"Failed to run '{cmd_str}': {e}")
                success = False

        return success
