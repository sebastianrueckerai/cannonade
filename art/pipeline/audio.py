#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///
"""Audio pipeline: music and sound effects through fal's queue, a round runner, a measurement sheet. Run from the art folder."""

import argparse
import base64
import datetime as dt
import html
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parent.parent
if (ROOT / ".env.session").exists():
    for line in (ROOT / ".env.session").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip())
CAP_USD = float(os.environ.get("SESSION_CAP_USD", 10.0))
SESSION_START = os.environ.get("SESSION_START", "")

# USD per run, or per second of output when the value is a ("s", rate) pair; read from the fal pages on 2026-10-20.
PRICES = {
    "minimax/music-3": ("s", 0.002),
    "fal-ai/stable-audio-25/text-to-audio": 0.20,
    "fal-ai/lyria3/pro": 0.08,
    "fal-ai/ace-step": ("s", 0.0002),
    "fal-ai/ace-step/audio-to-audio": ("s", 0.0002),
    "fal-ai/elevenlabs/sound-effects/v2": ("s", 0.002),
    "fal-ai/stable-audio-3/small/sfx/text-to-audio": 0.0206,
    "mirelo-ai/sfx2.0/text-to-audio": ("s", 0.010),
}
# The field that sets the length, per endpoint, so the per-second price can be estimated before the run.
DURATION_FIELD = {
    "minimax/music-3": "duration",
    "fal-ai/ace-step": "duration",
    "fal-ai/elevenlabs/sound-effects/v2": "duration_seconds",
    "mirelo-ai/sfx2.0/text-to-audio": "duration",
}
UNKNOWN_PRICE = 0.30
DEFAULT_SECONDS = 60  # the length assumed when an endpoint takes none and bills per second


def load_env():
    for line in (ROOT / ".env.tools").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            os.environ[k.strip()] = v.strip().strip('"')


def spent():
    total = 0.0
    for p in list((ROOT / "game").rglob("*.json")) + list((ROOT / "experiments").rglob("*.json")):
        try:
            d = json.loads(p.read_text())
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        if isinstance(d, dict) and "est_cost_usd" in d and d.get("created", "") >= SESSION_START:
            total += d["est_cost_usd"]
    return total


def check_cap(est):
    if spent() + est > CAP_USD:
        sys.exit(f"cap: spent ~${spent():.2f} + ${est:.2f} would pass ${CAP_USD:.2f}")


def parse_params(items):
    out = {}
    for it in items or []:
        k, v = it.split("=", 1)
        try:
            out[k] = json.loads(v)
        except json.JSONDecodeError:
            out[k] = v
    return out


def estimate(model, params):
    price = PRICES.get(model, UNKNOWN_PRICE)
    if isinstance(price, tuple):
        secs = params.get(DURATION_FIELD.get(model, ""), DEFAULT_SECONDS)
        return round(price[1] * float(secs), 4)
    return price


def fal_queue(model, body):
    """Submit to fal's queue and wait for the result. Music endpoints take minutes."""
    h = {"Authorization": f"Key {os.environ['FAL_KEY']}"}
    r = httpx.post(f"https://queue.fal.run/{model}", json=body, headers=h, timeout=60)
    if r.status_code != 200:
        sys.exit(f"fal {r.status_code}: {r.text[:500]}")
    q = r.json()
    deadline = time.time() + 900
    while time.time() < deadline:
        s = httpx.get(q["status_url"], headers=h, timeout=60).json()
        if s.get("status") == "COMPLETED":
            res = httpx.get(q["response_url"], headers=h, timeout=60)
            if res.status_code != 200:
                sys.exit(f"fal result {res.status_code}: {res.text[:500]}")
            return res.json()
        if s.get("status") not in ("IN_QUEUE", "IN_PROGRESS"):
            sys.exit(f"fal status: {json.dumps(s)[:500]}")
        time.sleep(3)
    sys.exit(f"fal: {model} did not finish in 15 minutes")


def fal_upload(path):
    """Put a file on fal's storage and return its URL. A data URI made the audio endpoints answer 500."""
    h = {"Authorization": f"Key {os.environ['FAL_KEY']}"}
    mime = {"wav": "audio/wav", "mp3": "audio/mpeg", "ogg": "audio/ogg"}.get(path.suffix[1:].lower(), "application/octet-stream")
    r = httpx.post("https://rest.alpha.fal.ai/storage/upload/initiate?storage_type=fal-cdn-v3",
                   json={"content_type": mime, "file_name": path.name}, headers=h, timeout=60)
    if r.status_code != 200:
        sys.exit(f"fal upload {r.status_code}: {r.text[:300]}")
    up = r.json()
    put = httpx.put(up["upload_url"], content=path.read_bytes(), headers={"Content-Type": mime}, timeout=300)
    if put.status_code not in (200, 201):
        sys.exit(f"fal upload put {put.status_code}: {put.text[:300]}")
    return up["file_url"]


