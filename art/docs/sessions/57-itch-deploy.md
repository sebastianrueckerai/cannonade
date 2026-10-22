# Session 57: the itch.io deploy chain

Sebastian, 2026-10-22: "Push the current version then!" — the game goes live free on
[moonlightart.itch.io/cannonade](https://moonlightart.itch.io/cannonade), reachable from the portfolio site.
Roadmap: E3, E6, E7, marketing.

## What ships

[tools/deploy_itch.sh](../../../tools/deploy_itch.sh) runs the web export and pushes `build/web` to
`moonlightart/cannonade:HTML5` with butler, then prints the channel status. Butler 15.32.0 lives in
`~/.local/bin` (its login was done once in this session; the credentials sit in `~/.config/itch/butler_creds`).
The channel name `HTML5` is what makes itch mark the build as playable in the browser, so no upload needs a
"played in the browser" tick. The page URL was a typo: the game was created as `cannonande`, so every butler push to `moonlightart/cannonade`
answered "invalid game" (nine slug probes missed the doubled n; a probe that only grepped for that one error
string also misread a bad-user reply as a hit and sent the account-name theory down a wrong path).
`butler status moonlightart/cannonande` resolves with no channels, the manual zip upload; Sebastian renames
the URL in the page editor and the deploy target stays `moonlightart/cannonade:HTML5`. `tools/export_web.sh` builds the pck from the working tree, which on tracked
files equals master 1c3caed. First push: this session, 174 MB pck + 39.5 MB wasm.

What butler cannot do is make the page, so the empty project was created by hand once. Page text, cover,
screenshots, theme and publish stay in the browser (E7 lists them with the palette).

## The web menu (I88)

The first upload showed the old web gate's mistake: the shipped build opened on Watch and Practice, Player
vs. AI missing. Sebastian's menu for the released page: Player VS AI, Watch AI vs AI, Tutorial & Controls,
Volume, and no Quit in a browser. `Menu.modes_for(web)` now picks versus and ai2 for the web build and every
mode for the desktop; Sandbox and Quit were already desktop-only. tests/menu_test pins the pair.

## Not verified

- The browser play itself: the push succeeded, but nobody loaded the game in a browser on itch yet.
