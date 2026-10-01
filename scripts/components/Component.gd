extends Node
## Base class of all ported Unity MonoBehaviours. In this port a Unity
## GameObject is a Node3D and each of its MonoBehaviours is a child node named
## after the script (see U.comp()). `go` is the owning "GameObject".

var go: Node3D:
	get:
		return get_parent() as Node3D
