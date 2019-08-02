# Information for how to move through the air from a start position to an end position.
extends Edge
class_name AirToAirEdge

var start: Vector2
var end: Vector2

func _init(start: Vector2, end: Vector2) \
        .(_calculate_instructions(start, end)) -> void:
    self.start = start
    self.end = end

# TODO: Implement this

static func _calculate_instructions(start: Vector2, end: Vector2) -> PlayerInstructions:
    return null
