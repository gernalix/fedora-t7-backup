#!/usr/bin/bash
set -Eeuo pipefail

readonly ACTIVITY_ID=583921
if [[ $EUID -ne 0 ]]; then exec sudo "$0" "$@"; fi

systemctl disable --now t7-restic-backup.timer t7-restic-check.timer t7-restic-maintenance.timer 2>/dev/null || true
systemctl stop t7-restic-backup.service t7-restic-check.service t7-restic-maintenance.service 2>/dev/null || true
rm -f /etc/systemd/system/t7-restic-backup.service /etc/systemd/system/t7-restic-backup.timer \
    /etc/systemd/system/t7-restic-check.service /etc/systemd/system/t7-restic-check.timer \
    /etc/systemd/system/t7-restic-maintenance.service /etc/systemd/system/t7-restic-maintenance.timer \
    /usr/local/libexec/t7-restic-backup /etc/udev/rules.d/90-t7-name.rules \
    /etc/udev/rules.d/90-t7-veeamre.rules
systemctl daemon-reload
udevadm control --reload-rules
printf 'activity=%s INFO automation removed; repository, credential, config, cache, and state preserved\n' "$ACTIVITY_ID"
printf 'Manual destructive cleanup, only if intended: /mnt/T7_BACKUP/restic-fedora /etc/credstore.encrypted/t7-restic-password /etc/t7-restic-backup /var/lib/t7-restic-backup /var/cache/t7-restic-backup\n'
