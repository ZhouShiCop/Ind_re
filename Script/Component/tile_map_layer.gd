extends Node2D
## 瓦片地图绘制控制器
## 支持建造模式切换、连续绘制和路径补偿

# ============================================================
# 配置常量
# ============================================================
const DEFAULT_SOURCE_ID: int = 1
const DEFAULT_ATLAS_COORDS: Vector2i = Vector2i(1, 0)
const TERRAIN_ID_DISABLED: int = -1

# ============================================================
# 导出变量（编辑器可调整）
# ============================================================
@export var build_mode: bool = false  ## 是否处于建造模式
@export var destroy_mode: bool = false

# ============================================================
# 成员变量
# ============================================================
var _is_building: bool = false         ## 是否正在绘制
var _last_tile_pos: Vector2i           ## 上一帧瓦片坐标
var _current_tile_pos: Vector2i        ## 当前瓦片坐标
var _foucs_button : Fouc_Button
@onready var _tile_map_layer: TileMapLayer = $tiles

# ============================================================
# 生命周期函数
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if not (build_mode or destroy_mode):
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)


func _process(_delta: float) -> void:
	if _is_building and (build_mode or destroy_mode):
		_draw_tiles()

# ============================================================
# 输入处理
# ============================================================
## 处理鼠标按键事件
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if event.pressed:
		_is_building = true
	elif event.is_released():
		_is_building = false
		# 重置位置，避免下次点击出现错误的补偿直线
		_last_tile_pos = Vector2i.ZERO
		_current_tile_pos = Vector2i.ZERO

# ============================================================
# 绘制逻辑
# ============================================================
## 执行瓦片绘制或删除
func _draw_tiles() -> void:
	var mouse_pos := get_global_mouse_position()
	_current_tile_pos = _tile_map_layer.local_to_map(mouse_pos)
	
	# 初始状态：直接处理当前位置
	if _last_tile_pos == Vector2i.ZERO:
		_process_tile(_current_tile_pos)
		_last_tile_pos = _current_tile_pos
		return
	
	# 使用 Bresenham 算法填充路径（补偿快速移动）
	var path := _get_line_points(_last_tile_pos, _current_tile_pos)
	for tile_pos in path:
		_process_tile(tile_pos)
	
	_last_tile_pos = _current_tile_pos


## 处理单个瓦片（根据模式选择绘制或删除）
func _process_tile(coord: Vector2i) -> void:
	if destroy_mode:
		_erase_tile(coord)
	else:
		_paint_tile(coord)


## 绘制单个瓦片
func _paint_tile(coord: Vector2i) -> void:
	var tile_data := _tile_map_layer.get_cell_tile_data(coord)
	
	# 检查是否需要绘制（空格子或非固体）
	if tile_data != null and tile_data.get_custom_data("Is_Solid"):
		return
	
	print("绘制瓦片: ", coord)
	
	_tile_map_layer.set_cell(
		coord,
		DEFAULT_SOURCE_ID,
		DEFAULT_ATLAS_COORDS,
		0
	)
	
	# 更新相邻格子的地形连接
	_update_terrain_neighbors(coord)


## 删除单个瓦片
func _erase_tile(coord: Vector2i) -> void:
	var tile_data := _tile_map_layer.get_cell_tile_data(coord)
	
	# 检查是否需要删除（非空格子）
	if tile_data == null:
		return
	
	print("删除瓦片: ", coord)
	
	# 清除瓦片
	_tile_map_layer.set_cell(coord, -1)
	
	# 更新原位置的地形连接
	_tile_map_layer.set_cells_terrain_connect([coord], 0, -1, true)
	
	# 更新相邻格子的地形连接
	_update_terrain_neighbors(coord)

# ============================================================
# 地形处理
# ============================================================
## 更新相邻格子的地形连接
func _update_terrain_neighbors(coord: Vector2i) -> void:
	var neighbors: Array[Vector2i] = [
		coord + Vector2i.RIGHT,
		coord + Vector2i.LEFT,
		coord + Vector2i.DOWN,
		coord + Vector2i.UP,
	]
	
	for neighbor in neighbors:
		var neighbor_data := _tile_map_layer.get_cell_tile_data(neighbor)
		if neighbor_data == null or not neighbor_data.get_custom_data("Is_Solid"):
			_tile_map_layer.set_cells_terrain_connect([neighbor], 0, -1, true)

# ============================================================
# 算法工具
# ============================================================
## Bresenham 直线算法 - 获取两点间所有瓦片坐标
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
# 公共接口
# ============================================================
## 按钮按下回调
func button_press(button_name: String,node:Fouc_Button) -> void:
	match button_name:
		"Build_Button":
			# 切换建造模式，关闭删除模式
			build_mode = not build_mode
			if build_mode:
				destroy_mode = false
			_print_current_mode()
		
		"Destroy":
			# 切换删除模式，关闭建造模式
			destroy_mode = not destroy_mode
			if destroy_mode:
				build_mode = false
			_print_current_mode()
		
		_:
			print("未知的按钮: ", button_name)
	if _foucs_button:
		_foucs_button.Is_Pressed = false	
	node.Is_Pressed = true
	_foucs_button = node


## 打印当前模式
func _print_current_mode() -> void:
	if build_mode:
		print("当前模式: [建造模式]")
	elif destroy_mode:
		print("当前模式: [删除模式]")
	else:
		print("当前模式: [关闭]")

# ============================================================
# 调试工具
# ============================================================
## 打印所有地形配置信息
func print_all_terrains() -> void:
	if _tile_map_layer == null:
		push_error("未找到 TileMapLayer 节点！")
		return
	
	var tile_set := _tile_map_layer.tile_set
	if tile_set == null:
		push_error("TileMapLayer 未绑定 TileSet 资源！")
		return
	
	var set_count := tile_set.get_source_count()
	for set_idx in range(set_count):
		var set_name := tile_set.get_source_id(set_idx)
		print("地形集: [%d] %s" % [set_idx, set_name])
		
		var terrain_count := tile_set.get_terrains_count(set_idx)
		for terrain_idx in range(terrain_count):
			var terrain_name := tile_set.get_terrain_name(set_idx, terrain_idx)
			print("  - 地形: [%d] %s" % [terrain_idx, terrain_name])

@onready var buttons: Array = [] # Store all button nodes

func _ready() -> void:
	# Initialize buttons array with all TextureButton nodes
	buttons = get_tree().get_nodes_in_group("buttons")

func set_button_pressed(target_button: TextureButton) -> void:
	for button in buttons:
		if button == target_button:
			button.Is_Pressed = true
		else:
			button.Is_Pressed = false
