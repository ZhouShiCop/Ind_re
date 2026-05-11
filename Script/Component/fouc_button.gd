extends Button
class_name fouc_button

## 工具栏聚焦按钮 —— 点击时通过 SignalBus 发射全局信号

@export var button_name: String = "" ## 按钮唯一标识（用于模式分发）

@export var is_pressed: bool:
	get:
		return is_pressed
	set(value):
		is_pressed = value
		_border.visible = value

@onready var _border: TextureRect = $Border
@onready var _signal_bus: Node = get_node("/root/SignalBus")


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE  ## 禁用键盘焦点，确保每次点击都触发回调
	pressed.connect(_on_pressed)


## 按钮确认按下 -> 通过 SignalBus 全局广播
func _on_pressed() -> void:
	_signal_bus.emit_toolbar_button_pressed(button_name, self)
