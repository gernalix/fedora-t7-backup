#!/usr/bin/bash
set -Eeuo pipefail
umask 077

readonly ACTIVITY_ID=684219
readonly RESTIC_PASSWORD_FILE=/home/daniele/.config/codex/secrets/fedora_t7_backup.restic_password
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

command -v restic >/dev/null || { printf 'activity=%s ERROR restic is not installed\n' "$ACTIVITY_ID" >&2; exit 1; }
[[ -s $RESTIC_PASSWORD_FILE ]] || {
    printf 'activity=%s ERROR canonical Restic password file is missing or empty: %s\n' \
        "$ACTIVITY_ID" "$RESTIC_PASSWORD_FILE" >&2
    exit 1
}
[[ $(stat -c '%U:%G' "$RESTIC_PASSWORD_FILE") == daniele:daniele ]] || {
    printf 'activity=%s ERROR canonical Restic password owner must be daniele:daniele\n' "$ACTIVITY_ID" >&2
    exit 1
}
[[ $(stat -c '%a' "$RESTIC_PASSWORD_FILE") == 600 ]] || {
    printf 'activity=%s ERROR canonical Restic password mode must be 600\n' "$ACTIVITY_ID" >&2
    exit 1
}

install -d -m 0755 /usr/local/libexec /usr/share/doc/fedora-t7-backup
install -d -m 0755 /etc/udev/rules.d
install -d -m 0750 /etc/t7-restic-backup
install -d -m 0700 /var/lib/t7-restic-backup /var/cache/t7-restic-backup
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP=/var/lib/t7-restic-backup/install-backups/activity-684219-$STAMP
install -d -m 0700 "$BACKUP"
for old in /usr/local/libexec/t7-restic-backup /etc/systemd/system/t7-restic-*.service \
    /etc/systemd/system/t7-restic-*.timer /etc/udev/rules.d/90-t7-name.rules; do
    [[ -f $old ]] && cp -a -- "$old" "$BACKUP/$(basename "$old")"
done
install -m 0755 "$ROOT/scripts/t7-restic-backup" "$ROOT/scripts/t7-restic-lifecycle" \
    "$ROOT/scripts/t7-restic-metrics" "$ROOT/scripts/t7-restic-notify" \
    "$ROOT/scripts/t7-restic-reminder" /usr/local/libexec/
install -m 0644 "$ROOT/config/excludes.txt" /etc/t7-restic-backup/excludes.txt
install -m 0644 "$ROOT/docs/human/OPERATIONS.md" /usr/share/doc/fedora-t7-backup/OPERATIONS.md
systemctl disable --now t7-restic-backup.timer t7-restic-check.timer t7-restic-maintenance.timer 2>/dev/null || true
rm -f /etc/systemd/system/t7-restic-backup.timer /etc/systemd/system/t7-restic-check.service \
    /etc/systemd/system/t7-restic-check.timer /etc/systemd/system/t7-restic-maintenance.service \
    /etc/systemd/system/t7-restic-maintenance.timer
install -m 0644 "$ROOT/systemd/"*.service "$ROOT/systemd/"*.timer /etc/systemd/system/
rm -f /etc/udev/rules.d/90-t7-veeamre.rules
install -m 0644 "$ROOT/udev/90-t7-name.rules" /etc/udev/rules.d/90-t7-name.rules

restorecon -RF /usr/local/libexec/t7-restic-* /etc/t7-restic-backup \
    "$RESTIC_PASSWORD_FILE" /var/lib/t7-restic-backup \
    /var/cache/t7-restic-backup /etc/systemd/system/t7-restic-* \
    /usr/share/doc/fedora-t7-backup 2>/dev/null || true
systemctl daemon-reload
udevadm control --reload-rules
if [[ -e /dev/disk/by-id/usb-Samsung_PSSD_T7_Shield_S6YGNS0Y903440H-0:0-part1 ]]; then
    t7_device=$(readlink -e /dev/disk/by-id/usb-Samsung_PSSD_T7_Shield_S6YGNS0Y903440H-0:0-part1)
    udevadm trigger --action=change --name-match="$t7_device" --settle
fi
systemd-analyze verify /etc/systemd/system/t7-restic-*.service /etc/systemd/system/t7-restic-*.timer
if [[ ! -f /var/lib/t7-restic-backup/maintenance.state ]]; then
    now=$(date +%s)
    printf 'last_prune=%s\nlast_light=%s\nlast_full=%s\n' "$now" "$now" "$now" \
        >/var/lib/t7-restic-backup/maintenance.state
    chmod 0600 /var/lib/t7-restic-backup/maintenance.state
fi
printf 'activity=%s INFO installed; udev trigger active; daily/weekly/monthly timers disabled\n' "$ACTIVITY_ID"
