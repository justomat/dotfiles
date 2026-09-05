import os
import shutil
import subprocess
from typing import Any

import dotbot


class Skills(dotbot.Plugin):
    """
    Dotbot plugin for managing agent skills using pnpx skills.
    """

    supports_dry_run = True

    _directives = ["skills", "skill"]

    def can_handle(self, directive: str) -> bool:
        return directive in self._directives

    def _find_runner(self) -> str | None:
        """
        Locate pnpx or npx binary, checking PATH and common mise shim locations.
        """
        candidates = [
            shutil.which("pnpx"),
            os.path.expanduser("~/.local/share/mise/shims/pnpx"),
            os.path.expanduser("~/.local/share/mise/installs/pnpm/latest/pnpx"),
            shutil.which("npx"),
            os.path.expanduser("~/.local/share/mise/shims/npx"),
        ]
        for c in candidates:
            if c and os.path.isfile(c) and os.access(c, os.X_OK):
                return c
        return None

    def handle(self, directive: str, data: Any) -> bool:
        if directive not in self._directives:
            msg = f"Skills plugin cannot handle directive {directive}"
            raise ValueError(msg)

        if not data:
            return True

        runner = self._find_runner()
        if not runner:
            self._log.error("Neither pnpx nor npx found in PATH or mise shims")
            return False

        if isinstance(data, str):
            items = [data]
        elif isinstance(data, list):
            items = data
        elif isinstance(data, dict):
            items = [data]
        else:
            self._log.error(f"Invalid data format for {directive} directive: {data}")
            return False

        defaults = {
            "global": True,
            "yes": True,
            "all": False,
            "copy": False,
        }
        defaults.update(self._context.defaults().get(directive, {}))

        success = True
        for item in items:
            pkg = ""
            flags = []

            if isinstance(item, str):
                pkg = item
                if defaults["global"]:
                    flags.append("-g")
                if defaults["yes"]:
                    flags.append("-y")
                if defaults["all"]:
                    flags.append("--all")
                if defaults["copy"]:
                    flags.append("--copy")
            elif isinstance(item, dict):
                pkg = item.get("package", item.get("name", ""))
                is_global = item.get("global", defaults["global"])
                is_yes = item.get("yes", defaults["yes"])
                is_all = item.get("all", defaults["all"])
                is_copy = item.get("copy", defaults["copy"])

                if is_global:
                    flags.append("-g")
                if is_yes:
                    flags.append("-y")
                if is_all:
                    flags.append("--all")
                if is_copy:
                    flags.append("--copy")
                if "skill" in item:
                    flags.extend(["--skill", item["skill"]])
                if "agent" in item:
                    flags.extend(["--agent", item["agent"]])

            if not pkg:
                self._log.error(f"Missing package in skill directive item: {item}")
                success = False
                continue

            cmd = [runner, "skills", "add", pkg] + flags
            cmd_str = " ".join(cmd)

            if self._context.dry_run():
                self._log.action(f"Would run: {cmd_str}")
                continue

            self._log.action(f"Installing skills from {pkg} ({cmd_str})")
            try:
                # Ensure HOME environment is properly preserved
                env = os.environ.copy()
                subprocess.check_call(cmd, cwd=os.path.expanduser("~"), env=env)
                self._log.info(f"Successfully installed skills from {pkg}")
            except subprocess.CalledProcessError as e:
                self._log.error(f"Failed installing skills from {pkg}: {e}")
                success = False

        return success
