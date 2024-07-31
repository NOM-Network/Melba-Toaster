extends Node
class_name Variables

static var default_model_position := Vector2(740, 1160)
static var default_model_scale := 0.33
static var default_lower_third_position := [Vector2(35, 682), Vector2(1, 1)]

static var positions := {
	# use Tulpes - [ position, scale ]
	"intro": {}, # placeholder for intro animation

	"under": {
		"model": [Vector2(740, 2080), 0.33],
		"lower_third": default_lower_third_position,
	},

	"default": {
		"model": [default_model_position, default_model_scale],
		"lower_third": default_lower_third_position,
	},

	"gaming": {
		"model": [Vector2(1680, 1420), 0.3],
		"lower_third": [Vector2(35, 800), Vector2(0.777, 0.777)],
	},

	"close": {
		"model": [Vector2(740, 1500), 0.5],
		"lower_third": default_lower_third_position,
	},

	"fullscreen": {
		"model": [Vector2(920, 3265), 1.35],
		"lower_third": default_lower_third_position,
	},

	"full_height": {
		"model": [Vector2(740, 520), 0.15],
		"lower_third": default_lower_third_position,
	},

	"collab": {
		"model": [Vector2(362, 963.8469), 0.28],
		"lower_third": [Vector2(35, 700), Vector2(0.777, 0.777)],
	},

	"collab_song": {
		"model": [Vector2(377, 1054), default_model_scale],
		"lower_third": default_lower_third_position,
	}
}

static var pinnable_assets := {
	"censor": PinnableAsset.new("CensorAnimation", "Nose", Vector2(0, -120), 1.5),
	"glasses": PinnableAsset.new("GlassSprites", "Nose", Vector2(10, -110), 1.1),
	"hat": PinnableAsset.new("Hat", "ArtMesh67", Vector2(150, 100), 1.1),
	"band": PinnableAsset.new("TetoBand", "ArtMesh30", Vector2(-75, 70), 1.0),
	"pikmin": PinnableAsset.new("Pikmin", "ArtMesh4", Vector2(120, -120), 0.8, 0, 3)
}

static var toggles := {
	"toast": Toggle.new("Param9", 0.5),
	"void": Toggle.new("Param14", 0.5),
	"tears": Toggle.new("Param20", 0.5),
	"toa": Toggle.new("Param21", 1.0),
	"confused": Toggle.new("Param18", 0.5),
	"gymbag": Toggle.new("Param28", 0.5)
}

static var animations := {
	"idle1": Live2DAnimation.new(0, 7), # Original: 8.067
	"idle2": Live2DAnimation.new(1, 4), # Original: 4.267
	"idle3": Live2DAnimation.new(2, 5), # Original: 5.367
	"sleep": Live2DAnimation.new(3, 10.3, true), # Original: 10.3
	"confused": Live2DAnimation.new(4, 4.0, true) # Original: 10
}

static var emotions_modifiers := {
    # Negative
	"anger": - 1.0,
		"disappointment": - 0.5,
		"disgust": - 0.5,
		"embarrassment": - 0.3,
		"fear": - 0.3,
		"grief": - 0.3,
		"annoyance": - 0.1,
		"confusion": - 0.1,
		"sadness": - 0.1,

	# Neutral
		"admiration": 0.0,
		"approval": 0.0,
		"caring": 0.0,
		"curiosity": 0.0,
		"desire": 0.0,
		"disapproval": 0.0,
		"gratitude": 0.0,
		"nervousness": 0.0,
		"pride": 0.0,
		"realization": 0.0,
		"relief": 0.0,
		"remorse": 0.0,
		"neutral": 0.0,
		"anticipation": 0.0,

	# Positive
		"amusement": 0.5,
		"excitement": 0.5,
		"joy": 0.5,
		"love": 0.5,
		"surprise": 0.5,
		"optimism": 0.1,
}
