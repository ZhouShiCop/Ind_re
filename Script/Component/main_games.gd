extends Node2D
class_name Main_Games
## 瓦片地图绘制控制器
## 支持建造/删除模式切换、连续绘制和路径补偿（Bresenham）

# ============================================================
# 枚举定义
# ============================================================
enum Operator_Mode {
	Idle,
	Build_Mode,
	Destroy_Mode,
	Cancel_Mode,
	Dig_Mode,
}

# ============================================================
# 常量
# ============================================================
const DEFAULT_SOURCE_ID: int = 1
const DEFAULT_ATLAS_COORDS: Vector2i = Vector2i(1, 0)

const _DIRECTIONS_4: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]

# ============================================================
# 导出变量（编辑器可调整）
# ============================================================
@export var build_mode: bool = false   ## 是否处于建造模式
@export var destroy_mode: bool = false ## 是否处于删除模式
@export var debug_state: Operator_Mode = Operator_Mode.Idle

# ============================================================
# 节点引用
# ============================================================
@onready var _tile_map_layer: TileMapLayer = $tiles
@onready var _vf_layer: Vf_TileMap = $vf
@onready var _signal_bus: Node = get_node("/root/SignalBus")

# ============================================================
# 内部状态
# ============================================================
var _is_building: bool = false       ## 是否正在绘制（鼠标按住）
var _last_tile_pos: Vector2i         ## 上一帧瓦片坐标
var _current_tile_pos: Vector2i      ## 当前瓦片坐标
var _focus_button: fouc_button      ## 当前聚焦的按钮
var _buttons: Array[Node] = []       ## 工具栏按钮组

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_buttons = get_tree().get_nodes_in_group("buttons")
	# 注册全局信号监听
	_signal_bus.connect_safe(
		"toolbar_button_pressed",
		_on_toolbar_button_pressed
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_any_mode_active():
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)


func _process(_delta: float) -> void:
	if _is_building and _is_any_mode_active():
		_draw_tiles()

# ============================================================
# 模式判断
# ============================================================

## 是否有任一操作模式处于激活状态
func _is_any_mode_active() -> bool:
	return build_mode or destroy_mode


## 获取当前激活的操作模式
func _get_current_mode() -> Operator_Mode:
	if build_mode:
		return Operator_Mode.Build_Mode
	if destroy_mode:
		return Operator_Mode.Destroy_Mode
	return Operator_Mode.Idle

# ============================================================
# 鼠标输入处理
# ============================================================

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_on_draw_start()
	elif event.is_released():
		_on_draw_end()


## 开始绘制
func _on_draw_start() -> void:
	_is_building = true
	_vf_layer.Is_Press_Middle = true
	_current_tile_pos = _tile_map_layer.local_to_map(get_global_mouse_position())
	_vf_layer.Start_coord = _current_tile_pos
	_vf_layer.End_coord = _current_tile_pos


## 结束绘制
func _on_draw_end() -> void:
	_is_building = false
	_vf_layer.Is_Press_Middle = false
	_last_tile_pos = Vector2i.ZERO
	_current_tile_pos = Vector2i.ZERO

# ============================================================
# 瓦片绘制核心
# ============================================================

## 每帧调用：根据鼠标移动连续绘制/删除瓦片
func _draw_tiles() -> void:
	var mouse_pos := get_global_mouse_position()
	_current_tile_pos = _tile_map_layer.local_to_map(mouse_pos)
	_vf_layer.End_coord = _current_tile_pos

	if _last_tile_pos == Vector2i.ZERO:
		_process_tile(_current_tile_pos)
		_last_tile_pos = _current_tile_pos
		return

	var path := _get_line_points(_last_tile_pos, _current_tile_pos)
	for tile_pos in path:
		_process_tile(tile_pos)

	_last_tile_pos = _current_tile_pos


## 处理单个瓦片：根据当前模式分发到绘制或删除
func _process_tile(coord: Vector2i) -> void:
	if destroy_mode:
		_erase_tile(coord)
	else:
		_paint_tile(coord)


## 在指定坐标绘制瓦片
func _paint_tile(coord: Vector2i) -> void:
	var tile_data := _tile_map_layer.get_cell_tile_data(coord)
	if tile_data != null and tile_data.get_custom_data("Is_Solid"):
		return

	print("绘制瓦片: ", coord)
	_tile_map_layer.set_cell(coord, DEFAULT_SOURCE_ID, DEFAULT_ATLAS_COORDS, 0)
	_signal_bus.emit_tile_painted(coord, DEFAULT_SOURCE_ID, DEFAULT_ATLAS_COORDS)
	_update_terrain_neighbors(coord)


