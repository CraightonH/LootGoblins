"""Build a reproducible addon-only ZIP using Python's standard library."""
from pathlib import Path
import hashlib
import os
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "LootGoblin"
TOC = ADDON / "LootGoblin.toc"


def build(version=None):
    toc = TOC.read_text(encoding="utf-8")
    match = re.search(r"^## Version:\s*([\w.-]+)\s*$", toc, re.MULTILINE)
    if not match:
        raise ValueError("LootGoblin.toc needs a package-safe version")
    version = version or os.environ.get("ADDON_RELEASE_VERSION") or match.group(1)
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*)?", version):
        raise ValueError("Invalid package version")
    paths = {TOC, ADDON / "README.txt"}
    for line in toc.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            path = (ADDON / line).resolve()
            path.relative_to(ADDON.resolve())
            if not path.is_file():
                raise FileNotFoundError(f"Missing TOC dependency: {line}")
            paths.add(path)
    destination = ROOT / "dist" / f"LootGoblin-{version}.zip"
    destination.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        payload = {"LootGoblin/" + path.relative_to(ADDON).as_posix(): path.read_bytes() for path in paths}
        # Set the release version only in the ZIP; keep the working tree intact.
        packaged_toc = toc[:match.start(1)] + version + toc[match.end(1):]
        payload["LootGoblin/LootGoblin.toc"] = packaged_toc.encode("utf-8")
        payload["LootGoblin/LICENSE"] = (ROOT / "LICENSE").read_bytes()
        for member, contents in sorted(payload.items()):
            info = zipfile.ZipInfo(member, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, contents)
    with zipfile.ZipFile(destination) as archive:
        assert archive.testzip() is None
        assert "LootGoblin/LootGoblin.toc" in archive.namelist()
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    print(f"Built {destination.relative_to(ROOT)} ({destination.stat().st_size} bytes)")
    print(f"SHA-256: {digest}")
    return destination


if __name__ == "__main__":
    build()
