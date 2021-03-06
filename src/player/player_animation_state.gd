class_name PlayerAnimationState
extends Reference


const POST_PATH_DURATION_TO_MIN_CONFIDENCE := 1.0
const MIN_POST_PATH_CONFIDENCE_OPACITY := 0.3
const LOW_CONFIDENCE_MODULATE_MASK := Color("cccc22")

var player_position := Vector2.INF
var animation_type := PlayerAnimationType.UNKNOWN
var animation_position := 0.0
var facing_left := false
var confidence_multiplier := 0.0


func reset() -> void:
    self.player_position = Vector2.INF
    self.animation_type = PlayerAnimationType.UNKNOWN
    self.animation_position = 0.0
    self.facing_left = false
    self.confidence_multiplier = 0.0


func copy(other: PlayerAnimationState) -> void:
    self.player_position = other.player_position
    self.animation_type = other.animation_type
    self.animation_position = other.animation_position
    self.facing_left = other.facing_left
    self.confidence_multiplier = other.confidence_multiplier
