"""Isolated emulator companion: real SEND intents and DocumentsUI SAF picker."""
import argparse
import hashlib
import json
import re
import shlex
import subprocess
import tempfile
import time
import uuid
from urllib.parse import quote
import xml.etree.ElementTree as ET
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adb", required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--audio", required=True)
    args = parser.parse_args()
    prefix = [args.adb, "-s", args.device]
    package = "br.com.definitivedownloader.app.integration"
    component = package + "/br.com.definitivedownloader.app.MainActivity"

    def adb(*items, data=None):
        result = subprocess.run(prefix + list(items), input=data, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, timeout=30)
        if result.returncode:
            raise RuntimeError(str(items) + ': ' + result.stderr.decode(errors='replace') + result.stdout.decode(errors='replace'))
        return result.stdout

    def shell(*items):
        return adb("shell", " ".join(shlex.quote(str(item)) for item in items)).decode("utf-8")

    if shell("getprop", "ro.kernel.qemu").strip() != "1":
        raise RuntimeError("Emulator required")
    if not adb("emu", "avd", "name").decode().startswith("Definitive_API_36"):
        raise RuntimeError("Dedicated AVD required")

    def marker(name):
        deadline = time.monotonic() + 300
        while name not in Path(args.log).read_text(encoding="utf-8-sig", errors="replace"):
            if time.monotonic() > deadline:
                raise TimeoutError(name)
            time.sleep(0.25)

    def tap(*labels):
        deadline = time.monotonic() + 35
        while time.monotonic() < deadline:
            try:
                result = shell("uiautomator", "dump", "/data/local/tmp/dd-storage-ui.xml")
                if "dumped" not in result.lower():
                    time.sleep(0.5)
                    continue
                root = ET.fromstring(shell("cat", "/data/local/tmp/dd-storage-ui.xml"))
                for node in root.iter("node"):
                    if node.get("enabled") != "true":
                        continue
                    if any(node.get(attr, "").casefold() in [s.casefold() for s in labels]
                           for attr in ("text", "content-desc")):
                        bounds = [int(n) for n in re.findall(r"\d+", node.get("bounds", ""))]
                        if len(bounds) == 4:
                            shell("input", "tap", (bounds[0]+bounds[2])//2, (bounds[1]+bounds[3])//2)
                            return
            except (ET.ParseError, subprocess.SubprocessError):
                pass
            time.sleep(0.5)
        raise TimeoutError("UI target: " + repr(labels))

    token = uuid.uuid4().hex[:12]
    filename = "dd-share-" + token + ".mp3"
    destination = "/sdcard/Documents/DdStorage-" + token
    uri = None
    audio = Path(args.audio).read_bytes()
    def choose_destination():
        tap("Exportar cópia")
        tap("Escolher destino")
        tap("DdStorage-" + token)
        tap("Use this folder", "Usar esta pasta")
        tap("Allow", "Permitir")

    try:
        shell("mkdir", "-p", destination)
        shell("content", "insert", "--uri", "content://media/external/audio/media",
              "--bind", "_display_name:s:" + filename, "--bind", "mime_type:s:audio/mpeg",
              "--bind", "relative_path:s:Music/DdAutomatedFixture")
        rows = shell("content", "query", "--uri", "content://media/external/audio/media",
                     "--projection", "_id:_display_name", "--where", "_display_name='" + filename + "'")
        match = re.search(r"_id=(\d+), _display_name=" + re.escape(filename), rows)
        if not match:
            raise RuntimeError("Fixture media URI not created")
        uri = "content://media/external/audio/media/" + match[1]
        # `content write` truncates piped binary input on this emulator. Push
        # only this UUID fixture, then verify reading through its actual URI.
        adb("push", args.audio, "/sdcard/Music/DdAutomatedFixture/" + filename)
        received = adb("exec-out", "content", "read", "--uri", uri)
        if hashlib.sha256(received).digest() != hashlib.sha256(audio).digest():
            raise RuntimeError("External fixture write was not binary-safe")
        marker("ANDROID_STORAGE_SHARE_TEXT")
        print("Delivering text", flush=True)
        shell("am", "start", "-n", component, "-a", "android.intent.action.SEND", "-t", "text/plain",
              "--es", "android.intent.extra.TEXT", "Fixture https://fixture.invalid/shared.mp3")
        marker("ANDROID_STORAGE_SHARE_MP3")
        print("Delivering MP3", flush=True)
        print(shell("am", "start", "-n", component, "-a", "android.intent.action.SEND", "-t", "audio/mpeg",
              "-d", uri, "--eu", "android.intent.extra.STREAM", uri, "--grant-read-uri-permission"), flush=True)
        marker("ANDROID_STORAGE_PREPARE_JOURNAL")
        partial = destination + "/partial-owned"
        known = partial + "/journal-copy.mp3"
        foreign = partial + "/foreign-sentinel.txt"
        shell("mkdir", partial)
        adb("push", args.audio, known)
        tree_id = "primary:Documents/DdStorage-" + token
        def document(identifier):
            return "content://com.android.externalstorage.documents/tree/" + quote(tree_id, safe="") + "/document/" + quote(identifier, safe="")
        with tempfile.TemporaryDirectory(prefix="dd-journal-fixture-") as temp:
            sentinel = Path(temp) / "foreign.txt"
            sentinel.write_text("Keep this separately created fixture", encoding="utf-8")
            adb("push", str(sentinel), foreign)
            plan = Path(temp) / "plan.json"
            plan.write_text(json.dumps({"id": str(uuid.uuid4()), "root": document(tree_id + "/partial-owned"),
                                       "file": document(tree_id + "/partial-owned/journal-copy.mp3")}), encoding="utf-8")
            temporary_plan = "/data/local/tmp/dd-export-plan-" + token + ".json"
            adb("push", str(plan), temporary_plan)
            shell("run-as", package, "cp", temporary_plan, "files/storage-export-plan.json")
            shell("rm", temporary_plan)
        marker("ANDROID_STORAGE_EXPORT_BLOCKED")
        choose_destination()
        tap("Fechar")
        if shell("cat", foreign) != "Keep this separately created fixture":
            raise RuntimeError("Untracked content was modified")
        if shell("stat", "-c", "%s", known).strip() != str(len(audio)):
            raise RuntimeError("Recovery deleted files before checking unknown content")
        shell("rm", foreign)  # Only this test-created sentinel, never user content.
        shell("run-as", package, "touch", "files/storage-export-retry")
        marker("ANDROID_STORAGE_EXPORT")
        choose_destination()
        tap("Fechar")  # Completion dialog; the progress dialog has no Fechar.
        shell("test", "!", "-e", partial)
        public = shell("find", destination, "-type", "f").strip().splitlines()
        mp3 = [s for s in public if s.endswith(".mp3")]
        m3u = [s for s in public if s.endswith(".m3u8")]
        if len(mp3) != 1 or len(m3u) != 1:
            raise RuntimeError("Incomplete public snapshot: " + repr(public))
        with tempfile.TemporaryDirectory(prefix="dd-export-check-") as temp:
            copy = Path(temp) / "audio.mp3"
            adb("pull", mp3[0], str(copy))
            if hashlib.sha256(copy.read_bytes()).digest() != hashlib.sha256(audio).digest():
                raise RuntimeError("Exported audio hash differs")
        playlist = shell("cat", m3u[0])
        if Path(mp3[0]).name not in playlist:
            raise RuntimeError("M3U8 does not reference the exported file")
        shell("run-as", package, "touch", "files/storage-export-verified")
        marker("ANDROID_STORAGE_OVERFLOW")
        for index in range(9):
            shell("am", "start", "-n", component, "-a", "android.intent.action.SEND", "-t", "text/plain",
                  "--es", "android.intent.extra.TEXT", "https://fixture.invalid/burst-" + str(index) + ".mp3")
        shell("run-as", package, "touch", "files/storage-overflow-sent")
        marker("ANDROID_STORAGE_VERIFIED")
        print("Verified SEND text/MP3, foreign-content guard, exact journal cleanup and public SAF copy with matching SHA-256/M3U8.")
    finally:
        if uri:
            shell("content", "delete", "--uri", uri)
        # Only the uniquely created fixture directory; never another destination.
        if re.fullmatch(r"/sdcard/Documents/DdStorage-[a-f0-9]{12}", destination):
            shell("rm", "-rf", destination)


if __name__ == "__main__":
    main()
