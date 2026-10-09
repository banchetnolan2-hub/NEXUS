class_name NxPort
extends RefCounted
## Port types and connection rules shared by the simulation and the interface.

const POWER := &"power"     ## Electrical network (undirected, many links).
const SHAFT := &"shaft"     ## Rotating shaft (output -> input).
const FLUID := &"fluid"     ## Pipe (output -> input).
const SIGNAL := &"signal"   ## Logic signal (output -> inputs).
const PROBE := &"probe"     ## Measurement link from a tank to a sensor.

const IN := &"in"
const OUT := &"out"
const BOTH := &"both"

const NAMES := {
	POWER: "Électricité",
	SHAFT: "Arbre mécanique",
	FLUID: "Tuyau",
	SIGNAL: "Signal logique",
	PROBE: "Mesure",
}


static func color(type: StringName) -> Color:
	match type:
		POWER:
			return NxPalette.ENERGY
		SHAFT:
			return NxPalette.MECHANICAL
		FLUID:
			return NxPalette.FLUID
		SIGNAL:
			return NxPalette.LOGIC
		PROBE:
			return NxPalette.LOGIC.lightened(0.35)
	return NxPalette.TEXT_MUTED


static func type_name(type: StringName) -> String:
	return NAMES.get(type, String(type))
