class_name ActiveTrajectoryAnnotatorSettingsLabeledControlItem
extends CheckboxLabeledControlItem


const LABEL := "Active trajectory"
const DESCRIPTION := ("")


func _init(__ = null).(
        LABEL,
        DESCRIPTION \
        ) -> void:
    pass


func on_pressed(pressed: bool) -> void:
    Su.is_active_trajectory_shown = pressed
    Sc.save_state.set_setting(
            Su.ACTIVE_TRAJECTORY_SHOWN_SETTINGS_KEY,
            pressed)


func get_is_pressed() -> bool:
    return Su.is_active_trajectory_shown


func get_is_enabled() -> bool:
    return true
