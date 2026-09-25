"""Run with python3 -m unittest discover -s tests -v.

Requires Nix, Bash, coreutils, fd, tree and file; no Wayland session needed.
"""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class CopyContextTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        repo = Path(__file__).resolve().parents[1]
        # Evaluate the actual Nix string without fetching/building flake inputs.
        expression = """
          let pkgs = {
            writeShellApplication = x: x;
            coreutils = null; tree = null; fd = null;
            file = null; wl-clipboard = null;
          }; in (builtins.head (import ./modules/scripts/copy-context.nix {
            inherit pkgs;
          }).environment.systemPackages).text
        """
        cls.script = json.loads(subprocess.check_output(
            ["nix-instantiate", "--eval", "--strict", "--json", "--expr", expression],
            cwd=repo, text=True,
        ))

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "-project with spaces"
        self.project.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.scratch = self.root / "scratch"
        self.scratch.mkdir()
        self.clipboard = self.root / "clipboard"
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        TMPDIR=str(self.scratch), CLIPBOARD=str(self.clipboard))
        self.stub("wl-copy", 'cat > "$CLIPBOARD"')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\n" + body + "\n")
        path.chmod(0o755)

    def run_export(self, target=None):
        result = subprocess.run(
            ["bash", "-euo", "pipefail", "-c", self.script, "copy-context",
             target if target is not None else self.project.name],
            cwd=self.root, env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(list(self.scratch.iterdir()), [], result.stderr)
        return result

    def test_unusual_names_and_exclusions(self):
        for name in ["normal.txt", "line\nbreak.txt", "-leading.txt"]:
            (self.project / name).write_text(f"content of {name}\n")
        (self.project / "binary.dat").write_bytes(b"\x00\x01\x02")
        excluded = self.project / "node_modules"
        excluded.mkdir()
        (excluded / "ignored.txt").write_text("excluded content")
        result = self.run_export()
        self.assertEqual(result.returncode, 0, result.stderr)
        output = self.clipboard.read_text()
        for name in ["normal.txt", "line\nbreak.txt", "-leading.txt"]:
            self.assertIn(f"content of {name}", output)
        self.assertNotIn("excluded content", output)
        self.assertNotIn("\x00", output)
        self.assertIn("3 fichiers", result.stdout)

    def test_clipboard_failure_cleans_temporary_export(self):
        self.stub("wl-copy", "exit 7")
        result = self.run_export()
        self.assertEqual(result.returncode, 7)
        self.assertNotIn("Succès", result.stdout)

    def test_discovery_failure_does_not_copy_partial_export(self):
        self.stub("fd", "exit 9")
        result = self.run_export()
        self.assertEqual(result.returncode, 9)
        self.assertFalse(self.clipboard.exists())

    def test_invalid_target_does_not_touch_clipboard(self):
        ordinary_file = self.root / "file.txt"
        ordinary_file.write_text("text")
        for target in [str(ordinary_file), str(self.root / "missing")]:
            with self.subTest(target=target):
                self.assertNotEqual(self.run_export(target).returncode, 0)
                self.assertFalse(self.clipboard.exists())


if __name__ == "__main__":
    unittest.main()
