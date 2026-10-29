"""Read-only verification of probe files against the imported test playlist."""
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import subprocess
import sys

from mutagen.mp3 import MP3

database, directory, ffmpeg = map(Path, sys.argv[1:4])
connection = sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True)
connection.row_factory = sqlite3.Row
collection = connection.execute(
    "SELECT id FROM collections WHERE source_url=? AND partial=0 ORDER BY id DESC LIMIT 1",
    ("https://open.spotify.com/playlist/4PYxm8yonIPl6XxizOPYb1",),
).fetchone()
tracks = {
    row["position"]: dict(row) for row in connection.execute(
        "SELECT position,title,artist,duration_ms FROM tracks WHERE collection_id=? ORDER BY position LIMIT 100",
        (collection["id"],),
    )
}
connection.close()
results = []
for file in sorted(directory.glob("*.mp3"))[:100]:
    prefix = re.match(r"(\d+) - ", file.name)
    position = int(prefix[1]) if prefix else 1
    expected = tracks.get(position)
    result = {"file": file.name, "position": position, "bytes": file.stat().st_size}
    try:
        media = MP3(file)
        digest = hashlib.sha256()
        with file.open("rb") as source:
            for block in iter(lambda: source.read(65536), b""):
                digest.update(block)
        decoded = subprocess.run(
            [str(ffmpeg), "-v", "error", "-xerror", "-i", str(file), "-f", "null", "-"],
            capture_output=True, timeout=30, check=False,
        )
        delta = media.info.length - expected["duration_ms"] / 1000 if expected else None
        result.update({
            "sha256": digest.hexdigest(), "duration_seconds": round(media.info.length, 3),
            "expected_duration_seconds": expected["duration_ms"] / 1000 if expected else None,
            "duration_delta_seconds": round(delta, 3) if delta is not None else None,
            "title": str(media.tags.get("TIT2")), "artist": str(media.tags.get("TPE1")),
            "cover_count": len(media.tags.getall("APIC")), "full_decode_exit": decoded.returncode,
            "requires_review": delta is None or abs(delta) > 2 or decoded.returncode != 0,
        })
    except Exception as error:
        result.update({"verification_error": type(error).__name__, "requires_review": True})
    results.append(result)
present = {row["position"] for row in results if not row["requires_review"]}
print(json.dumps({"expected_tracks": len(tracks), "files": results,
                  "missing_or_review_positions": sorted(set(tracks) - present)}, ensure_ascii=True, indent=2))
