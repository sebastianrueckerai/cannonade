# AI music and sound effects: models and where to buy them

Researched on 2026-10-20 for roadmap K5. Prices were read from the vendor pages that day. Four web
research passes fed this page, and the facts that decide the pick were read again on the fal and Google
pages by the session agent.

## Verdict

Everything worth trying runs on fal.ai, so the FAL_KEY already in `.env.tools` buys music and sound
effects without a new account. The whole soundtrack and a few hundred effects cost under 20 USD on any
of the candidates, so price does not decide, the ear does. Run a probe like the image model probe
of round 00: the same three music prompts on four fal endpoints, the same five effect prompts on three
fal endpoints, under 5 USD in total, then pick a row for [providers.md](../providers.md).

Music candidates on fal, in the order to try:

| endpoint | model | USD | length | output | instrumental switch |
|---|---|---|---|---|---|
| `minimax/music-3` | MiniMax Music 3 | 0.002 per second | up to 300 s | 44.1 kHz stereo WAV | none, `lyrics` is required. Put `[instrumental]` on its own line and say "instrumental only, no vocals" in the prompt |
| `fal-ai/stable-audio-25/text-to-audio` | Stable Audio 2.5 | 0.20 per run | up to 3 min | not read | instrumental only, no vocal model |
| `fal-ai/lyria3/pro` | Google Lyria 3 Pro | 0.08 per run | a few minutes | MP3 | prompt only: "Instrumental only, no vocals" |
| `fal-ai/ace-step` | ACE-Step 1.0, Apache-2.0 | 0.0002 per second | about 4 min | not read | prompt |

Sound effect candidates on fal:

| endpoint | model | USD | length | output |
|---|---|---|---|---|
| `fal-ai/elevenlabs/sound-effects/v2` | ElevenLabs SFX v2 | 0.002 per second | 0.1 to 30 s, loop option in the ElevenLabs API | MP3, 48 kHz WAV only without loop |
| `fal-ai/stable-audio-3/small/sfx/text-to-audio` | Stable Audio 3 Small SFX, open weights | 0.0206 per run | not stated | MP3 |
| `mirelo-ai/sfx2.0/text-to-audio` | Mirelo SFX 2.0 | 0.010 per second until 2026-12-13, then 0.015 | not stated | WAV |
| `sonilo/v1.1/text-to-sound-effects` | Sonilo 1.1 | 0.0018 per second | up to 180 s | not read |
| `CassetteAI/sound-effects-generator` | CassetteAI | 0.01 per run | up to 30 s | not read |

Every row above carries fal's "Commercial use" badge. The badge is fal's label, not a licence text.
The MMAudio, ThinkSound and HunyuanVideo-Foley endpoints also sit on fal, but their weights are
non-commercial or research only (MMAudio CC BY-NC 4.0, ThinkSound "Commercial use is NOT permitted"),
and Hunyuan's licence excludes the EU. Do not ship their output.

## MiniMax Music

The current lineup on platform.minimax.io is `music-3.0` (recommended), `music-2.6` and `music-cover`
(a cover from 6 s to 6 min of reference audio). Music 2.5, 2.5+ and 2.0 are discontinued. The API
takes a prompt of up to 2000 characters, lyrics of up to 3500, has an `is_instrumental` flag and a
lyrics optimiser, and returns MP3, WAV or PCM at 16 to 44.1 kHz. The pricing page says 0.15 USD per
track of up to 5 minutes for 3.0 and 2.6.

The direct API is not an option: the pricing page, with a notice dated 2026-08-20, says the platform
"will no longer be available to new users". Existing payers keep access. The free models are being shut
down. The MiniMax Audio consumer app sells subscriptions from 5 USD a month, and a secondary source says
its terms allow personal use only. The terms of service page returned no text, so the API licence
quote comes from a third-party summary: users "retain your ownership rights in Client input and
generated content". That summary is not verified.

Hosts:

