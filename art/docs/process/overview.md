# The production process

One shared creative direction feeds four production lines. This page holds the master graph. Each stage has its own page with the detailed chart, the inputs every model gets, and the acceptance test.

**This chart is the process.** When a session changes how we make something, it changes the chart in the same commit and adds a line to [process-log.md](../process-log.md).

## Layers

1. **Art direction**: mood, colour, shape, lighting, the cross-domain rules and the era ladder, each picked by Sebastian, written into a design bible of text and images, then an asset list with the essentials marked, then the first item per essential class. [art-direction.md](art-direction.md)
2. **The design bible**: [art_bible.md](../../game/art-direction/art_bible.md) with the rules files and anchor images next to it in [game/art-direction/](../../game/art-direction). Every production line reads its chapter of the bible.
3. **Production lines**: 3D world assets [assets-3d.md](assets-3d.md), in-game 2D and identity [assets-2d.md](assets-2d.md), marketing art [marketing.md](marketing.md).
4. **Integration**: assets tested together in the game from the gameplay camera. [integration.md](integration.md)
5. **Feedback**: a failure returns to the asset, to the domain rules, or to the shared kit. Which level is a judgement the critic makes and the human confirms.

## Legend for every chart

| mark | data that flows |
|---|---|
| T | text: briefs, prompts, critiques |
| J | structured values: JSON and YAML |
| I | image: PNG, JPG |
| M | mesh or scene: .blend, .glb, .obj |
| C | code: Blender Python, GDScript |
| R | render or screenshot |
| A | audio: WAV, MP3, OGG |

Solid arrows are handoffs. Dashed arrows are feedback or optional reuse.

## Master graph

```mermaid
flowchart TB
    subgraph KIT["01  Art direction, see art-direction.md. Every arrow is a pick by Sebastian"]
      direction TB
      IN["Brief, gameplay contract, references, the round 01 anchor [T+J+I]"]
      MOOD["A  Mood and theme: worlds in words, a moodboard each [T+I]"]
      COL["B  Colour: 3 palettes on one frame [J+I]"]
      SHAPE["C  Shape language and detail level [T+I]"]
      LIGHT["D  Lighting and atmosphere [J+I]"]
      XD["E  What stays, what differs: game, menu, splash, store, type [T+I]"]
      TIER["F  Era ladder and the ingredient metaphor [T+I]"]
      BIBLE["G  Design bible v0: text, numbers, anchor images [T+J+I]"]
      LIST["H  Asset list from the game data, essentials marked [J]"]
      FIRST["I  First item per essential class: sketches, references, 3D [I+M]"]
      IN --> MOOD --> COL --> SHAPE --> LIGHT --> XD --> TIER --> BIBLE --> LIST --> FIRST
      FIRST -. style does not hold .-> SHAPE
    end

    subgraph W3D["02A  3D world assets, see assets-3d.md"]
      AS["asset.yaml: dims, parts, pivots, materials [J]"]
      RV["Image model: one side view of the picked sketch on plain ground [T+I in, I out]"]
      CL["Coding agent writes bpy [T+J+I in, C out]"]
      BP["Blender runs the script [C in, M out]"]
      T3["Meshy image-to-3D, low-poly with a face count [I+J in, M out]"]
      SP["Cleanup by hand in Blender: split.json names barrel, pivot, fixes [J+M in, M out]"]
      BL["Blender normaliser: units, origin, repair, simplify [M in, M out]"]
      MT["Materials from palette.json, or texture model [J+I+M]"]
      QC["Geometry report + wire view + solidity + matcap/texture/gameplay renders + critic [J+R in, T/J out]"]
      BN["Bench in the game: Sebastian turns and tilts the model [R]"]
      LIB["Approved asset: .blend, .glb, previews, manifest"]
      AS --> RV
      AS --> CL
      RV --> CL --> BP --> BL
      RV --> T3 --> SP --> BN
      BL --> MT --> QC -->|pass| LIB
      BN -->|pass| LIB
      QC -. repair .-> BL
      BN -. a fault .-> SP
      QC -. redo reference .-> RV
    end

    subgraph UI2D["02B  In-game 2D and identity, see assets-2d.md"]
      US["UI spec: screens, sizes, states [J]"]
      NB["Name, type, logo brief [T]"]
      UC["Image model: UI, icon, logo concepts [T+I in, I out]"]
      UB["Build: SVG, PNG, atlas, Godot Theme [I/C]"]
      UQ["Readability check in game at 1280x720 and phone width [R]"]
      UL["Approved UI, icons, logo, type system [I+J]"]
      US --> UC
      NB --> UC
      UC --> UB --> UQ -->|pass| UL
      UQ -. revise .-> UB
    end

    subgraph PROMO["02C  Splash, cover, store art, see marketing.md"]
      PS["Marketing contract: message, copy, platform sizes [J]"]
      PR["Approved renders and gameplay screenshots [I]"]
      PI["Image model and editor: key art [T+I in, I out]"]
      PC["Deterministic compositing with logo and copy [I+T]"]
      PQ["Review in the real platform crops [I+J]"]
      PL["Approved marketing set [I]"]
      PS --> PI
      PR --> PI --> PC --> PQ -->|pass| PL
      PQ -. revise .-> PI
    end

    subgraph GAME["03  Integration in Grid Cannons, see integration.md"]
      SY["godot_sync: copy approved files into the game repo [M+I]"]
      GD["Preview scene from the gameplay camera [M+I+C]"]
      SH["Gameplay screenshots [R]"]
      RW["Cross-domain review: do UI, world and store art belong to one game [T+J+I]"]
      FB["Feedback level: asset, domain or global [T]"]
      SY --> GD --> SH --> RW --> FB
    end

    subgraph AUD["02D  Music and sound effects, see sound.md in the game design"]
      CUE["Cue list from the game's events: trigger, length, character [J]"]
      AR["Audio round: directions times cues times models, audio.py [T in, A out]"]
      AQ["Loudness sheet and Whisper word count, then Sebastian's ear [A in, J out]"]
      AV["Versions of the picked theme: ACE-Step remix of the clip [A in, A out]"]
      CUE --> AR --> AQ --> AV
    end

    BIBLE --> CUE
    BIBLE --> AS
    BIBLE --> RV
    BIBLE --> US
    BIBLE --> NB
    BIBLE --> UC
    BIBLE --> PS
    BIBLE --> PI
    LIB --> SY
    AV --> SY
    UL --> SY
    UL --> PC
    LIB -. hero renders .-> PR
    SH --> PR
    FB -. asset fix .-> AS
    FB -. UI fix .-> US
    FB -. global style revision .-> BIBLE
```