def rel(p):
    p = Path(p).resolve()
    return str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p)


def cmd_gen(a):
    load_env()
    prompt = Path(a.prompt_file).read_text().strip() if a.prompt_file else (a.prompt or "")
    params = parse_params(a.param)
    est = a.est if a.est is not None else estimate(a.model, params)
    check_cap(est)
    body = {**({a.prompt_field: prompt} if prompt else {}), **params}
    if a.audio:
        body["audio_url"] = fal_upload(Path(a.audio))
    res = fal_queue(a.model, body)
    files = res["audio"] if isinstance(res["audio"], list) else [res["audio"]]
    saved = []
    for i, f in enumerate(files):
        ext = Path(f.get("file_name") or "").suffix or {"audio/wav": ".wav", "audio/x-wav": ".wav", "audio/mpeg": ".mp3"}.get(f.get("content_type"), ".mp3")
        out = Path(a.out).with_suffix(ext)
        if len(files) > 1:
            out = out.with_stem(f"{out.stem}-{i + 1}")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(httpx.get(f["url"], timeout=300).content)
        saved.append(out)
    out = Path(a.out)
    meta = {
        "model": a.model,
        "prompt": prompt,
        **({"audio": rel(a.audio)} if a.audio else {}),
        "params": params,
        "seed": res.get("seed", (res.get("seeds") or [None])[0]),
        **({"lyrics": res["lyrics"]} if res.get("lyrics") else {}),
        "duration": res.get("duration"),
        "label": a.label,
        "est_cost_usd": est,
        "created": dt.datetime.now().isoformat(timespec="seconds"),
        "outputs": [p.name for p in saved],
    }
    out.with_suffix(".json").write_text(json.dumps(meta, indent=2))
    for p in saved:
        print(p)
    print(f"~${est:.3f}, total ~${spent():.2f}")


def cmd_round(a):
    """Every direction times every track times every model. `round.json`: models {slug: {id, prompt_field?, params?, only?}},
    directions [{slug, ...fields}], tracks {slug: {prompt, params?}}; a track prompt is formatted with the direction's fields."""
    rd = Path(a.round).resolve()
    cfg = json.loads((rd / a.config).read_text())
    (rd / "prompts").mkdir(exist_ok=True)
    jobs = []
    for mslug, m in cfg["models"].items():
        for d in cfg["directions"]:
            if "only" in m and d["slug"] not in m["only"]:
                continue
            for tslug, t in cfg["tracks"].items():
                prompt = t["prompt"].format(**d)
                stem = f"{d['slug']}-{tslug}--{mslug}"
                if list(rd.glob(f"{stem}.*")) and not all(p.suffix in (".json", ".txt") for p in rd.glob(f"{stem}.*")):
                    continue
                pf = rd / "prompts" / f"{stem}.txt"
                pf.write_text(prompt + "\n")
                cmd = ["uv", "run", "--script", str(Path(__file__).resolve()), "gen", "--model", m["id"],
                       "--prompt-file", str(pf), "--out", str(rd / f"{stem}.mp3"), "--label", stem]
                if "prompt_field" in m:
                    cmd += ["--prompt-field", m["prompt_field"]]
                params = {**m.get("params", {}), **t.get("params", {}).get(mslug, {})}
                for k, v in params.items():
                    cmd += ["--param", f"{k}={v if isinstance(v, str) else json.dumps(v)}"]
                jobs.append((stem, cmd))
    print(f"{len(jobs)} runs")
    def run(job):
        stem, cmd = job
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
        return stem, r.returncode, (r.stdout + r.stderr).strip().splitlines()[-1:] if (r.stdout + r.stderr).strip() else []
    with ThreadPoolExecutor(max_workers=a.parallel) as ex:
        for stem, code, tail in ex.map(run, jobs):
            print(("ok  " if code == 0 else "FAIL"), stem, *tail)
    cmd_page(argparse.Namespace(round=str(rd)))


def measure(p):
    """Duration, integrated loudness and true peak through ffmpeg."""
    r = subprocess.run(["ffmpeg", "-nostats", "-i", str(p), "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True)
    txt = r.stderr
    def grab(pat):
        m = re.findall(pat, txt)  # the last match is the summary, the earlier ones are the running values
        return float(m[-1]) if m else None
    dur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(p)],
                         capture_output=True, text=True).stdout.strip()
    return {"seconds": round(float(dur), 1) if dur else None,
            "lufs": grab(r"I:\s+(-?[\d.]+) LUFS"),
            "range_lu": grab(r"LRA:\s+([\d.]+) LU"),
            "peak_dbtp": grab(r"Peak:\s+(-?[\d.]+) dBFS")}


WHISPER_PRICE = 0.005  # fal-ai/whisper bills compute seconds; a 90 s clip takes a few


