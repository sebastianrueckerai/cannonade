# Blender with an AI agent

Notes from the setup on 22 September 2026. Every number here was measured on this machine.

## What is installed

The setup has two halves and both are needed.

The add-on runs inside Blender. It came from the lab.blender.org extension repository and sits in `~/.config/blender/<version>/extensions/lab_blender_org/mcp`. It needs Blender 5.1 or newer. It opens a TCP server on `localhost:9876`. Auto Start is on, so the socket comes up a few seconds after Blender opens.

The MCP server runs as a separate process. It went on with:

```bash
uv tool install "git+https://projects.blender.org/lab/blender_mcp.git#subdirectory=mcp"
```

That puts `blender-mcp` on PATH. It speaks MCP over stdio, or over HTTP with `--transport http --port N`.

`blx` also sits on PATH. It sends a Python file straight to the add-on socket and prints the `result` dict as JSON.

Blender 5.2.2 is at `~/Applications/blender-5.2.2-linux-x64/blender`.

## Running Blender

With a window, the add-on starts the socket on its own.

Without a window: `blender --background --command blender_mcp`. Renders work in that mode. Screenshots do not.

## MCP server or direct socket

For modelling, the direct socket wins. For picking apart a file somebody else built, the MCP server wins.

The add-on is the engine. It listens on port 9876, takes a JSON message holding Python code, runs that code inside Blender, and returns whatever the code assigned to `result`. The `blender-mcp` process is a relay. It speaks MCP to the agent on one side and that same socket on the other. Its socket code is twenty lines. `blx` is those twenty lines as a command.

What the relay adds is mostly names. Of its 26 tools, 16 plus their command-line twins send pre-written Python over that socket. Three read bundled documentation and never touch Blender. One, `execute_blender_code`, passes the agent's own Python through, which is what `blx` does without the relay.

What the relay costs is fixed. The tool schemas and the server instructions enter the agent's context at every session start, which is 7600 tokens before any work happens. Per call the two routes cost about the same, because a tool call carrying code and a shell command carrying code are the same size.

What the direct socket gives up is one thing. The screenshot tools hand the agent a PNG inline. `blx` writes a PNG to disk and the agent reads it in a second step. In Claude Code those are the same. On a harness that cannot read an image file they are not.

Three documentation tools come with the server and cost more than reading the files. The files sit at `~/.local/share/uv/tools/blender-mcp/lib/python3.12/site-packages/blmcp/data`, 1942 for the API and 2358 for the manual. `search_api_docs` on the single word "bevel" cost 6400 tokens. `awk` on the same file returned the signature for 91. The server's own instructions tell the model to read those files directly.

On Pi the question does not arise, because Pi has no MCP support.

## Making meshes

The model writes bpy and bmesh code and reads back numbers. It never needs to see vertices, and the server has no mesh tool anyway. Geometry comes back only through code the model writes. It reasons in parameters, not coordinates.

A mid-poly rock at 98 vertices and 0 non-manifold edges:

```python
import bpy, bmesh
from mathutils import noise
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0)
ob = bpy.context.active_object
bm = bmesh.new(); bm.from_mesh(ob.data)
for v in bm.verts:
    v.co += v.normal * (noise.noise(v.co * 1.7) * 0.35 + noise.noise(v.co * 4.0) * 0.12)
    v.co.z *= 0.65
bm.to_mesh(ob.data); bm.free()
m = ob.modifiers.new("Decimate", "DECIMATE"); m.ratio = 0.6
bpy.ops.object.modifier_apply(modifier="Decimate")
```

A chair at 48 base vertices is six scaled cubes, each with a 0.01 bevel modifier, joined. Boxes plus bevel plus a join covers most hard-surface furniture.

Reference images go in as ordinary image input. A separate sketch step buys nothing, because the script is the plan.

## Checking a result

Three ways, cheapest first. Most checks end at the first one.

1. Numbers. Dimensions, vertex and face counts, non-manifold edge count, bounding box, evaluated poly count from the depsgraph, symmetry error. Tens of tokens.
2. A small render. Workbench, matcap, cavity on, 320 to 640 pixels wide. 100 to 350 image tokens. Four camera angles composed into one image with `imbuf` beat four separate renders.
3. A viewport screenshot. It needs a window, costs the same as a render, and shows the interface as well. Worth it only for edit mode and wireframe questions.

```python
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "MATCAP"
sc.display.shading.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = 640, 400
sc.render.filepath = "/tmp/check.png"
bpy.ops.render.render(write_still=True)
```

## What things cost

Measured on Blender 5.2.2 through a stdio client. The two session-start rows are the whole difference between the two routes:

| item | tokens |
|---|---|
| tool schemas at session start | 6100 |
| server instructions at session start | 1500 |
| one code call returning a small dict | 35 to 90 |
| scene summary, 4 objects | 565 |
| 12 sampled vertices, rounded | 210 |
| get_python_api_docs, exact identifier | 660 |
| search_api_docs, one word | 6400 |
| 320x240 render, image cost | 100 |
| 3D viewport screenshot, 670x438 | 390 |
| get_screenshot_of_window_as_json | 1140 |

Four habits follow from that table. Vertex arrays never go into the conversation. An exact identifier lookup replaces a search. Renders stay small. Scripts live as files and get re-run instead of being written again in chat.

## Harness setup

Claude Code reads a `.mcp.json` in the project, or the same block under `mcpServers` in `~/.claude.json`. The config does not depend on the model, so Z.AI behind Claude Code works unchanged.

```json
{"mcpServers": {"blender": {"command": "blender-mcp", "args": [], "env": {}}}}
```

Hermes takes the same thing under `mcp_servers` in `~/.hermes/config.yaml`. `hermes import-agent claude-code` copies it across.

Pi refuses MCP by design. Use `blx` with a short skill file, or wrap the server with `mcporter`.

## Gotchas

- The server's own instructions call code execution a last resort. That is right for inspecting a scene and wrong for modelling.
- `render_thumbnail_to_path` ignores the path given to it and writes into a Blender temp directory. Read the `filepath` it returns.
- `get_screenshot_of_*` fail in background mode. In a window they work. `size_limit_in_bytes` caps bytes and not pixels, and the add-on halves the image until it fits, so a small limit is the way to ask for a rough look.
- Executed code must assign a dict to `result`. Anything else returns an error.
- `bpy_prop_collection` rejects a slice step. Use `list(obj.data.vertices)[::n]`, not `obj.data.vertices[::n]`.
- The add-on blocks `wm.quit_blender`, the factory-reset operators and `sys.exit`. Nothing else is sandboxed. This runs arbitrary code with full access to the filesystem.
- Apply scale before booleans and physics. Non-uniform scale breaks both.
- Update the depsgraph before reading computed values such as world matrices or modifier results.
- A point-inside-mesh test by nearest face and its normal fails on generated meshes: Meshy's open UV seams and flipped faces put points a metre "inside". Measure clearance by geometry instead, such as a part's lowest point against the top of the part below, or sampled points against a known radius.
- The headless Blender behind the socket can die between calls (session 12). `blx` then fails with a refused connection. Restart it with `blender --background --command blender_mcp` and wait for port 9876.
