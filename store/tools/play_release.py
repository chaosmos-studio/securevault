"""Sends SecureVault's store listing and a release to Google Play through the Play Developer API.

Every run builds one edit and validates it. Nothing reaches Play without --commit.

Usage, from the repo root:
  python3 store/tools/play_release.py read
  python3 store/tools/play_release.py listing [--images] [--commit]
  python3 store/tools/play_release.py release <aab> [--commit]

read: prints the listing, contact details and production track Play holds, then discards the edit.
listing: the en-US title, short and full description from assets/store/listing.md, the contact email and
  website, and with --images the 512 icon, the feature graphic and the phone screenshots from assets/store/,
  each set replaced in file name order.
release: uploads the AAB and puts it on production for everyone, with the newest notes in release_notes.txt.

The key (default ~/.config/chaosmos/ci-uploader.json) is read by path and never printed. Its service account
needs "Manage store presence" for the listing and "Release to production" for a release.
"""

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

ROOT = Path(__file__).resolve().parents[2]
STORE = ROOT / "assets/store"
PACKAGE = "com.shravangoswami.securevault"
CONTACT = {"contactEmail": "hello@chaosmos.studio", "contactWebsite": "https://chaosmos.studio/securevault/"}
API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/"
LIMITS = {"title": 30, "shortDescription": 80, "fullDescription": 4000}


def token(key_path: Path) -> str:
    key = json.loads(key_path.read_text())
    now = int(time.time())
    claim = {"iss": key["client_email"], "scope": "https://www.googleapis.com/auth/androidpublisher",
             "aud": key["token_uri"], "iat": now, "exp": now + 900}
    signed = jwt.encode(claim, key["private_key"], algorithm="RS256", headers={"kid": key["private_key_id"]})
    body = ("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=" + signed).encode()
    with urllib.request.urlopen(urllib.request.Request(key["token_uri"], data=body)) as reply:
        return json.load(reply)["access_token"]


