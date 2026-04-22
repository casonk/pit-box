#!/usr/bin/env bash

resolve_registry_hostname() {
  local root_dir="$1"
  local site_name="$2"
  local wiring_repo="${PIT_BOX_WIRING_HARNESS_REPO:-$root_dir/../wiring-harness}"

  [[ -f "$wiring_repo/scripts/site_registry.py" ]] || return 1

  python3 - "$wiring_repo" "$site_name" <<'PYEOF'
from pathlib import Path
import sys

repo = Path(sys.argv[1]).resolve()
site_name = sys.argv[2]
sys.path.insert(0, str(repo / "scripts"))

from site_registry import find_site, load_sites

site = find_site(load_sites(repo / "services.toml"), site_name)
if site and site.get("hostname"):
    print(site["hostname"])
PYEOF
}

populate_site_hostname() {
  local root_dir="$1"
  local site_name="$2"
  local var_name="$3"
  local current_value="${!var_name:-}"
  local registry_value=""

  if registry_value="$(resolve_registry_hostname "$root_dir" "$site_name" 2>/dev/null)" && [[ -n "$registry_value" ]]; then
    if [[ -n "$current_value" && "$current_value" != "$registry_value" ]]; then
      echo "warning: $var_name=$current_value does not match wiring-harness registry ($registry_value); using registry value" >&2
    fi
    printf -v "$var_name" '%s' "$registry_value"
    export "$var_name=$registry_value"
    return 0
  fi

  if [[ -n "$current_value" ]]; then
    return 0
  fi

  echo "Missing $var_name and no $site_name entry found in the wiring-harness site registry." >&2
  return 1
}
