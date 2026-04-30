#!/usr/bin/env python3
"""Create or update the Guacamole credential entry in auto-pass."""

from __future__ import annotations

import argparse
import configparser
import secrets
import shlex
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
AUTO_PASS_ROOT = REPO_ROOT.parent / "auto-pass"
DEFAULT_AUTO_PASS_ENV_FILE = AUTO_PASS_ROOT / "config" / "auto-pass.env.local"
DEFAULT_ENTRY = "pit-box/remote-desktop/guacamole"
AUTO_PASS_CONFIG = REPO_ROOT / "config" / "auto-pass.ini"


class ExportError(RuntimeError):
    pass


def _parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for line_no, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" not in stripped:
            raise ExportError(f"invalid env assignment in {path} line {line_no}")
        key, raw_value = stripped.split("=", 1)
        key = key.strip()
        try:
            tokens = shlex.split(raw_value.strip(), posix=True)
        except ValueError as exc:
            raise ExportError(f"invalid env value in {path} line {line_no}: {exc}") from exc
        values[key] = tokens[0] if len(tokens) == 1 else " ".join(tokens)
    return values


def _load_repo_auto_pass_config() -> dict[str, str]:
    if not AUTO_PASS_CONFIG.is_file():
        return {}
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    try:
        with AUTO_PASS_CONFIG.open(encoding="utf-8") as handle:
            parser.read_file(handle)
    except (OSError, configparser.Error) as exc:
        raise ExportError(f"cannot read {AUTO_PASS_CONFIG}: {exc}") from exc

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


def _setting(settings: dict[str, str], key: str, default: str = "") -> str:
    return str(settings.get(key, default) or "").strip()


def _resolve_path(raw_path: str) -> Path:
    text = str(raw_path or "").strip()
    if not text:
        return DEFAULT_AUTO_PASS_ENV_FILE
    path = Path(text).expanduser()
    if path.is_absolute():
        return path
    return (REPO_ROOT / path).resolve()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--settings",
        default=str(REPO_ROOT / "settings.env"),
        help="pit-box settings.env path.",
    )
    parser.add_argument("--entry", default="", help=f"KeePass entry path. Default: {DEFAULT_ENTRY}")
    parser.add_argument("--profile", default="", help="auto-pass profile override.")
    parser.add_argument("--env-file", default="", help="auto-pass env file path.")
    parser.add_argument("--username", default="", help="Guacamole username.")
    parser.add_argument(
        "--password-stdin",
        action="store_true",
        help="Read the Guacamole password from stdin.",
    )
    parser.add_argument(
        "--generate",
        action="store_true",
        help="Generate a new Guacamole password instead of reading settings.env.",
    )
    parser.add_argument(
        "--allow-interactive",
        action="store_true",
        help="Allow auto-pass to prompt for the KeePass database password.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print target without writing.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    settings_path = Path(args.settings).expanduser()
    settings = _parse_env_file(settings_path)
    repo_auto_pass = _load_repo_auto_pass_config()

    entry = (
        str(args.entry or "").strip()
        or _setting(settings, "REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_ENTRY")
        or repo_auto_pass.get("web_password_keepass_entry", "")
        or DEFAULT_ENTRY
    )
    profile = str(args.profile or "").strip() or _setting(
        settings,
        "REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_PROFILE",
    ) or repo_auto_pass.get("profile", "infra")
    env_file = _resolve_path(
        str(args.env_file or "").strip()
        or _setting(settings, "REMOTE_DESKTOP_WEB_AUTO_PASS_ENV_FILE")
        or repo_auto_pass.get("env_file", "")
    )
    username = str(args.username or "").strip() or _setting(
        settings,
        "REMOTE_DESKTOP_WEB_USER",
        "iphone",
    )
    hostname = _setting(settings, "REMOTE_DESKTOP_WEB_HOSTNAME")
    url = f"https://{hostname}/" if hostname else ""

    if args.password_stdin:
        password = sys.stdin.read().rstrip("\n")
    elif args.generate:
        password = secrets.token_urlsafe(24)
    else:
        password = _setting(settings, "REMOTE_DESKTOP_WEB_PASSWORD")

    if not entry:
        raise ExportError("KeePass entry path is empty")
    if not username:
        raise ExportError("Guacamole username is empty")
    if not password:
        raise ExportError(
            "Guacamole password is empty; set REMOTE_DESKTOP_WEB_PASSWORD, "
            "use --password-stdin, or use --generate"
        )

    if args.dry_run:
        print(f"dry-run: would upsert {entry!r} for username {username!r}")
        return 0

    auto_pass_src = AUTO_PASS_ROOT / "src"
    if not auto_pass_src.is_dir():
        raise ExportError(f"auto-pass source tree not found at {auto_pass_src}")
    sys.path.insert(0, str(auto_pass_src))

    from auto_pass.envfile import load_config_environment  # noqa: PLC0415
    from auto_pass.keepassxc import ensure_group, upsert_keepassxc_entry  # noqa: PLC0415

    if env_file.is_file():
        load_config_environment(str(env_file), profile=profile or None)
    elif profile:
        load_config_environment(str(env_file), profile=profile)

    notes = (
        "Guacamole login for pit-box Safari remote desktop. "
        "The xrdp desktop login remains the local Linux account."
    )
    parent_parts = entry.strip("/").split("/")[:-1]
    for index in range(1, len(parent_parts) + 1):
        ensure_group(
            "/".join(parent_parts[:index]),
            allow_interactive=bool(args.allow_interactive),
        )

    mode = upsert_keepassxc_entry(
        entry,
        username=username,
        password=password,
        url=url or None,
        notes=notes,
        allow_interactive=bool(args.allow_interactive),
    )
    print(f"{mode}: {entry}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ExportError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
