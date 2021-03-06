class_name EdgeFromJsonFactory
extends Node


var EDGE_TYPE_TO_CLASS := {
    EdgeType.FROM_AIR_EDGE: FromAirEdge,
    EdgeType.CLIMB_DOWN_WALL_TO_FLOOR_EDGE: ClimbDownWallToFloorEdge,
    EdgeType.CLIMB_OVER_WALL_TO_FLOOR_EDGE: ClimbOverWallToFloorEdge,
    EdgeType.FALL_FROM_FLOOR_EDGE: FallFromFloorEdge,
    EdgeType.FALL_FROM_WALL_EDGE: FallFromWallEdge,
    EdgeType.INTRA_SURFACE_EDGE: IntraSurfaceEdge,
    EdgeType.JUMP_FROM_SURFACE_EDGE: JumpFromSurfaceEdge,
    EdgeType.WALK_TO_ASCEND_WALL_FROM_FLOOR_EDGE: \
            WalkToAscendWallFromFloorEdge,
}


func create(
        json_object: Dictionary,
        context: Dictionary) -> Edge:
    var edge: Edge = EDGE_TYPE_TO_CLASS[int(json_object.t)].new()
    edge.load_from_json_object(json_object, context)
    return edge
