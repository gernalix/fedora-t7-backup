#!/usr/bin/bash
set -Eeuo pipefail

readonly ACTIVITY_ID=684219
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
INSERT INTO incidents (
  incident_id,first_seen_utc,last_seen_utc,occurrence_count,severity,status,
  root_cause,resolution_summary,title,systems,alerts,prompt_ids,commit_refs,source_ref
) VALUES (
  'T7_LIFECYCLE_MOUNT_NAMESPACE','2026-07-11T23:51:57Z','2026-07-11T23:56:28Z',3,
  'HIGH','RESOLVED',
  'Filesystem hardening namespace hid mounts created after service start; RequiresMountsFor stopped the requiring service during final unmount',
  'Use global systemd mount lifecycle without filesystem namespace options while retaining locks,timeouts,NoNewPrivileges,capability bounds and process restrictions',
  'T7 lifecycle mount namespace blocked finalization',
  'Fedora host; systemd; udev; Samsung T7; fedora-t7-backup',
  'Telegram error notifications; journal failure','684219','activity 684219',
  '/home/daniele/MegaVault/projects/fedora-t7-backup/docs/ai/INCIDENT_REGISTRY.md'
)
ON CONFLICT(incident_id) DO UPDATE SET
  last_seen_utc=excluded.last_seen_utc,occurrence_count=excluded.occurrence_count,
  severity=excluded.severity,status=excluded.status,root_cause=excluded.root_cause,
  resolution_summary=excluded.resolution_summary,title=excluded.title,systems=excluded.systems,
  alerts=excluded.alerts,prompt_ids=excluded.prompt_ids,commit_refs=excluded.commit_refs,source_ref=excluded.source_ref;
INSERT OR IGNORE INTO incident_events (
  incident_id,timestamp_utc,severity,status,source,alert_code,symptom,detail,payload_json
) VALUES (
  'T7_LIFECYCLE_MOUNT_NAMESPACE','2026-07-11T23:56:28Z','HIGH','RESOLVED',
  'fedora-t7-backup','MOUNT_NAMESPACE','Mount lifecycle could not both see and stop the global mount',
  'Real udev replay created snapshot f7682be7 then synced,unmounted,notified and exited success',
  '{"activity_id":"684219","result":"PASS"}'
);
COMMIT;
SQL

result=$(sqlite3 -readonly "$DB" 'PRAGMA integrity_check; PRAGMA foreign_key_check;')
[[ $result == ok ]] || { printf 'activity=%s incident_registry_integrity=FAIL\n' "$ACTIVITY_ID" >&2; exit 1; }
printf 'activity=%s incident_registry_upsert=PASS incidents=T7_MOUNTPOINT_FELL_THROUGH_TO_INTERNAL_ROOT,T7_LIFECYCLE_MOUNT_NAMESPACE\n' "$ACTIVITY_ID"
