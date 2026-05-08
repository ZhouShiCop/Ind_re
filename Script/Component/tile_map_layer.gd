extends Node2D

# ========== 配置常量（替换硬编码）==========
const DEFAULT_LAYER: int = 0
const DEFAULT_SOURCE_ID: int = 1          # 原硬编码 1
const DEFAULT_ATLAS_COORDS: Vector2i = Vector2i(1, 0)  # 原硬编码 Vector2i(1,0)
const TERRAIN_ID_DISABLED: int = -1       # 表示不使用地形连接（原传 -1）
var Is_buildMode : bool
var Is_building  : bool
var last_pos	 : Vector2i
var current_pos  : Vector2i

# ========== 成员变量 ==========
@onready var tile_map_layer: TileMapLayer = $TileMapLayer


# ========== 输入处理 ==========
func _unhandled_input(event: InputEvent) -> void:
	if Is_buildMode:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Is_building = true
		if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			Is_building = false	
			last_pos = current_pos
			# 获取鼠标位置并转换为瓦片坐标

func _process(delta: float) -> void:
	if(Is_building and Is_buildMode):
		Build()

func Build():
	print(last_pos)
	print(current_pos)
	var mouse_pos = get_global_mouse_position()
	if current_pos:
		last_pos = current_pos
	current_pos = tile_map_layer.local_to_map(mouse_pos)
	var manhattan_dist = abs(current_pos.x - last_pos.x) + abs(current_pos.y - last_pos.y)
	if manhattan_dist <= 1 and last_pos == Vector2i(0,0):
		# 相邻或相同格子：直接绘制（包括对角线，因为对角线曼哈顿距离=2，所以这里其实只处理正交相邻）
		# 如果你想包含对角线（即8邻域），改用 max(|dx|, |dy|) <= 1
		paint_terrain_at(current_pos, 0, TERRAIN_ID_DISABLED)
	else:
		# 距离 >1：启用路径补偿
		var path = get_line_tiles(last_pos, current_pos)
		for tile in path:
			# 可选：跳过起点（因为上一帧已绘制）
			if tile == last_pos:
				continue
			paint_terrain_at(tile, 0, TERRAIN_ID_DISABLED)
		
	last_pos = current_pos


	var tile_coord = tile_map_layer.local_to_map(mouse_pos)
	# 获取地形集索引（注意：此处逻辑可能仍有误，但按原行为保留）
	var terrain_set_index = tile_map_layer.tile_set.get_source_id(0)
	# 调用绘制函数（保持原调用方式）
	paint_terrain_at(tile_coord, terrain_set_index, TERRAIN_ID_DISABLED)
	
func get_line_tiles(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx - dy
	var x = from.x
	var y = from.y
	
	while true:
		points.append(Vector2i(x, y))
		if x == to.x and y == to.y:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	return points
	
func Button_Press(Name:String):
	print(Name)
	if(Name == "Build_Button"):
		Is_buildMode = !Is_buildMode
	pass

# ========== 绘制逻辑（去硬编码，但接口不变）==========
func paint_terrain_at(coord: Vector2i, terrain_set_index: int, terrain_id: int):
	var cells_to_paint = [coord]
	
	# 调试信息（保留）
	#print(tile_map_layer.tile_set.get_terrain_name(0, 0))
	#print(tile_map_layer.tile_set.get_source_id(0))
	#print(cells_to_paint)
	
	# 替换硬编码：使用命名常量
	if(tile_map_layer.get_cell_tile_data(coord) == null or!tile_map_layer.get_cell_tile_data(coord).get_custom_data("Is_Solid")):
		print("重新生成:")
		print(coord)
		tile_map_layer.set_cell(
			cells_to_paint[0],
			DEFAULT_SOURCE_ID,
			DEFAULT_ATLAS_COORDS,
			0  # alternative_tile，若固定可也设为常量
		)
	
	# 原本被注释的地形连接（保留注释）
	var crood_list : Array[Vector2i] = [cells_to_paint.get(0)+Vector2i(1,0),cells_to_paint.get(0)+Vector2i(-1,0),cells_to_paint.get(0)+Vector2i(0,1),cells_to_paint.get(0)+Vector2i(0,-1)]
	for crood:Vector2i in crood_list:
		var cells : TileData = tile_map_layer.get_cell_tile_data(crood)
		if cells == null or !cells.get_custom_data("Is_Solid"):
			var croodArray : Array[Vector2i] = [crood]
			tile_map_layer.set_cells_terrain_connect(croodArray, 0, -1, true)
			
	#print(tile_map_layer.get_used_cells())


# ========== 调试工具（不变）==========
func print_all_terrains():
	if tile_map_layer == null:
		push_error("未找到 TileMapLayer 节点！请检查场景树路径")
		return
	
	var tile_set = tile_map_layer.tile_set
	if tile_set == null:
		push_error("TileMapLayer 未绑定 TileSet 资源！")
		return
	
	#print("------------------------------------------------")
	#print("开始检查 TileSet 地形配置...")
	
	var set_count = tile_set.get_source_count()
	for set_idx in range(set_count):
		var set_name = tile_set.get_source_id(set_idx)
		print("📁 地形集索引: ", set_idx, " 名称: ", set_name)
		
		var terrain_count = tile_set.get_terrains_count(set_idx)
		for terrain_idx in range(terrain_count):
			var terrain_name = tile_set.get_terrain_name(set_idx, terrain_idx)
			print("   - 🟩 地形ID: ", terrain_idx, " 名称: ", terrain_name)
			
	#print("检查完毕。如果上方是空的，说明 TileSet 里没配置地形。")
	#print("------------------------------------------------")
