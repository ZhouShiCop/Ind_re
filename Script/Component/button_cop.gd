extends MarginContainer
class_name Button_Cop
@onready var button: fouc_button = $Button
@onready var _border: TextureRect = $Border
@onready var _signal_bus: SignalBus = get_node("/root/SignalBus")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_signal_bus.connect_safe(SignalBus.S_MODE_CHANGED, _on_mode_changed)
	_border.visible = false
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass

func _on_mode_changed(mode: Main_Games.Operator_Mode) -> void:
	var mode_name_map: Dictionary = {
		Main_Games.Operator_Mode.Build_Mode: "Build_Mode",
		Main_Games.Operator_Mode.Destroy_Mode: "Destroy_Mode",
		Main_Games.Operator_Mode.Cancel_Mode: "Cancel_Mode",
	}
	_border.visible = (mode_name_map.get(mode, "") == button.button_name)
	pass
