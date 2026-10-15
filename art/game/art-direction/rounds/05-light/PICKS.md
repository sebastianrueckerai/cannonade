# Picks, round 05: lighting and atmosphere

The colour anchor redrawn at the picked shape rules of D22, then relit five times, so the comparison is light, sky, fog and water only. One sheet: [picks-sheet.jpg](picks-sheet.jpg), numbered 1 to 6. [light-13px.png](light-13px.png) shows the six at the game's default view, a tile 24.7 px wide, magnified four times. The candidate numbers per variant are in [lighting_rules.yaml](../../lighting_rules.yaml), the pick fills `picked` and becomes the game's WorldEnvironment and every preview render.

| | sun | shadows | sky and fog | sea |
|---|---|---|---|---|
| 1 noon | high, 70 degrees | short, hard | clear, no fog | flat blue |
| 2 morning | low left, 25 degrees | long, soft | haze at the horizon | calm, a sparkle |
| 3 afternoon | front right, 45 degrees | medium | cream fog band at the horizon | flat blue, foam line |
| 4 fogged | high, 70 degrees | short | depth fog from mid-board to cream | fades into the fog |
| 5 overcast | none | none | grey-blue, flat | flat matte |
| 6 evening | low right, 15 degrees | long, warm | orange and pink | reflects the sky in streaks |

Critics: Gemini ranks 1, 3, 2, 4, 6, 5, GLM ranks 1, 3, 2, 6, 4, 5. Both put noon first for readability and afternoon second for readability with mood, both say 5 loses the wall base against the sand with no shadow and 4 eats the far tiles the player builds on. The director ranks 3, 1, 2, 4, 5, 6, see [notes.md](notes.md): the afternoon light keeps every edge of noon and adds the warmth the brief asks for. Your pick is the decision and goes into [docs/decisions.md](../../../../docs/decisions.md), into [lighting_rules.yaml](../../lighting_rules.yaml) and, as the picked frame, into [world_style.png](../../anchors/world_style.png), the one frame every downstream prompt attaches.

## Pick one lighting, by number

- [ ] 1 noon
- [ ] 2 morning
- [x] 3 afternoon
- [ ] 4 fogged
- [ ] 5 overcast
- [ ] 6 evening
- [ ] correction: ______ (sun angle, shadow strength, fog depth or water, in words or numbers)

## Pick

Sebastian, 11 October: 3, afternoon, no correction. Decision D23. Both critics had 3 second after noon, the director first.

## Comments
