# Session 31: music and sound effects, the first probe

Sebastian, 2026-10-20: "I am looking into making music and sound effects for the game with AI. Research
MiniMax Music and other models, see where I can buy them, maybe even the providers I already have." Then:
"Make a list of sound effects needed for the game. Also music: I want one song (no lyrics) for the
shooting and one for the building round, a menu music and win and lose screen music. Win, lose and menu
can be versions of one of the main themes. I am leaning towards chip tune music, but if you want to go a
few other directions, give it a try. I am curious to see what the models can do and what you can come up
with. But it should fit the game and setting or at least not clash with it. For sound effects the usual:
shooting, impact, placing, crumbling."

Roadmap: K5. Cap: 10 USD. Spent: about 6.5 USD.

## Deliverables and what they feed

| deliverable | why | feeds |
|---|---|---|
| [research/ai-audio-providers.md](../research/ai-audio-providers.md) | which models exist, where they are sold, what their licences allow | the model rows in [providers.md](../providers.md) |
| [sound.md](../../game/design/sound.md) | the cue list: five music cues and 54 effect sets, each with the function that fires it | the Godot integration, the next rounds |
| [audio.py](../../pipeline/audio.py) | music and effects through fal's queue, a round runner, a loudness sheet, a Whisper vocals check | every audio round |
| round [36-music-probe](../../game/art-direction/rounds/36-music-probe) | four directions times two themes on four models, 40 clips | Sebastian's pick of a direction and a model |
| round [37-sfx-probe](../../game/art-direction/rounds/37-sfx-probe) | twelve cues on three models, 36 clips | the pick of an effects model |
| round [38-theme-versions](../../game/art-direction/rounds/38-theme-versions) | menu, win and lose as remixes of one build theme | the way the versions get made |
| stage 02D in [overview.md](../process/overview.md) | sound joins the process chart | the process |

## How to listen

Each round folder has an `index.html` with a player per clip, the prompt under it, and a `sheet.md`
with the numbers. Open the three pages in a browser from the folder:
[36-music-probe/index.html](../../game/art-direction/rounds/36-music-probe/index.html),
[37-sfx-probe/index.html](../../game/art-direction/rounds/37-sfx-probe/index.html),
[38-theme-versions/index.html](../../game/art-direction/rounds/38-theme-versions/index.html).
The clips stay on disk and out of git. Every clip has a sidecar with the model, the prompt, the
parameters, the seed and the cost, so a clip can be made again.

## The music probe, round 36

Four directions, two themes each, the same prompt on four fal endpoints. The prompt follows MiniMax's
structured caption: genre, tempo, key, mood, arrangement, "instrumental only, no vocals" first.

| direction | what |
|---|---|
| chip | chiptune: two pulse leads, triangle bass, noise drums. Sebastian's lean |
| toybox | toy-box folk orchestra: whistle, fiddle, accordion, marimba, glockenspiel, pizzicato, woodblock |
| organ | fairground band organ with snare, bass drum and bells: the shooting gallery |
| chipfolk | chiptune lead over accordion, fiddle, banjo and hand drums: a sea shanty with an 8-bit edge |

What the numbers say before anyone listened:

| model | clips | seconds | LUFS | words in the Whisper check | USD per clip |
|---|---|---|---|---|---|
| Stable Audio 2.5 | 8 | 90.0 each | -10.7 to -15.8 | 0 to 3 | 0.20 |
| Lyria 3 Pro | 8 | 86 to 91 | -10.7 to -12.2 | 0 to 5 | 0.08 |
| ACE-Step 1.0 | 8 | 89.9 each | -8.9 to -17.0 | 0 to 6 | 0.018 |
| MiniMax Music 3, `[instrumental]` lyrics | 8 | 9.9 to 24.1 | -12.9 to -15.3 | 0 to 1 | 0.18 |
| MiniMax Music 3, empty song tags | 8 | 90.1 each | -13.3 to -16.6 | 1 on four, 39 to 297 on four | 0.18 |

