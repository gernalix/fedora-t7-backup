#!/usr/bin/bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

bash -n "$ROOT/scripts/t7-restic-backup" "$ROOT/scripts/install.sh" "$ROOT/scripts/uninstall.sh" \
    "$ROOT/scripts/register-incident.sh" "$ROOT/tests/simulate-absent.sh"
verify_output=$(systemd-analyze verify "$ROOT/systemd/"*.service "$ROOT/systemd/"*.timer 2>&1 || true)
unexpected=$(sed '/Command \/usr\/local\/libexec\/t7-restic-backup is not executable: No such file or directory/d' <<<"$verify_output")
[[ -z $unexpected ]] || { printf '%s\n' "$unexpected" >&2; exit 1; }
if rg -n -i '(^|[^A-Z_])password\s*=\s*\S+|(^|[^A-Z_])token\s*=\s*\S+|gho_[A-Za-z0-9]+|github_pat_[A-Za-z0-9_]+' "$ROOT" \
    --glob '!tests/static.sh' --glob '!docs/human/OPERATIONS.md'; then
    printf 'activity=583921 secret_scan=FAIL\n' >&2
    exit 1
fi
rg -q 'ACTIVITY_ID=583921' "$ROOT/scripts/t7-restic-backup"
rg -q 'S6YGNS0Y903440H' "$ROOT/scripts/t7-restic-backup"
rg -q '4c75ac03-4c73-43f8-afd9-f90db49a74fc' "$ROOT/scripts/t7-restic-backup"
printf 'activity=583921 static_tests=PASS\n'
