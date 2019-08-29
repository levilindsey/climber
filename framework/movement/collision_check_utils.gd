class_name CollisionCheckUtils

# Checks whether a collision would occur with any surface during the given instructions. This
# is calculated by stepping through each discrete physics frame, which should exactly emulate the
# actual Player trajectory that would be used.
static func check_instructions_for_collision(global_calc_params: MovementCalcGlobalParams, \
        instructions: MovementInstructions, vertical_step: MovementVertCalcStep, \
        horizontal_steps: Array) -> SurfaceCollision:
    var movement_params := global_calc_params.movement_params
    var current_instruction_index := -1
    var next_instruction: MovementInstruction = instructions.instructions[0]
    var delta := Utils.PHYSICS_TIME_STEP
    var is_first_jump := true
    # On average, an instruction set will start halfway through a physics frame, so let's use that
    # average here.
    var previous_time: float = instructions.instructions[0].time - delta * 0.5
    var current_time := previous_time + delta
    var duration := instructions.duration
    var is_pressing_left := false
    var is_pressing_right := false
    var is_pressing_jump := false
    var horizontal_acceleration_sign := 0
    var position := global_calc_params.origin_constraint.position
    var velocity := Vector2.ZERO
    var has_started_instructions := false
    var space_state := global_calc_params.space_state
    var shape_query_params := global_calc_params.shape_query_params
    var displacement: Vector2
    var collision: SurfaceCollision
    
    var current_horizontal_step_index := 0
    var current_horizontal_step: MovementCalcStep = horizontal_steps[0]
    var continuous_horizontal_state: Array
    var continuous_vertical_state: Array
    var continuous_position: Vector2
    
    # Record the position for edge annotation debugging.
    var frame_discrete_positions := []
    var frame_continuous_positions := [position]
    
    # Iterate through each physics frame, checking each for a collision.
    while current_time < duration:
        # Update position for this frame, according to the velocity from the previous frame.
        delta = Utils.PHYSICS_TIME_STEP
        displacement = velocity * delta
        shape_query_params.transform = Transform2D(0.0, position)
        shape_query_params.motion = displacement
        
        # Iterate through the horizontal steps in order to calculate what the frame positions would
        # be according to our continuous movement calculations.
        while current_horizontal_step.time_step_end < current_time:
            current_horizontal_step_index += 1
            current_horizontal_step = horizontal_steps[current_horizontal_step_index]
        continuous_horizontal_state = \
                HorizontalMovementUtils.calculate_horizontal_end_state_for_time(movement_params, \
                        current_horizontal_step, current_time)
        continuous_vertical_state = \
                VerticalMovementUtils.calculate_vertical_end_state_for_time_from_step( \
                        movement_params, vertical_step, current_time)
        continuous_position.x = continuous_horizontal_state[0]
        continuous_position.y = continuous_vertical_state[0]
        
        if displacement != Vector2.ZERO:
            # Check for collision.
            # FIXME: LEFT OFF HERE: DEBUGGING: Add back in:
            # - To debug why this is failing, try rendering only the failing path somehow.
#            collision = FrameCollisionCheckUtils.check_frame_for_collision(space_state, \
#                    shape_query_params, movement_params.collider_half_width_height, \
#                    global_calc_params.surface_parser)
            if collision != null:
                instructions.frame_discrete_positions = PoolVector2Array(frame_discrete_positions)
                instructions.frame_continuous_positions = PoolVector2Array(frame_continuous_positions)
                return collision
        else:
            # Don't check for collisions if we aren't moving anywhere.
            # We can assume that all frame starting positions are not colliding with anything;
            # otherwise, it should have been caught from the motion of the previous frame. The
            # collision margin could yield collision results in the initial frame, but we want to
            # ignore these.
            collision = null
        
        # This point corresponds to when Player._physics_process would be called:
        # - The position for the current frame has been calculated from the previous frame's velocity.
        # - Any collision state has been calculated.
        # - We can now check whether inputs have changed.
        # - We can now calculate the velocity for the current frame.
        
        while next_instruction != null and next_instruction.time < current_time:
            current_instruction_index += 1
            
            # FIXME: --A:
            # - Think about at what point the velocity change from the step instruction happens.
            # - Is this at the right time?
            # - Is it too late?
            # - Does it reflect actual playback?
            # - Should initial jump_boost happen sooner?
            
            match next_instruction.input_key:
                "jump":
                    is_pressing_jump = next_instruction.is_pressed
                    if is_pressing_jump:
                        velocity.y = movement_params.jump_boost
                "move_left":
                    is_pressing_left = next_instruction.is_pressed
                    horizontal_acceleration_sign = -1 if is_pressing_left else 0
                "move_right":
                    is_pressing_right = next_instruction.is_pressed
                    horizontal_acceleration_sign = 1 if is_pressing_right else 0
                _:
                    Utils.error()
            
            next_instruction = instructions.instructions[current_instruction_index + 1] if \
                    current_instruction_index + 1 < instructions.instructions.size() else null
        
        # FIXME: E: After implementing instruction execution, check whether it also does this, and
        #           whether this should be uncommented.
