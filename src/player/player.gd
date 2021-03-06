class_name Player
extends KinematicBody2D


const GROUP_NAME_HUMAN_PLAYERS := "human_players"
const GROUP_NAME_COMPUTER_PLAYERS := "computer_players"

var player_name: String
var can_grab_walls: bool
var can_grab_ceilings: bool
var can_grab_floors: bool
var movement_params: MovementParams
# Array<EdgeCalculator>
var edge_calculators: Array
# Array<Surface>
var possible_surfaces_set: Dictionary
var actions_from_previous_frame := PlayerActionState.new()
var actions := PlayerActionState.new()
var surface_state := PlayerSurfaceState.new()
var navigation_state: PlayerNavigationState
var pointer_listener: PlayerPointerListener

var new_selection: PointerSelectionPosition
var last_selection: PointerSelectionPosition
var pre_selection: PointerSelectionPosition

var is_human_player := false
var is_fake := false
var _is_initialized := false
var _is_destroyed := false
var _is_navigator_initialized := false
var _is_ready := false

var graph: PlatformGraph
var surface_parser: SurfaceParser
var navigator: Navigator
var velocity := Vector2.ZERO
var level
var collider: CollisionShape2D
var animator: PlayerAnimator
var prediction: PlayerPrediction
# Array<PlayerActionSource>
var action_sources := []
# Dictionary<String, bool>
var _previous_actions_this_frame := {}
# Array<PlayerActionHandler>
var action_handlers: Array
# SurfaceType
var current_action_type: int

var just_triggered_jump := false
var is_rising_from_jump := false
var jump_count := 0

var did_move_last_frame := false

var current_max_horizontal_speed: float
var _can_dash := true
var _dash_cooldown_timeout: int
var _dash_fade_tween: ScaffolderTween


func _init(player_name: String) -> void:
    self.player_name = player_name
    
    self.level = Sc.level
    
    var player_params: PlayerParams = Su.player_params[player_name]
    self.can_grab_walls = player_params.movement_params.can_grab_walls
    self.can_grab_ceilings = player_params.movement_params.can_grab_ceilings
    self.can_grab_floors = player_params.movement_params.can_grab_floors
    self.movement_params = player_params.movement_params
    self.current_max_horizontal_speed = \
            player_params.movement_params.max_horizontal_speed_default
    self.edge_calculators = player_params.edge_calculators
    self.action_handlers = player_params.action_handlers
    
    self.new_selection = PointerSelectionPosition.new(self)
    self.last_selection = PointerSelectionPosition.new(self)
    self.pre_selection = PointerSelectionPosition.new(self)


func _ready() -> void:
    if is_fake:
        # Fake players are only used for testing potential collisions under the
        # hood.
        return
    
    # TODO: Somehow consolidate how collider shapes are defined?
    
    var shape_owners := get_shape_owners()
    assert(shape_owners.size() == 1)
    var owner_id: int = shape_owners[0]
    assert(shape_owner_get_shape_count(owner_id) == 1)
    var collider_shape := shape_owner_get_shape(owner_id, 0)
    assert(Sc.geometry.do_shapes_match(
            collider_shape,
            movement_params.collider_shape))
    var transform := shape_owner_get_transform(owner_id)
    assert(abs(transform.get_rotation() - \
            movement_params.collider_rotation) < Sc.geometry.FLOAT_EPSILON)
    
    if movement_params.bypasses_runtime_physics:
        set_collision_mask_bit(
                Su.WALLS_AND_FLOORS_COLLISION_MASK_BIT, false)
        set_collision_mask_bit(
                Su.FALL_THROUGH_FLOORS_COLLISION_MASK_BIT, false)
        set_collision_mask_bit(
                Su.WALK_THROUGH_WALLS_COLLISION_MASK_BIT, false)
    
    # Ensure we use the actual Shape2D reference that is used by Godot's
    # collision system.
    movement_params.collider_shape = collider_shape
    
