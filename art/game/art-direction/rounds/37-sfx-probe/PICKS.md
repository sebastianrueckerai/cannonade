# Picks, round 37: sound effects

Twelve cues on three fal endpoints in `round.json`, then more cannon shots in `cannons.json` and
`cannons-more.json`, then stone crumbles and placing sounds in `crumble-place.json`, all on one page,
[index.html](index.html). 74 clips, 0.80 USD. Stable Audio 3 Small ran in the first set and is out
(D82). ElevenLabs made one take per prompt, Mirelo two.

Sebastian, 2026-10-20, on the page, the page open in his tabs:

| clip | his word | becomes |
|---|---|---|
| sfx-castle-claim--eleven | "That's ok" | `castle_claimed` |
| sfx-draw-piece--eleven | listed without a word, taken as a pick | `draw_piece` |
| sfx-heavy-shot--eleven | "This is shit, sounds like a faint drum beat" | out |
| boom-big--eleven | "Great, use it! Make two variants for variety" | `heavy_1`, with `heavy_2` and `heavy_3` from two more takes of the same prompt |
| boom-normal--eleven | "Great, use it!" | `cannon_1` |
| boom-normal--mirelo-1, -2 | "Also good, use so we have variety, but make sure the levels of these and the other one are similar" | `cannon_2`, `cannon_3`, levelled with `cannon_1` |
| sfx-ui-click--mirelo | "use this" | `ui_click`, UI bus |
| sfx-ship-sink--eleven | "and this" | `ship_sink` |
| sfx-place-piece--eleven, sfx-place-invalid--eleven | "and these" | `place_piece`, `place_invalid` |
| sfx-phase-horn--eleven | "use" | `horn_battle` |
| sfx-hit-water--eleven | "use" | `hit_water` |
| the first crumbles | "most sound more like stone blocks crumbling" wanted, so four stone angles came in `crumble-place.json` | out |
| crunch-crumble--eleven, crunch-crumble--mirelo-1, -2 | "Those 3 can be used for things crumbling (walls, castle)" | `crumble_1`, `crumble_2`, `crumble_3` |
| the first cannon shots | "not great", wanted umpf: `cannons.json` with four angles, a normal and a big gun | picked above |

"Eleven seems to be the best so far."

The picks are game assets in [game/assets/audio/](../../assets/audio) and copies in the game's
[assets/audio/](/home/womb/repos/grid-cannons/assets/audio), made by `audio.py final`: silence cut at
both ends, the loudest 400 ms at -16 LUFS (UI -22), peaks under -1 dBTP, 44.1 kHz 16-bit WAV, a sidecar
naming the source clip. Decision D83.

Open on this page: a placing sound from the stone sets if the wooden one should go, and the rest of the A list.
