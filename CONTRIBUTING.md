# Contributing to pit-box

Thank you for your interest in contributing. This is a security-focused
repository — please read this guide carefully before submitting changes.

## Before You Start

Open an issue first to discuss the change you want to make. This avoids
duplicate work and ensures the proposed change aligns with the project's
[security model](docs/security-model.md).

## Workflow

1. Fork the repository.
2. Create a branch from `main` with a descriptive name, e.g.
   `feat/ipv6-support` or `fix/firewall-rule-order`.
3. Make your changes, then run `scripts/validate.sh` to confirm nothing is
   broken.
4. Commit using [Conventional Commits](#commit-style).
5. Open a pull request using the provided template.

## Commit Style

Use the following prefixes, consistent with the AGENTS.md commit style:

| Prefix       | When to use                                            |
|--------------|--------------------------------------------------------|
| `feat`       | New feature or capability                              |
| `fix`        | Bug fix                                                |
| `docs`       | Documentation only                                     |
| `scripts`    | Shell script changes                                   |
| `security`   | Security hardening or policy changes                   |
| `chore`      | Dependency bumps, housekeeping, tooling config         |
| `ci`         | CI/workflow changes                                    |

Examples:

```
docs: clarify full-tunnel routing in architecture.md
scripts: add firewalld masquerade step
security: tighten ssh hardening snippet
```

## Pre-commit Validation

This repository uses [pre-commit](https://pre-commit.com/). Install and run it
before pushing:

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

Hooks include trailing-whitespace, YAML validation, large-file detection,
private-key detection, and ShellCheck at warning severity.

## What Must Never Be Committed

- `settings.env` (contains real IPs, ports, key paths)
- Any file in `secrets/` except `.gitkeep` and the usage `README.md`
- Any file in `build/` or `dist/`
- Real private keys, pre-shared keys, or any cryptographic material
- Personal or network-identifying information

Committing secret material is a hard blocker for any PR.

## Pull Request Checklist

Before requesting review, confirm:

- [ ] `scripts/validate.sh` passes on a clean render
- [ ] No secrets, keys, or `settings.env` data are included
- [ ] Example configs still match README defaults
- [ ] ShellCheck passes (`pre-commit run shellcheck`)
- [ ] Docs are updated if behavior changed

## Code of Conduct

All contributors are expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