#    shape_owner_clear_shapes(owner_id)
#    shape_owner_add_shape(owner_id, movement_params.collider_shape)
    
    self.pointer_listener = PlayerPointerListener.new(self)
    add_child(pointer_listener)
    
    var animators: Array = Sc.utils.get_children_by_type(
            self,
            PlayerAnimator)
    assert(animators.size() <= 1)
    if animators.empty():
        animator = Sc.utils.add_scene(
                self,
                movement_params.animator_params.player_animator_path_or_scene)
    else:
        animator = animators[0]
    animator.set_up(self, true)
    
    if Su.annotators.is_annotator_enabled(
            AnnotatorType.PATH_PRESELECTION) and \
            (is_human_player and Su.is_human_prediction_shown or \
            !is_human_player and Su.is_computer_prediction_shown):
        prediction = PlayerPrediction.new()
        prediction.set_up(self)
    
    # Set up a Tween for the fade-out at the end of a dash.
    _dash_fade_tween = ScaffolderTween.new()
    add_child(_dash_fade_tween)
    
    # Start facing the right.
    surface_state.horizontal_facing_sign = 1
    animator.face_right()
    
    _is_ready = true
    _check_for_initialization_complete()
    
    surface_state.previous_center_position = self.position
    surface_state.center_position = self.position
    
    Sc.device.connect(
            "display_resized",
            self,
            "_on_resized")
    _on_resized()


func _on_annotators_ready() -> void:
    if is_instance_valid(prediction):
        Su.annotators.path_preselection_annotator \
                .add_prediction(prediction)


func _destroy() -> void:
    _is_destroyed = true
    if is_instance_valid(prediction):
        prediction.queue_free()
    if is_instance_valid(animator):
        animator._destroy()
    if !is_queued_for_deletion():
        queue_free()


func _unhandled_input(event: InputEvent) -> void:
    if _is_initialized and \
            !_is_destroyed and \
            Sc.gui.is_user_interaction_enabled and \
            navigator.is_currently_navigating and \
            event is InputEventKey:
        navigator.stop()


func _on_resized() -> void:
    Sc.camera_controller._on_resized()


func init_human_player_state() -> void:
    is_human_player = true
    # Only a single, user-controlled player should have a camera.
    _set_camera()
    _init_navigator()
    _init_user_controller_action_source()
    _is_navigator_initialized = true
    _check_for_initialization_complete()


func init_computer_player_state() -> void:
    is_human_player = false
    _init_navigator()
    _is_navigator_initialized = true
    _check_for_initialization_complete()


func set_platform_graph(graph: PlatformGraph) -> void:
    self.graph = graph
    self.surface_parser = graph.surface_parser
    self.possible_surfaces_set = graph.surfaces_set
    _check_for_initialization_complete()


func _check_for_initialization_complete() -> void:
    self._is_initialized = \
            graph != null and \
            _is_navigator_initialized and \
            _is_ready


func _set_camera() -> void:
    var camera := Camera2D.new()
    camera.smoothing_enabled = true
    camera.smoothing_speed = Sc.gui.camera_smoothing_speed
    add_child(camera)
    # Register the current camera, so it's globally accessible.
    Sc.camera_controller.set_current_camera(camera, self)


func _init_user_controller_action_source() -> void:
    action_sources.push_back(UserActionSource.new(self, true))


func _init_navigator() -> void:
    navigator = Navigator.new(self, graph)
    navigation_state = navigator.navigation_state
    action_sources.push_back(navigator.instructions_action_source)


func _physics_process(delta: float) -> void:
    if is_fake or \
            !_is_initialized or \
            _is_destroyed:
        # Fake players are only used for testing potential collisions under the
        # hood.
        return
    
    var delta_scaled: float = Sc.time.scale_delta(delta)
    
    _update_actions(delta_scaled)
    _update_surface_state()
    _handle_pointer_selections()
    
    if surface_state.just_left_air:
        print_msg("GRABBED    :%8s;%8.3fs;P%29s;V%29s; %s", [
                player_name,
                Sc.time.get_play_time(),
                surface_state.center_position,
                velocity,
                surface_state.grabbed_surface.to_string(),
            ])
    elif surface_state.just_entered_air:
        print_msg("LAUNCHED   :%8s;%8.3fs;P%29s;V%29s; %s", [
                player_name,
                Sc.time.get_play_time(),
                surface_state.center_position,
                velocity,
                surface_state.previous_grabbed_surface.to_string(),
            ])
    elif surface_state.just_touched_a_surface:
        var side_str: String
        if surface_state.is_touching_floor:
            side_str = "FLOOR"
        elif surface_state.is_touching_ceiling:
            side_str = "CEILING"
        else:
            side_str = "WALL"
        print_msg("TOUCHED    :%8s;%8.3fs;P%29s;V%29s; %s", [
                player_name,
                Sc.time.get_play_time(),
                surface_state.center_position,
                velocity,
                side_str,
            ])
    
    _update_navigator(delta_scaled)
    
    actions.delta_scaled = delta_scaled
    actions.log_new_presses_and_releases(
            self, Sc.time.get_play_time())
    
    # Flip the horizontal direction of the animation according to which way the
    # player is facing.
    if surface_state.horizontal_facing_sign == 1:
        animator.face_right()
    elif surface_state.horizontal_facing_sign == -1:
        animator.face_left()
    
    _process_actions()
    _process_animation()
    _process_sounds()
    _update_collision_mask()
    
    if !movement_params.bypasses_runtime_physics:
        # Since move_and_slide automatically accounts for delta, we need to
        # compensate for that in order to support our modified framerate.
        var modified_velocity: Vector2 = velocity * Sc.time.get_combined_scale()
        
        # TODO: Use the remaining pre-collision movement that move_and_slide
        #       returns. This might be needed in order to move along slopes?
        move_and_slide(
                modified_velocity,
                Sc.geometry.UP,
                false,
                4,
                Sc.geometry.FLOOR_MAX_ANGLE)
        surface_state.collision_count = get_slide_count()
    
    surface_state.previous_center_position = surface_state.center_position
    surface_state.center_position = self.position
    
    did_move_last_frame = \
            surface_state.previous_center_position != \
            surface_state.center_position
    if did_move_last_frame:
        pointer_listener.on_player_moved()