#        if !has_started_instructions:
#            has_started_instructions = true
#            # When we start executing the instruction set, the current elapsed time of the
#            # instruction set will be less than a full frame. So we use a delta that represents the
#            # actual time the instruction set should have been running for so far.
#            delta = current_time - instructions.instructions[0].time
        
        # Record the position for edge annotation debugging.
        frame_discrete_positions.push_back(position)
        
        # Update state for the next frame.
        position += displacement
        velocity = MovementUtils.update_velocity_in_air(velocity, delta, is_pressing_jump, \
                is_first_jump, horizontal_acceleration_sign, movement_params)
        velocity = MovementUtils.cap_velocity(velocity, movement_params)
        previous_time = current_time
        current_time += delta
        
        # Record the position for edge annotation debugging.
        frame_continuous_positions.push_back(continuous_position)
    
    # Check the last frame that puts us up to end_time.
    delta = duration - current_time
    displacement = velocity * delta
    shape_query_params.transform = Transform2D(0.0, position)
    shape_query_params.motion = displacement
    continuous_horizontal_state = \
            HorizontalMovementUtils.calculate_horizontal_end_state_for_time(movement_params, \
                    current_horizontal_step, duration)
    continuous_vertical_state = \
            VerticalMovementUtils.calculate_vertical_end_state_for_time_from_step( \
                    movement_params, vertical_step, duration)
    continuous_position.x = continuous_horizontal_state[0]
    continuous_position.y = continuous_vertical_state[0]
    # FIXME: LEFT OFF HERE: DEBUGGING: Add back in:
    # - To debug why this is failing, try rendering only the failing path somehow.
#    collision = FrameCollisionCheckUtils.check_frame_for_collision(space_state, \
#            shape_query_params, movement_params.collider_half_width_height, \
#            global_calc_params.surface_parser)
    if collision != null:
        instructions.frame_discrete_positions = PoolVector2Array(frame_discrete_positions)
        instructions.frame_continuous_positions = PoolVector2Array(frame_continuous_positions)
        return collision
    
    # Record the position for edge annotation debugging.
    frame_discrete_positions.push_back(position + displacement)
    frame_continuous_positions.push_back(continuous_position)
    instructions.frame_discrete_positions = PoolVector2Array(frame_discrete_positions)
    instructions.frame_continuous_positions = PoolVector2Array(frame_continuous_positions)
    
    return null

# Checks whether a collision would occur with any surface during the given horizontal step. This
# is calculated by stepping through each physics frame, which should exactly emulate the actual
# Player trajectory that would be used. The main error with this approach is that successive steps
# will be tested with their start time perfectly aligned to a physics frame boundary, but when
# executing a resulting instruction set, the physics frame boundaries will line up at different
# times.
static func check_discrete_horizontal_step_for_collision( \
        global_calc_params: MovementCalcGlobalParams, local_calc_params: MovementCalcLocalParams, \
        horizontal_step: MovementCalcStep) -> SurfaceCollision:
    var movement_params := global_calc_params.movement_params
    var delta := Utils.PHYSICS_TIME_STEP
    var is_first_jump := true
    # On average, an instruction set will start halfway through a physics frame, so let's use that
    # average here.
    var previous_time := horizontal_step.time_step_start - delta * 0.5
    var current_time := previous_time + delta
    var step_end_time := horizontal_step.time_step_end
    var position := horizontal_step.position_step_start
    var velocity := horizontal_step.velocity_step_start
    var has_started_instructions := false
    var jump_instruction_end_time := local_calc_params.vertical_step.time_instruction_end
    var is_pressing_jump := jump_instruction_end_time > current_time
    var is_pressing_move_horizontal := current_time > horizontal_step.time_instruction_start and \
            current_time < horizontal_step.time_instruction_end
    var horizontal_acceleration_sign := 0
    var space_state := global_calc_params.space_state
    var shape_query_params := global_calc_params.shape_query_params
    var displacement: Vector2
    var collision: SurfaceCollision
    
    # Iterate through each physics frame, checking each for a collision.
    while current_time < step_end_time:
        # Update state for the current frame.
        delta = Utils.PHYSICS_TIME_STEP
        displacement = velocity * delta
        shape_query_params.transform = Transform2D(0.0, position)
        shape_query_params.motion = displacement
        
        if displacement != Vector2.ZERO:
            # Check for collision.
            collision = FrameCollisionCheckUtils.check_frame_for_collision(space_state, \
                    shape_query_params, movement_params.collider_half_width_height, \
                    global_calc_params.surface_parser)
            if collision != null:
                return collision
        else:
            # Don't check for collisions if we aren't moving anywhere.
            # We can assume that all frame starting positions are not colliding with anything;
            # otherwise, it should have been caught from the motion of the previous frame. The
            # collision margin could yield collision results in the initial frame, but we want to
            # ignore these.
            collision = null
        
        # Determine whether the jump button is still being pressed.
        is_pressing_jump = jump_instruction_end_time > current_time
        
        # Determine whether the horizontal movement button is still being pressed.
        is_pressing_move_horizontal = current_time > horizontal_step.time_instruction_start and \
            current_time < horizontal_step.time_instruction_end
        horizontal_acceleration_sign = \
            horizontal_step.horizontal_acceleration_sign if is_pressing_move_horizontal else 0
        
        # FIXME: E: After implementing instruction execution, check whether it also does this, and
        #           whether this should be uncommented.
