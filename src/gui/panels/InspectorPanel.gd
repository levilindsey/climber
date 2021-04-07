class_name InspectorPanel
extends VBoxContainer

const PANEL_MARGIN_RIGHT := 20.0
const TOGGLE_DURATION := 0.2
const DEFAULT_GUI_SCALE := 1.0

var is_open := false setget _set_is_open,_get_is_open

var _toggle_open_tween: Tween

var _checkbox_control_item_classes := [
    PlayerAnnotatorSettingsLabeledControlItem,
    LevelAnnotatorSettingsLabeledControlItem,
    PlayerPositionAnnotatorSettingsLabeledControlItem,
    SurfacesAnnotatorSettingsLabeledControlItem,
    PlayerTrajectoryAnnotatorSettingsLabeledControlItem,
    RulerAnnotatorSettingsLabeledControlItem,
    LogSurfacerEventsSettingsLabeledControlItem,
]

func _ready() -> void:
    assert(Surfacer.is_inspector_enabled)
    
    theme = Gs.theme
    
    Gs.add_gui_to_scale(self, DEFAULT_GUI_SCALE)
    
    _set_footer_visibility(!is_open)
    
    _toggle_open_tween = Tween.new()
    add_child(_toggle_open_tween)
    
    Surfacer.platform_graph_inspector = \
            $PanelContainer/VBoxContainer/Sections/InspectorContainer/ \
            PlatformGraphInspector
    Surfacer.legend = \
            $PanelContainer/VBoxContainer/Sections/Legend
    Surfacer.selection_description = \
            $PanelContainer/VBoxContainer/Sections/SelectionDescription
    
    if (Surfacer.inspector_panel_starts_open or \
                    Surfacer.debug_params.has("limit_parsing")) and \
            !OS.has_touchscreen_ui_hint():
        _set_is_open(true)
    
    _initialize_annotator_checkboxes()
    
    # Tell the element annotator to populate the legend, now that it's
    # available.
    Surfacer.annotators.element_annotator.update()
    
    update_gui_scale(1.0)

func _exit_tree() -> void:
    Gs.remove_gui_to_scale(self)
    Gs.active_overlays.erase(self)
    Surfacer.platform_graph_inspector = null
    Surfacer.legend = null
    Surfacer.selection_description = null

func update_gui_scale(gui_scale: float) -> bool:
    update_gui_scale_helper(gui_scale)
    update_gui_scale_helper(1.0)
    call_deferred("update_gui_scale_helper", 1.0)
    return true

func update_gui_scale_helper(gui_scale: float) -> void:
    for child in get_children():
        if child is Control:
            Gs.utils._scale_gui_recursively(child, gui_scale)
    rect_size.x = $PanelContainer.rect_size.x
    _set_footer_visibility(!is_open)
    rect_position.x = \
            get_viewport().size.x - \
            rect_size.x - \
            PANEL_MARGIN_RIGHT * Gs.gui_scale
    rect_position.y = \
            0.0 if \
            is_open else \
            _get_closed_position_y()

func _initialize_annotator_checkboxes() -> void:
    for item_class in _checkbox_control_item_classes:
        var item: CheckboxLabeledControlItem = item_class.new()
        item.pressed = item.get_is_pressed()
        var checkbox := CheckBox.new()
        checkbox.pressed = item.get_is_pressed()
        checkbox.text = item.label
        checkbox.connect( \
                "pressed", \
                self, \
                "_on_checkbox_pressed", \
                [item])
        $PanelContainer/VBoxContainer/Sections/MarginContainer/Annotators \
                .add_child(checkbox)
        item.control = checkbox

func _on_checkbox_pressed(item: CheckboxLabeledControlItem) -> void:
    Gs.utils.give_button_press_feedback()
    item.pressed = !item.pressed
    item.on_pressed(item.pressed)

func _get_closed_position_y() -> float:
    return -$PanelContainer.rect_size.y - 1.0

func _set_is_open(value: bool) -> void:
    if is_open != value:
        _toggle_open()

func _get_is_open() -> bool:
    return is_open

func _toggle_open() -> void:
    is_open = !is_open
    
    var position_y_start: float = self.rect_position.y
    var position_y_end: float
    var duration: float
    var text: String
    
    if is_open:
        position_y_end = 0.0
        duration = TOGGLE_DURATION
    else:
        position_y_end = _get_closed_position_y()
        duration = TOGGLE_DURATION
    
    # Start the sliding animation.
    _toggle_open_tween.reset_all()
    _toggle_open_tween.interpolate_property( \
            self, \
            "rect_position:y", \
            position_y_start, \
            position_y_end, \
            duration, \
            Tween.TRANS_LINEAR, \
            Tween.EASE_IN)
    _toggle_open_tween.start()
    
    _set_footer_visibility(!is_open)
    
    if is_open:
        Surfacer.platform_graph_inspector.select_first_item()
    else:
        Surfacer.platform_graph_inspector.collapse()
    
    Gs.active_overlays.erase(self)
    if is_open:
        Gs.active_overlays.push_back(self)
    
    Gs.utils.release_focus()

func _set_footer_visibility(is_visible: bool) -> void:
    $Spacer.visible = is_visible
    $Footer.visible = is_visible
    rect_size.y = \
            $PanelContainer.rect_size.y + \
                    $Spacer.rect_size.y + \
                    $Footer.rect_size.y if \
            is_visible else \
            $PanelContainer.rect_size.y

func _on_GearButton_pressed() -> void:
    Gs.utils.give_button_press_feedback()
    _toggle_open()

func _on_PauseButton_pressed() -> void:
    Gs.utils.give_button_press_feedback()
    Gs.level.pause()