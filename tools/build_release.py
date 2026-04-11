from __future__ import annotations

from pathlib import Path
import shutil
import tempfile
import zipfile


ADDON_ROOT = Path(__file__).resolve().parents[1]
ADDON_NAME = "RepSheet"
TOC_NAME = f"{ADDON_NAME}.toc"
LOCAL_DEV_PATH = Path("Core/LocalDev.lua")
OUTPUT_DIR = ADDON_ROOT.parents[1]
SOURCE_ICON_PATTERN = "Media/Icons/*.png"
IGNORE_NAMES = {
    ".git",
    ".gitignore",
    "CURSEFORGE_SUBMISSION.md",
    "__pycache__",
    "tools",
    "build",
    "dist",
    "release",
}


def read_version() -> str:
    toc_path = ADDON_ROOT / TOC_NAME
    for line in toc_path.read_text().splitlines():
        prefix = "## Version:"
        if line.startswith(prefix):
            return line.split(":", 1)[1].strip()
    raise RuntimeError(f"Unable to find version in {toc_path}")


def ignore_filter(_directory: str, names: list[str]) -> set[str]:
    ignored = set()
    for name in names:
        if name in IGNORE_NAMES:
            ignored.add(name)
        elif name.endswith(".pyc") or name.endswith(".pyo") or name.endswith(".zip"):
            ignored.add(name)
    return ignored


def strip_local_dev_file(staging_root: Path) -> None:
    toc_path = staging_root / TOC_NAME
    local_dev_path = staging_root / LOCAL_DEV_PATH

    if local_dev_path.exists():
        local_dev_path.unlink()

    lines = toc_path.read_text().splitlines()
    filtered_lines = [line for line in lines if line.strip() != str(LOCAL_DEV_PATH).replace("\\", "/")]
    toc_path.write_text("\n".join(filtered_lines) + "\n")


def strip_source_icon_pngs(staging_root: Path) -> None:
    for path in staging_root.glob(SOURCE_ICON_PATTERN):
        path.unlink()


def build_release_zip() -> Path:
    version = read_version()
    output_path = OUTPUT_DIR / f"{ADDON_NAME}-{version}.zip"

    with tempfile.TemporaryDirectory() as temp_dir:
        staging_parent = Path(temp_dir)
        staging_root = staging_parent / ADDON_NAME
        shutil.copytree(ADDON_ROOT, staging_root, ignore=ignore_filter)
        strip_local_dev_file(staging_root)
        strip_source_icon_pngs(staging_root)

        with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(staging_root.rglob("*")):
                archive.write(path, path.relative_to(staging_parent))

    return output_path


def main() -> None:
    output_path = build_release_zip()
    print(output_path)


if __name__ == "__main__":
    main()
