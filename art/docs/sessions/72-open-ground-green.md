# 72 — Open ground grass on every board

Sebastian, 2026-10-23: "Hm, the ground color seems to change,. often it is green but sometimes I get sand
colored. MAke it all green!"

## Design

1. [Map.gd](../../../scripts/components/Map.gd)'s `_randomize_colors` drew one of two open-ground
   families per board, sand (#f0c975) or grass (#8fbf3c); some boards came out sand. The arrays hold
   the grass pair alone now. The `U.rint` draw stays: it feeds the shared map-build stream, and every
   seeded board keeps its layout, only the ground hue changes.
2. The stamped mud inside walls (D70's paving pair) and the water keep their colours: his complaint is
   the board-to-board flip, not the wall floors.
3. Guard in [walls_test.gd](../../../tests/walls_test.gd), the ground-colour home: on the built board
   every non-water tile's open colour is grass family (green over red). Red watch: the arrays pinned
   to sand fails it everywhere.

## Steps

1. Map.gd: one grass pair, comment fixed.
2. walls_test guard, red-watch with sand forced.
3. Suite green, a before/after render of a board that drew sand, merge by push.

## Ticks

- [x] I118, D99