#        if !has_started_instructions:
#            has_started_instructions = true
#            # When we start executing the instruction, the current elapsed time of the instruction
#            # will be less than a full frame. So we use a delta that represents the actual time the
#            # instruction should have been running for so far.
#            delta = current_time - horizontal_step.time_step_start
        
        # Update state for the next frame.
        position += displacement
        velocity = MovementUtils.update_velocity_in_air(velocity, delta, is_pressing_jump, \
                is_first_jump, horizontal_acceleration_sign, movement_params)
        velocity = MovementUtils.cap_velocity(velocity, movement_params)
        previous_time = current_time
        current_time += delta
    
    # Check the last frame that puts us up to end_time.
    delta = step_end_time - current_time
    displacement = velocity * delta
    shape_query_params.transform = Transform2D(0.0, position)
    shape_query_params.motion = displacement
    collision = FrameCollisionCheckUtils.check_frame_for_collision(space_state, \
            shape_query_params, movement_params.collider_half_width_height, \
            global_calc_params.surface_parser)
    if collision != null:
        return collision
    
    return null

# Checks whether a collision would occur with any surface during the given horizontal step. This
# is calculated by considering the continuous physics state according to the parabolic equations of
# motion. This does not necessarily accurately reflect the actual Player trajectory that would be
# used.
static func check_continuous_horizontal_step_for_collision( \
        global_calc_params: MovementCalcGlobalParams, local_calc_params: MovementCalcLocalParams, \
        horizontal_step: MovementCalcStep) -> SurfaceCollision:
    var movement_params := global_calc_params.movement_params
    var vertical_step := local_calc_params.vertical_step
    var collider_half_width_height := movement_params.collider_half_width_height
    var surface_parser := global_calc_params.surface_parser
    var delta := Utils.PHYSICS_TIME_STEP
    var previous_time := horizontal_step.time_step_start
    var current_time := previous_time + delta
    var step_end_time := horizontal_step.time_step_end
    var previous_position := horizontal_step.position_step_start
    var current_position := previous_position
    var space_state := global_calc_params.space_state
    var shape_query_params := global_calc_params.shape_query_params
    var horizontal_state: Array
    var vertical_state: Array
    var collision: SurfaceCollision
    
    # Iterate through each physics frame, checking each for a collision.
    while current_time < step_end_time:
        # Update state for the current frame.
        horizontal_state = HorizontalMovementUtils.calculate_horizontal_end_state_for_time( \
                movement_params, horizontal_step, current_time)
        vertical_state = VerticalMovementUtils.calculate_vertical_end_state_for_time_from_step( \
                movement_params, vertical_step, current_time)
        current_position.x = horizontal_state[0]
        current_position.y = vertical_state[0]
        shape_query_params.transform = Transform2D(0.0, previous_position)
        shape_query_params.motion = current_position - previous_position
        
        assert(shape_query_params.motion != Vector2.ZERO)
        
        # Check for collision.
        collision = FrameCollisionCheckUtils.check_frame_for_collision(space_state, \
                shape_query_params, collider_half_width_height, surface_parser)
        if collision != null:
            return collision
        
        # Update state for the next frame.
        previous_position = current_position
        previous_time = current_time
        current_time += delta
    
    # Check the last frame that puts us up to end_time.
    current_time = step_end_time
    if !Geometry.are_floats_equal_with_epsilon(previous_time, current_time):
        horizontal_state = HorizontalMovementUtils.calculate_horizontal_end_state_for_time( \
                movement_params, horizontal_step, current_time)
        vertical_state = VerticalMovementUtils.calculate_vertical_end_state_for_time_from_step( \
                movement_params, vertical_step, current_time)
        current_position.x = horizontal_state[0]
        current_position.y = vertical_state[0]
        shape_query_params.transform = Transform2D(0.0, previous_position)
        shape_query_params.motion = current_position - previous_position
        assert(shape_query_params.motion != Vector2.ZERO)
        collision = FrameCollisionCheckUtils.check_frame_for_collision(space_state, \
                shape_query_params, collider_half_width_height, surface_parser)
        if collision != null:
            return collision
    
    return null