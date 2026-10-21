class_name Indicators
## How a gun shows its reload and its aim (blender-ai round 27, picked by Sebastian).
##
## Reload: a ring flat on the gun's plate, round the gun's foot, in the gun's iron shifted a
## little toward the owner's team colour. Its band thins outward to nothing over the reload,
## then the plate pulses red once at ready (scripts/components/Cooldown.gd).
## Aim: a cube of light on the tile under the cursor (PlayerController, BuildingPlace.target_on),
## own guns only; it is the aim indicator while the battle runs. The shells' white trails
## (Catalog, GPUParticles3D) show where they flew; the predicted-path arc is kept but off (I77).

## Only this player's guns show their aim. Main sets it to the human player at the start of every
## game; null (no human, as in AI against AI) lets every side show.
static var own_player = null
## How far the ring's iron shifts toward the team colour: visible, and the cozy look holds.
static var ring_shift := 0.35
static var plate_iron := Color("#544d52")  # the plate colour of D39
static var pulse_red := Color("#c8322d")   # the ready pulse on the plate: the kit's ui_accent
## Tool-side only: multiplies every gun's reload at spawn, so a screenshot run has a mid-reload
## window to catch. It must be set before the battle spawns its guns. 1.0 in the game.
static var reload_scale := 1.0


## Whether `player`'s guns show their aim: the arc and the light on the aimed-at tile.
static func shows(player) -> bool:
	return own_player == null or player == own_player
