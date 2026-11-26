"""Test release versions, payload selection and reproducible packaging."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location("package", Path(__file__).resolve().parents[1] / "scripts/package.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.addon = self.root / "LootGoblin"
        self.addon.mkdir()
        self.toc = self.addon / "LootGoblin.toc"
        self.original = "## Interface: 16001\n## Version: 0.3.1-alpha\nCore.lua\n"
        self.toc.write_text(self.original)
        (self.addon / "Core.lua").write_text("-- code\n")
        (self.addon / "README.txt").write_text("Usage\n")
        (self.addon / "development.lua").write_text("-- must not ship\n")
        (self.root / "LICENSE").write_text("License fixture\n")
        for key, value in [("ROOT", self.root), ("ADDON", self.addon), ("TOC", self.toc)]:
            patcher = patch.object(package, key, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_tag_version_only_changes_packaged_toc(self):
        path = package.build("1.0.0-beta.2")
        with zipfile.ZipFile(path) as archive:
            self.assertIn(b"## Version: 1.0.0-beta.2", archive.read("LootGoblin/LootGoblin.toc"))
            self.assertEqual(archive.read("LootGoblin/LICENSE"), b"License fixture\n")
            self.assertNotIn("LootGoblin/development.lua", archive.namelist())
        self.assertEqual(self.toc.read_text(), self.original)

    def test_identical_inputs_produce_identical_archives(self):
        first = package.build("1.0.0").read_bytes()
        second = package.build("1.0.0").read_bytes()
        self.assertEqual(first, second)

    def test_unsafe_version_is_rejected(self):
        with self.assertRaises(ValueError):
            package.build("../other")

    def test_toc_cannot_escape_addon_folder(self):
        self.toc.write_text(self.original + "../LICENSE\n")
        with self.assertRaises(ValueError):
            package.build("1.0.0")
