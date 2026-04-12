# REFS-PUBLIC.md - Public References

> Record external public repositories, datasets, documentation, APIs, or other
> public resources that this repository utilizes or depends on.
> This file is tracked and intentionally kept free of private or local-only details.

## Public Repositories

- No fixed external code repository is the main upstream; the repo documents and automates a private WireGuard plus SSH pattern.

## Public Datasets and APIs

- No standing public data APIs are required; the repo configures local VPN and SSH surfaces.

## Documentation and Specifications

- https://www.wireguard.com/ - WireGuard protocol and configuration reference
- https://www.openssh.com/manual.html - OpenSSH reference for the hardened SSH path
- https://firewalld.org/documentation/ - firewalld reference for Fedora firewall steps

## Notes

- This repo intentionally avoids public SaaS integrations. Durable external references are limited to the VPN, firewall, and SSH specs it implements.
