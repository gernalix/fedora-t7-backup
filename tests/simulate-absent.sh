#!/usr/bin/bash
set -u

readonly ACTIVITY_ID=684219
readonly MOUNT_POINT=/mnt/T7_BACKUP

umount "$MOUNT_POINT" || exit 90
before=$(find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 -printf . | wc -c)
printf 'activity=%s simulation=absent internal_entries_before=%s\n' "$ACTIVITY_ID" "$before"
[[ $before -eq 0 ]] || exit 91

set +e
/usr/local/libexec/t7-restic-backup backup
job_rc=$?
set -e

after=$(find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 -printf . | wc -c)
printf 'activity=%s simulation=absent job_exit=%s internal_entries_after=%s\n' \
    "$ACTIVITY_ID" "$job_rc" "$after"
if [[ $job_rc -eq 21 && $after -eq 0 && ! -e $MOUNT_POINT/restic-fedora ]]; then
    printf 'activity=%s simulation_result=PASS expected_failure=yes\n' "$ACTIVITY_ID"
    exit 21
fi
printf 'activity=%s simulation_result=FAIL\n' "$ACTIVITY_ID" >&2
exit 92
