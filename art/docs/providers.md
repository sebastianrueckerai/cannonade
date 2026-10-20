# Providers, keys and models

Keys live in the gitignored `.env.tools` at the repo root, one `NAME=value` per line. `.env.example` lists the names. Never print a key. Tools read the file and let it override the shell, because a stale shell key once broke a run in the portfolio repo.

## Which key buys what

| variable in .env.tools | provider | use here | name the SDK expects |
|---|---|---|---|
| FAL_KEY | fal.ai | image generation and editing, image-to-3D (TRELLIS.2, Hunyuan3D, Tripo, Meshy and Rodin endpoints), vision critics through `any-llm/vision` | FAL_KEY |
| REPLICATE_KEY | Replicate | second host for image, video and 3D models | REPLICATE_API_TOKEN |
| TRIPO_KEY | Tripo | image-to-3D direct, low-poly option, rigging | HTTP header |
| MESHY_KEY | Meshy | image-to-3D with a target face count, texture generation | HTTP header |
| ZAI_KEY | Z.AI | GLM vision critic and coding model | HTTP header |

## Role to model

One model per role. Change a row here when a spike shows a better one, and log the change in [process-log.md](process-log.md).

| role | model | via | status |
|---|---|---|---|
| Creative director, prompt writer, Blender coder, first-pass critic | the agent that runs the session | Claude Code | in use |
| Image generation: world frames, asset references, style frames | `google/nano-banana-2.1` with `aspect_ratio` and `resolution: 1K`, 0.15 USD. Best low-poly flat-shaded look and the only one that kept the tile grid. Garbles text | fal | picked in the probe [game/art-direction/rounds/00-model-probe/](../game/art-direction/rounds/00-model-probe), 2026-10-11 |
| Image generation: menu and UI frames, anything with text | `ideogram/v4` with `image_size` and `rendering_speed: BALANCED`, 0.09 USD. Perfect text, clean low poly, but renders a world prompt as an isolated asset | fal | picked in the probe |
| Image generation: cheap breadth | `recraft/v4.1/flash/text-to-image`, 0.007 USD. Clean low poly and perfect text, world scenes come out abstract | fal | picked in the probe |
| Not for low poly | `blackforestlabs/flux-3` paints, `alibaba/qwen-image-3` renders textured 3D and garbles button text | fal | probe |
| Image editing and reference-conditioned generation | `google/nano-banana-2.1/edit`, 0.15 USD. With two or three references and a prompt that says "style references only" it makes a new composition in the reference style and keeps the tile grid, used for the round 02 moodboards. With one frame and a swatch sheet it keeps the composition and moves every surface toward its swatch, but does not hit hex values, used for the round 03 recolours. A literal phrase in the prompt becomes a literal object: "on a sunlit table" put a table in the frame. `blackforestlabs/flux-3/edit-image` is the untested second option | fal | in use since round 02, 2026-10-11 |
| Painted 2D: key art, repaints, title lettering | `google/nano-banana-2.1/edit` at `resolution: 2K`, about 0.25 USD. Paints the store art and letters a title correctly on a flat green screen for keying. Edits keep the composition when asked to change one thing, so a fix is an edit pasted back through a mask. It does not size objects to a grid, whether asked in words or given a block-out as the first image. `ideogram/v4` blocked three harmless title prompts with its safety filter and misspelled one | fal | in use since session 05, 2026-10-12 |
| Inpainting | `fal-ai/flux-lora/inpainting`, 0.035 USD per megapixel rounded up: strength 0.8 to 0.9 removes an object cleanly, 0.6 redraws a painted-over object. `fal-ai/flux-pro/v1/fill`, 0.05 USD per megapixel, ignores a paint-over | fal | session 05 |
| Upscale | `fal-ai/aura-sr`, 4x, for the 3840 px library hero | fal | session 05 |
| Independent vision critic | Gemini 2.5 Pro through fal `any-llm/vision` with `reasoning: true`, 0.03 USD. Its probe verdict matched the session agent's own read on every model. `glm-5v-turbo` through Z.AI is the second critic, in use since the top-up on 2026-10-11. On round 01 it agreed with Gemini on the first and the last two places. GPT-5 through fal any-llm returned 404 the same day. Both return an empty answer when the token budget is short: GLM needs `max_tokens` of 12000, Gemini sometimes needs a rerun with 16000 to 20000 and the images at 1280 to 1536 px. Both claim faults that are not there, so a critic's fault is checked in a crop before it counts. GLM answers 429 when four calls run at once, so the critics run one after another | fal, Z.AI | both in use |
| Image-to-3D baseline | `fal-ai/trellis-2` | fal | untested here |
| Image-to-3D with PBR textures | `fal-ai/hunyuan-3d/v3.1/pro/image-to-3d` | fal | untested here |
| Image-to-3D, the game's models | Meshy API, `meshy-t2` low-poly mode with `target_polycount`, 15 credits textured. Returns parts, hits the face count. No endpoint edits an existing mesh's shape and Meshy Edit is browser-only, so shape variants run through the picture chain (D72) | Meshy | picked in round 18, D36 |
| Image-to-3D, simple shapes only | Tripo API, `smart_low_poly` with `face_limit`, 40 credits. Slower, overshoots the face count 1.3 to 2.3 times, fuses the parts. API credits are bought apart from Tripo Studio | Tripo | round 18, D36: used for trees and rocks until the balance is spent |
| Procedural geometry, repair, render, export | Blender 5.2.2 through `blx` | local | in use, see [blender.md](blender.md) |
| Music: the themes and their versions | `minimax/music-3`, 0.002 USD a second, 44.1 kHz WAV, duration a cap of 1 to 300 s. A lyrics structure of empty section tags (`[verse]`, `[chorus]`) reaches the cap but sings nonsense on half the clips, `[instrumental]` tags alone stop at 10 to 32 s, and sixteen of them sing too: on fal it makes a short instrumental or a long song. `fal-ai/stable-audio-25/text-to-audio` (0.20, `seconds_total` up to 190, instrumental by nature), `fal-ai/lyria3/pro` (0.08, MP3, length by prompt) and `fal-ai/ace-step` (0.0002 a second, `tags` and `lyrics` `[inst]`) ran beside it in round 36. Versions of a picked theme: `fal-ai/ace-step/audio-to-audio` remixes a clip under new tags | fal | probe in round 36, session 31, pick open |
| Sound effects | `fal-ai/elevenlabs/sound-effects/v2` (`text`, `duration_seconds` 0.5 to 22, 0.002 USD a second, MP3) and `mirelo-ai/sfx2.0/text-to-audio` (0.010 a second, WAV, `negative_prompt`) ran in round 37. `fal-ai/stable-audio-3/small/sfx/text-to-audio` ran beside them and is out: six of its twelve impacts came back over full scale and Sebastian called the set terrible (D82) | fal | probe in round 37, pick open between the two |
| Versions of a music clip | `fal-ai/ace-step/audio-to-audio` in `remix` mode keeps the material and takes new tags, no strength control, round 38. `fal-ai/stable-audio-25/audio-to-audio` takes `audio_url`, a prompt and `strength` 0.01 to 1 (0 is the input, 1 ignores it, default 0.8) with `total_seconds` up to 190, untested | fal | round 38 made three, the ear decides |
| Vocals check on a music clip | `fal-ai/whisper` through `audio.py vocals`: the word count of the transcript, a few words for an instrumental | fal | in use since session 31 |

