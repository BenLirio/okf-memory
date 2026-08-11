"""Background git commit+push of the memory bundle. Failures log; they never block capture."""

import logging
import subprocess
import threading
from pathlib import Path

log = logging.getLogger("gitsync")
_lock = threading.Lock()


def _run(root: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, timeout=120)


def _sync(root: Path, message: str, push: bool) -> None:
    with _lock:
        _run(root, "add", "-A")
        commit = _run(root, "commit", "-m", message)
        if commit.returncode != 0 and "nothing to commit" not in commit.stdout + commit.stderr:
            log.error("git commit failed: %s", commit.stderr.strip())
            return
        if push:
            p = _run(root, "push")
            if p.returncode != 0:
                log.error("git push failed: %s", p.stderr.strip())


def sync_async(root: Path, message: str, push: bool = True) -> None:
    threading.Thread(target=_sync, args=(root, message, push), daemon=True).start()
