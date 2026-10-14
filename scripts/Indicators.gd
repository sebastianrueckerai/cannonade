class_name Indicators
## The battle readability candidates of blender-ai round 27: how a gun shows its reload and its
## aim. One static style per concern, set by tools/shoot_battle.gd --ind=<reload>,<arc> before
## the battle starts. The default is the shipped look, so the game plays as before.
##
## reload:  ring      the white ring above the gun (shipped)
##          heat      the barrel glows warm after a shot and cools to iron as it reloads
##          plate     the plate under the gun fills from a warm tint toward its iron grey
##          ground    the ring laid flat round the plate, only while reloading
##          slump     the barrel rests low after a shot and rises to its firing angle
##          none      nothing
## arc:     wire      every aiming gun keeps its team-colour wire (shipped)
##          taper     own guns only, thin, fading toward the landing, gone when the shell flies
##          band      a flat stripe on the ground from muzzle to landing, gone when the shell flies
##          marker    no line, a ring on the target tile while aiming, gone when the shell flies
##          puffs     round smoke dots along the path, gone when the shell flies
##          none      nothing

static var reload_style := "ring"
static var arc_style := "wire"
## Only this player's guns draw arcs under the own-guns styles; null draws every side.
static var own_player = null
static var heat_colour := Color("#ff8a3c")
static var plate_warm := Color("#b8734a")
static var plate_iron := Color("#544d52")
