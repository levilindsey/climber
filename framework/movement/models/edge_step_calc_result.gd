class_name EdgeStepCalcResult

enum {
    MOVEMENT_VALID,
    TARGET_OUT_OF_REACH,
    NO_VALID_CONSTRAINT,
    NO_VALID_TARGET_FROM_FAKE,
    ALREADY_BACKTRACKED_FOR_SURFACE,
    RECURSION_VALID,
    BACKTRACKING_VALID,
    BACKTRACKING_INVALID,
    UNKNOWN,
}

static func to_string(result: int) -> String:
    match result:
        MOVEMENT_VALID:
            return "MOVEMENT_VALID"
        TARGET_OUT_OF_REACH:
            return "TARGET_OUT_OF_REACH"
        NO_VALID_CONSTRAINT:
            return "NO_VALID_CONSTRAINT"
        NO_VALID_TARGET_FROM_FAKE:
            return "NO_VALID_TARGET_FROM_FAKE"
        ALREADY_BACKTRACKED_FOR_SURFACE:
            return "ALREADY_BACKTRACKED_FOR_SURFACE"
        RECURSION_VALID:
            return "RECURSION_VALID"
        BACKTRACKING_VALID:
            return "BACKTRACKING_VALID"
        BACKTRACKING_INVALID:
            return "NO_RESULTS_FROM_BACKTRACKING"
        UNKNOWN, _:
            return "UNKNOWN"

static func to_description_string(result: int) -> String:
    match result:
        MOVEMENT_VALID:
            return "Movement is valid."
        TARGET_OUT_OF_REACH:
            return "The target is out of reach."
        NO_VALID_CONSTRAINT:
            return "There is no valid edge constraint for movement around the colliding surface."
        NO_VALID_TARGET_FROM_FAKE:
            return "There is no valid target constraint to replace the fake constraint."
        ALREADY_BACKTRACKED_FOR_SURFACE:
            return "We have already backtracked to consider a new max jump height from colliding with this surface."
        RECURSION_VALID:
            return "Valid movement was found when recursing."
        BACKTRACKING_VALID:
            return "Valid movement was found when backtracking."
        BACKTRACKING_INVALID:
            return "No valid movement was found despite backtracking to consider a new max jump height."
        UNKNOWN, _:
            return "Unexpected result"
