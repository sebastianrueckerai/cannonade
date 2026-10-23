#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx", "pillow"]
# ///
"""Image-to-3D through Tripo and Meshy: one run, the files downloaded at once, a sidecar. Run from the repo root.

  mesh.py tripo --image a.png --out raw/x.glb --param smart_low_poly=true --param face_limit=1000
  mesh.py tripo --views front.png left.png back.png right.png --out raw/x.glb     (- for a missing view)
  mesh.py meshy --image a.png --out raw/x.glb --param model_type=smart-topology --param target_polycount=500
  mesh.py meshy --views a.png b.png --out raw/x.glb --param ai_model=meshy-6
  mesh.py meshy-retexture --model final.glb --style-image style.png --out raw/x.glb    (retexture an existing mesh, Meshy)
  mesh.py tripo-fal --image a.png --out raw/x.glb --param face_limit=1000 --param texture=standard
  mesh.py balance
"""

import argparse
import datetime as dt
import json
import os
import sys
import time
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent))
from img import ROOT, check_cap, data_uri, load_env, parse_params, spent  # noqa: E402

TRIPO = "https://api.tripo3d.ai/v2/openapi"
TRIPO_VERSION = "v3.1-20260211"
MESHY = "https://api.meshy.ai/openapi/v1"
# Tripo through fal pays USD straight from the key: $0.30 a run with standard textures, $0.40 with HD.
FAL_TRIPO = "https://queue.fal.run/tripo3d/tripo/v2.5/image-to-3d"
# Tripo API credits cost 0.01 USD. Meshy credits come with the Pro plan, 1,000 for 20 USD a month.
USD_PER_CREDIT = {"tripo": 0.01, "meshy": 0.02, "tripo-fal": 1.0}
# Upper bounds per run for the cap check before the call. The sidecar records what the provider charged.
EST_CREDITS = {"tripo": 70, "meshy": 30, "tripo-fal": 0.40}


def tripo_req(method, path, **kw):
    for _ in range(40):  # 429 is too many tasks at once, 5xx or an empty body a passing fault: wait and retry
        r = httpx.request(method, f"{TRIPO}{path}", headers={"Authorization": f"Bearer {os.environ['TRIPO_KEY']}"},
                          timeout=180, **kw)
        try:
            d = r.json()
        except ValueError:
            d = None
        if r.status_code != 429 and r.status_code < 500 and d is not None:
            break
        time.sleep(float(r.headers.get("Retry-After", 30)))
    if d.get("code") != 0:
        sys.exit(f"tripo {path}: {r.status_code} {r.text[:400]}")
    return d["data"]


def meshy_req(method, path, **kw):
    r = httpx.request(method, f"{MESHY}{path}", headers={"Authorization": f"Bearer {os.environ['MESHY_KEY']}"},
                      timeout=180, **kw)
    if r.status_code >= 300:
        sys.exit(f"meshy {path}: {r.status_code} {r.text[:400]}")
    return r.json()


def tripo_file(path):
    with open(path, "rb") as f:
        token = tripo_req("POST", "/upload", files={"file": (Path(path).name, f)})["image_token"]
    return {"type": "png" if path.endswith(".png") else "jpg", "file_token": token}


def run_tripo(a, params):
    if a.views:
        body = {"type": "multiview_to_model", "files": [{} if v == "-" else tripo_file(v) for v in a.views]}
    else:
        body = {"type": "image_to_model", "file": tripo_file(a.image)}
    body = {"model_version": TRIPO_VERSION, **body, **params}
    tid = tripo_req("POST", "/task", json=body)["task_id"]
    while True:
        time.sleep(5)
        t = tripo_req("GET", f"/task/{tid}")
        if t["status"] == "success":
            break
        if t["status"] not in ("queued", "running"):
            sys.exit(f"tripo task {tid}: {t['status']}")
    out = t.get("output", {})
    urls = {k: out[k] for k in ("pbr_model", "model", "base_model", "rendered_image") if out.get(k)}
    return tid, {**body, "files": "uploaded", "file": "uploaded"}, urls, t.get("consumed_credit")


