extends EdgeMovementCalculator
class_name JumpFromSurfaceToSurfaceCalculator

const MovementCalcOverallParams := preload("res://framework/edge_movement/models/movement_calculation_overall_params.gd")

const NAME := 'JumpFromSurfaceToSurfaceCalculator'

# FIXME: LEFT OFF HERE: ---------------------------------------------------------A
# FIXME: -----------------------------
# 
# - Debug why no valid Edges are found in FallFromWallCalculator.
# 
# - Implement annotators for new Edges.
#   - FallFromWall
#   - FallFromFloor
#   - ClimbOverWallToFloor
#     - Render quarter circle with ends aligned coaxially with corner.
#   - ClimbDownWallToFloor
#     - Render 90-degree connected line segments? Where are the end points?
#   - ClimbUpWallFromFloor
#     - Render 90-degree connected line segments? Where are the end points?
# 
# - Fix any remaining Navigator movement issues.
# - Fix performance.
#   - Should I almost never be actually storing things in Pool arrays? It seems like I mostly end
#     up passing them around as arguments to functions, to they get copied as values...
# 
# - Debug why this edge calculation generates 35 steps...
#   - test_level_long_rise
#   - from top-most floor to bottom-most (wide) floor, on the right side
# 
# - Fix frame collision detection...
#   - Seeing pre-existing collisions when jumping from walls.
#   - Fix collision-detection errors from logs.
#   - Go through levels and verify that all expected edges work.
# 
# - Fix issue where jumping around edge sometimes isn't going far enough; it's clipping the corner.
# 
# - Test/debug FallMovementUtils.find_a_landing_trajectory.
# 
# - Remove calls to MovementInstructionsUtils.test_instructions?
# 
# --- Expected cut-off for demo date ---
# 
# - Start with debug menu closed. Open when rendering edge-calc annotator.
# 
# - Create a temporary toast message.
#   - Shown at top-mid.
#   - Disappears after clicking anywhere.
#   - Explains controls and click-to-focus.
#     - Squirrel Away!
#     - _Click anywhere on window to give focus (Levi will fix that eventually...)._
#     - Controls:
#       - Use mouse to direct cat to move automatically.
#       - Use keyboard to control cat manually (UDLR, X, Z)
#       - Ctrl+click to debug how an edge was calculated (click on both ends where the edge should have gone).
# 
# - Add a top-level button to debug menu to hide all annotations.
#   - (grid, clicks, player position, player recent movement, platform graph, ...)
# - Add sub-buttons for individual annotators.
#   - Collision calculation annotator in particular.
# 
# - Prepare a different, more interesting level for demo (some walls connecting to floors too).
# 
# - Make each background layer more faded. Only interactable foreground should pop so much.
# 
# ---  ---
# 
# - Put together some illustrative screenshots with special one-off annotations to explain the
#   graph parsing steps.
#   - A couple surfaces
#   - Show different tiles, to illustrate how surfaces get merged.
#   - All surfaces (different colors)
#   - A couple edges
#   - All edges
#   - 
# 
# - Update README.
# 
# ---  ---
# 
# - Implement/debug the other EdgeMovementCalculators.
#   - Figure out what to do for FallFromFloorEdge.
#     - We need to on-the-fly detect when the player has left the floor and entered the air.
#     - We need to at-that-point start running the instructions for the fall trajectory.
#     - So FallFromFloorEdge might need to be replaced with two edges? WalkOffFloorEdge, and AirToSurfaceEdge?
# - Move get_instructions_to_air to somewhere else.
# - Adjust cat_params to only allow subsets of EdgeMovementCalculators, in order to test the non-jump edges
# 
# - Update navigation to do some additional on-the-fly edge calculations.
#   - Only limit this to a few additional potential edges along the path.
#   - The idea is that the edges tend to produce very unnatural composite trajectories (similar to
#     using perpendicular Manhatten distance routes instead of more diagonal routes).
#   >- Basically, try jumping from earlier on any given surface.
#     - It may be hard to know exactly where along a surface to try jumping from though...
#     - Should probably just use some simple heuristic and just give up when they fail with
#       false-positive rates.
#   >- Also, update velocity_start for these on-the-fly edges to be more intelligent.
# 
# - Update navigator to force player state to match expected edge start state.
#   - Configurable.
#   - Both position and velocity.
# - Add support for forcing state during edge movement to match what is expected from the original edge calculations.
#   - Configurable.
#   - Apply this to both position and velocity.
#   - Also, allow for this to use a weighted average of the expected state vs the actual state from normal run-time.
#   - Also, add a warning message when the player is too far from what's expected.
# 
# - Update edge-calculations to support variable velocity_start_x values.
#   - Allow for up-front edge calculation to use any desired velocity_start_x between
#     -max_horizontal_speed_default and max_horizontal_speed_default.
#   - This is probably a decent approximation, since we can usually assume that the ramp-up
#     distance to get from 0 to max-x-speed on the floor is small enough that we can ignore it.
#   - We could probably actually do an even better job by limiting the range for velocity_start_x
#     for floor-surface-end-jump-off-points to be between either -max_horizontal_speed_default and
#     0 or 0 and max_horizontal_speed_default.
# 
# ---  ---
# 
# - Add squirrel assets and animation.
#   - Start by copying-over the Piskel squirrel animation art.
#   - Create squirrel parts art in Aseprite.
#   - Create squirrel animation key frames in Godot.
#     - Idle, standing
#     - Idle, climbing
#     - Crawl-walk-sniff
#     - Bounding walk
#     - Climbing up
#     - Climbing down (just run climbing-up in reverse? Probably want to bound down, facing down,
#       as opposed to cat. Will make transition weird, but whatever?)
#     - 
# 
# ---  ---
# 
# - Loading screen
#   - While downloading, and while parsing level graph
#   - Hand-animated pixel art
#   - Simple GIF file
#   - Host/load/show separately from the rest of the JavaScript and assets
#   - Squirrels digging-up/eating tulips
# 
# - Welcome screen
#   - Hand-animated pixel art
#   x- Gratuitous whooshy sliding shine and a sparkle at the end
#   x- With squirrels running and climbing over the letters?
#   >- Approach:
#     - Start simple. Pick font. Render in Inkscape. Create a hand-pixel-drawn copy in Aseprite.
#     - V1: Show "Squirrel Away" text. Animate squirrel running across, right to left, in front of letters.
#     - V2: Have squirrel pause to the left of the S, with its tail overlapping the S. Give a couple tail twitches. Then have squirrel leave.
#     
# ---  ---
# 
# - Update some edge calculators to offset the expected near-side, far-side, close-side, top-side,
#   bottom-side, etc. jump-off/land-on position calculations to account for neighbor surfaces that
#   would get in the way.
# 
# - Add some extra improvements to check_frame_for_collision:
#   - [maybe?] Rather than just using closest_intersection_point, sort all intersection_points, and
#     try each of them in sequence when the first one fails	
#   - [easy to add, might be nice for future] If that also fails, use a completely separate new
#     cheap-and-dirty check-for-collision-in-frame method?	
#     - Check if intersection_points is not-empty.
#     - Sort them by closest in direction of motion (and ignoring behind points).
#     - Iterate through points, trying to get tile index by a slight nudge offset from each
#       intersection point in the direction of motion until one sticks.
#     - Choose surface side just from dominant motion component.
#   - Add a field on the collision class for the type of collision check used
#   - Add another field (or another option for the above field) to indicate that none of the
#     collision checks worked, and this collision is in an error state
#   - Use this error state to abort collision/step/edge calculations (rather than the current
#     approach of returning null, which is the same as with not detecting any collisions at all).
# 
# - Add better annotation selection.
#   - Add shorcuts for toggling debugging annotations
#     - Add support for triggering the calc-step annotations based on a shortcut.
#       - i
#       - also, require clicking on the start and end positions in order to select which edge to
#         debug
#         - Use this _in addition to_ the current top-level configuration for specifying which edge
#           to calculate?
#       - also, then only actually calculate the edge debug state when using this click-to-specify
#         debug mode
#     - also, add other shortcuts for toggling other annotations:
#       - whether all surfaces are highlighted
#       - whether the player's position+collision boundary are rendered
#       - whether the player's current surface is rendered
#       - whether all edges are rendered
#       - whether grid boundaries+indices are rendered
#     - create a collapsible dat.GUI-esque menu at the top-right that lists all the possible
#       annotation configuration options
#       - set up a nice API for creating these, setting values, listening for value changes, and
#         defining keyboard shortcuts.
#   - Use InputMap to programatically add keybindings.
#     - This should enable our framework to setup all the shortcuts it cares about, without
#       consumers needing to ever redeclare anything in their project settings.
#     - This should also enable better API design for configuring keybindings and menu items from
#       the same place.
#     - https://godot-es-docs.readthedocs.io/en/latest/classes/class_inputmap.html#class-inputmap
# 
# - Finish remaining surface-closest-point-jump-off calculation cases.
#   - Also, maybe still not quite far enough with the offset?
# 
# - Implement fall-through/walk-through movement-type utils.
# 
# >- Commit message:
# 




