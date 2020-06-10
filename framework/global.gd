extends Node

const LEVEL_RESOURCE_PATHS := [
    "res://levels/level_1.tscn",
    "res://levels/level_2.tscn",
    "res://levels/level_3.tscn",
    "res://levels/level_4.tscn",
    "res://levels/level_5.tscn",
    "res://levels/level_6.tscn",
]

const TEST_RUNNER_SCENE_RESOURCE_PATH := "res://test/test_runner.tscn"

const UTILITY_PANEL_RESOURCE_PATH := \
        "res://framework/controls/panels/utility_panel.tscn"
const WELCOME_PANEL_RESOURCE_PATH := \
        "res://framework/controls/panels/welcome_panel.tscn"

const IN_DEBUG_MODE := true
const IN_TEST_MODE := false
const UTILITY_PANEL_STARTS_OPEN := true

#const STARTING_LEVEL_RESOURCE_PATH := \
#        "res://test/data/test_level_long_rise.tscn"
#const STARTING_LEVEL_RESOURCE_PATH := \
#        "res://test/data/test_level_long_fall.tscn"
#const STARTING_LEVEL_RESOURCE_PATH := \
#        "res://test/data/test_level_far_distance.tscn"
#const STARTING_LEVEL_RESOURCE_PATH := \
#        "res://levels/level_3.tscn"
#const STARTING_LEVEL_RESOURCE_PATH := \
#        "res://levels/level_4.tscn"
#const STARTING_LEVEL_RESOURCE_PATH := \
#        "res://levels/level_5.tscn"
const STARTING_LEVEL_RESOURCE_PATH := \
        "res://levels/level_6.tscn"

const PLAYER_RESOURCE_PATH := "res://players/cat_player.tscn"
#const PLAYER_RESOURCE_PATH := "res://players/data/test_player.tscn"

const DEBUG_PARAMS := \
        {} if \
        !IN_DEBUG_MODE else \
        {
    limit_parsing = {
        player_name = "cat",
#        
#        edge = {
#            origin = {
#                surface_side = SurfaceSide.FLOOR,
#            },
#            destination = {
#                surface_side = SurfaceSide.FLOOR,
#            },
#        },
#        
#        edge_type = EdgeType.CLIMB_OVER_WALL_TO_FLOOR_EDGE,
#        edge_type = EdgeType.FALL_FROM_WALL_EDGE,
#        edge_type = EdgeType.FALL_FROM_FLOOR_EDGE,
        edge_type = EdgeType.JUMP_INTER_SURFACE_EDGE,
#        edge_type = EdgeType.CLIMB_DOWN_WALL_TO_FLOOR_EDGE,
#        edge_type = EdgeType.WALK_TO_ASCEND_WALL_FROM_FLOOR_EDGE,
#        
#        # Level: long rise; fall-from-wall
#        edge = {
#            origin = {
#                surface_side = SurfaceSide.LEFT_WALL,
#                surface_start_vertex = Vector2(0, -448),
#                surface_end_vertex = Vector2(0, -384),
#                position = Vector2(0, -448),
#            },
#            destination = {
#                surface_side = SurfaceSide.FLOOR,
#                surface_start_vertex = Vector2(128, 64),
#                surface_end_vertex = Vector2(192, 64),
#                position = Vector2(128, 64),
#            },
#        },
#        
#        # Level: long rise; jump-up-left
#        edge = {
#            origin = {
#                surface_side = SurfaceSide.FLOOR,
#                surface_start_vertex = Vector2(128, 64),
#                surface_end_vertex = Vector2(192, 64),
#                position = Vector2(128, 64),
#            },
#            destination = {
#                surface_side = SurfaceSide.FLOOR,
#                surface_start_vertex = Vector2(-128, -448),
#                surface_end_vertex = Vector2(0, -448),
#                position = Vector2(-128, -448),
#            },
#        },
#        
#        # Level: long rise; fall-from-floor-lower-right
#        edge = {
#            origin = {
#                surface_side = SurfaceSide.FLOOR,
#                surface_start_vertex = Vector2(128, 64),
#                position = Vector2(192, 64),
#            },
#        },
#        
#        # Level: jump-up-right from long base floor to close short floor
#        edge = {
#            origin = {
#                surface_side = SurfaceSide.FLOOR,
#                surface_start_vertex = Vector2(-960, 256),
#                surface_end_vertex = Vector2(2688, 256),
#            },
#            destination = {
#                surface_side = SurfaceSide.FLOOR,
#                surface_start_vertex = Vector2(128, 64),
#                surface_end_vertex = Vector2(192, 64),
#            },
#        },
    },
    extra_annotations = {},
}

const PLAYER_ACTIONS := {}

const EDGE_MOVEMENTS := {}

# Dictionary<String, PlayerParams>
var player_params := {}

var space_state: Physics2DDirectSpaceState

var canvas_layers: CanvasLayers
var current_level: Level
var current_player_for_clicks: Player
var camera_controller: CameraController
var element_annotator: ElementAnnotator
var platform_graph_inspector: PlatformGraphInspector
var legend: Legend
var selection_description: SelectionDescription
var utility_panel: UtilityPanel
var welcome_panel: WelcomePanel

var is_level_ready := false

# Keeps track of the current total elapsed time of unpaused gameplay.
var elapsed_play_time_sec: float setget ,_get_elapsed_play_time_sec

# TODO: Verify that all render-frame _process calls in the scene tree happen
#       without interleaving with any _physics_process calls from other nodes
#       in the scene tree.
var _elapsed_latest_play_time_sec: float
var _elapsed_physics_play_time_sec: float
var _elapsed_render_play_time_sec: float

func get_is_paused() -> bool:
    return get_tree().paused

func pause() -> void:
    get_tree().paused = true

func unpause() -> void:
    get_tree().paused = false

func register_player_actions(player_action_classes: Array) -> void:
    # Instantiate the various PlayerActions.
    for player_action_class in player_action_classes:
        PLAYER_ACTIONS[player_action_class.NAME] = player_action_class.new()

func register_edge_movements(edge_movement_classes: Array) -> void:
    # Instantiate the various EdgeMovements.
    for edge_movement_class in edge_movement_classes:
        EDGE_MOVEMENTS[edge_movement_class.NAME] = edge_movement_class.new()

func register_player_params(player_param_classes: Array) -> void:
    var player_params: PlayerParams
    for param_class in player_param_classes:
        player_params = PlayerParamsUtils.create_player_params(param_class)
        self.player_params[player_params.name] = player_params

func _ready() -> void:
    _elapsed_physics_play_time_sec = 0.0
    _elapsed_render_play_time_sec = 0.0
    _elapsed_latest_play_time_sec = 0.0

func _process(delta: float) -> void:
    _elapsed_render_play_time_sec += delta
    _elapsed_latest_play_time_sec = _elapsed_render_play_time_sec

func _physics_process(delta: float) -> void:
    assert(Geometry.are_floats_equal_with_epsilon( \
            delta, \
            Utils.PHYSICS_TIME_STEP))
    _elapsed_physics_play_time_sec += delta
    _elapsed_latest_play_time_sec = _elapsed_physics_play_time_sec

func _get_elapsed_play_time_sec() -> float:
    return _elapsed_latest_play_time_sec

func add_overlay_to_current_scene(node: Node) -> void:
    get_tree().get_current_scene().add_child(node)
