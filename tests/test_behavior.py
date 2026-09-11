#!/usr/bin/python3
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NOTIFY = ROOT / "scripts" / "t7-restic-notify"
UDEV_VERIFY = ROOT / "scripts" / "t7-udev-verify"


class NotifyBehaviorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.state = self.base / "state"
        self.calls = self.base / "calls.jsonl"
        self.env_file = self.base / "telegram.env"
        package = self.base / "telegram_notify"
        package.mkdir()
        (package / "__init__.py").write_text(
            """
import json
import os

def send_message(title, message, *, chat_id=None, project_id=None):
    with open(os.environ["T7_FAKE_TELEGRAM_CALLS"], "a", encoding="utf-8") as handle:
        handle.write(json.dumps({
            "title": title,
            "message": message,
            "chat_id": chat_id,
            "project_id": project_id,
            "token": os.environ.get("TELEGRAM_BOT_TOKEN", ""),
        }, sort_keys=True) + "\\n")
    if os.environ.get("T7_FAKE_TELEGRAM_MODE") == "fail":
        raise RuntimeError(f"HTTP 500 token={os.environ.get('TELEGRAM_BOT_TOKEN')} chat={chat_id}")
""",
            encoding="utf-8",
        )

    def tearDown(self):
        self.tmp.cleanup()

    def write_env(self, body=None):
        self.env_file.write_text(
            body
            or """
TELEGRAM_BOT_TOKEN=generic-token
TELEGRAM_CHAT_ID=-1000000000000
export TELEGRAM_INSERT_BOT_NOISY_BOT_TOKEN = "noisy token"
TELEGRAM_INSERT_BOT_NOISY_CHAT_ID='12345678'
EXTRA_VALUE = "with spaces"
""",
            encoding="utf-8",
        )

    def result_file(self, body=None):
        path = self.base / "result.json"
        if body is None:
            body = {
                "snapshot_id": "abcdef123456",
                "duration_seconds": 12.4,
                "data_added_packed": 42,
            }
        if isinstance(body, str):
            path.write_text(body, encoding="utf-8")
        else:
            path.write_text(json.dumps(body), encoding="utf-8")
        return path

    def run_notify(self, *args, mode=None):
        env = os.environ.copy()
        env.update(
            {
                "PYTHONPATH": str(self.base),
                "T7_FAKE_TELEGRAM_CALLS": str(self.calls),
                "T7_NOTIFICATION_STATE": str(self.state),
                "TELEGRAM_NOTIFY_CONFIG": str(self.env_file),
                "T7_NOTIFY_BACKOFF_SECONDS": "0,0,0",
                "T7_NOTIFY_MAX_ATTEMPTS": "3",
            }
        )
        if mode:
            env["T7_FAKE_TELEGRAM_MODE"] = mode
        return subprocess.run(
            [sys.executable, str(NOTIFY), *args],
            cwd=ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def calls_json(self):
        if not self.calls.exists():
            return []
        return [json.loads(line) for line in self.calls.read_text(encoding="utf-8").splitlines()]

    def test_selects_noisy_token_and_chat_id_from_safe_env_parser(self):
        self.write_env()
        result = self.run_notify("success", "JOB1", "--result-file", str(self.result_file()), "--test")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        calls = self.calls_json()
        self.assertEqual(1, len(calls))
        self.assertEqual("12345678", calls[0]["chat_id"])
        self.assertEqual("noisy token", calls[0]["token"])
        self.assertEqual(16, calls[0]["project_id"])

    def test_success_uses_human_units_and_t7_unavailable_is_distinct(self):
        self.write_env()
        success = self.run_notify("success", "JOB10", "--result-file", str(self.result_file({"snapshot_id": "abcdef123456", "duration_seconds": 12.4, "data_added_packed": 2 * 1024 * 1024})))
        absent = self.run_notify("error", "JOB11", "--phase", "identity", "--exit-code", "20", "--mounted", "no")
        failure = self.run_notify("error", "JOB12", "--phase", "backup", "--exit-code", "97", "--mounted", "yes")
        self.assertEqual([0, 0, 0], [success.returncode, absent.returncode, failure.returncode])
        calls = self.calls_json()
        self.assertIn("2.00 MiB", calls[0]["message"])
        self.assertEqual("Backup T7 non eseguito", calls[1]["title"])
        self.assertIn("Azione richiesta: collega", calls[1]["message"])
        self.assertEqual("Backup T7 fallito", calls[2]["title"])
        self.assertIn("fallito durante l'esecuzione", calls[2]["message"])

    def test_missing_noisy_variables_fails_without_sending(self):
        self.write_env("TELEGRAM_BOT_TOKEN=generic\nTELEGRAM_CHAT_ID=123\n")
        result = self.run_notify("error", "JOB2", "--phase", "backup")
        self.assertEqual(result.returncode, 75)
        self.assertEqual([], self.calls_json())
        self.assertIn("missing Telegram T7 configuration", result.stdout)

    def test_ambiguous_env_line_is_rejected(self):
        self.write_env("TELEGRAM_INSERT_BOT_NOISY_BOT_TOKEN=abc\nnot a valid line\nTELEGRAM_INSERT_BOT_NOISY_CHAT_ID=123\n")
        result = self.run_notify("error", "JOB3", "--phase", "backup")
        self.assertEqual(result.returncode, 75)
        self.assertEqual([], self.calls_json())
        self.assertIn("ambiguous telegram.env line", result.stdout)

    def test_http_failure_queues_redacted_retry_then_flush_sends_and_deduplicates(self):
        self.write_env("TELEGRAM_INSERT_BOT_NOISY_BOT_TOKEN=secret-token\nTELEGRAM_INSERT_BOT_NOISY_CHAT_ID=87654321\n")
        first = self.run_notify("success", "JOB4", "--result-file", str(self.result_file()), mode="fail")
        self.assertEqual(first.returncode, 75)
        self.assertIn("queued=yes", first.stdout)
        self.assertNotIn("secret-token", first.stdout)
        self.assertNotIn("87654321", first.stdout)
        self.assertTrue((self.state / "queue" / "JOB4-success.json").exists())
        self.assertFalse((self.state / "JOB4-success.sent").exists())

        flush = self.run_notify("flush-queue")
        self.assertEqual(flush.returncode, 0, flush.stdout + flush.stderr)
        self.assertTrue((self.state / "JOB4-success.sent").exists())
        self.assertFalse((self.state / "queue" / "JOB4-success.json").exists())
        self.assertEqual(2, len(self.calls_json()))

        duplicate = self.run_notify("success", "JOB4", "--result-file", str(self.result_file()))
        self.assertEqual(duplicate.returncode, 0)
        self.assertIn("duplicate=ignored", duplicate.stdout)
        self.assertEqual(2, len(self.calls_json()))

    def test_success_notification_failure_after_backup_result_is_not_marked_sent(self):
        self.write_env()
        result = self.run_notify("success", "JOB5", "--result-file", str(self.result_file()), mode="fail")
        self.assertEqual(result.returncode, 75)
        self.assertFalse((self.state / "JOB5-success.sent").exists())
        self.assertTrue((self.state / "queue" / "JOB5-success.json").exists())

    def test_result_json_missing_incomplete_or_invalid_fails_before_send(self):
        self.write_env()
        missing = self.run_notify("success", "JOB6", "--result-file", str(self.base / "missing.json"))
        invalid = self.run_notify("success", "JOB7", "--result-file", str(self.result_file("{bad json")))
        incomplete = self.run_notify("success", "JOB8", "--result-file", str(self.result_file({"snapshot_id": "abc"})))
        self.assertEqual([65, 65, 65], [missing.returncode, invalid.returncode, incomplete.returncode])
        self.assertEqual([], self.calls_json())

    def test_events_log_rotates(self):
        self.write_env()
        self.state.mkdir(parents=True)
        events = self.state / "events.log"
        events.write_text("x" * (300 * 1024), encoding="utf-8")
        result = self.run_notify("error", "JOB9", "--phase", "backup")
        self.assertEqual(result.returncode, 0)
        self.assertTrue((self.state / "events.log.1").exists())
        self.assertLess((self.state / "events.log").stat().st_size, 10000)


class UdevBehaviorTests(unittest.TestCase):
    def test_udev_add_output_requires_t7_systemd_wants(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "udev.txt"
            output.write_text(
                "DEVTYPE=disk\nSYSTEMD_WANTS=fedora-system-monitor-device-add@sdb.service t7-restic-backup.service\n",
                encoding="utf-8",
            )
            env = os.environ.copy()
            env["T7_UDEV_TEST_OUTPUT"] = str(output)
            result = subprocess.run(
                [str(UDEV_VERIFY)],
                cwd=ROOT,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("trigger_executed=no", result.stdout)


if __name__ == "__main__":
    unittest.main()