class Edit:
    def __init__(self, auth: str) -> None:
        self.auth = auth
        self.id = self.call("POST", "edits", {})["id"]

    def call(self, method: str, path: str, payload: dict | None = None, raw: bytes | None = None,
             kind: str = "image/png") -> dict:
        upload = raw is not None
        url = (UPLOAD if upload else API) + PACKAGE + "/" + (path if path == "edits" else f"edits/{self.id}/{path}")
        if upload:
            url += "?uploadType=media"
        data = raw if upload else (json.dumps(payload).encode() if payload is not None else None)
        request = urllib.request.Request(url, method=method, data=data, headers={
            "Authorization": "Bearer " + self.auth, "Content-Type": kind if upload else "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=600) as reply:
                text = reply.read()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as err:
            sys.exit(f"{method} {path}: HTTP {err.code} {err.read().decode()[:600]}")

    def finish(self, commit: bool) -> None:
        self._post(":validate")
        print("the edit validates")
        if commit:
            self._post(":commit")
            print("committed")
        else:
            self.discard()
            print("discarded: run again with --commit to send it")

    def discard(self) -> None:
        self._send(urllib.request.Request(API + PACKAGE + "/edits/" + self.id, method="DELETE",
                                          headers={"Authorization": "Bearer " + self.auth}))

    def _post(self, verb: str) -> None:
        self._send(urllib.request.Request(API + PACKAGE + f"/edits/{self.id}{verb}", method="POST",
                                          headers={"Authorization": "Bearer " + self.auth}))

    @staticmethod
    def _send(request: urllib.request.Request) -> None:
        try:
            urllib.request.urlopen(request).read()
        except urllib.error.HTTPError as err:
            sys.exit(f"{request.full_url.rsplit('/', 1)[-1]}: HTTP {err.code} {err.read().decode()[:600]}")


def section(text: str, heading: str) -> str:
    """The text under a "## heading" in listing.md, up to the next heading."""
    match = re.search(rf"^## {re.escape(heading)}[^\n]*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not match:
        sys.exit(f"listing.md has no '## {heading}' section")
    return match.group(1).strip()


def words() -> dict:
    text = (STORE / "listing.md").read_text()
    found = {"title": section(text, "App name"), "shortDescription": section(text, "Short description"),
             "fullDescription": section(text, "Full description")}
    over = [f"{field} {len(found[field])} > {limit}" for field, limit in LIMITS.items() if len(found[field]) > limit]
    if over:
        sys.exit("over Play's limits: " + ", ".join(over))
    return found


def notes() -> tuple[str, str]:
    """The newest release's name and notes in release_notes.txt."""
    text = (ROOT / "release_notes.txt").read_text()
    match = re.search(r"Release Name: (\S+).*?Release Notes:\n(.*?)\n---", text, re.S)
    if not match:
        sys.exit("release_notes.txt has no release block")
    body = match.group(2).strip()
    if len(body) > 500:
        sys.exit(f"release notes are {len(body)} characters, over Play's 500")
    return match.group(1), body


def read(edit: Edit) -> None:
    listing = edit.call("GET", "listings/en-US")
    for field in LIMITS:
        value = listing.get(field, "")
        print(f"{field}: {len(value)} characters: {value[:90]!r}")
    details = edit.call("GET", "details")
    print("details:", {k: details.get(k) for k in ("contactEmail", "contactWebsite", "defaultLanguage")})
    for kind in ("icon", "featureGraphic", "phoneScreenshots"):
        print(f"{kind}: {len(edit.call('GET', f'listings/en-US/{kind}').get('images', []))} image(s)")
    for track in edit.call("GET", "tracks").get("tracks", []):
        for release in track.get("releases", []):
            print(f"track {track['track']}: {release.get('name')} codes {release.get('versionCodes')} "
                  f"{release.get('status')}")
    edit.discard()


def listing(edit: Edit, images: bool) -> None:
    found = words()
    edit.call("PUT", "listings/en-US", dict(found, language="en-US"))
    print("listing: " + ", ".join(f"{k} {len(v)}" for k, v in found.items()))
    details = edit.call("GET", "details")
    edit.call("PUT", "details", dict(details, **CONTACT))
    print("details:", CONTACT)
    if not images:
        return
    for kind, path in {"icon": STORE / "play_store_icon_512.png",
                       "featureGraphic": STORE / "feature_graphic_1024x500.png"}.items():
        edit.call("DELETE", f"listings/en-US/{kind}")
        edit.call("POST", f"listings/en-US/{kind}", raw=path.read_bytes())
        print(f"{kind}: {path.name}")
    shots = sorted((STORE / "screenshots/phone").glob("*.png"))
    edit.call("DELETE", "listings/en-US/phoneScreenshots")
    for path in shots:
        edit.call("POST", "listings/en-US/phoneScreenshots", raw=path.read_bytes())
    print("phoneScreenshots: " + ", ".join(p.name for p in shots))


def release(edit: Edit, aab: Path) -> None:
    name, text = notes()
    bundle = edit.call("POST", "bundles", raw=aab.read_bytes(), kind="application/octet-stream")
    code = str(bundle["versionCode"])
    print(f"uploaded {aab.name}: version code {code}")
    edit.call("PUT", "tracks/production", {"track": "production", "releases": [{
        "name": name, "versionCodes": [code], "status": "completed",
        "releaseNotes": [{"language": "en-US", "text": text}]}]})
    print(f"production: {name} (code {code}) to everyone, notes {len(text)} characters")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("action", choices=["read", "listing", "release"])
    parser.add_argument("aab", nargs="?", type=Path, help="release: the signed AAB")
    parser.add_argument("--images", action="store_true", help="listing: also the icon, feature graphic and screenshots")
    parser.add_argument("--commit", action="store_true", help="send the edit instead of discarding it")
    parser.add_argument("--key", type=Path, default=Path.home() / ".config/chaosmos/ci-uploader.json")
    args = parser.parse_args()
    if args.action == "listing":
        words()
    if args.action == "release" and (args.aab is None or not args.aab.exists()):
        sys.exit("release needs the path of a signed AAB")
    edit = Edit(token(args.key))
    if args.action == "read":
        read(edit)
        return
    if args.action == "listing":
        listing(edit, args.images)
    else:
        release(edit, args.aab)
    edit.finish(args.commit)


if __name__ == "__main__":
    main()
