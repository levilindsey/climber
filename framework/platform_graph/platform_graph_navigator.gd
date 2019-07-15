extends Reference
class_name PlatformGraphNavigator

var player # TODO: Add type back
var graph: PlatformGraph
var surface_state: PlayerSurfaceState
var surface_parser: SurfaceParser

var _stopwatch: Stopwatch

var is_currently_navigating := false
var reached_destination := false
var current_path: PlatformGraphPath
var current_edge: PlatformGraphEdge
var current_edge_index := -1

var just_collided_unexpectedly := false
var just_entered_air_unexpectedly := false
var just_landed_on_expected_surface := false
var just_interrupted_navigation := false
var just_reached_start_of_edge := false

func _init(player, graph: PlatformGraph) -> void:
    self.player = player
    self.graph = graph
    surface_state = player.surface_state
    surface_parser = graph.surface_parser
    _stopwatch = Stopwatch.new()

# Starts a new navigation to the given destination.
func start_new_navigation(target: Vector2) -> bool:
    assert(surface_state.is_grabbing_a_surface) # FIXME: Remove
    
    var origin := surface_state.player_center_position_along_surface
    var destination := find_closest_position_on_a_surface(target, player)
    var path := graph.find_path(origin, destination)
    
    if path == null:
        # Destination cannot be reached from origin.
        current_path = null
        current_edge = null
        current_edge_index = -1
        is_currently_navigating = false
        reached_destination = false
        return false
    else:
        # Destination can be reached from origin.
        current_path = path
        current_edge = current_path.edges[0]
        current_edge_index = 0
        is_currently_navigating = true
        reached_destination = false
        return true

func reset() -> void:
    current_path = null
    current_edge_index = -1
    current_edge = null
    is_currently_navigating = false

# Updates player-graph state in response to the given new PlayerSurfaceState.
func update() -> void:
    if !is_currently_navigating:
        return
    
    var is_grabbed_surface_expected := \
            surface_state.grabbed_surface == current_edge.end.surface
    just_collided_unexpectedly = \
            !is_grabbed_surface_expected and player.get_slide_count() > 0
    just_entered_air_unexpectedly = \
            surface_state.just_entered_air and !just_reached_start_of_edge
    just_landed_on_expected_surface = surface_state.just_left_air and \
            surface_state.grabbed_surface == current_edge.end.surface
    just_interrupted_navigation = just_collided_unexpectedly or just_entered_air_unexpectedly
    # FIXME: Add logic to detect when we've reached the target PositionAlongSurface when moving within node.
    just_reached_start_of_edge = false
    
    if just_interrupted_navigation:
        print("PlatformGraphNavigator: just_interrupted_navigation")
        
        # Re-calculate navigation to the same destination.
        var destination = current_path.end_instructions_destination if \
                current_path.has_end_instructions else \
                current_path.surface_destination.target_point
#        start_new_navigation(destination) # FIXME: Add back in after implementing edge calculations and executions
    
    elif just_reached_start_of_edge:
        print("PlatformGraphNavigator: just_reached_start_of_edge")
        
        reached_destination = current_path.edges.size() == current_edge_index + 1
        if reached_destination:
            reset()
        else:
            current_edge_index += 1
            current_edge = current_path.edges[current_edge_index]
            
            # FIXME: Trigger next instruction set
    
    elif just_landed_on_expected_surface:
        print("PlatformGraphNavigator: just_landed_on_expected_surface")
        
        # FIXME: Detect when position is too far from expected.
        # FIXME: Start moving within the surface to the next edge start position.
        pass
    
    elif surface_state.is_grabbing_a_surface:
        print("PlatformGraphNavigator: Moving along a surface")
        
        # FIXME: Continue moving toward next edge.
        pass
    
    else: # Moving through the air.
        print("PlatformGraphNavigator: Moving through the air")
        
        # FIXME: Detect when position is too far from expected.
        # FIXME: Continue executing movement instruction set.
        pass

# Finds the Surface the corresponds to the given PlayerSurfaceState.
func calculate_grabbed_surface(surface_state: PlayerSurfaceState) -> Surface:
    return surface_parser.get_surface_for_tile(surface_state.grabbed_tile_map, \
            surface_state.grabbed_tile_map_index, surface_state.grabbed_side)

# Finds the closest PositionAlongSurface to the given target point.
static func find_closest_position_on_a_surface(target: Vector2, player) -> PositionAlongSurface:
    var position := PositionAlongSurface.new()
    var surface := _get_closest_surface(target, player.possible_surfaces)
    position.match_surface_target_and_collider(surface, target, player.collider_half_width_height)
    return position

# Gets the closest surface to the given point.
static func _get_closest_surface(target: Vector2, surfaces: Array) -> Surface:
    var closest_surface: Surface
    var closest_distance_squared: float
    var current_distance_squared: float
    
    closest_surface = surfaces[0]
    closest_distance_squared = \
            Geometry.get_distance_squared_from_point_to_polyline(target, closest_surface.vertices)
    
    for current_surface in surfaces:
        current_distance_squared = Geometry.distance_squared_from_point_to_rect(target, \
                current_surface.bounding_box)
        if current_distance_squared < closest_distance_squared:
            current_distance_squared = Geometry.get_distance_squared_from_point_to_polyline( \
                    target, current_surface.vertices)
            if current_distance_squared < closest_distance_squared:
                closest_distance_squared = current_distance_squared
                closest_surface = current_surface
    
    return closest_surface