Model IDs on fal change often. Read the endpoint page before a paid run and write the ID you used into the sidecar JSON.

## Image-to-3D, measured on 22 September 2026


LLaMA-Mesh does not work for production. No inference provider deploys it, so there is no API to buy. Its licence, NSCLv1, is non-commercial only. It was trained on 30,000 Objaverse meshes filtered to under 500 faces, and its 8k token cap sets a hard ceiling on output size, so it cannot reach mid-poly at all. It runs locally as an 8B GGUF file. MeshLLM published a paper and no weights.

Image-to-3D through an API is the route that works. fal charges per request with no subscription, one key covers many models, and its Hunyuan endpoint returns OBJ next to GLB, so nothing needs converting before Blender.

Price per generation on fal, read from the endpoint pages on 22 September 2026:

| fal endpoint | USD per run |
|---|---|
| `fal-ai/trellis-2`, 512p | 0.25 |
| `fal-ai/trellis-2`, 1024p | 0.30 |
| `fal-ai/trellis-2`, 1536p | 0.35 |
| `fal-ai/hunyuan-3d/v3.1/pro/image-to-3d` | 0.375 |

Hunyuan adds 0.15 each for PBR materials, multi-view input and a custom face count. fal also carries Rodin 2.5, Tripo H3.1 and Meshy v7, with image and text entry points.

Four fal account facts matter in practice. A new account runs 2 concurrent requests, rising to 40 as credits are bought, and anything over the limit queues rather than fails. Output files live on the CDN for at least 7 days, so download them in the same script or set `X-Fal-Object-Lifecycle-Preference`. Purchased credits expire after 365 days. The account locks when the balance falls under its threshold.

Licensing runs per model, shown as a `Commercial use` or `Research only` badge on the endpoint page. The Hunyuan weights licence grants rights in the worldwide territory excluding the European Union, United Kingdom and South Korea. Check the badge before commercial work from inside those territories. TripoSR and the Microsoft TRELLIS line are MIT with no territory clause.

Direct vendors, when one specific model is wanted. Tripo sells credits at 0.01 USD each, prepaid, with the API billed apart from its consumer plans. Tencent Cloud charges 15 to 30 credits per Hunyuan generation at roughly 0.0135 to 0.015 per credit. Meshy bills 20 credits untextured and 30 textured per image-to-3D, with API access from the Pro tier.

The Hunyuan 2.x line ships open weights and self-hosts for free, but the full version wants more than the 11 GB of VRAM in this machine. At these prices self-hosting only pays above roughly 1500 generations a month.

The pipeline that works: generate from a reference image, import the OBJ, then decimate and remesh in Blender to the target budget. Generated topology never ships as it arrives.

## Music and sound effects, measured on 20 October 2026

The research of session 31 is in [research/ai-audio-providers.md](research/ai-audio-providers.md): every usable
model, where it is sold, what it costs and what its licence allows. The short of it: fal carries everything worth
trying, MiniMax's own API takes no new users, and a whole soundtrack costs under 20 USD on any candidate, so the
ear decides. There is no audio critic on fal's any-llm, so the only independent check is the Whisper transcript
above and the loudness sheet of [audio.py](../pipeline/audio.py).