def fal_upload(path):
    # the Tripo app cannot fetch data URIs, so the image goes to fal storage first
    data = Path(path).read_bytes()
    ct = "image/png" if path.endswith(".png") else "image/jpeg"
    r = httpx.post("https://rest.alpha.fal.ai/storage/upload/initiate",
                   headers={"Authorization": f"Key {os.environ['FAL_KEY']}"},
                   json={"content_type": ct, "file_name": Path(path).name}, timeout=60)
    if r.status_code != 200:
        sys.exit(f"fal upload initiate: {r.status_code} {r.text[:400]}")
    up = r.json()
    httpx.put(up["upload_url"], content=data, headers={"Content-Type": ct}, timeout=300).raise_for_status()
    return up["file_url"]


def run_tripo_fal(a, params):
    if a.views:
        sys.exit("tripo-fal takes one --image, not --views")
    body = {"image_url": fal_upload(a.image), "texture": "standard", "pbr": False, **params}
    r = httpx.post(FAL_TRIPO, headers={"Authorization": f"Key {os.environ['FAL_KEY']}"}, json=body, timeout=120)
    if r.status_code != 200:
        sys.exit(f"tripo-fal submit: {r.status_code} {r.text[:400]}")
    rid = r.json()["request_id"]
    print(f"tripo-fal request {rid}", flush=True)
    auth = {"Authorization": f"Key {os.environ['FAL_KEY']}"}
    status_url = r.json()["status_url"]
    while True:
        time.sleep(5)
        for _ in range(10):  # transient 429/5xx or an empty body a passing fault: wait and retry
            try:
                s = httpx.get(status_url, headers=auth, timeout=60).json()
                break
            except ValueError:
                time.sleep(10)
        if s["status"] == "COMPLETED":
            break
        if s["status"] not in ("IN_QUEUE", "IN_PROGRESS"):
            sys.exit(f"tripo-fal {rid}: {s['status']} {str(s)[:300]}")
    d = httpx.get(f"{FAL_TRIPO}/requests/{rid}".replace("/v2.5/image-to-3d", ""), headers=auth, timeout=120).json()
    if "detail" in d:
        sys.exit(f"tripo-fal {rid}: {json.dumps(d['detail'])[:400]}")
    urls = {k: d[k]["url"] for k in ("model_mesh", "base_model", "pbr_model", "rendered_image") if d.get(k)}
    shown = {k: v for k, v in body.items() if k != "image_url"}
    return rid, {"endpoint": "tripo3d/tripo/v2.5/image-to-3d", **shown}, urls, 0.30


def run_meshy(a, params):
    if a.views:
        kind, body = "multi-image-to-3d", {"image_urls": [data_uri(v, max_side=2048) for v in a.views]}
    else:
        kind, body = "image-to-3d", {"image_url": data_uri(a.image, max_side=2048)}
    body = {**body, "target_formats": ["glb"], **params}
    tid = meshy_req("POST", f"/{kind}", json=body)["result"]
    while True:
        time.sleep(5)
        t = meshy_req("GET", f"/{kind}/{tid}")
        if t["status"] == "SUCCEEDED":
            break
        if t["status"] not in ("PENDING", "IN_PROGRESS"):
            sys.exit(f"meshy task {tid}: {t['status']} {t.get('task_error')}")
    urls = {"model": t["model_urls"]["glb"]}
    if t.get("thumbnail_url"):
        urls["rendered_image"] = t["thumbnail_url"]
    shown = {k: v for k, v in body.items() if k not in ("image_url", "image_urls")}
    return tid, {"endpoint": kind, **shown}, urls, t.get("consumed_credits")


def run_meshy_retexture(a, params):
    body = {"model_url": data_uri(a.model), **params}
    shown = {"model": a.model}
    if a.style_image:
        body["image_style_url"] = data_uri(a.style_image, max_side=2048)
        shown["style_image"] = a.style_image
    if a.style_text:
        body["text_style_prompt"] = a.style_text
    body = {**body, "target_formats": ["glb"]}
    r = meshy_req("POST", "/retexture", json=body)
    tid = r.get("result") or r["id"]
    while True:
        time.sleep(5)
        t = meshy_req("GET", f"/retexture/{tid}")
        if t["status"] == "SUCCEEDED":
            break
        if t["status"] not in ("PENDING", "IN_PROGRESS"):
            sys.exit(f"meshy task {tid}: {t['status']} {t.get('task_error')}")
    urls = {"model": t["model_urls"]["glb"]}
    if t.get("thumbnail_url"):
        urls["rendered_image"] = t["thumbnail_url"]
    return tid, {"endpoint": "retexture", **shown, "target_formats": body["target_formats"]}, urls, t.get("consumed_credits")