Whisper on an instrumental returns one to six words of its own filler ("Thank you", "Tata"), so the
threshold is about ten. Everything from Stable Audio, Lyria and ACE-Step came back instrumental.
MiniMax has no instrumental switch on fal, and its clip ends where the lyrics structure ends: six
`[instrumental]` tags gave 32 s, a structure of empty `[verse]` and `[chorus]` tags gave 90 s but sung
nonsense on four of eight clips, and sixteen `[instrumental]` tags gave 76 s with 452 words of sung
letters. The three tests are in the `length` folder of the round. On fal, MiniMax makes a short
instrumental or a long song, not a long instrumental.
MiniMax is the only one of the four that returns 44.1 kHz WAV, the others return WAV or MP3 at their
own rates. No clip is a seamless loop, all four end or fade, so the loop gets cut on a bar line by hand.

The ear is the critic. There is no audio critic on fal's any-llm, so this session had no second
judge beyond the numbers, and the pick is Sebastian's.

## The effects probe, round 37

Twelve cues, one prompt each in the toy register of the bible, on three fal endpoints. Durations set
per cue, 0.5 to 2 s.

| model | clips | LUFS | true peak dBTP | USD per clip | note |
|---|---|---|---|---|---|
| ElevenLabs SFX v2 | 12 | -6 to -28 | -9 to +1.4 | 0.001 to 0.004 | takes a duration from 0.5 s, MP3, the loop option exists |
| Mirelo SFX 2.0 | 12 | -11 to -41 | -1.0 on every clip | 0.003 to 0.020 | WAV, peak-limited, takes a negative prompt |
| Stable Audio 3 Small SFX | 12 | +4.9 to -34 | +7.4 to -14.6 | 0.021 | WAV, minimum 1 s. Six impacts sit above full scale and clip |

Every clip gets normalised to its bus level before it enters the game, so the levels above do not
decide. The clipped Stable Audio clips do: a clip over 0 dBTP has lost its peaks already.

## The versions, round 38

The menu, win and lose cues as remixes of one build theme through `fal-ai/ace-step/audio-to-audio`,
remix mode, 0.0002 USD a second. The source was the chiptune build theme from Stable Audio 2.5, picked
by its numbers (90 s, 0 words). The menu remixed the whole clip under "slow, soft, music box, sparse,
84 BPM, no drums". Win and lose remixed its first 16 s with a fade under "triumphant fanfare" and
"slow, minor, sad, sparse". All three came back instrumental, 0 to 4 words, at the source's length.
The endpoint refuses a clip as a data URI with a 500, so [audio.py](../../pipeline/audio.py) uploads
the reference to fal's storage first.

Whether a remix keeps enough of the theme to count as a version is a question for the ear. The other
routes are MiniMax's cover model on the direct API, which takes no new users, or a tracker by hand on
the chosen chiptune theme.

## Findings for the process

- A music round costs 2 to 5 USD and an effects round under 1 USD, so breadth is free. The expensive
  part is the listening.
- Numbers before ears: the sheet catches the short clips, the clipped clips and the sung clips before
  a minute of listening is spent.
- An endpoint's minimum length and its duration field differ per model: ElevenLabs 0.5 s, Stable
  Audio 3 Small 1 s, MiniMax a cap the song structure fills.

## Open, for Sebastian

1. A direction: chip, toybox, organ or chipfolk, from round 36. The question is which fits the painted
   toy fortress and does not clash, and whether chiptune reads as Cannonade or as a different game.
2. A music model for the two themes. By the numbers Stable Audio 2.5 and Lyria 3 Pro deliver 90 s
   instrumentals every time, ACE-Step is the cheapest, MiniMax is the only WAV but sings or stops short.
3. An effects model: ElevenLabs by its duration control and loop option, Mirelo by its clean peaks, or
   Stable Audio 3 Small once normalised.
4. Whether the ACE-Step remixes of round 38 count as versions of the theme.

The picks go into decisions.md as D82 and following, then round 39 makes the five cues and the A-list
effects on the picked models, and the Godot side follows: three buses, the hooks of the cue list.