func _update_navigator(delta_scaled: float) -> void:
    navigator.update()
    
    # TODO: There's probably a more efficient way to do this.
    if navigator.actions_might_be_dirty:
        actions.copy(actions_from_previous_frame)
        _update_actions(delta_scaled)
        _update_surface_state(true)


func _handle_pointer_selections() -> void:
    if new_selection.get_has_selection():
        print_msg("NEW POINTER SELECTION:%8s;%8.3fs;P%29s; %s", [
                player_name,
                Sc.time.get_play_time(),
                str(new_selection.pointer_position),
                new_selection.navigation_destination.to_string() if \
                new_selection.get_is_selection_navigatable() else \
                "[No matching surface]"
            ])
        
        if new_selection.get_is_selection_navigatable():
            last_selection.copy(new_selection)
            navigator.navigate_path(last_selection.path)
            Sc.audio.play_sound("nav_select_success")
        else:
            print_msg("TARGET IS TOO FAR FROM ANY SURFACE")
            Sc.audio.play_sound("nav_select_fail")
        
        new_selection.clear()
        pre_selection.clear()


func _update_actions(delta_scaled: float) -> void:
    # Record actions for the previous frame.
    actions_from_previous_frame.copy(actions)
    
    # Clear actions for the current frame.
    actions.clear()
    
    # Update actions for the current frame.
    for action_source in action_sources:
        action_source.update(
                actions,
                actions_from_previous_frame,
                Sc.time.get_scaled_play_time(),
                delta_scaled,
                navigation_state)
    
    actions.start_dash = \
            Sc.level_input.is_action_just_pressed("dash") and \
            movement_params.can_dash and \
            _can_dash


# Updates physics and player states in response to the current actions.
func _process_actions() -> void:
    _previous_actions_this_frame.clear()
    
    if surface_state.is_grabbing_wall:
        current_action_type = SurfaceType.WALL
    elif surface_state.is_grabbing_floor:
        current_action_type = SurfaceType.FLOOR
    else:
        current_action_type = SurfaceType.AIR
    
    for action_handler in action_handlers:
        var is_action_relevant_for_surface: bool = \
                action_handler.type == current_action_type or \
                action_handler.type == SurfaceType.OTHER
        var is_action_relevant_for_physics_mode: bool = \
                !movement_params.bypasses_runtime_physics or \
                !action_handler.uses_runtime_physics
        if is_action_relevant_for_surface and \
                is_action_relevant_for_physics_mode:
            _previous_actions_this_frame[action_handler.name] = \
                    action_handler.process(self)


func _process_animation() -> void:
    match current_action_type:
        SurfaceType.FLOOR:
            if actions.pressed_left or actions.pressed_right:
                animator.play(PlayerAnimationType.WALK)
            else:
                animator.play(PlayerAnimationType.REST)
        SurfaceType.WALL:
            if processed_action("WallClimbAction"):
                if actions.pressed_up:
                    animator.play(PlayerAnimationType.CLIMB_UP)
                elif actions.pressed_down:
                    animator.play(PlayerAnimationType.CLIMB_DOWN)
                else:
                    Sc.logger.error()
            else:
                animator.play(PlayerAnimationType.REST_ON_WALL)
        SurfaceType.AIR:
            if velocity.y > 0:
                animator.play(PlayerAnimationType.JUMP_FALL)
            else:
                animator.play(PlayerAnimationType.JUMP_RISE)
        _:
            Sc.logger.error()


func _process_sounds() -> void:
    pass


func processed_action(name: String) -> bool:
    return _previous_actions_this_frame.get(name) == true


