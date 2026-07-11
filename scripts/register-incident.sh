#!/usr/bin/bash
set -Eeuo pipefail

readonly ACTIVITY_ID=583921
readonly DB=${INCIDENT_REGISTRY_DB:-/home/daniele/sync_root/db/incident_registry.sqlite}

[[ -f $DB ]] || { printf 'activity=%s incident_registry_missing=%s\n' "$ACTIVITY_ID" "$DB" >&2; exit 1; }

sqlite3 "$DB" <<'SQL'
PRAGMA foreign_keys=ON;
BEGIN IMMEDIATE;
INSERT INTO incidents (
  incident_id,first_seen_utc,last_seen_utc,occurrence_count,severity,status,
  root_cause,resolution_summary,title,systems,alerts,prompt_ids,commit_refs,source_ref
) VALUES (
  'T7_MOUNTPOINT_FELL_THROUGH_TO_INTERNAL_ROOT',
  '2026-07-11T23:09:00Z','2026-07-11T23:09:00Z',1,'CRITICAL','RESOLVED',
  'nofail fstab allowed boot without T7 and the persistent mount directory resolved to internal Btrfs',
  'Require separate mount,ext4,UUID,label,serial,model,parent disk and different device from root before repository access',
  'T7 mountpoint fell through to internal root',
  'Fedora host; Samsung T7; /mnt/T7_BACKUP; fedora-t7-backup',
  'journal nonzero backup job','583921','activity 583921',
  '/home/daniele/MegaVault/projects/fedora-t7-backup/docs/ai/INCIDENT_REGISTRY.md'
)
ON CONFLICT(incident_id) DO UPDATE SET
  last_seen_utc=excluded.last_seen_utc,
  severity=excluded.severity,
  status=excluded.status,
  root_cause=excluded.root_cause,
  resolution_summary=excluded.resolution_summary,
  title=excluded.title,
  systems=excluded.systems,
  alerts=excluded.alerts,
  prompt_ids=excluded.prompt_ids,
  commit_refs=excluded.commit_refs,
  source_ref=excluded.source_ref;
INSERT OR IGNORE INTO incident_events (
  incident_id,timestamp_utc,severity,status,source,alert_code,symptom,detail,payload_json
) VALUES (
  'T7_MOUNTPOINT_FELL_THROUGH_TO_INTERNAL_ROOT','2026-07-11T23:33:33Z',
  'CRITICAL','RESOLVED','fedora-t7-backup','MOUNT_GUARD',
  'Mountpoint without T7 would resolve to internal root',
  'Isolated absent simulation exited 21 with internal entries 0 to 0; subsequent backup succeeded',
  '{"activity_id":"583921","test":"absent_mount_namespace","result":"PASS"}'
);
COMMIT;
SQL

result=$(sqlite3 -readonly "$DB" 'PRAGMA integrity_check; PRAGMA foreign_key_check;')
[[ $result == ok ]] || { printf 'activity=%s incident_registry_integrity=FAIL\n' "$ACTIVITY_ID" >&2; exit 1; }
printf 'activity=%s incident_registry_upsert=PASS incident_id=T7_MOUNTPOINT_FELL_THROUGH_TO_INTERNAL_ROOT\n' "$ACTIVITY_ID"
