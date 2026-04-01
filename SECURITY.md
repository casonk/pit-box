# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in pit-box, please report it
privately. **Do not open a public issue.**

Contact the maintainer directly via a private GitHub Security Advisory or
encrypted email. Include:

- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

You will receive an acknowledgment within 72 hours and a resolution timeline
as soon as one can be assessed.

## What Not to Report Publicly

- Real private keys, pre-shared keys, or WireGuard credentials
- Real IP addresses, port numbers, or network topology from `settings.env`
- Contents of `secrets/`, `build/`, or `dist/`

## Hard Rules — What Must Never Be Committed

Regardless of circumstances, the following must never be committed to this
repository:

- `settings.env` (contains real network coordinates)
- Any file in `secrets/` other than `.gitkeep` and the usage `README.md`
- Real WireGuard private keys or pre-shared keys
- Real SSH private keys
- Personal IP addresses, subnet ranges, or identifying network data

If secret material is ever accidentally committed, treat it as compromised
immediately: rotate keys, update firewall rules, and audit access logs.

## Supported Versions

This project does not maintain versioned release branches. Apply fixes to
`main` and re-run `scripts/validate.sh` to verify.

## Disclosure Policy

Confirmed vulnerabilities in the scaffold logic, hardening scripts, or
generated config templates will be disclosed in `CHANGELOG.md` after a fix
is available, without revealing reporter-identifying information.