func release_wall() -> void:
    if !surface_state.is_grabbing_wall:
        return
    
    surface_state.is_grabbing_wall = false
    surface_state.is_grabbing_left_wall = false
    surface_state.is_grabbing_right_wall = false
    
    surface_state.is_grabbing_walk_through_walls = \
            actions.pressed_up
    
    if surface_state.is_touching_floor:
        surface_state.is_grabbing_floor = true
        surface_state.just_grabbed_floor = true
        surface_state.just_grabbed_a_surface = true
    else:
        surface_state.is_grabbing_a_surface = false


# Updates some basic surface-related state for player's actions and environment
# of the current frame.
func _update_surface_state(preserves_just_changed_state := false) -> void:
    # Flip the horizontal direction of the animation according to which way the
    # player is facing.
    if actions.pressed_face_right:
        surface_state.horizontal_facing_sign = 1
    elif actions.pressed_face_left:
        surface_state.horizontal_facing_sign = -1
    elif actions.pressed_right:
        surface_state.horizontal_facing_sign = 1
    elif actions.pressed_left:
        surface_state.horizontal_facing_sign = -1
    
    if actions.pressed_right:
        surface_state.horizontal_acceleration_sign = 1
    elif actions.pressed_left:
        surface_state.horizontal_acceleration_sign = -1
    else:
        surface_state.horizontal_acceleration_sign = 0
    
    var next_is_touching_floor: bool
    var next_is_touching_ceiling: bool
    var next_is_touching_wall: bool
    if movement_params.bypasses_runtime_physics:
        var expected_surface := \
                _get_expected_position_for_bypassing_runtime_physics().surface
        next_is_touching_floor = \
                expected_surface != null and \
                expected_surface.side == SurfaceSide.FLOOR
        next_is_touching_ceiling = \
                expected_surface != null and \
                expected_surface.side == SurfaceSide.CEILING
        next_is_touching_wall = \
                expected_surface != null and \
                (expected_surface.side == SurfaceSide.LEFT_WALL or \
                expected_surface.side == SurfaceSide.RIGHT_WALL)
        surface_state.which_wall = \
                SurfaceSide.NONE if \
                !next_is_touching_wall else \
                expected_surface.side
    else:
        # Note: These might give false negatives when colliding with a corner.
        #       AFAICT, Godot will simply pick one of the corner's adjacent
        #       segments to base the collision normal off of, so the other
        #       segment will be ignored (and the other segment could correspond
        #       to floor or ceiling).
        next_is_touching_floor = is_on_floor()
        next_is_touching_ceiling = is_on_ceiling()
        next_is_touching_wall = is_on_wall()
        surface_state.which_wall = \
                Sc.geometry.get_which_wall_collided_for_body(self)
    
    surface_state.is_touching_left_wall = \
            surface_state.which_wall == SurfaceSide.LEFT_WALL
    surface_state.is_touching_right_wall = \
            surface_state.which_wall == SurfaceSide.RIGHT_WALL
    
    var next_is_touching_a_surface := \
            next_is_touching_floor or \
            next_is_touching_ceiling or \
            next_is_touching_wall
    
    surface_state.just_touched_floor = \
            (preserves_just_changed_state and \
                    surface_state.just_touched_floor) or \
            (next_is_touching_floor and \
                    !surface_state.is_touching_floor)
    surface_state.just_stopped_touching_floor = \
            (preserves_just_changed_state and \
                    surface_state.just_stopped_touching_floor) or \
            (!next_is_touching_floor and \
                    surface_state.is_touching_floor)
    
    surface_state.just_touched_ceiling = \
            (preserves_just_changed_state and \
                    surface_state.just_touched_ceiling) or \
            (next_is_touching_ceiling and \
                    !surface_state.is_touching_ceiling)
    surface_state.just_stopped_touching_ceiling = \
            (preserves_just_changed_state and \
                    surface_state.just_stopped_touching_ceiling) or \
            (!next_is_touching_ceiling and \
                    surface_state.is_touching_ceiling)
    
    surface_state.just_touched_wall = \
            (preserves_just_changed_state and \
                    surface_state.just_touched_wall) or \
            (next_is_touching_wall and \
                    !surface_state.is_touching_wall)
    surface_state.just_stopped_touching_wall = \
            (preserves_just_changed_state and \
                    surface_state.just_stopped_touching_wall) or \
            (!next_is_touching_wall and \
                    surface_state.is_touching_wall)
    
    surface_state.just_touched_a_surface = \
            (preserves_just_changed_state and \
                    surface_state.just_touched_a_surface) or \
            (next_is_touching_a_surface and \
                    !surface_state.is_touching_a_surface)
    surface_state.just_stopped_touching_a_surface = \
            (preserves_just_changed_state and \
                    surface_state.just_stopped_touching_a_surface) or \
            (!next_is_touching_a_surface and \
                    surface_state.is_touching_a_surface)
    
    surface_state.is_touching_floor = next_is_touching_floor
    surface_state.is_touching_ceiling = next_is_touching_ceiling
    surface_state.is_touching_wall = next_is_touching_wall
    surface_state.is_touching_a_surface = next_is_touching_a_surface
    
    # Calculate the sign of a colliding wall's direction.
    surface_state.toward_wall_sign = \
            (0 if !surface_state.is_touching_wall else \
            (1 if surface_state.which_wall == SurfaceSide.RIGHT_WALL else \
            -1))
    
    surface_state.is_facing_wall = \
        (surface_state.which_wall == SurfaceSide.RIGHT_WALL and \
                surface_state.horizontal_facing_sign > 0) or \
        (surface_state.which_wall == SurfaceSide.LEFT_WALL and \
                surface_state.horizontal_facing_sign < 0)
    surface_state.is_pressing_into_wall = \
        (surface_state.which_wall == SurfaceSide.RIGHT_WALL and \
                actions.pressed_right) or \
        (surface_state.which_wall == SurfaceSide.LEFT_WALL and \
                actions.pressed_left)
    surface_state.is_pressing_away_from_wall = \
        (surface_state.which_wall == SurfaceSide.RIGHT_WALL and \
                actions.pressed_left) or \
        (surface_state.which_wall == SurfaceSide.LEFT_WALL and \
                actions.pressed_right)
    
    var facing_into_wall_and_pressing_up: bool = \
            actions.pressed_up and \
            (surface_state.is_facing_wall or \
                    surface_state.is_pressing_into_wall)
    var facing_into_wall_and_pressing_grab: bool = \
            actions.pressed_grab_wall and \
            (surface_state.is_facing_wall or \
                    surface_state.is_pressing_into_wall)
    var touching_floor_and_pressing_down: bool = \
            surface_state.is_touching_floor and \
            actions.pressed_down
    surface_state.is_triggering_wall_grab = \
            (surface_state.is_pressing_into_wall or \
            facing_into_wall_and_pressing_up or \
            facing_into_wall_and_pressing_grab) and \
            !touching_floor_and_pressing_down
    
    surface_state.is_triggering_fall_through = \
            actions.pressed_down and \
            actions.just_pressed_jump
    
    # Whether we are grabbing a wall.
    surface_state.is_grabbing_wall = \
            movement_params.can_grab_walls and (
                surface_state.is_touching_wall and \
                (surface_state.is_grabbing_wall or \
                        surface_state.is_triggering_wall_grab) and \
                !touching_floor_and_pressing_down
            )
    
    # Whether we should fall through fall-through floors.
    if surface_state.is_grabbing_wall:
        surface_state.is_falling_through_floors = actions.pressed_down
    elif surface_state.is_touching_floor:
        surface_state.is_falling_through_floors = \
                surface_state.is_triggering_fall_through
    else:
        surface_state.is_falling_through_floors = actions.pressed_down
    
    # Whether we should fall through fall-through floors.
    surface_state.is_grabbing_walk_through_walls = \
            movement_params.can_grab_walls and (
                surface_state.is_grabbing_wall or \
                actions.pressed_up
            )
    
    surface_state.velocity = velocity
    
    _update_which_side_is_grabbed(preserves_just_changed_state)
    _update_which_surface_is_grabbed(preserves_just_changed_state)


