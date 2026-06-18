#!/usr/bin/env python3
"""Compute the Guacamole password SHA-256 hash and store it in a dedicated
KeePassXC entry (pit-box/remote-desktop/guacamole-hash) so the render script
never needs the plaintext password in bash.

Run once after any password change:
    python3 scripts/store_guacamole_hash.py
"""

from __future__ import annotations

import configparser
import hashlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
AUTO_PASS_ROOT = REPO_ROOT.parent / "auto-pass"
AUTO_PASS_CONFIG = REPO_ROOT / "config" / "auto-pass.ini"


def _load_config() -> tuple[str, str, str, str]:
    """Return (profile, env_file, password_entry, hash_entry)."""
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    if AUTO_PASS_CONFIG.is_file():
        with AUTO_PASS_CONFIG.open(encoding="utf-8") as fh:
            parser.read_file(fh)

    profile = parser.get("auto_pass", "profile", fallback="").strip()
    env_file_raw = parser.get("auto_pass", "env_file", fallback="").strip()
    password_entry = parser.get("remote_desktop", "web_password_keepass_entry", fallback="").strip()
    hash_entry = parser.get("remote_desktop", "web_password_hash_keepass_entry", fallback="").strip()

    if env_file_raw:
        env_path = Path(env_file_raw).expanduser()
        if not env_path.is_absolute():
            env_path = (REPO_ROOT / env_path).resolve()
        env_file = str(env_path)
    else:
        env_file = str(AUTO_PASS_ROOT / "config" / "auto-pass.env.local")

    return profile, env_file, password_entry, hash_entry


def main() -> int:
    auto_pass_src = AUTO_PASS_ROOT / "src"
    if not auto_pass_src.is_dir():
        print(f"error: auto-pass source not found at {auto_pass_src}", file=sys.stderr)
        return 1
    sys.path.insert(0, str(auto_pass_src))

    from auto_pass.envfile import load_config_environment  # noqa: PLC0415
    from auto_pass.keepassxc import resolve_keepassxc_entry, upsert_keepassxc_entry  # noqa: PLC0415

    profile, env_file, password_entry, hash_entry = _load_config()

    if not password_entry:
        print("error: web_password_keepass_entry not set in config/auto-pass.ini", file=sys.stderr)
        return 1
    if not hash_entry:
        print("error: web_password_hash_keepass_entry not set in config/auto-pass.ini", file=sys.stderr)
        return 1

    env_path = Path(env_file)
    if env_path.is_file():
        load_config_environment(env_file, profile=profile or None)
    elif profile:
        load_config_environment(env_file, profile=profile)

    print(f"Reading password from: {password_entry}")
    result = resolve_keepassxc_entry(
        entry=password_entry,
        attrs_map={"password": "password"},
        allow_interactive=True,
    )
    password = str(result.get("password", "")).strip()
    if not password:
        print("error: entry password is empty", file=sys.stderr)
        return 1

    computed_hash = hashlib.sha256(password.encode()).hexdigest()
    print(f"SHA-256 hash: {computed_hash}")

    print(f"Writing hash to:  {hash_entry}")
    action = upsert_keepassxc_entry(
        hash_entry,
        username="sha256",
        password=computed_hash,
        allow_interactive=True,
    )
    print(f"Done ({action}): {hash_entry}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
