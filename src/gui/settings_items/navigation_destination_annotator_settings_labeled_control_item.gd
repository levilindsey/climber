class_name NavigationDestinationAnnotatorSettingsLabeledControlItem
extends CheckboxLabeledControlItem


const LABEL := "Nav destination"
const DESCRIPTION := ("")


func _init(__ = null).(
        LABEL,
        DESCRIPTION \
        ) -> void:
    pass


func on_pressed(pressed: bool) -> void:
    Su.is_navigation_destination_shown = pressed
    Sc.save_state.set_setting(
            Su.NAVIGATION_DESTINATION_SHOWN_SETTINGS_KEY,
            pressed)


func get_is_pressed() -> bool:
    return Su.is_navigation_destination_shown


func get_is_enabled() -> bool:
    return true