def cmd_run(a):
    load_env()
    if not (a.image or a.views):
        sys.exit("give --image or --views")
    params = parse_params(a.param)
    check_cap(EST_CREDITS[a.provider] * USD_PER_CREDIT[a.provider])
    t0 = time.time()
    tid, body, urls, credits = {"tripo": run_tripo, "meshy": run_meshy, "tripo-fal": run_tripo_fal}[a.provider](a, params)
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    saved = {}
    for k, url in urls.items():
        if k == "rendered_image":
            p = out.with_name(f"{out.stem}-preview{Path(url.split('?')[0]).suffix or '.png'}")
        elif k == "model" and "pbr_model" in urls or k == "base_model":
            p = out.with_name(f"{out.stem}-{k}.glb")
        else:
            p = out
        p.write_bytes(httpx.get(url, timeout=300, follow_redirects=True).content)
        saved[k] = p.name
    credits = credits if credits is not None else EST_CREDITS[a.provider]

    def rel(p):
        return str(Path(p).resolve().relative_to(ROOT)) if p and p != "-" else p

    meta = {
        "provider": a.provider,
        "task_id": tid,
        "inputs": [rel(p) for p in (a.views or [a.image])],
        "params": body,
        "label": a.label,
        "credits": credits,
        "est_cost_usd": round(credits * USD_PER_CREDIT[a.provider], 3),
        "elapsed_s": round(time.time() - t0),
        "created": dt.datetime.now().isoformat(timespec="seconds"),
        "outputs": saved,
    }
    out.with_suffix(".json").write_text(json.dumps(meta, indent=2))
    print(f"{out} {credits} credits, {meta['elapsed_s']} s, session ~${spent():.2f}")


def cmd_retexture(a):
    load_env()
    params = parse_params(a.param)
    check_cap(EST_CREDITS["meshy"] * USD_PER_CREDIT["meshy"])
    t0 = time.time()
    tid, body, urls, credits = run_meshy_retexture(a, params)
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    saved = {}
    for k, url in urls.items():
        if k == "rendered_image":
            p = out.with_name(f"{out.stem}-preview{Path(url.split('?')[0]).suffix or '.png'}")
        else:
            p = out
        p.write_bytes(httpx.get(url, timeout=300, follow_redirects=True).content)
        saved[k] = p.name
    credits = credits if credits is not None else EST_CREDITS["meshy"]

    def rel(p_):
        return str(Path(p_).resolve().relative_to(ROOT))

    meta = {
        "provider": "meshy",
        "task_id": tid,
        "inputs": [rel(a.model)] + ([rel(a.style_image)] if a.style_image else []),
        "params": body,
        "label": a.label,
        "credits": credits,
        "est_cost_usd": round(credits * USD_PER_CREDIT["meshy"], 3),
        "elapsed_s": round(time.time() - t0),
        "created": dt.datetime.now().isoformat(timespec="seconds"),
        "outputs": saved,
    }
    out.with_suffix(".json").write_text(json.dumps(meta, indent=2))
    print(f"{out} {credits} credits, {meta['elapsed_s']} s, session ~${spent():.2f}")


def cmd_balance(_):
    load_env()
    print("tripo", tripo_req("GET", "/user/balance")["balance"], "credits")
    print("meshy", meshy_req("GET", "/balance")["balance"], "credits")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("tripo", "meshy", "tripo-fal"):
        g = sub.add_parser(name)
        g.add_argument("--image")
        g.add_argument("--views", nargs="+", help="tripo: front left back right, - for a missing one. meshy: 1 to 4, front first")
        g.add_argument("--param", action="append", help="key=value, value parsed as JSON when possible")
        g.add_argument("--label")
        g.add_argument("--out", required=True)
        g.set_defaults(func=cmd_run, provider=name)
    g = sub.add_parser("meshy-retexture")
    g.add_argument("--model", required=True)
    g.add_argument("--style-image")
    g.add_argument("--style-text")
    g.add_argument("--param", action="append", help="key=value, value parsed as JSON when possible")
    g.add_argument("--label")
    g.add_argument("--out", required=True)
    g.set_defaults(func=cmd_retexture)
    sub.add_parser("balance").set_defaults(func=cmd_balance)
    a = ap.parse_args()
    a.func(a)


if __name__ == "__main__":
    main()
