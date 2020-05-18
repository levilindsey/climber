extends InspectorItemController
class_name DestinationSurfaceItemController

const TYPE := InspectorItemType.DESTINATION_SURFACE
const IS_LEAF := false
const STARTS_COLLAPSED := true

var origin_surface: Surface
var destination_surface: Surface
# Dictionary<EdgeType, Array<Edge>>
var edge_types_to_valid_edges: Dictionary
# Dictionary<EdgeType, Array<FailedEdgeAttempt>>
var edge_types_to_failed_edges: Dictionary
# Array<JumpLandPositions>
var jump_type_jump_land_positions: Array
# Array<JumpLandPositions>
var fall_type_jump_land_positions: Array

func _init( \
        parent_item: TreeItem, \
        tree: Tree, \
        graph: PlatformGraph, \
        origin_surface: Surface, \
        destination_surface: Surface, \
        edge_types_to_valid_edges: Dictionary, \
        edge_types_to_failed_edges: Dictionary) \
        .( \
        TYPE, \
        IS_LEAF, \
        STARTS_COLLAPSED, \
        parent_item, \
        tree, \
        graph) -> void:
    self.origin_surface = origin_surface
    self.destination_surface = destination_surface
    self.edge_types_to_valid_edges = edge_types_to_valid_edges
    self.edge_types_to_failed_edges = edge_types_to_failed_edges
    self.jump_type_jump_land_positions = \
            JumpLandPositionsUtils.calculate_jump_land_positions_for_surface_pair( \
                    graph.movement_params, \
                    origin_surface, \
                    destination_surface, \
                    true)
    self.fall_type_jump_land_positions = \
            JumpLandPositionsUtils.calculate_jump_land_positions_for_surface_pair( \
                    graph.movement_params, \
                    origin_surface, \
                    destination_surface, \
                    false)
    _post_init()

func to_string() -> String:
    return "%s{ [%s, %s] }" % [ \
        InspectorItemType.get_type_string(TYPE), \
        str(destination_surface.first_point), \
        str(destination_surface.last_point), \
    ]

func get_text() -> String:
    return "%s [%s, %s]" % [ \
        SurfaceSide.get_side_string(destination_surface.side), \
        str(destination_surface.first_point), \
        str(destination_surface.last_point), \
    ]

func find_and_expand_controller( \
        search_type: int, \
        metadata: Dictionary) -> InspectorItemController:
    assert(search_type == InspectorSearchType.EDGE)
    
    if metadata.destination_surface != destination_surface:
        return null
    
    expand()
    
    var result: InspectorItemController
    var child := tree_item.get_children()
    while child != null:
        result = child.get_metadata(0).find_and_expand_controller( \
                search_type, \
                metadata)
        if result != null:
            return result
        child = child.get_next()
    
    select()
    
    return null

func _create_children_inner() -> void:
    var valid_edges: Array
    var failed_edges: Array
    var is_a_jump_calculator: bool
    var jump_land_positions: Array
    
    for edge_type in EdgeType.values():
        if InspectorItemController.EDGE_TYPES_TO_SKIP.find(edge_type) >= 0:
            continue
        
        valid_edges = \
                edge_types_to_valid_edges[edge_type] if \
                edge_types_to_valid_edges.has(edge_type) else \
                []
        failed_edges = \
                edge_types_to_failed_edges[edge_type] if \
                edge_types_to_failed_edges.has(edge_type) else \
                []
        
        if !valid_edges.empty() or \
                !failed_edges.empty():
            is_a_jump_calculator = InspectorItemController.JUMP_CALCULATORS.find(edge_type) >= 0
            jump_land_positions = \
                    jump_type_jump_land_positions if \
                    is_a_jump_calculator else \
                    fall_type_jump_land_positions
            EdgeTypeInSurfacesGroupItemController.new( \
                    tree_item, \
                    tree, \
                    graph, \
                    origin_surface, \
                    destination_surface, \
                    edge_type, \
                    valid_edges, \
                    failed_edges, \
                    jump_land_positions)

func _destroy_children_inner() -> void:
    # Do nothing.
    pass

func _draw_annotations() -> void:
    # FIXME: -----------------
    pass