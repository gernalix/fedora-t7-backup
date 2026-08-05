#!/usr/bin/bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

bash -n "$ROOT/scripts/t7-restic-backup" "$ROOT/scripts/t7-restic-lifecycle" \
    "$ROOT/scripts/t7-restic-reminder" "$ROOT/scripts/install.sh" "$ROOT/scripts/uninstall.sh" \
    "$ROOT/scripts/register-incident.sh" "$ROOT/scripts/t7-udev-verify" "$ROOT/tests/simulate-absent.sh"
PYTHONPYCACHEPREFIX=/tmp/activity-684219-pycache python3 -m py_compile \
    "$ROOT/scripts/t7-restic-metrics" "$ROOT/scripts/t7-restic-notify" "$ROOT/tests/test_behavior.py"
verify_output=$(systemd-analyze verify "$ROOT/systemd/"*.service "$ROOT/systemd/"*.timer 2>&1 || true)
unexpected=$(sed '/Command \/usr\/local\/libexec\/t7-restic-.* is not executable: No such file or directory/d' <<<"$verify_output")
[[ -z $unexpected ]] || { printf '%s\n' "$unexpected" >&2; exit 1; }
if rg -n -i '(^|[^A-Z_])password\s*=\s*\S+|(^|[^A-Z_])token\s*=\s*\S+|gho_[A-Za-z0-9]+|github_pat_[A-Za-z0-9_]+' "$ROOT" \
    --glob '!tests/static.sh' --glob '!tests/test_behavior.py' --glob '!docs/human/OPERATIONS.md'; then
    printf 'activity=684219 secret_scan=FAIL\n' >&2
    exit 1
fi
rg -q 'ACTIVITY_ID=684219' "$ROOT/scripts/t7-restic-backup"
rg -q 'S6YGNS0Y903440H' "$ROOT/scripts/t7-restic-backup"
rg -q '4c75ac03-4c73-43f8-afd9-f90db49a74fc' "$ROOT/scripts/t7-restic-backup"
rg -q 'TEST CONTROLLATO' "$ROOT/scripts/t7-restic-notify"
rg -q 'T7_TEST_FAIL_PHASE' "$ROOT/scripts/t7-restic-lifecycle"
rg -Fq 'LoadCredential=restic-password:/home/daniele/.config/codex/secrets/fedora_t7_backup.restic_password' \
    "$ROOT/systemd/t7-restic-backup.service"
! rg -q 'openssl rand|LoadCredentialEncrypted=' "$ROOT/scripts/install.sh" \
    "$ROOT/systemd/t7-restic-backup.service"
! rg -Fq '/home/daniele/.config/telegram-notify/telegram-notify.env' \
    "$ROOT/scripts/t7-restic-lifecycle" "$ROOT/systemd/t7-restic-reminder.service"
rg -Fq '/home/daniele/.config/codex/secrets/telegram.env' \
    "$ROOT/scripts/t7-restic-lifecycle" "$ROOT/systemd/t7-restic-reminder.service"
rg -Fq 'TELEGRAM_INSERT_BOT_NOISY_BOT_TOKEN' "$ROOT/scripts/t7-restic-notify"
rg -Fq 'TELEGRAM_INSERT_BOT_NOISY_CHAT_ID' "$ROOT/scripts/t7-restic-notify"
rg -Fq 'telegram_send=failed' "$ROOT/scripts/t7-restic-notify"
rg -Fq 'notification_attempt=success' "$ROOT/scripts/t7-restic-lifecycle"
rg -Fq 'flush-queue' "$ROOT/scripts/t7-restic-notify" "$ROOT/systemd/t7-restic-notify-retry.service"
rg -Fq 'trigger_executed=no' "$ROOT/scripts/t7-udev-verify"
! rg -Fq 'udevadm trigger --action=change' "$ROOT/scripts/install.sh"
rg -Fq 'systemctl enable --now t7-restic-notify-retry.timer' "$ROOT/scripts/install.sh"
printf 'activity=684219 static_tests=PASS\n'