func _update_which_side_is_grabbed(
        preserves_just_changed_state := false) -> void:
    var next_is_grabbing_floor := false
    var next_is_grabbing_ceiling := false
    var next_is_grabbing_left_wall := false
    var next_is_grabbing_right_wall := false
    
    if surface_state.is_grabbing_wall:
        next_is_grabbing_left_wall = surface_state.is_touching_left_wall
        next_is_grabbing_right_wall = surface_state.is_touching_right_wall
    elif surface_state.is_grabbing_ceiling:
        next_is_grabbing_ceiling = true
    elif surface_state.is_touching_floor:
        next_is_grabbing_floor = true
    
    var next_is_grabbing_a_surface := \
            next_is_grabbing_floor or \
            next_is_grabbing_ceiling or \
            next_is_grabbing_left_wall or \
            next_is_grabbing_right_wall
    
    surface_state.just_grabbed_floor = \
            (preserves_just_changed_state and \
                    surface_state.just_grabbed_floor) or \
            (next_is_grabbing_floor and \
                    !surface_state.is_grabbing_floor)
    surface_state.just_grabbed_ceiling = \
            (preserves_just_changed_state and \
                    surface_state.just_grabbed_ceiling) or \
            (next_is_grabbing_ceiling and \
                    !surface_state.is_grabbing_ceiling)
    surface_state.just_grabbed_left_wall = \
            (preserves_just_changed_state and \
                    surface_state.just_grabbed_left_wall) or \
            (next_is_grabbing_left_wall and \
                    !surface_state.is_grabbing_left_wall)
    surface_state.just_grabbed_right_wall = \
            (preserves_just_changed_state and \
                    surface_state.just_grabbed_right_wall) or \
            (next_is_grabbing_right_wall and \
                    !surface_state.is_grabbing_right_wall)
    surface_state.just_grabbed_a_surface = \
            surface_state.just_grabbed_floor or \
            surface_state.just_grabbed_ceiling or \
            surface_state.just_grabbed_left_wall or \
            surface_state.just_grabbed_right_wall
    
    surface_state.just_entered_air = \
            (preserves_just_changed_state and \
                    surface_state.just_entered_air) or \
            (!next_is_grabbing_a_surface and \
                    surface_state.is_grabbing_a_surface)
    surface_state.just_left_air = \
            (preserves_just_changed_state and \
                    surface_state.just_left_air) or \
            (next_is_grabbing_a_surface and \
                    !surface_state.is_grabbing_a_surface)
    
    surface_state.is_grabbing_floor = next_is_grabbing_floor
    surface_state.is_grabbing_ceiling = next_is_grabbing_ceiling
    surface_state.is_grabbing_left_wall = next_is_grabbing_left_wall
    surface_state.is_grabbing_right_wall = next_is_grabbing_right_wall
    surface_state.is_grabbing_a_surface = next_is_grabbing_a_surface
    
    surface_state.grabbed_side = \
            SurfaceSide.FLOOR if \
                    surface_state.is_grabbing_floor else \
            (SurfaceSide.CEILING if \
                    surface_state.is_grabbing_ceiling else \
            (SurfaceSide.LEFT_WALL if \
                    surface_state.is_grabbing_left_wall else \
            (SurfaceSide.RIGHT_WALL if \
                    surface_state.is_grabbing_right_wall else \
            SurfaceSide.NONE)))
    match surface_state.grabbed_side:
        SurfaceSide.FLOOR:
            surface_state.grabbed_surface_normal = Sc.geometry.UP
        SurfaceSide.CEILING:
            surface_state.grabbed_surface_normal = Sc.geometry.DOWN
        SurfaceSide.LEFT_WALL:
            surface_state.grabbed_surface_normal = Sc.geometry.RIGHT
        SurfaceSide.RIGHT_WALL:
            surface_state.grabbed_surface_normal = Sc.geometry.LEFT


