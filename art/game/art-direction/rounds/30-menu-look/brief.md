# Round 30: the menu's look

Session plan: [14-menu-look.md](../../../docs/sessions/14-menu-look.md). What the round designs: the menu's **font family**, the **panel and button material and shape**, and **texture use**. The menu's structure (which buttons exist, their order, the help overlay) is the web-menu thread's, not this round's.

## Parts

1. Font family — one face on every menu control, the bible's one-family rule. 16 px floor, sentence case.
2. Panel material and shape — what the button column sits on: flat cream with the bible's 3 px corner cut and 2 px ui_dark outline, or a painted surface.
3. Button treatment — the button face as its own object (board, card, plaque), its normal state now, hover and pressed derived by [Art.gd](/home/womb/repos/cannonade/scripts/Art.gd) until the pick.
4. Accent use — ui_accent #c8322d stays on one action only; candidates show where that line sits on buttons.

## Fixed

The logo, [menu_background.png](/home/womb/repos/cannonade/assets/art/ui/menu_background.png), the palette ui colours (ui_light #fbefd9, ui_dark #3a2e28, ui_accent #c8322d, wood #7a4a2e), sentence case, text sits on a panel never on the board, panels at the window edge, 2D surfaces are painted illustration never an edit of the game's render (D24), the real menu scene at 1280 by 720 and 390 wide as the review unit, no change to Menu.gd or menu.tscn.

## Directions

- **a painted wooden sign** — a harbour board: planks or one board per button, wood #7a4a2e family, painted lettering light on wood or dark on a painted band, the logo language extended into the UI. Font: IM Fell English or Alegreya.
- **b harbour chart** — cream ui_light panel like an aged chart, ink ui_dark linework, a corner-cut edge, wax-red accent. Font: Alegreya.
- **c bible-literal flat** — the control: flat cream panel, 3 px corner cut, 2 px ui_dark outline, flat button faces. Texture none. Font: Signika.
- **d carved painted panel** — warm dark carved wood relief, light lettering, the cozy-shop-front look. Font: Metamorphous.

## Questions the candidates answer

Does a wooden sign read as cozy next to the painted background, or as a second painting fighting the first (D24)? Which font holds at 390 px wide (D4)? Does the texture survive 9-slice stretching, corners intact, middle quiet enough for text? Does the accent stay singular when buttons have their own colour?

## References

The web pass (2026-10-18) gave the genre pattern rather than per-game captures — interfaceingame's per-game pages 404 for both titles probed. The pattern, from the [cozy UI asset collections](https://itch.io/game-assets/tag-cozy/tag-user-interface) and the [painted-menu pin boards](https://fi.pinterest.com/jhtakalo/menus-ui): wooden boards as the button container, warm light, rounded organic shapes, one accent. From genre knowledge, the comparables to name: Songs of Conquest (painted parchment panels, warm book serif), Northgard (quiet flat panels over a painted ground, texture nearly absent), Kingdoms and Castles (light, flat, toy-like, no wood). Wood is the common risk: it texture-loads the screen fast.

The stronger references are in-house: the logo language from the round 06 painted-sign study (cream lettering, dark outline, warm offset shadow, now [logo.png](/home/womb/repos/cannonade/assets/art/ui/logo.png)), the painted [menu background](/home/womb/repos/cannonade/assets/art/ui/menu_background.png), bible chapter 5 (ui_light panels, corner cut, ui_dark outline), D24 (painted illustration, never a render edit), and the style anchors [marketing_style.png](../anchors/marketing_style.png) and [world_style.png](../anchors/world_style.png) as texture style refs for generation.

## Limits

From the session plan: 4 directions, gen 1 dies, at most 2 carried forward, cap USD 6, stop 19:00, nothing in the live ui/ slots before the pick.

## Gen 1 verdict (critics: gemini + glm, cross-checked on native-res crops)

Carried to gen 2: **a** (paint it flatter and brighter, plainer centres) and **b** (ink-outline the buttons, lift the sheet off the background). **d dies**: measured — cream-on-dark text low contrast, frames eat a quarter of the 44 px button, "Practice" label clipped at 390, carved frame busy; both critics call it a different genre. **c stays the fallback only**: perfect legibility, no theme; critics call it pasted-on (it is the bible-literal control, that is its job).

Claims that failed the crop check and were dropped: all four titles drown (montage artefact — titles are cream on their panel, legible), a black rectangle behind d's buttons (the panel frame, no defect), b's text is light grey (it is ink; the real b defect is the pale button outline).

Gen 2 learnings baked into the prompts: wood as flat 3-tone painted illustration (base #8b5a2b, highlight #a67c52, shadow #5c3d1e), knots and seams only in the frame band, never the stretched middle 60 %; brighter than walnut so the menu is not a dark hole over the harbour; no nails, rope or bevels; parchment buttons get a solid 2–3 px ink outline so they read as pressable; the chart sheet gets the logo's language — thin ink line plus a warm hard-edged shadow band around it; a faint compass-rose watermark in one corner only. Title painted onto the sign and a wax-seal accent are Menu.gd work, out of this round's scope (noted for the session plan's result).

## Gen 2 outcome

Four regens beyond the first pass (both buttons regenerated edge-to-edge — gen-1's cream
backdrop margins and b's doubled inner line were the two defect classes), a-panel's 40 px
backdrop cropped deterministically in the builder, panel content padding 20→12 px vertical so
all seven buttons sit above the fold at 390 (pixel-verified: last bottom y ≈ 695 of 720).
Both critics on the final board independently ship **b, the harbour chart**; **a** is the
atmospheric runner-up with the known contrast cost (cream on oak) and one knot in the panel
frame. Boards and verified facts in [PICKS.md](PICKS.md); awaiting Sebastian's pick.