## What each model gets, and what comes back

Text and numbers carry intent, dimensions, constraints, colour values and technical limits. Images carry what numbers cannot: shape language, atmosphere, composition. Meshes carry geometry and construction. Renders let a critic see the result under real viewing conditions. No one of these replaces another.

| step | the model gets | the model returns |
|---|---|---|
| Creative exploration | T: premise, tone, mechanics, gameplay contract. I: inspirations | 3 to 6 written directions, each with prompts |
| Style frames | T: one direction prompt. I: optional inspirations | several images per direction |
| Direction critique | T: brief and criteria. I: all candidates together | strengths, faults, a ranking, a recommended edit per image |
| Asset reference | T: asset description, dims, shape rules. I: approved anchors | front, side, three-quarter views on neutral ground |
| Procedural 3D | T+J: asset.yaml, geometry rules, palette. I: references | Blender Python, then an editable .blend |
| Generative 3D | I: isolated references. J: the API parameters it supports | raw .glb or .obj, optional textures |
| Blender repair | M: the asset. T+J: spec. I: reference and review renders | corrected .blend and .glb |
| Materials | J: palette and material rules. I: texture references. M: when the API needs it | material assignments or texture maps |
| 3D critique | R: 4-view sheet and gameplay view. J: geometry report. J: asset.yaml | pass or a structured correction list |
| In-game 2D | T+J: purpose, sizes, states. I: approved anchors | SVG, PNG, atlas |
| Key art | T: message, composition, brand rules. I: anchors, renders, screenshots | key art, splash, background |
| Store assembly | T+J: copy, exact sizes. I: key art, logo | composited store files |

A mesh API reads one image and a few numbers. It cannot read the art bible. The upstream image step must put the art direction into the reference image. A coding agent reads text and images, so it gets explicit rules.

## Where the agentic process leaves the human one

The human order is mood, concept art, model sheet, mesh, texture, integrate. We start from it and test where cheap code and cheap meshes let us cut or reorder. Roadmap item H1 tests whether the 2D reference stage pays for itself on low-poly procedural assets. H2 tests variations of a finished asset in place of prototypes. Results go into [process-log.md](../process-log.md) and change the charts here.

## Feedback levels

- **Asset**: the cannon wheels are too small. Change the asset parameters or the mesh.
- **Domain**: every cannon has more detail than every wall. Change geometry_rules.yaml and rebuild the dependent assets.
- **Global**: UI, world and store art look like three games. Revise the design bible, then decide which consumers regenerate.
