"""Check a plain embedded Godot PCK and the locally known private key exclusion."""
from pathlib import Path
import hashlib
import json
import struct
import sys


def audit(package):
    path = Path(package)
    data = path.read_bytes()
    assert data[-4:] == b"GDPC", "Embedded PCK missing"
    start = len(data) - 12 - struct.unpack_from("<Q", data, len(data) - 12)[0]
    magic, version, major, minor, patch, flags = struct.unpack_from("<6I", data, start)
    assert magic == 0x43504447 and version in (3, 4)
    assert not flags & 1, "PCK directory must not be encrypted"
    file_base, directory = struct.unpack_from("<2Q", data, start + 24)
    position = directory + start
    count = struct.unpack_from("<I", data, position)[0]
    position += 4
    names = []
    for _ in range(count):
        length = struct.unpack_from("<I", data, position)[0]
        position += 4
        name = data[position:position+length].rstrip(b"\0").decode()
        position += length
        offset, size = struct.unpack_from("<2Q", data, position)
        digest = data[position+16:position+32]
        file_flags = struct.unpack_from("<I", data, position+32)[0]
        position += 36
        assert not file_flags & 1, "Resource must not be encrypted"
        assert not any(value in name for value in (".private/", ".gdkey", "export_credentials", ".build/", "tests/", "publish/", "release_qa", "encryption_qa")), "Private or development file included"
        raw = data[start+file_base+offset:start+file_base+offset+size]
        assert len(raw) == size and hashlib.md5(raw).digest() == digest, "Resource checksum mismatch"
        names.append(name)
    assert any(n.endswith("licenses/Godot-LICENSE.txt") for n in names)
    assert any(n.endswith("licenses/Godot-COPYRIGHT.txt") for n in names)
    key_path = Path(__file__).resolve().parents[1] / ".private" / "pck-encryption.gdkey"
    if key_path.exists():
        key = key_path.read_text().strip()
        assert key.encode() not in data and bytes.fromhex(key) not in data, "Old private key embedded in EXE"
    return {"engine": f"{major}.{minor}.{patch}", "files_verified": count, "unencrypted": True, "private_files_excluded": True, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}


if __name__ == "__main__":
    print(json.dumps(audit(sys.argv[1])))
