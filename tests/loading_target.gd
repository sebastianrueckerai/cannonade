extends Node
## Minimal stand-in for Main's loading contract: a staged build with progress.

signal built

var staged := false
var progress := 0.0
