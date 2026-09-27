# Fedora T7 Backup

## Purpose and boundaries
This repository provides encrypted, deduplicated Restic backups of configured Fedora paths to a validated external backup filesystem. It is a file-level recovery system, not a block-level disk clone. MegaVault owns project identity and runtime inventory; C2 owns work-item lifecycle. The backup medium and notification transport are external dependencies.

## Architecture
The lifecycle script validates and mounts the expected medium, runs the backup, performs configured retention/maintenance, synchronizes and unmounts, then sends a status notification. udev can request the systemd backup unit when the expected device is attached. See `docs/ai/PROJECT.md`, `docs/human/OPERATIONS.md`, and `docs/human/overview.md`.

## Safety
Never initialize over an existing Restic repository, format or repartition storage, weaken device validation, or identify a durable disk as `/dev/sdX`. Never expose or commit the Restic password, notification credentials, backups, or logs. Install and live backup/recovery tests change system or backup state and require explicit operational authorization. Source validation must not access the attached backup device, repository, live system state, or notification endpoints. Run isolated tests with `python3 -B tests/test_behavior.py -q` and static checks with `bash tests/static.sh`.
