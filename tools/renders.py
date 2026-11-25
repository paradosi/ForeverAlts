#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Forever Alts renders: Blizzard's Armory picture of each of your characters, for the Armory tab.

An addon can't download anything, and the game won't tell it what another character looks like.
Blizzard renders every Forever character for its Armory site, though, and its web API hands out
the pictures. This runs on a machine with the API credentials and SSH to the game PC:

  1. copies ForeverAlts.lua (the saved variables) from the game PC, for the character names;
  2. asks /profile/wow/character/{first-last}/character-media for each one's "main-raw" render
     (1600x1200 PNG, transparent background);
  3. trims the empty space, squares it and scales it to 512x512, and writes a TGA (what WoW reads);
  4. writes a small data addon, ForeverAlts_Renders (TOC, Renders.lua listing the pictures,
     renders/*.tga), and copies it into the game's AddOns folder when anything changed.

The data addon sits beside ForeverAlts, not inside it, so deploying a new ForeverAlts build
doesn't wipe the pictures. The game finds a new file only at startup: a new picture shows after
a game restart, not /reload. Silent and successful when the game PC is off.

  renders.py            fetch, convert, push when changed
  renders.py --force    push even if nothing changed
"""
import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from io import BytesIO
from pathlib import Path

from PIL import Image

CREDS = Path(os.environ.get("FA_CREDS", Path.home() / ".claude" / "creds" / "battlenet.txt"))
GAME_HOST = os.environ.get("FA_GAME_HOST", "northpc")
WOW = "C:/Program Files (x86)/World of Warcraft/_forever_"
ACCOUNT = os.environ.get("FA_ACCOUNT", "364039442#1")
SAVED = f"{WOW}/WTF/Account/{ACCOUNT}/SavedVariables/ForeverAlts.lua"
ADDONS = f"{WOW}/Interface/AddOns"
DATA = Path(os.environ.get("FA_DATA", Path.home() / "data" / "forever-alts-renders"))
OUT = DATA / "ForeverAlts_Renders"
REGION = "us"
SIZE = 512
UA = "forever-alts-renders/1.0"


def log(msg):
    print(msg, flush=True)


def quiet_ssh_errors(text):
    return " ".join(ln for ln in text.splitlines() if "post-quantum" not in ln and "upgraded" not in ln
                    and "openssh.com/pq" not in ln and "decrypt later" not in ln)


def ssh_ok():
    return subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", GAME_HOST, "exit 0"],
                          capture_output=True).returncode == 0


def names_from(saved: Path):
    wrapper = DATA / "names.lua"
    wrapper.write_text('dofile(...) for _, c in pairs(ForeverAltsDB and ForeverAltsDB.chars or {}) do '
                       'if type(c.name) == "string" then print(c.name) end end\n')
    out = subprocess.run(["lua5.1", str(wrapper), str(saved)], capture_output=True, text=True, check=True).stdout
    return sorted({n.strip() for n in out.splitlines() if n.strip()})


_token = None


def token():
    global _token
    if not _token:
        cid, secret = CREDS.read_text().split()[:2]
        req = urllib.request.Request("https://oauth.battle.net/token", data=b"grant_type=client_credentials",
                                     headers={"User-Agent": UA})
        req.add_header("Authorization", "Basic " + base64.b64encode(f"{cid}:{secret}".encode()).decode())
        with urllib.request.urlopen(req, timeout=30) as r:
            _token = json.load(r)["access_token"]
    return _token


def get(url, auth=True):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    if auth:
        req.add_header("Authorization", f"Bearer {token()}")
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def slug(name):
    return "-".join(name.lower().split())


def render_url(name):
    path = f"/profile/wow/character/{urllib.parse.quote(slug(name))}/character-media"
    url = f"https://{REGION}.api.blizzard.com{path}?namespace=profile-forever-{REGION}&locale=en_US"
    try:
        media = json.loads(get(url))
    except urllib.error.HTTPError as e:
        if e.code == 404:  # not on the Armory yet (a brand-new character, or one not logged out since)
            return None
        raise
    for a in media.get("assets", []):
        if a.get("key") == "main-raw":
            return a.get("value")
    return None


def to_tga(png: bytes, dest: Path):
    """Trim to the character, square it with a little room, scale to SIZE, write a 32-bit TGA."""
    img = Image.open(BytesIO(png)).convert("RGBA")
    box = img.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if box:
        img = img.crop(box)
    w, h = img.size
    side = int(max(w, h) * 1.08)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - w) // 2, side - h - (side - h) // 4))  # stands a little low, like on a floor
    canvas.resize((SIZE, SIZE), Image.LANCZOS).save(dest, format="TGA")


def write_addon(entries):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "ForeverAlts_Renders.toc").write_text(
        "## Interface: 16001\n"
        "## Title: Forever Alts Renders\n"
        "## Notes: Armory pictures of your characters for Forever Alts' Armory tab. Written by tools/renders.py; don't edit.\n"
        "## Author: paradosi-Dreamscythe\n"
        f"## Version: {time.strftime('%Y.%m.%d.%H%M', time.gmtime())}\n"
        "Renders.lua\n")
    lines = ["-- Generated by ForeverAlts tools/renders.py: one Armory picture per character (lowercase name).",
             "ForeverAltsRenders = {"]
    for name in sorted(entries):
        e = entries[name]
        lines.append(f'    ["{name.lower()}"] = {{ file = "{e["file"]}", updated = {e["updated"]} }},')
    lines.append("}")
    (OUT / "Renders.lua").write_text("\n".join(lines) + "\n")


def push():
    p = subprocess.run(["scp", "-q", "-r", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", str(OUT), f"{GAME_HOST}:{ADDONS}/"],
                       capture_output=True, text=True)
    if p.returncode:
        log(f"not pushed to {GAME_HOST}: {quiet_ssh_errors(p.stderr)[-200:] or 'unreachable'}")
        return False
    log(f"pushed ForeverAlts_Renders to {GAME_HOST} (restart the game to see new pictures)")
    return True


def main():
    force = "--force" in sys.argv
    DATA.mkdir(parents=True, exist_ok=True)
    (OUT / "renders").mkdir(parents=True, exist_ok=True)
    state_file = DATA / "state.json"
    state = json.loads(state_file.read_text()) if state_file.exists() else {"chars": {}, "pushed": False}

    if not ssh_ok():
        log(f"{GAME_HOST} unreachable; nothing to do")
        return
    saved = DATA / "ForeverAlts.lua"
    p = subprocess.run(["scp", "-q", "-o", "BatchMode=yes", f"{GAME_HOST}:{SAVED}", str(saved)], capture_output=True, text=True)
    if p.returncode:
        log(f"no ForeverAlts saved variables on {GAME_HOST} yet: {quiet_ssh_errors(p.stderr)[-160:]}")
        return
    names = names_from(saved)

    changed = False
    for name in names:
        url = render_url(name)
        if not url:
            log(f"{name}: no Armory render yet")
            continue
        png = get(url, auth=False)
        digest = hashlib.sha256(png).hexdigest()
        known = state["chars"].get(name)
        file = slug(name)
        tga = OUT / "renders" / f"{file}.tga"
        if known and known["sha"] == digest and tga.exists():
            continue
        to_tga(png, tga)
        state["chars"][name] = {"sha": digest, "file": file, "updated": int(time.time())}
        changed = True
        log(f"{name}: new render")

    # Characters no longer in the saved data lose their picture
    for name in [n for n in state["chars"] if n not in names]:
        (OUT / "renders" / f"{state['chars'][name]['file']}.tga").unlink(missing_ok=True)
        del state["chars"][name]
        changed = True

    if changed or force or not state.get("pushed"):
        write_addon(state["chars"])
        state["pushed"] = push()
    state_file.write_text(json.dumps(state, indent=1))


if __name__ == "__main__":
    main()
