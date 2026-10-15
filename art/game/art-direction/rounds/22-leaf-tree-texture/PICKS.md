# Round 22 — leaf tree texture (B6)

Question: one leaf-tree mesh (nature_build, seed 21), two material paths.

- Column A — flat palette bands: palette.json leaf #3d7f34 / wood #7a4a2e, hard boundary. The D5 default look.
- Column B — painted texture: D44 storybook stops, contact shadow with scalloped edge, crease, brush noise, dabs, bark dashes. Round 7 final paint of b6_variants.py.

Board: b6-board.png, composed with PIL from Blender renders (full 448x672, crown and base 560x560, seam strips 300x672 = cols 205-355 / rows .08-.68 of the 560px seam view at 2x) and in-game crops (186x224 window at 3x, both from the same seeded shot: `--mode=single --seed=1 --look=0,6 --zoom=6`, variant made deterministic by parking the other GLB, window at px 445-631 / 154-378). Procedural board, no provider call, no sidecar JSON.

## Pick

Board 1, column B (painted texture) — Sebastian, 2026-10-13. Recorded as D49. The flat palette path is deleted; C5 ports the painted path into nature_build.py for all nine looks.

## C5 gate

Board: c5-gate-board.png. Nine looks on the D49 painted path, magnified per D48, grove crop at the bottom. Gemini critic first: GATE: PASS (critique/c5-gate-board.json).
Recipe: per asset a whole 3/4 ortho view (tree 2.3 / bush 1.15 / boulder 1.25, az 35, el 18) and a close-up (tree crown 0.85 at 55/35, bush 0.55 at 30/25, boulder 0.62 at 30/20); trees add the seam view (0.75, az 30, el 15) as the same 2x strip recipe as B6. C11 game light in Blender. Board 3 kinds x 3 looks, PIL composed; bottom row is the seed-1 grove shot cropped to px 475,150 to 1105,545 at 1.5x nearest. Procedural board, no sidecar JSON.
Pick: the board passes — Sebastian, 2026-10-13. Recorded as D50. All nine looks ship.
