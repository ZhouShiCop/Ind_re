extends Button
class_name fouc_button

## 工具栏聚焦按钮 —— 点击时通过 SignalBus 发射全局信号
## Border 状态由 mode_changed 信号驱动，不再依赖外部推送

#region 导出变量
@export var button_name: String = "" ## 按钮唯一标识（用于模式分发）
#endregion

#region 节点引用
@onready var _border: TextureRect = $Border
@onready var _signal_bus: Node = get_node("/root/SignalBus")
#endregion

#region 生命周期
func _ready() -> void:
	focus_mode = Control.FOCUS_NONE  ## 禁用键盘焦点，确保每次点击都触发回调
	pressed.connect(_on_pressed)
	_signal_bus.connect_safe("mode_changed", _on_mode_changed)
	_border.visible = false
#endregion

#region 信号处理
## 按钮确认按下 -> 通过 SignalBus 全局广播
func _on_pressed() -> void:
	_signal_bus.emit_toolbar_button_pressed(button_name, self)


## 监听模式变更 —— 自行判断是否应该高亮 border
func _on_mode_changed(mode_name: String, is_active: bool) -> void:
	_border.visible = (button_name == mode_name and is_active)
#endregion
