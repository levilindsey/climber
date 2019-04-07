extends Reference
class_name PlatformGraphNavigator

# FIXME: LEFT OFF HERE
# - Update the HumanPlayer to also use a navigator, and use that to test (print) when state changes
#   occur and calculating:
#   - which surface was hit (it's vertices and it's type),
#   - then the current PositionOnSurface,
#   - then which other surfaces are nearby,
#     - Will need to add that function for getting nearby surfaces
#   - then a start for implemententing EdgeInstructions
# - Implement some additional annotations that are updated dynamically as the player moves:
#   - Render a dot for the player's current PositionOnSurface
#   - 

# Updates player-graph state in response to the given new SurfaceState.
func update(surface_state: SurfaceState) -> void:
    pass

func find_path(start_node: PoolVector2Array, end_node: PoolVector2Array):
    # TODO
    pass

func traverse_edge(start: PositionOnSurface, end: PositionOnSurface) -> void:
    # TODO
    pass

# A reference to the actual surface node, and a specification for position along that node.
# 
# FIXME: ACTUALLY, should the following be true? Not extending past might be both slightly more realistic as well as better for handling the offset I wanted to add before jumping landing near the edge anyway...
# Note: A position along a surface could actually extend past the edges of the surface. This is
# because a player's bounding box has non-zero width and height.
# 
# The position always indicates the center of the player's bounding box.
class PositionOnSurface extends Reference:
    func _init():
        pass
    
    # TODO
    # - A reference to the actual surface/Node
    # - Specification for position along that node.
    # - Node type

# Information for how to move from a start position on one surface to an end position on another
# surface.
class EdgeInstructions extends Reference:
    func _init():
        pass
    
    # TODO
    # - start_node_start_pos: PositionOnSurface
    # - end_node_end_pos: PositionOnSurface
    # - end_node_start_pos: PositionOnSurface
    # - end_node_end_pos: PositionOnSurface
    # - instruction set to move from start to end node
    # - instruction set to move within start node
    # - instruction set to move within end node
