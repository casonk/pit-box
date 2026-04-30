#!/usr/bin/env python3
"""Resolve the Guacamole login credential for the remote desktop gateway."""

from __future__ import annotations

import argparse
import configparser
import shlex
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
AUTO_PASS_ROOT = REPO_ROOT.parent / "auto-pass"
DEFAULT_AUTO_PASS_ENV_FILE = AUTO_PASS_ROOT / "config" / "auto-pass.env.local"
AUTO_PASS_CONFIG = REPO_ROOT / "config" / "auto-pass.ini"


class ResolveError(RuntimeError):
    pass


def _resolve_path(raw_path: str) -> Path:
    text = str(raw_path or "").strip()
    if not text:
        return DEFAULT_AUTO_PASS_ENV_FILE
    path = Path(text).expanduser()
    if path.is_absolute():
        return path
    return (REPO_ROOT / path).resolve()


def _load_repo_auto_pass_config() -> dict[str, str]:
    if not AUTO_PASS_CONFIG.is_file():
        return {}
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    try:
        with AUTO_PASS_CONFIG.open(encoding="utf-8") as handle:
            parser.read_file(handle)
    except (OSError, configparser.Error) as exc:
        raise ResolveError(f"cannot read {AUTO_PASS_CONFIG}: {exc}") from exc

    values: dict[str, str] = {}
    if parser.has_section("auto_pass"):
        values["profile"] = parser.get("auto_pass", "profile", fallback="").strip()
        values["env_file"] = parser.get("auto_pass", "env_file", fallback="").strip()
    if parser.has_section("remote_desktop"):
        values["web_password_keepass_entry"] = parser.get(
            "remote_desktop",
            "web_password_keepass_entry",
            fallback="",
        ).strip()
    return {key: value for key, value in values.items() if value}


def _resolve_from_auto_pass(
    *,
    entry: str,
    profile: str,
    env_file: Path,
    fallback_user: str,
    allow_interactive: bool,
) -> tuple[str, str]:
    auto_pass_src = AUTO_PASS_ROOT / "src"
    if not auto_pass_src.is_dir():
        raise ResolveError(f"auto-pass source tree not found at {auto_pass_src}")
    sys.path.insert(0, str(auto_pass_src))

    from auto_pass.envfile import load_config_environment  # noqa: PLC0415
    from auto_pass.keepassxc import resolve_keepassxc_entry  # noqa: PLC0415

    if env_file.is_file():
        load_config_environment(str(env_file), profile=profile or None)
    elif profile:
        load_config_environment(str(env_file), profile=profile)

    result = resolve_keepassxc_entry(
        entry=entry,
        attrs_map={"username": "username", "password": "password"},
        allow_interactive=allow_interactive,
    )
    username = str(result.get("username", "")).strip() or fallback_user
    password = str(result.get("password", ""))
    return username, password


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--entry", default="", help="KeePassXC entry path.")
    parser.add_argument("--profile", default="", help="auto-pass profile override.")
    parser.add_argument(
        "--env-file",
        default="",
        help="auto-pass env file path.",
    )
    parser.add_argument("--user", default="", help="Fallback Guacamole username.")
    parser.add_argument(
        "--fallback-password",
        default="",
        help="Fallback password from settings.env when no KeePass entry is configured.",
    )
    parser.add_argument(
        "--allow-interactive",
        action="store_true",
        help="Allow auto-pass to prompt for the KeePass database password.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_auto_pass = _load_repo_auto_pass_config()
    entry = str(args.entry or "").strip() or repo_auto_pass.get(
        "web_password_keepass_entry",
        "",
    )
    profile = str(args.profile or "").strip() or repo_auto_pass.get("profile", "")
    env_file = _resolve_path(str(args.env_file or "").strip() or repo_auto_pass.get("env_file", ""))
    username = str(args.user or "").strip()
    password = str(args.fallback_password or "")
    source = "settings.env"

    if entry:
        try:
            username, password = _resolve_from_auto_pass(
                entry=entry,
                profile=profile,
                env_file=env_file,
                fallback_user=username,
                allow_interactive=bool(args.allow_interactive),
            )
            source = f"auto-pass:{entry}"
        except Exception as exc:
            raise ResolveError(f"auto-pass lookup failed for {entry!r}: {exc}") from exc

    if not username:
        raise ResolveError("remote desktop web username is empty")
    if not password:
        raise ResolveError(
            "remote desktop web password is empty; set "
            "REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_ENTRY or REMOTE_DESKTOP_WEB_PASSWORD"
        )

    print(f"REMOTE_DESKTOP_WEB_USER={shlex.quote(username)}")
    print(f"REMOTE_DESKTOP_WEB_PASSWORD={shlex.quote(password)}")
    print(f"REMOTE_DESKTOP_WEB_PASSWORD_SOURCE={shlex.quote(source)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ResolveError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