func _update_which_surface_is_grabbed(
        preserves_just_changed_state := false) -> void:
    if surface_state.is_grabbing_a_surface:
        if movement_params.bypasses_runtime_physics:
            _update_grab_state_from_expected_navigation(
                    preserves_just_changed_state)
        else:
            _update_grab_state_from_collision(
                    preserves_just_changed_state)
        
        Sc.geometry.get_collision_tile_map_coord(
                surface_state.collision_tile_map_coord_result,
                surface_state.grab_position,
                surface_state.grabbed_tile_map,
                surface_state.is_touching_floor,
                surface_state.is_touching_ceiling,
                surface_state.is_touching_left_wall,
                surface_state.is_touching_right_wall)
        var next_grab_position_tile_map_coord := \
                surface_state.collision_tile_map_coord_result.tile_map_coord
        if !surface_state.collision_tile_map_coord_result \
                .is_godot_floor_ceiling_detection_correct:
            match surface_state.collision_tile_map_coord_result.surface_side:
                SurfaceSide.FLOOR:
                    surface_state.is_touching_floor = true
                    surface_state.is_grabbing_floor = true
                    surface_state.is_touching_ceiling = false
                    surface_state.is_grabbing_ceiling = false
                    surface_state.just_grabbed_ceiling = false
                    surface_state.grabbed_side = SurfaceSide.FLOOR
                    surface_state.grabbed_surface_normal = Sc.geometry.UP
                SurfaceSide.CEILING:
                    surface_state.is_touching_ceiling = true
                    surface_state.is_grabbing_ceiling = true
                    surface_state.is_touching_floor = false
                    surface_state.is_grabbing_floor = false
                    surface_state.just_grabbed_floor = false
                    surface_state.grabbed_side = SurfaceSide.CEILING
                    surface_state.grabbed_surface_normal = Sc.geometry.DOWN
                SurfaceSide.LEFT_WALL, \
                SurfaceSide.RIGHT_WALL:
                    surface_state.is_touching_ceiling = \
                            !surface_state.is_touching_ceiling
                    surface_state.is_touching_floor = \
                            !surface_state.is_touching_floor
                    surface_state.is_grabbing_ceiling = false
                    surface_state.is_grabbing_floor = false
                    surface_state.just_grabbed_floor = false
                    surface_state.just_grabbed_ceiling = false
                _:
                    Sc.logger.error()
        surface_state.just_changed_tile_map_coord = \
                (preserves_just_changed_state and \
                        surface_state.just_changed_tile_map_coord) or \
                (surface_state.just_left_air or \
                        next_grab_position_tile_map_coord != \
                                surface_state.grab_position_tile_map_coord)
        surface_state.grab_position_tile_map_coord = \
                next_grab_position_tile_map_coord
        
        if surface_state.just_changed_tile_map_coord or \
                surface_state.just_changed_tile_map:
            surface_state.grabbed_tile_map_index = \
                    Sc.geometry.get_tile_map_index_from_grid_coord(
                            surface_state.grab_position_tile_map_coord,
                            surface_state.grabbed_tile_map)
        
        var next_grabbed_surface := surface_parser.get_surface_for_tile(
                surface_state.grabbed_tile_map,
                surface_state.grabbed_tile_map_index,
                surface_state.grabbed_side)
        surface_state.just_changed_surface = \
                (preserves_just_changed_state and \
                        surface_state.just_changed_surface) or \
                (surface_state.just_left_air or \
                        next_grabbed_surface != surface_state.grabbed_surface)
        if surface_state.just_changed_surface:
            surface_state.previous_grabbed_surface = \
                    surface_state.previous_grabbed_surface if \
                    preserves_just_changed_state else \
                    surface_state.grabbed_surface
        surface_state.grabbed_surface = next_grabbed_surface
        
        surface_state.center_position_along_surface.match_current_grab(
                surface_state.grabbed_surface,
                surface_state.center_position)
        
    else:
        if surface_state.just_entered_air:
            surface_state.just_changed_grab_position = true
            surface_state.just_changed_tile_map = true
            surface_state.just_changed_tile_map_coord = true
            surface_state.just_changed_surface = true
            surface_state.previous_grabbed_surface = \
                    surface_state.previous_grabbed_surface if \
                    preserves_just_changed_state else \
                    surface_state.grabbed_surface
        
        surface_state.grab_position = Vector2.INF
        surface_state.grabbed_tile_map = null
        surface_state.grab_position_tile_map_coord = Vector2.INF
        surface_state.grabbed_surface = null
        surface_state.center_position_along_surface.reset()