func _init().(NAME) -> void:
    pass

func get_can_traverse_from_surface(surface: Surface) -> bool:
    return surface != null

func get_all_edges_from_surface(collision_params: CollisionCalcParams, edges_result: Array, \
        surfaces_in_fall_range_set: Dictionary, surfaces_in_jump_range_set: Dictionary, \
        origin_surface: Surface) -> void:
    var movement_params := collision_params.movement_params
    var debug_state := collision_params.debug_state
    var constraint_offset = MovementCalcOverallParams.calculate_constraint_offset(movement_params)
    var velocity_start := movement_params.get_jump_initial_velocity(origin_surface.side)
    
    var jump_positions: Array
    var land_positions: Array
    var edge: JumpFromSurfaceToSurfaceEdge
    
    for destination_surface in surfaces_in_jump_range_set:
        # This makes the assumption that traversing through any fall-through/walk-through surface
        # would be better handled by some other Movement type, so we don't handle those
        # cases here.
        
        if origin_surface == destination_surface:
            # We don't need to calculate edges for the degenerate case.
            continue
        
        jump_positions = MovementUtils.get_all_jump_land_positions_from_surface( \
                movement_params, origin_surface, destination_surface.vertices, \
                destination_surface.bounding_box, destination_surface.side)
        land_positions = MovementUtils.get_all_jump_land_positions_from_surface( \
                movement_params, destination_surface, origin_surface.vertices, \
                origin_surface.bounding_box, origin_surface.side)
        
        for jump_position in jump_positions:
            for land_position in land_positions:
                ###################################################################################
                # Allow for debug mode to limit the scope of what's calculated.
                if EdgeMovementCalculator.should_skip_edge_calculation(debug_state, \
                        origin_surface, destination_surface, jump_position, land_position, \
                        jump_positions, land_positions):
                    continue
                
                # Record some extra debug state when we're limiting calculations to a single edge.
                var in_debug_mode: bool = debug_state.in_debug_mode and \
                        debug_state.has('limit_parsing') and \
                        debug_state.limit_parsing.has('edge') != null
                ###################################################################################
                
                edge = calculate_edge(collision_params, jump_position, land_position, true, \
                        velocity_start, false, in_debug_mode)
                
                if edge != null:
                    # Can reach land position from jump position.
                    edges_result.push_back(edge)
                    # For efficiency, only compute one edge per surface pair.
                    break
            
            if edge != null:
                # For efficiency, only compute one edge per surface pair.
                edge = null
                break

