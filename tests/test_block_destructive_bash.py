import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


HOOK = Path(__file__).resolve().parents[1] / "hooks" / "block_destructive_bash.py"


def run_hook(command):
    payload = {
        "tool_name": "Bash",
        "tool_input": {"command": command},
        "cwd": "/tmp/example-project",
    }
    env = os.environ.copy()
    with tempfile.TemporaryDirectory(prefix="claude-hook-test-") as temp_home:
        env["CLAUDE_BLOCK_LOG"] = str(Path(temp_home) / "blocked.log")
        return subprocess.run(
            [sys.executable, str(HOOK)],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            check=False,
            env=env,
        )


class BlockDestructiveBashTest(unittest.TestCase):
    def assert_blocked(self, command):
        result = run_hook(command)
        self.assertEqual(result.returncode, 0)
        output = json.loads(result.stdout)
        decision = output["hookSpecificOutput"]
        self.assertEqual(decision["hookEventName"], "PreToolUse")
        self.assertEqual(decision["permissionDecision"], "deny")
        self.assertTrue(decision["permissionDecisionReason"])

    def test_blocks_destructive_patterns(self):
        blocked = [
            "rm -rf dist",
            "psql -c 'DROP TABLE users'",
            "git push --force origin main",
            "mysql -e 'TRUNCATE sessions'",
            "psql -c 'DELETE FROM users'",
        ]
        for command in blocked:
            with self.subTest(command=command):
                self.assert_blocked(command)

    def test_allows_normal_bash_commands(self):
        allowed = [
            "npm test",
            "git status --short",
            "rm dist/app.js",
            "psql -c 'DELETE FROM users WHERE id = 1'",
        ]
        for command in allowed:
            with self.subTest(command=command):
                result = run_hook(command)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
