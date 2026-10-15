# Session 12b: concept art for the loading screen

A side session before session 13. Roadmap item: D6.

Sebastian, 2026-10-15: "Just make a few more pictures in the same style as the cover art. A cannon firing, different version of one castle or a wall being shot... come up with 20 ideas, make them into images, critique them, refine them, ... the usual! Show me the results"

## Why these deliverables

- **The loading screen shows concept art (D65).** Today it draws from five anchors, two of them sheets of objects on a plain ground. Pictures painted for the screen, in the cover art's style, give every load a scene from the game.
- **The cover art is the style.** It is the picture Sebastian picked after seven rounds (D25). Each new picture takes it as the style reference, the way round 11 made new duels from one image.
- **The game's own guns.** The gun pictures show the heavy gun, the mortar and the flak of the game (D31, D60), never the parked siege gun (D64).

## Plan

1. Twenty ideas in words, [ideas.md](../../game/art-direction/rounds/29-loading-art/ideas.md), and the round's [checklist](../../game/art-direction/rounds/29-loading-art/checklist.md).
2. One picture per idea with `google/nano-banana-2.1/edit` at 2K, the cover art attached, through [round.py](../../pipeline/round.py).
3. The agent checks every picture against the checklist in magnified crops. The Gemini and GLM critics read the same pictures, and every fault they claim is checked in a crop before it counts.
4. Refine: a picture that fails is fixed through a mask when the fault is local, or painted again with a sharper prompt.
5. Show Sebastian the passing pictures, at most 25, open in his editor, with a picks page. His picks become loading looks through `storeset.py loading`, in a later step.

## Limits

- Spending cap 12 USD from the session start in `art/.env.session`. Twenty pictures cost about 5 USD.
- No change to the game in this session. The picks reach the game after Sebastian picks them.

## Result

Twenty pictures pass the checklist, one per idea, on the [picks page](../../game/art-direction/rounds/29-loading-art/PICKS.md), waiting on Sebastian's picks. Nine came out right at the first try. Eight were painted again, for a fault or for their own landscape, and three were fixed through masks. Spent 9.11 USD of the 12 USD cap.

One change to the game: the loading bar moved to the bottom right corner, because the castle pictures keep the cover's layout, which puts a castle corner where a centred bar sits.
