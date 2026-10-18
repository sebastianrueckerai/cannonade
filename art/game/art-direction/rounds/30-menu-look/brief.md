# Round 30: the menu's look

Session plan: [14-menu-look.md](../../../docs/sessions/14-menu-look.md). What the round designs: the menu's **font family**, the **panel and button material and shape**, and **texture use**. The menu's structure (which buttons exist, their order, the help overlay) is the web-menu thread's, not this round's.

## Parts

1. Font family — one face on every menu control, the bible's one-family rule. 16 px floor, sentence case.
2. Panel material and shape — what the button column sits on: flat cream with the bible's 3 px corner cut and 2 px ui_dark outline, or a painted surface.
3. Button treatment — the button face as its own object (board, card, plaque), its normal state now, hover and pressed derived by [Art.gd](/home/womb/repos/grid-cannons/scripts/Art.gd) until the pick.
4. Accent use — ui_accent #c8322d stays on one action only; candidates show where that line sits on buttons.

## Fixed

The logo, [menu_background.png](/home/womb/repos/grid-cannons/assets/art/ui/menu_background.png), the palette ui colours (ui_light #fbefd9, ui_dark #3a2e28, ui_accent #c8322d, wood #7a4a2e), sentence case, text sits on a panel never on the board, panels at the window edge, 2D surfaces are painted illustration never an edit of the game's render (D24), the real menu scene at 1280 by 720 and 390 wide as the review unit, no change to Menu.gd or menu.tscn.

## Directions

- **a painted wooden sign** — a harbour board: planks or one board per button, wood #7a4a2e family, painted lettering light on wood or dark on a painted band, the logo language extended into the UI. Font: IM Fell English or Alegreya.
- **b harbour chart** — cream ui_light panel like an aged chart, ink ui_dark linework, a corner-cut edge, wax-red accent. Font: Alegreya.
- **c bible-literal flat** — the control: flat cream panel, 3 px corner cut, 2 px ui_dark outline, flat button faces. Texture none. Font: Signika.
- **d carved painted panel** — warm dark carved wood relief, light lettering, the cozy-shop-front look. Font: Metamorphous.

## Questions the candidates answer

Does a wooden sign read as cozy next to the painted background, or as a second painting fighting the first (D24)? Which font holds at 390 px wide (D4)? Does the texture survive 9-slice stretching, corners intact, middle quiet enough for text? Does the accent stay singular when buttons have their own colour?

## References

The web pass (2026-10-18) gave the genre pattern rather than per-game captures — interfaceingame's per-game pages 404 for both titles probed. The pattern, from the [cozy UI asset collections](https://itch.io/game-assets/tag-cozy/tag-user-interface) and the [painted-menu pin boards](https://fi.pinterest.com/jhtakalo/menus-ui): wooden boards as the button container, warm light, rounded organic shapes, one accent. From genre knowledge, the comparables to name: Songs of Conquest (painted parchment panels, warm book serif), Northgard (quiet flat panels over a painted ground, texture nearly absent), Kingdoms and Castles (light, flat, toy-like, no wood). Wood is the common risk: it texture-loads the screen fast.

The stronger references are in-house: the logo language from the round 06 painted-sign study (cream lettering, dark outline, warm offset shadow, now [logo.png](/home/womb/repos/grid-cannons/assets/art/ui/logo.png)), the painted [menu background](/home/womb/repos/grid-cannons/assets/art/ui/menu_background.png), bible chapter 5 (ui_light panels, corner cut, ui_dark outline), D24 (painted illustration, never a render edit), and the style anchors [marketing_style.png](../anchors/marketing_style.png) and [world_style.png](../anchors/world_style.png) as texture style refs for generation.

## Limits

From the session plan: 4 directions, gen 1 dies, at most 2 carried forward, cap USD 6, stop 19:00, nothing in the live ui/ slots before the pick.
