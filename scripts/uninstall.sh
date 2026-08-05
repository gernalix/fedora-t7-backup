#!/usr/bin/bash
set -Eeuo pipefail

readonly ACTIVITY_ID=684219
if [[ $EUID -ne 0 ]]; then exec sudo "$0" "$@"; fi

systemctl disable --now t7-restic-backup.timer t7-restic-check.timer t7-restic-maintenance.timer \
    t7-restic-notify-retry.timer 2>/dev/null || true
systemctl stop t7-restic-backup.service t7-restic-reminder.timer t7-restic-reminder.service \
    t7-restic-notify-retry.timer t7-restic-notify-retry.service 2>/dev/null || true
rm -f /etc/systemd/system/t7-restic-backup.service /etc/systemd/system/t7-restic-backup.timer \
    /etc/systemd/system/t7-restic-check.service /etc/systemd/system/t7-restic-check.timer \
    /etc/systemd/system/t7-restic-maintenance.service /etc/systemd/system/t7-restic-maintenance.timer \
    /etc/systemd/system/t7-restic-reminder.service /etc/systemd/system/t7-restic-reminder.timer \
    /etc/systemd/system/t7-restic-notify-retry.service /etc/systemd/system/t7-restic-notify-retry.timer \
    /usr/local/libexec/t7-restic-backup /usr/local/libexec/t7-restic-lifecycle \
    /usr/local/libexec/t7-restic-metrics /usr/local/libexec/t7-restic-notify \
    /usr/local/libexec/t7-restic-reminder /usr/local/libexec/t7-udev-verify \
    /etc/udev/rules.d/90-t7-name.rules \
    /etc/udev/rules.d/90-t7-veeamre.rules
systemctl daemon-reload
udevadm control --reload-rules
printf 'activity=%s INFO automation removed; repository, canonical credential, config, cache, and state preserved\n' "$ACTIVITY_ID"
printf 'Manual destructive cleanup, only if intended: /mnt/T7_BACKUP/restic-fedora /home/daniele/.config/codex/secrets/fedora_t7_backup.restic_password /etc/t7-restic-backup /var/lib/t7-restic-backup /var/cache/t7-restic-backup\n'