func _update_grab_state_from_expected_navigation(
        preserves_just_changed_state: bool) -> void:
    var position_along_surface := \
            _get_expected_position_for_bypassing_runtime_physics()
    
    var next_grab_position := \
            position_along_surface.target_projection_onto_surface
    surface_state.just_changed_grab_position = \
            (preserves_just_changed_state and \
                    surface_state.just_changed_grab_position) or \
            (surface_state.just_left_air or \
                    next_grab_position != surface_state.grab_position)
    surface_state.grab_position = next_grab_position
    
    var next_grabbed_tile_map := position_along_surface.surface.tile_map
    surface_state.just_changed_tile_map = \
            (preserves_just_changed_state and \
                    surface_state.just_changed_tile_map) or \
            (surface_state.just_left_air or \
                    next_grabbed_tile_map != \
                            surface_state.grabbed_tile_map)
    surface_state.grabbed_tile_map = next_grabbed_tile_map


func _get_expected_position_for_bypassing_runtime_physics() -> \
        PositionAlongSurface:
    return navigator.navigation_state.expected_position_along_surface if \
            navigator.is_currently_navigating else \
            navigator.get_previous_destination()


func _update_grab_state_from_collision(
        preserves_just_changed_state: bool) -> void:
    var collision := _get_attached_surface_collision(
            self,
            surface_state)
    assert((collision != null) == surface_state.is_grabbing_a_surface)
    
    var next_grab_position := collision.position
    surface_state.just_changed_grab_position = \
            (preserves_just_changed_state and \
                    surface_state.just_changed_grab_position) or \
            (surface_state.just_left_air or \
                    next_grab_position != surface_state.grab_position)
    surface_state.grab_position = next_grab_position
    
    var next_grabbed_tile_map := collision.collider
    surface_state.just_changed_tile_map = \
            (preserves_just_changed_state and \
                    surface_state.just_changed_tile_map) or \
            (surface_state.just_left_air or \
                    next_grabbed_tile_map != \
                            surface_state.grabbed_tile_map)
    surface_state.grabbed_tile_map = next_grabbed_tile_map


