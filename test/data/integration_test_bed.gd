extends "res://addons/gut/test.gd"
class_name IntegrationTestBed

var TEST_LEVEL_LONG_FALL := {
    scene_resource_path = "res://framework/test/data/test_level_long_fall.tscn",
    start = {
        surface = Surface.new( \
                [Vector2(128, 64), Vector2(192, 64)], \
                SurfaceSide.FLOOR, \
                null, \
                [0]),
        # These are the Player's center positions when jumping/landing on this part of the Surface.
        positions = {
            near = Vector2(192, 54),
            far = Vector2(128, 54),
        }
    },
    end = {
        surface = Surface.new( \
                [Vector2(256, 832), Vector2(320, 832)], \
                SurfaceSide.FLOOR, \
                null, \
                [38]),
        # These are the Player's center positions when jumping/landing on this part of the Surface.
        positions = {
            near = Vector2(256, 822),
            far = Vector2(320, 822),
        }
    },
}

var TEST_LEVEL_LONG_RISE := {
    scene_resource_path = "res://framework/test/data/test_level_long_rise.tscn",
    start = {
        surface = Surface.new( \
                [Vector2(128, 64), Vector2(192, 64)], \
                SurfaceSide.FLOOR, \
                null, \
                [44]),
        # These are the Player's center positions when jumping/landing on this part of the Surface.
        positions = {
            near = Vector2(128, 54),
            far = Vector2(192, 54),
        }
    },
    end = {
        surface = Surface.new( \
                [Vector2(-128, -448), Vector2(-64, -448)], \
                SurfaceSide.FLOOR, \
                null, \
                [0]),
        # These are the Player's center positions when jumping/landing on this part of the Surface.
        positions = {
            near = Vector2(-64, -458),
            far = Vector2(-128, -458),
        }
    },
}

var TEST_LEVEL_FAR_DISTANCE := {
    scene_resource_path = "res://framework/test/data/test_level_far_distance.tscn",
    start = {
        surface = Surface.new( \
                [Vector2(128, 64), Vector2(192, 64)], \
                SurfaceSide.FLOOR, \
                null, \
                [0]),
        # These are the Player's center positions when jumping/landing on this part of the Surface.
        positions = {
            near = Vector2(192, 54),
            far = Vector2(128, 54),
        }
    },
    end = {
        surface = Surface.new( \
                [Vector2(704, 64), Vector2(768, 64)], \
                SurfaceSide.FLOOR, \
                null, \
                [9]),
        # These are the Player's center positions when jumping/landing on this part of the Surface.
        positions = {
            near = Vector2(704, 54),
            far = Vector2(768, 54),
        }
    },
}

const GROUPS := [
    Utils.GROUP_NAME_HUMAN_PLAYERS,
    Utils.GROUP_NAME_COMPUTER_PLAYERS,
    Utils.GROUP_NAME_SURFACES,
]

const END_COORDINATE_CLOSE_THRESHOLD := UnitTestBed.END_COORDINATE_CLOSE_THRESHOLD
const END_POSITION_CLOSE_THRESHOLD := UnitTestBed.END_POSITION_CLOSE_THRESHOLD

var sandbox: Node

var movement_params: MovementParams
var level: Level
var player: TestPlayer
var platform_graph: PlatformGraph
var surface_parser: SurfaceParser
var space_state: Physics2DDirectSpaceState
var start_surface: Surface
var end_surface: Surface

var climb_down_wall_to_floor_calculator: ClimbDownWallToFloorCalculator
var climb_over_wall_to_floor_calculator: ClimbOverWallToFloorCalculator
var fall_from_floor_calculator: FallFromFloorCalculator
var fall_from_wall_calculator: FallFromWallCalculator
var jump_inter_surface_calculator: JumpInterSurfaceCalculator
var walk_to_ascend_wall_from_floor_calculator: WalkToAscendWallFromFloorCalculator

func before_each() -> void:
    sandbox = self

func after_each() -> void:
    destroy()

func set_up(data := TEST_LEVEL_LONG_FALL) -> void:
    set_up_level(data)
    
    # FIXME: ----------------
#    var position := Vector2(160.0, 0.0) if data.scene_resource_path.find("test_") >= 0 \
#            else Vector2.ZERO
#    level.add_player(Global.PLAYER_RESOURCE_PATH, false, position)

func destroy() -> void:
    # FIXME: This shouldn't be possible. Why does Gut trigger this sometimes?
    if sandbox == null:
        return
    
    var scene_tree := sandbox.get_tree()
    
    for group in GROUPS:
        for node in scene_tree.get_nodes_in_group(group):
            node.remove_from_group(group)
            node.queue_free()
    
    for node in sandbox.get_children():
        sandbox.remove_child(node)
        node.queue_free()
    
    movement_params = null
    jump_inter_surface_calculator = null
    level = null
    platform_graph = null
    player = null
    surface_parser = null
    space_state = null
    start_surface = null
    end_surface = null

func set_up_level(data: Dictionary) -> void:
    var level_scene := load(data.scene_resource_path)
    level = level_scene.instance()
    sandbox.add_child(level)
    
    player = level.human_player
    platform_graph = player.graph
    movement_params = player.movement_params
    surface_parser = level.surface_parser
    space_state = level.get_world_2d().direct_space_state
    
    for movement_calculator in player.movement_calculators:
        if movement_calculator is ClimbDownWallToFloorCalculator:
            climb_down_wall_to_floor_calculator = movement_calculator
        elif movement_calculator is ClimbOverWallToFloorCalculator:
            climb_over_wall_to_floor_calculator = movement_calculator
        elif movement_calculator is FallFromFloorCalculator:
            fall_from_floor_calculator = movement_calculator
        elif movement_calculator is FallFromWallCalculator:
            fall_from_wall_calculator = movement_calculator
        elif movement_calculator is JumpInterSurfaceCalculator:
            jump_inter_surface_calculator = movement_calculator
        elif movement_calculator is WalkToAscendWallFromFloorCalculator:
            walk_to_ascend_wall_from_floor_calculator = movement_calculator
        else:
            Utils.error()
    assert(climb_down_wall_to_floor_calculator != null)
    assert(climb_over_wall_to_floor_calculator != null)
    assert(fall_from_floor_calculator != null)
    assert(fall_from_wall_calculator != null)
    assert(jump_inter_surface_calculator != null)
    assert(walk_to_ascend_wall_from_floor_calculator != null)
    
    _store_surfaces(data)

func _store_surfaces(data: Dictionary) -> void:
    for surface in surface_parser.all_surfaces:
        if surface.side == data.start.surface.side and \
                surface.first_point == data.start.surface.first_point and \
                surface.last_point == data.start.surface.last_point:
            start_surface = surface
        elif surface.side == data.end.surface.side and \
                surface.first_point == data.end.surface.first_point and \
                surface.last_point == data.end.surface.last_point:
            end_surface = surface
    
    assert(start_surface != null)
    assert(end_surface != null)