def cmd_vocals(a):
    """Transcribe every music clip of a round with Whisper on fal: an instrumental clip returns a few words at most.
    The word count goes into the clip's sidecar as `vocal_words`, with the text."""
    load_env()
    rd = Path(a.round).resolve()
    for p in sorted(rd.glob("*.json")):
        d = json.loads(p.read_text())
        if "est_cost_usd" not in d or "model" not in d or ("vocal_words" in d and not a.redo):
            continue
        clip = rd / d["outputs"][0]
        if not clip.exists():
            continue
        small = Path("/tmp") / f"{clip.stem}.whisper.mp3"
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(clip), "-ac", "1", "-ar", "16000", "-b:a", "48k", str(small)], check=True)
        check_cap(WHISPER_PRICE)
        res = fal_queue("fal-ai/whisper", {"audio_url": "data:audio/mpeg;base64," + base64.b64encode(small.read_bytes()).decode(),
                                           "task": "transcribe", "chunk_level": "none"})
        text = (res.get("text") or "").strip()
        d["vocal_words"] = len(text.split())
        d["vocal_text"] = text[:300]
        d["est_cost_usd"] = round(d["est_cost_usd"] + WHISPER_PRICE, 4)
        p.write_text(json.dumps(d, indent=2))
        print(f"{d['vocal_words']:4d} words  {d['label']}  {text[:80]!r}")


def cmd_page(a):
    """index.html with a player, the prompt and the measurements per clip, and sheet.md with the numbers."""
    rd = Path(a.round).resolve()
    metas = []
    for p in sorted(rd.glob("*.json")):
        d = json.loads(p.read_text())
        if "est_cost_usd" not in d or "model" not in d:
            continue
        clip = rd / d["outputs"][0]
        if not clip.exists():
            continue
        metas.append({**d, "file": clip.name, **measure(clip)})
    rows = ["| clip | model | s | LUFS | LRA | peak dBTP | words | USD |", "|---|---|---|---|---|---|---|---|"]
    cards = []
    for m in metas:
        rows.append(f"| {m['label']} | {m['model']} | {m['seconds']} | {m['lufs']} | {m['range_lu']} | {m['peak_dbtp']} | {m.get('vocal_words', '')} | {m['est_cost_usd']:.3f} |")
        cards.append(
            f'<div class="c"><b>{html.escape(m["label"])}</b> <small>{html.escape(m["model"])} · {m["seconds"]} s · '
            f'{m["lufs"]} LUFS · {m.get("vocal_words", "?")} words · ~${m["est_cost_usd"]:.3f}</small><br><audio controls preload="none" src="{html.escape(m["file"])}"></audio>'
            f'<details><summary>prompt</summary><pre>{html.escape(m["prompt"])}</pre></details></div>')
    total = sum(m["est_cost_usd"] for m in metas)
    (rd / "sheet.md").write_text("\n".join(rows) + f"\n\n{len(metas)} clips, ~${total:.2f}\n")
    (rd / "index.html").write_text(
        f'<!doctype html><meta charset="utf-8"><title>{html.escape(rd.name)}</title>'
        '<style>body{font:14px system-ui;margin:20px;max-width:900px}.c{border-bottom:1px solid #ddd;padding:8px 0}'
        'audio{width:100%;display:block;margin:4px 0}pre{white-space:pre-wrap;font-size:12px}</style>'
        f'<h1>{html.escape(rd.name)}</h1><p>{len(metas)} clips, ~${total:.2f}</p>' + "".join(cards))
    print(rd / "index.html")
    print(f"{len(metas)} clips, ~${total:.2f}")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("gen")
    g.add_argument("--model", required=True)
    g.add_argument("--prompt")
    g.add_argument("--prompt-file")
    g.add_argument("--prompt-field", default="prompt", help="the request field the prompt goes into (text, tags)")
    g.add_argument("--audio", help="a reference clip, sent as a data URI")
    g.add_argument("--param", action="append", help="k=v, JSON values allowed")
    g.add_argument("--out", required=True, help="the extension follows the result")
    g.add_argument("--label")
    g.add_argument("--est", type=float)
    g.set_defaults(fn=cmd_gen)
    r = sub.add_parser("round")
    r.add_argument("round")
    r.add_argument("config", nargs="?", default="round.json")
    r.add_argument("--parallel", type=int, default=4)
    r.set_defaults(fn=cmd_round)
    v = sub.add_parser("vocals")
    v.add_argument("round")
    v.add_argument("--redo", action="store_true")
    v.set_defaults(fn=cmd_vocals)
    pg = sub.add_parser("page")
    pg.add_argument("round")
    pg.set_defaults(fn=cmd_page)
    c = sub.add_parser("cost")
    c.set_defaults(fn=lambda a: print(f"spent ~${spent():.2f} of ${CAP_USD:.2f} since {SESSION_START}"))
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
