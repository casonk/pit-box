# AGENTS.md

This repository is intended to be maintained by humans and automation agents.

## Mission

Maintain a secure, minimal, and understandable home remote-access stack based on:

- WireGuard as the sole public ingress
- SSH for administrative control
- Optional internal services over VPN
- No direct public exposure of admin web UIs unless explicitly required and documented

## Portfolio References

- `./util-repos/traction-control`: portfolio-wide standards and repo baseline
- `./util-repos/archility`: standard architecture bootstrap and render tooling
- `./util-repos/auto-pass`: standard password-management utility repo
- `./util-repos/nordility`: standard VPN-switching utility repo
- `./util-repos/shock-relay`: standard external-messaging utility repo
- `./util-repos/short-circuit`: standard WireGuard VPN setup and configuration utility
- `./util-repos/snowbridge`: standard SMB-based file-sharing and phone-access utility repo
- `./util-repos/dyno-lab`: standard unified test bench utility repo

## Session Continuity

- Read `AGENTS.md`, `LESSONSLEARNED.md`, and local-only `CHATHISTORY.md` before
  making substantive repo changes.
- Update local-only `CHATHISTORY.md` after meaningful work.
- Add durable operational guidance to `LESSONSLEARNED.md` when a lesson should
  change future behavior.

## Non-negotiable design constraints

1. **Do not** change the architecture to expose SSH directly on the public internet.
2. **Do not** add password-based SSH as a default.
3. **Do not** add admin web UIs as public-facing defaults.
4. **Do not** commit generated secrets, private keys, or environment-specific configs.
5. **Do not** silently change IP ranges, listen ports, or firewall policy semantics without updating:
   - `README.md`
   - `docs/architecture.md`
   - example configs
   - validation logic
6. Preserve a strong separation between:
   - examples
   - generated output
   - user secrets
   - install-time system state

## Preferred change style

When modifying the repo:

- prefer small, explicit scripts
- prefer idempotent operations where possible
- avoid hidden side effects
- document assumptions in comments
- fail early on missing prerequisites
- make distro-specific behavior explicit rather than clever

## Security expectations

Agents must preserve the following defaults unless a human explicitly requests otherwise:

- WireGuard is the only internet-facing service
- SSH uses public keys
- `PermitRootLogin no`
- `PasswordAuthentication no`
- firewall rules are narrow and interface-aware
- forwarding is enabled only when needed
- full-tunnel routing is opt-in

## Script standards

Shell scripts should:

- use `#!/usr/bin/env bash`
- use `set -euo pipefail`
- validate required environment variables
- print actionable error messages
- avoid destructive behavior without an explicit message
- avoid modifying unrelated system files

## Documentation standards

Any change affecting behavior must update:

- `README.md`
- relevant files in `docs/`
- example config templates in `configs/`
- validation logic in `scripts/validate.sh`

## Acceptable future additions

- QR generation for mobile import
- support for additional distributions
- IPv6 support improvements
- optional SFTP-only profiles
- optional reverse proxy for internal-only web UIs
- CI checks for shell linting and config rendering

## Forbidden future additions by default

- cloud tunnel agents that bypass the local design
- direct public exposure of Cockpit / similar
- password-based SSH enablement
- UPnP-based automatic router opening
- secret material committed into version control

## Release checklist

Before packaging a release:

1. run `scripts/validate.sh`
2. confirm no secrets are included
3. confirm examples still match README defaults
4. confirm firewall scripts match documented network model
5. confirm client config packaging still works

## Commit style

Use commit messages of the form:

- `docs: clarify full-tunnel routing`
- `scripts: add firewalld masquerade step`
- `configs: update iphone example AllowedIPs`
- `security: tighten ssh hardening snippet`

## Human override

If a human explicitly asks for a different topology, preserve their request but document the tradeoff in the README and architecture docs.

## Local CI Verification

Run before every push:

```bash
pre-commit run --all-files
```

Do not push changes that have not passed all checks locally.

