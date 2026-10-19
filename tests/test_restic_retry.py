"""Exercise the installed shell error-trap boundary without disks or credentials."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "t7-restic-backup"


class ResticRetryTests(unittest.TestCase):
    def invoke(self, *, json_output=False, failures="11 0", unlock_status=0):
        # Load definitions only; never enter identity checks or live dispatch.
        definitions = SCRIPT.read_text().split("\nrequire_root\nACTION=", 1)[0]
        self.assertNotIn("case \"$ACTION\"", definitions)
        with tempfile.TemporaryDirectory() as folder:
            env = os.environ.copy()
            env.update(TEST_ROOT=folder, FAILURES=failures, UNLOCK_STATUS=str(unlock_status))
            fake = r'''
ACTION=check-light
read -ra results <<< "$FAILURES"
attempt=0
restic() {
    printf '%s\n' "$*" >> "$TEST_ROOT/calls"
    if [[ $1 == unlock ]]; then
        return "$UNLOCK_STATUS"
    fi
    local status=${results[$attempt]:-0}
    attempt=$((attempt + 1))
    [[ $status != 0 ]] || printf '{"ok":true}\n'
    return "$status"
}
'''
            call = ('run_restic_json "$TEST_ROOT/output" check --read-data-subset=5%'
                    if json_output else 'run_restic check --read-data-subset=5%')
            result = subprocess.run(
                ["bash"], input=definitions + fake + "\n" + call + "\nprintf 'FINISHED\\n'\n",
                text=True, capture_output=True, env=env, timeout=10,
            )
            calls = (Path(folder) / "calls").read_text().splitlines()
            output = Path(folder) / "output"
            return result, calls, output.read_text() if output.exists() else None

    def test_stale_lock_is_unlocked_once_despite_inherited_err_trap(self):
        for json_output in (False, True):
            with self.subTest(json_output=json_output):
                result, calls, output = self.invoke(json_output=json_output)
                self.assertEqual(0, result.returncode, result.stdout + result.stderr)
                self.assertEqual(["check --read-data-subset=5%", "unlock", "check --read-data-subset=5%"], calls)
                self.assertIn("FINISHED", result.stdout)
                if json_output:
                    self.assertEqual('{"ok":true}\n', output)

    def test_other_errors_do_not_unlock_or_continue(self):
        for json_output in (False, True):
            with self.subTest(json_output=json_output):
                result, calls, _ = self.invoke(json_output=json_output, failures="1")
                self.assertEqual(1, result.returncode)
                self.assertEqual(["check --read-data-subset=5%"], calls)
                self.assertNotIn("FINISHED", result.stdout)

    def test_lock_still_present_after_unlock_fails_closed(self):
        for json_output in (False, True):
            with self.subTest(json_output=json_output):
                result, calls, _ = self.invoke(json_output=json_output, failures="11 11")
                self.assertEqual(11, result.returncode)
                self.assertEqual(["check --read-data-subset=5%", "unlock", "check --read-data-subset=5%"], calls)
                self.assertNotIn("FINISHED", result.stdout)

    def test_unlock_failure_never_retries_the_operation(self):
        result, calls, _ = self.invoke(unlock_status=1)
        self.assertEqual(1, result.returncode)
        self.assertEqual(["check --read-data-subset=5%", "unlock"], calls)
        self.assertNotIn("FINISHED", result.stdout)


if __name__ == "__main__":
    unittest.main()
