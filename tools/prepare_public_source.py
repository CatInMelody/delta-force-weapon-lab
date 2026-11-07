"""Create a fresh, audited source tree using an explicit publication allowlist."""
from pathlib import Path
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".build" / "public-source"


def audit(paths):
    # Compare locally without logging any secret value or copying private files.
    secrets = []
    private_key = ROOT / ".private" / "pck-encryption.gdkey"
    if private_key.exists():
        key = private_key.read_text().strip()
        if len(key) == 64:
            secrets.extend([key.encode(), bytes.fromhex(key)])
    token = re.compile(rb"(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)")
    for path in paths:
        raw = path.read_bytes()
        if any(secret in raw for secret in secrets) or token.search(raw):
            raise RuntimeError("Secret detected in candidate publication file; upload stopped")


def prepare():
    if OUT.exists():
        raise RuntimeError("Publication tree already exists; inspect before replacing")
    (ROOT / ".build").mkdir(exist_ok=True)
    (ROOT / ".build" / ".gdignore").write_text("", encoding="utf-8")
    sources = []
    for folder, suffixes in {
        "Code": {".gd", ".uid"}, "Scene": {".tscn"},
        "assets": {".png", ".webp", ".jpg", ".jpeg", ".svg", ".ttf", ".otf", ".json", ".import", ".gdshader", ".uid", ".tres", ".md"},
        "licenses": {".txt"}, "tests": {".gd", ".uid"},
    }.items():
        for path in (ROOT / folder).rglob("*"):
            if path.is_file() and path.suffix.lower() in suffixes and "update_http_fixture" not in path.parts:
                sources.append(path)
    sources.extend((ROOT / "data").glob("*.json"))
    sources.extend((ROOT / "data").glob("*.md"))
    for relative in [".editorconfig", ".gitattributes", ".gitignore", "README.md", "发布数据更新.md", "package.json", "package-lock.json", "project.godot", "export_presets.cfg", "非洲之心.png", "非洲之心.png.import", "feature_profiles/tool-release.gdbuild", "feature_profiles/精简构建说明.md", "tools/build_release.ps1", "tools/export_data_update.gd", "tools/export_data_update.gd.uid", "tools/prepare_public_source.py", "tools/audit_release.py", "tools/build_cloudflare.mjs", "publish/data-version.json", "publish/data-2.json", "publish/_headers", "publish/index.html"]:
        sources.append(ROOT / relative)
    manifest = json.loads((ROOT / "publish/data-version.json").read_text(encoding="utf-8-sig"))
    if not re.fullmatch(r"data-\d+\.json", manifest["package_url"]):
        raise RuntimeError("Invalid data snapshot filename")
    sources.append(ROOT / "publish" / manifest["package_url"])
    sources = sorted(set(sources))
    audit(sources)
    for source in sources:
        destination = OUT / source.relative_to(ROOT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    manifest = {str(p.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    (ROOT / ".build" / "public-source-manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"PUBLIC_SOURCE_AUDIT: PASS; {len(sources)} files; {sum(p.stat().st_size for p in sources)/1048576:.2f} MiB")


if __name__ == "__main__":
    prepare()
