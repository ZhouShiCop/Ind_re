extends TileMapLayer
class_name Vf_TileMap

## 选框可视化层 —— 管理选框与箭头的显隐状态
## 通过 mode_changed 信号驱动的状态机控制 UI

#region 节点引用
@onready var selection_panel: PanelContainer = $PanelContainer
@onready var selection_rect: NinePatchRect = $NinePatchRect
@onready var size_label: Label = $PanelContainer/VBoxContainer/Label
@onready var tile_count_label: Label = $PanelContainer/VBoxContainer/Label2
@onready var camera_2d: Camera2D = $"../Camera2D"
@onready var arrow: Control = $Arrow
@onready var _signal_bus: Node = get_node("/root/SignalBus")
#endregion

#region 常量与映射
## 信号字符串 → 枚举映射
const MODE_NAME_TO_ENUM: Dictionary = {
	"Build_Mode":   Main_Games.Operator_Mode.Build_Mode,
	"Destroy_Mode": Main_Games.Operator_Mode.Destroy_Mode,
	"Cancel_Mode":  Main_Games.Operator_Mode.Cancel_Mode,
	"Dig_Mode":     Main_Games.Operator_Mode.Dig_Mode,
}
#endregion

#region 内部状态
var _current_mode: Main_Games.Operator_Mode = Main_Games.Operator_Mode.Idle
var _selection_visible: bool = false
var _start_coord: Vector2i = Vector2i.ZERO
var _end_coord: Vector2i = Vector2i.ZERO
#endregion

#region 导出属性
@export var keep_selection_on_release: bool = false ## Cancel_Mode 松开后是否保留选框显示

@export var selection_visible: bool:
	set(v):
		if _selection_visible == v: return
		_selection_visible = v
		_apply_selection()
	get():
		return _selection_visible

@export var is_active: bool:
	set(v):
		_is_active = v
	get():
		return _is_active
var _is_active: bool = false

@export var is_mouse_pressed: bool:
	set(v):
		if _is_mouse_pressed == v: return
		_is_mouse_pressed = v
		_refresh_ui(&"press" if v else &"release")
	get():
		return _is_mouse_pressed
var _is_mouse_pressed: bool = false

@export var start_coord: Vector2i:
	set(v):
		if _start_coord == v: return
		_start_coord = v
		update_selection_ui()
	get():
		return _start_coord

@export var end_coord: Vector2i:
	set(v):
		if _end_coord == v: return
		_end_coord = v
		update_selection_ui()
	get():
		return _end_coord
#endregion

#region 生命周期
func _ready() -> void:
	if selection_panel:
		selection_panel.visible = false
		selection_rect.visible = false
	if arrow:
		arrow.visible = true  ## 默认启用 arrow 可见性
	_signal_bus.connect_safe("mode_changed", _on_mode_changed)


func _process(_delta: float) -> void:
	if arrow and arrow.visible:
		var mouse_tile := local_to_map(get_local_mouse_position())
		arrow.position = map_to_local(mouse_tile)
#endregion

#region 状态机控制
## 模式变更回调 —— 仅更新状态，委托 _refresh_ui 刷新 UI
func _on_mode_changed(mode_name: String, is_active: bool) -> void:
	_current_mode = MODE_NAME_TO_ENUM.get(mode_name, Main_Games.Operator_Mode.Idle) if is_active else Main_Games.Operator_Mode.Idle
	_refresh_ui(&"enter")

## 统一 UI 刷新 —— 唯一修改 selection_visible / arrow 的入口
## 以 (模式 × 事件) 状态机驱动
func _refresh_ui(event: StringName) -> void:
	match _current_mode:
		Main_Games.Operator_Mode.Idle:
			selection_visible = false
			_apply_arrow(true)

		Main_Games.Operator_Mode.Build_Mode:
			selection_visible = false
			_apply_arrow(event != &"press")

		Main_Games.Operator_Mode.Destroy_Mode:
			selection_visible = (event == &"press")
			_apply_arrow(event != &"press")

		Main_Games.Operator_Mode.Cancel_Mode:
			selection_visible = (event == &"press") or (event == &"release" and keep_selection_on_release)
			_apply_arrow(false)

## 应用选框可见性 —— 唯一操作 selection_panel / selection_rect 的入口
func _apply_selection() -> void:
	if _selection_visible:
		update_selection_ui()
		if selection_panel: selection_panel.visible = true
		if selection_rect: selection_rect.visible = true
	else:
		if selection_panel: selection_panel.visible = false
		if selection_rect: selection_rect.visible = false
		_start_coord = Vector2i.ZERO
		_end_coord = Vector2i.ZERO

## 应用 arrow 可见性
func _apply_arrow(visible: bool) -> void:
	if arrow: arrow.visible = visible
#endregion

#region 选框 UI
## 更新选框的位置和大小
func update_selection_ui():
	if not selection_panel:
		return

	# 1. 获取瓦片尺寸
	var tile_size := tile_set.tile_size

	# 2. 计算包围盒边界
	var min_x := mini(start_coord.x, end_coord.x)
	var min_y := mini(start_coord.y, end_coord.y)
	var max_x := maxi(start_coord.x, end_coord.x)
	var max_y := maxi(start_coord.y, end_coord.y)

	# 3. 计算格子数量
	var count_x := max_x - min_x + 1
	var count_y := max_y - min_y + 1

	# 4. 计算位置和尺寸
	var rect_pos := Vector2(min_x * tile_size.x, min_y * tile_size.y)
	var span_x := count_x * tile_size.x
	var span_y := count_y * tile_size.y
	var rect_size := Vector2(span_x, span_y)

	# --- 赋值 ---
	selection_panel.position = rect_pos
	selection_rect.position = rect_pos
	selection_panel.size = rect_size
	selection_rect.size = rect_size

	# 更新文本内容
	if size_label and (count_x >= 2 and count_y >= 2):
		size_label.text = "%d*%d" % [count_x, count_y]
		size_label.visible = true
	else:
		size_label.visible = false
		size_label.text = ""

	if tile_count_label:
		tile_count_label.text = "%d" % (count_x * count_y)

	# --- 更新字体大小 (随摄像机缩放) ---
	if camera_2d and size_label and tile_count_label:
		var cam_zoom := camera_2d.zoom.x

		if cam_zoom != 0:
			var size_mult := count_x if count_x > 20 else 20
			cam_zoom = cam_zoom if cam_zoom > 0.5 else 0.5
			var new_font_size := size_mult * 4 / (cam_zoom * 1.5)

			size_label.label_settings.font_size = new_font_size
			size_label.label_settings.outline_size = new_font_size * 0.05

## 清除选框状态
func clear_draw() -> void:
	start_coord = Vector2i(0, 0)
	end_coord = Vector2i(0, 0)
#endregion