| host | endpoint | USD | notes |
|---|---|---|---|
| fal | `minimax/music-3` | 0.002 per second | duration 1 to 300 s as an upper bound, seed, steps, guidance. Commercial use badge |
| fal | `fal-ai/minimax-music/v2.6` | 0.15 per run | prompt only, MP3 |
| fal | `fal-ai/minimax-music/v2` | 0.03 per run | Music 2.0 |
| fal | `fal-ai/minimax-music` | 0.035 per run | v1, 60 s, lyrics up to 400 characters |
| Replicate | `minimax/music-1.5`, `minimax/music-2.6` | not shown | 1.5: 240 s, reference audio 5 to 30 s |
| WaveSpeed | `minimax/music-2.5` | from 0.075 per run | not opened |

MiniMax released Music 3 as open weights on 2026-08-13 (MiniMaxAI/MiniMax-Music3 on Hugging Face).
Its licence allows commercial use under 20 million USD a year of revenue, requires the product to
"prominently display 'MiniMax-Music3' on the user interface", and requires a machine-generated
disclosure on public posts. That credit rules self-hosting out for Cannonade unless the credit is
acceptable on the credits screen. One blog calls it CC BY-NC. The LICENSE file contradicts that.
The VRAM need is not known.

MiniMax has no sound effect model. It sells speech, music and video with sound.

Quality: no independent benchmark covers the 2026 models. A vendor-adjacent review puts Music 3 at
about Suno 3.5 level, with clear vocals and thinner instrumental texture than Suno 5. An earlier
review praised the 2.5+ instrumentals, strings and piano.

## Other hosted music models

| model | does | max length | USD | commercial use | where |
|---|---|---|---|---|---|
| Google Lyria 3.5 | full songs, prompt-steered length, 44.1 kHz stereo, WAV on request, SynthID watermark | a few minutes | 0.08 per song on the Gemini API, no free tier | no Lyria-specific text. A forum thread asks whether the Google APIs terms limit selling output, with no Google answer | Gemini API `lyria-3.5`, a new provider. fal has Lyria 3 Pro at 0.08 and Lyria 2 at 0.10 per 30 s |
| ElevenLabs Music 2.5 | songs or instrumental, composition plan | 5 min | 0.15 per minute direct, 0.80 per minute on fal | the model terms allow "all online and offline commercial use" except film, TV, radio and Studio Games. An indie game is one under 500 000 USD revenue since release, by a developer under 1 million USD a year. Starter to Pro plans are for individuals | ElevenLabs API, fal `fal-ai/elevenlabs/music`, Replicate `elevenlabs/music` |
| Stable Audio 2.5 | instrumental, audio-to-audio, inpainting | 3 min | about 0.08 direct (8 credits), 0.20 on fal | fal badge, direct terms not read | fal, Replicate `stability-ai/stable-audio-2.5` |
| Stable Audio 3.0 | same, open weights | 6 min | 8 or 26 credits, sources disagree | Community Licence, free under 1 million USD revenue, registration needed | Stability API, not on fal or Replicate |
| Mureka 9.5 | lyrics or prompt to song, instrumental | 5.5 min | 0.15 to 0.50 per song, top-ups from 1000 USD | plans include commercial use | Mureka only |
| Beatoven Maestro | instrumental and effects | 2.5 min | about 0.10 on fal, not verified | perpetual licence on downloads | fal `Beatoven/music-generation` |
| Soundraw | instrumental with stems | 5 min | 29.99 USD a month for 100 songs | royalty free, games listed | Soundraw only |
| Suno 6 | songs | | no public API, partner intake since 2026-07-01 | | none |
| Udio | songs | | no API, downloads switched off | | none |

Suno, Udio and the big 2026 entrants give nothing to buy: no music API turned up from OpenAI, Meta,
ByteDance, Tencent, Alibaba, xAI or Kling.

## Other sound effect models