## 删除指定坐标的瓦片
func _erase_tile(coord: Vector2i) -> void:
	var tile_data := _tile_map_layer.get_cell_tile_data(coord)
	if tile_data == null:
		return

	print("删除瓦片: ", coord)
	_tile_map_layer.set_cell(coord, -1)
	_signal_bus.emit_tile_erased(coord)
	_tile_map_layer.set_cells_terrain_connect([coord], 0, -1, true)
	_update_terrain_neighbors(coord)

# ============================================================
# 地形连接更新
# ============================================================

## 更新目标坐标四邻域的地形连接
func _update_terrain_neighbors(center_coord: Vector2i) -> void:
	for direction in _DIRECTIONS_4:
		var neighbor := center_coord + direction
		var neighbor_data := _tile_map_layer.get_cell_tile_data(neighbor)
		if neighbor_data == null or not neighbor_data.get_custom_data("Is_Solid"):
			_tile_map_layer.set_cells_terrain_connect([neighbor], 0, -1, true)

# ============================================================
# 算法工具
# ============================================================

## Bresenham 直线算法 —— 返回两点间经过的所有瓦片坐标
func _get_line_points(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err := dx - dy
	var x := from.x
	var y := from.y

	while true:
		points.append(Vector2i(x, y))
		if x == to.x and y == to.y:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

	return points

# ============================================================
# 公共接口 —— 信号回调
# ============================================================

## [SignalBus.toolbar_button_pressed] 监听回调
func _on_toolbar_button_pressed(button_name: String, node: fouc_button) -> void:
	button_press(button_name, node)


## 工具栏按钮按下时的入口（支持直接调用与信号总线两种方式）
func button_press(button_name: String, node: fouc_button) -> void:
	_switch_mode(button_name)
	_update_focus_button(node)


## 切换操作模式
func _switch_mode(button_name: String) -> void:
	match button_name:
		"Build_Mode":
			build_mode = not build_mode
			if build_mode:
				destroy_mode = false
			_signal_bus.emit_mode_changed("Build_Mode", build_mode)
		"Destroy_Mode":
			destroy_mode = not destroy_mode
			if destroy_mode:
				build_mode = false
			_signal_bus.emit_mode_changed("Destroy_Mode", destroy_mode)
		_:
			push_warning("未知的按钮名称: %s" % button_name)
			return

	debug_state = _get_current_mode()
	_print_current_mode()


## 更新聚焦按钮的视觉状态
func _update_focus_button(new_focus: fouc_button) -> void:
	if _focus_button:
		_focus_button.is_pressed = false
	new_focus.is_pressed = true
	_focus_button = new_focus


## 打印当前操作模式到控制台
func _print_current_mode() -> void:
	var mode_name := ""
	match _get_current_mode():
		Operator_Mode.Build_Mode:
			mode_name = "建造模式"
		Operator_Mode.Destroy_Mode:
			mode_name = "删除模式"
		Operator_Mode.Idle:
			mode_name = "关闭"
	print("当前模式: [%s]" % mode_name)


## 设置指定按钮为按下状态，其余按钮取消按下
func set_button_pressed(target_button: TextureButton) -> void:
	for button in _buttons:
		button.is_pressed = (button == target_button)

# ============================================================
# 调试工具
# ============================================================

## 打印 TileSet 中所有地形集与地形信息
func print_all_terrains() -> void:
	if _tile_map_layer == null:
		push_error("未找到 TileMapLayer 节点！")
		return

	var tile_set := _tile_map_layer.tile_set
	if tile_set == null:
		push_error("TileMapLayer 未绑定 TileSet 资源！")
		return

	var source_count := tile_set.get_source_count()
	for idx in range(source_count):
		var source_id := tile_set.get_source_id(idx)
		print("地形集: [%d] %s" % [idx, source_id])

		var terrain_count := tile_set.get_terrains_count(source_id)
		for t_idx in range(terrain_count):
			var terrain_name := tile_set.get_terrain_name(source_id, t_idx)
			print("  - 地形: [%d] %s" % [t_idx, terrain_name])