# FIXME: LEFT OFF HERE: Move this somewhere else.
func get_edge_to_air(collision_params: CollisionCalcParams, \
        position_start: PositionAlongSurface, position_end: Vector2) -> SurfaceToAirEdge:
    var velocity_start := collision_params.movement_params.get_jump_initial_velocity( \
            position_start.surface.side)
    var overall_calc_params := create_movement_calc_overall_params(collision_params, \
            position_start.surface, position_start.target_point, null, position_end, \
            true, velocity_start, false, false)
    
    var calc_results := MovementStepUtils.calculate_steps_with_new_jump_height( \
            overall_calc_params, null, null)
    if calc_results == null:
        return null
    
    var edge := SurfaceToAirEdge.new(position_start, position_end, calc_results)
    
    # FIXME: ---------- Remove?
    if Utils.IN_DEV_MODE:
        MovementInstructionsUtils.test_instructions( \
                edge.instructions, overall_calc_params, calc_results)
    
    return edge

# FIXME: LEFT OFF HERE: ----------------------------------A:
# - Is there a better way I should be simplifying this construction pattern in general to make it
#   easier to reuse with other edge calculators?
static func calculate_edge(
        collision_params: CollisionCalcParams, \
        origin_position: PositionAlongSurface, \
        destination_position: PositionAlongSurface, \
        can_hold_jump_button: bool, \
        velocity_start: Vector2, \
        returns_invalid_constraints: bool, \
        in_debug_mode: bool) -> JumpFromSurfaceToSurfaceEdge:
    var overall_calc_params := create_movement_calc_overall_params(collision_params, \
            origin_position.surface, origin_position.target_point, destination_position.surface, \
            destination_position.target_point, can_hold_jump_button, velocity_start, \
            returns_invalid_constraints, in_debug_mode)
    if overall_calc_params == null:
        return null
    
    return create_edge_from_overall_params(overall_calc_params, origin_position, \
            destination_position)

static func create_movement_calc_overall_params(
        collision_params: CollisionCalcParams, \
        origin_surface: Surface, origin_position: Vector2, \
        destination_surface: Surface, destination_position: Vector2, \
        can_hold_jump_button: bool, \
        velocity_start: Vector2, \
        returns_invalid_constraints: bool, \
        in_debug_mode: bool) -> MovementCalcOverallParams:
    var terminals := MovementConstraintUtils.create_terminal_constraints(origin_surface, \
            origin_position, destination_surface, destination_position, \
            collision_params.movement_params, can_hold_jump_button, velocity_start, \
            returns_invalid_constraints)
    if terminals.empty():
        return null
    
    var overall_calc_params := MovementCalcOverallParams.new(collision_params, terminals[0], \
            terminals[1], velocity_start, can_hold_jump_button)
    overall_calc_params.in_debug_mode = in_debug_mode
    
    return overall_calc_params

static func create_edge_from_overall_params( \
        overall_calc_params: MovementCalcOverallParams, origin_position: PositionAlongSurface, \
        destination_position: PositionAlongSurface) -> JumpFromSurfaceToSurfaceEdge:
    var calc_results := MovementStepUtils.calculate_steps_with_new_jump_height( \
            overall_calc_params, null, null)
    if calc_results == null:
        return null
    
    var edge := JumpFromSurfaceToSurfaceEdge.new( \
            origin_position, destination_position, calc_results)
    
    # FIXME: ---------- Remove?
    if Utils.IN_DEV_MODE:
        MovementInstructionsUtils.test_instructions( \
                edge.instructions, overall_calc_params, calc_results)
    
    return edge