| model | input | max length | USD | commercial use | where |
|---|---|---|---|---|---|
| ElevenLabs SFX v2 | text, duration, loop, prompt influence | 30 s | 0.12 per minute direct, 40 credits per second with a set duration | royalty free on paid plans, attribution on the free plan. Starter 6 USD a month for 150 generations | ElevenLabs API, fal |
| Stable Audio 3 Small SFX | text | not stated | 0.0206 on fal, free self-hosted | Community Licence under 1 million USD, you own the output, training data licensed or Creative Commons | fal, Hugging Face |
| Adobe Firefly SFX | text, reference clip | 30 s, 48 kHz, 4 variants | 10 credits per run, plans from 9.99 USD for 2000 credits | "commercially safe" | Adobe only |
| Kling text-to-audio | text | 10 s | 0.035 on WaveSpeed | not verified | WaveSpeed |
| MOSS-SoundEffect 2.0 | text, 48 kHz | 30 s | free | Apache-2.0 per a blog, repo not read | self-host |
| MMAudio 2, ThinkSound, HunyuanVideo-Foley | video or text | 8 to 30 s | fal 0.001 per second and up | not for a sold game, see above | fal, Replicate |

No vendor has a loop mode for music, and only ElevenLabs has one for effects. Loops get cut to a
beat by hand, and Godot's AudioStreamWAV loop points or an AudioStreamOggVorbis loop flag play them.

## Open weights for self-hosting

The machine has 11 GB of VRAM. RunPod rents more.

| model | does | licence | commercial | VRAM | hosted |
|---|---|---|---|---|---|
| ACE-Step 1.5 (2B, Feb 2026) and 1.5 XL (4B, Apr 2026) | songs, instrumental, lyrics, cover, repaint, LoRA, up to 10 min | MIT, "you can strictly use the generated music for commercial purposes" | yes | under 4 GB with offload for 2B, 12 GB INT8 or 24 GB for XL | Replicate `fishaudio/ace-step-1.5` about 0.05 per run. fal has only 1.0 |
| ACE-Step 1.0 | same without cover and LoRA, 4 min | Apache-2.0 | yes | 8 GB | fal `fal-ai/ace-step` |
| HeartMuLa 3B | songs with lyrics, 4 to 6 min | Apache-2.0 | yes | 24 GB per an affiliated site | none |
| DiffRhythm 1.2 and 2 | songs, instrumental mode, 4 min 45 s | Apache-2.0 | yes | 8 GB chunked | none |
| InspireMusic | instrumental, 30 s or several minutes in the Long model | Apache-2.0 | yes | not stated | none |
| YuE 1 | songs | Apache-2.0 | yes | 16 to 24 GB | fal `fal-ai/yue`, deprecated |
| YuE 2 | songs, covers | CC BY-NC 4.0, companies must ask | no | 24 GB | none |
| Stable Audio Open 1.0 and Small | effects, loops, short music, 47 s or 11 s | Community Licence | yes under 1 million USD | about 12 GB for 1.0, less for Small | fal `fal-ai/stable-audio` |
| MusicGen, AudioGen | music 30 s, effects | weights CC BY-NC 4.0 | no | 8 to 16 GB | Replicate `meta/musicgen` |
| Tencent SongGeneration, LeVo 2 | songs, 4.5 min | academic only | no | 22 GB | WaveSpeed |
| TangoFlux, Tango 2, AudioLDM 2 | effects, 10 s | non-commercial | no | | Replicate `declare-lab/tango` |
| MiniMax-Music3 | songs, 5 min | MiniMax Community License, UI credit required | yes with the credit, under 20 million USD | not known | none |

Quality: the only human-voted board, CMU Music Arena of September 2025, predates the 2026 models and
put ACE-Step 1.0 fifth for vocals. ACE-Step 1.5 claims to beat Suno 5 on SongEval with its own
numbers. HeartMuLa's own test puts it ahead of YuE. One reviewer found HeartMuLa generic across styles.

## Not verified

- The MiniMax API terms: the page returned no text. The ownership quote is a third-party summary.
- Replicate prices: the pages show GPU-time estimates or nothing.
- Stable Audio 3.0 credits per run, 8 or 26.
- The Starter and Creator media rights cells of the ElevenLabs Music terms table.
- The Lyria output licence under the Google APIs terms.
- The Beatoven fal price and licence. The Mureka API terms. The MOSS licence from its repo.
- Max lengths and output formats of the fal effects endpoints marked "not read".
- No listening test of any model against the game. The probe does that.
