import json

import bmesh

from .geo import anchor, bbox, parts, tri_count


def solidity(objs):
    # closed volume over convex hull: a solid lands near 0.5 to 1.0, a cluster of flat
    # planes near 0. The session 08 card-cluster bushes passed every other check.
    vol = hull_vol = 0.0
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        vol += abs(bm.calc_volume())
        hull = bmesh.new()
        for v in bm.verts:
            hull.verts.new(v.co)
        bmesh.ops.convex_hull(hull, input=hull.verts)
        hull_vol += abs(hull.calc_volume())
        bm.free()
        hull.free()
    return round(vol / hull_vol, 3) if hull_vol > 1e-9 else 0.0


def run(asset, asset_dir):
    objs = parts(asset)
    per_part = {}
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()
        per_part[o.name] = {
            "verts": len(o.data.vertices),
            "tris": tri_count(o),
            "non_manifold_edges": non_manifold,
            "materials": [m.name for m in o.data.materials if m],
            "origin": [round(c, 4) for c in o.location],
        }
    lo, hi = bbox(objs)
    dims = [round(hi[i] - lo[i], 4) for i in range(3)]
    rep = {
        "asset_id": asset["asset_id"],
        "parts": per_part,
        "verts": sum(p["verts"] for p in per_part.values()),
        "tris": sum(p["tris"] for p in per_part.values()),
        "non_manifold_edges": sum(p["non_manifold_edges"] for p in per_part.values()),
        "materials": sorted({m for p in per_part.values() for m in p["materials"]}),
        "dims_m": dims,
        "bbox_min": [round(c, 4) for c in lo],
        "bbox_max": [round(c, 4) for c in hi],
        "solidity": solidity(objs),
    }
    fails = []
    d = asset.get("dimensions", {})
    for axis, i in (("max_x", 0), ("max_y", 1), ("max_z", 2)):
        if d.get(axis) is not None and dims[i] > d[axis] + 1e-3:
            fails.append(f"{axis}: {dims[i]} > {d[axis]}")
    b = asset.get("budget", {})
    if b.get("max_tris") and rep["tris"] > b["max_tris"]:
        fails.append(f"tris: {rep['tris']} > {b['max_tris']}")
    if b.get("min_solidity") is not None and rep["solidity"] < b["min_solidity"]:
        fails.append(f"solidity: {rep['solidity']} < {b['min_solidity']}")
    if b.get("max_materials") and len(rep["materials"]) > b["max_materials"]:
        fails.append(f"materials: {len(rep['materials'])} > {b['max_materials']}")
    if rep["non_manifold_edges"] and asset["route"] == "procedural":
        fails.append(f"non_manifold_edges: {rep['non_manifold_edges']}")
    if asset.get("pivots", {}).get("origin") == "ground_centre":
        rlo, rhi = bbox(anchor(asset, objs))
        if abs(rlo.z) > 1e-3 or abs(rlo.x + rhi.x) > 2e-3 or abs(rlo.y + rhi.y) > 2e-3:
            fails.append(f"origin not at ground centre: bbox_min {rep['bbox_min']} bbox_max {rep['bbox_max']}")
    rep["limits_ok"] = not fails
    rep["limit_failures"] = fails
    with open(asset_dir + "/report.json", "w") as f:
        json.dump(rep, f, indent=2)
        f.write("\n")
    return rep