# Update whether or not we should currently consider collisions with
# fall-through floors and walk-through walls.
func _update_collision_mask() -> void:
    set_collision_mask_bit(
            Su.FALL_THROUGH_FLOORS_COLLISION_MASK_BIT,
            !surface_state.is_falling_through_floors)
    set_collision_mask_bit(
            Su.WALK_THROUGH_WALLS_COLLISION_MASK_BIT,
            surface_state.is_grabbing_walk_through_walls)


static func _get_attached_surface_collision(
        body: KinematicBody2D,
        surface_state: PlayerSurfaceState) -> KinematicCollision2D:
    var closest_normal_diff: float = PI
    var closest_collision: KinematicCollision2D
    for i in surface_state.collision_count:
        var current_collision := body.get_slide_collision(i)
        
        var current_normal_diff: float
        if surface_state.is_grabbing_floor:
            current_normal_diff = \
                    abs(current_collision.normal.angle_to(Sc.geometry.UP))
        elif surface_state.is_grabbing_ceiling:
            current_normal_diff = \
                    abs(current_collision.normal.angle_to(Sc.geometry.DOWN))
        elif surface_state.is_grabbing_left_wall:
            current_normal_diff = \
                    abs(current_collision.normal.angle_to(Sc.geometry.RIGHT))
        elif surface_state.is_grabbing_right_wall:
            current_normal_diff = \
                    abs(current_collision.normal.angle_to(Sc.geometry.LEFT))
        else:
            continue
        
        if current_normal_diff < closest_normal_diff:
            closest_normal_diff = current_normal_diff
            closest_collision = current_collision
    
    return closest_collision


func start_dash(horizontal_acceleration_sign: int) -> void:
    if !_can_dash or \
            !movement_params.can_dash:
        return
    
    var start_max_speed := \
            movement_params.max_horizontal_speed_default * \
            movement_params.dash_speed_multiplier
    var end_max_speed := movement_params.max_horizontal_speed_default
    var duration: float = \
            movement_params.dash_fade_duration / \
            Sc.time.get_combined_scale()
    var delay: float = \
            (movement_params.dash_duration - 
            movement_params.dash_fade_duration) / \
            Sc.time.get_combined_scale()
    
    current_max_horizontal_speed = start_max_speed
    
    velocity.x = current_max_horizontal_speed * horizontal_acceleration_sign
    velocity.y += movement_params.dash_vertical_boost
    
    _dash_fade_tween.stop_all()
    _dash_fade_tween.interpolate_property(
            self,
            "current_max_horizontal_speed",
            start_max_speed,
            end_max_speed,
            duration,
            "ease_in",
            delay,
            TimeType.PLAY_RENDER_SCALED)
    _dash_fade_tween.start()
    
    Sc.time.clear_timeout(_dash_cooldown_timeout)
    _dash_cooldown_timeout = Sc.time.set_timeout(
            funcref(self, "set"),
            movement_params.dash_cooldown,
            ["_can_dash", true])
    
    if horizontal_acceleration_sign > 0:
        animator.face_right()
    else:
        animator.face_left()
    
    _can_dash = false


# Conditionally prints the given message, depending on the Player's
# configuration.
func print_msg(
        message_template: String,
        message_args = null) -> void:
    if Su.is_surfacer_logging and \
            movement_params.logs_player_actions and \
            (is_human_player or \
                    movement_params.logs_computer_player_events):
        if message_args != null:
            Sc.logger.print(message_template % message_args)
        else:
            Sc.logger.print(message_template)


func set_is_sprite_visible(is_visible: bool) -> void:
    animator.visible = is_visible


func get_is_sprite_visible() -> bool:
    return animator.visible


func set_position(position: Vector2) -> void:
    self.position = position
    surface_state.center_position = position
    surface_state.center_position_along_surface.match_current_grab(
            surface_state.grabbed_surface,
            surface_state.center_position)


func get_current_animation_state(result: PlayerAnimationState) -> void:
    result.player_position = position
    result.animation_type = animator.get_current_animation_type()
    result.animation_position = \
            animator.animation_player.current_animation_position
    result.facing_left = surface_state.horizontal_facing_sign == -1
