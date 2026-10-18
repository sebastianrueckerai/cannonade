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

(the web pass notes land here)

## Limits

From the session plan: 4 directions, gen 1 dies, at most 2 carried forward, cap USD 6, stop 19:00, nothing in the live ui/ slots before the pick.
