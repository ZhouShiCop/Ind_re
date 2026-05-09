extends TileMapLayer
class_name Vf_TileMap

# 注意：确保场景树中 NinePatchRect 是 TileMapLayer 的直接子节点
@onready var panel_container: PanelContainer = $PanelContainer
@onready var label: Label = $PanelContainer/VBoxContainer/Label
@onready var label_2: Label = $PanelContainer/VBoxContainer/Label2
@onready var camera_2d: Camera2D = $"../Camera2D"

# --- 导出变量 ---

@export var Is_Active : bool:
	set(v):
		Is_Active = v
		# 如果需要激活时重置，可以在这里调用 clear_draw()
	get():
		return Is_Active

@export var Is_Press_Middle : bool:
	set(v):
		Is_Press_Middle = v
		# 控制 NinePatchRect 的显隐
		if panel_container:
			panel_container.visible = v
	get():
		# 读取时重置逻辑（根据你的需求保留）
		clear_draw()
		return Is_Press_Middle

@export var Start_coord : Vector2i:
	set(v):
		Start_coord = v
		update_selection_ui() # 坐标改变时立即更新 UI

@export var End_coord : Vector2i:
	set(v):
		End_coord = v
		update_selection_ui() # 坐标改变时立即更新 UI

# --- 生命周期 ---

func _ready() -> void:
	if panel_container:
		panel_container.visible = false

# --- 核心逻辑 ---

# 更新 NinePatchRect 的位置和大小
func update_selection_ui():
	if not panel_container:
		return

	# 1. 获取瓦片尺寸
	var t_size = tile_set.tile_size

	# 2. 计算包围盒边界
	var min_x = mini(Start_coord.x, End_coord.x)
	var min_y = mini(Start_coord.y, End_coord.y)
	var max_x = maxi(Start_coord.x, End_coord.x)
	var max_y = maxi(Start_coord.y, End_coord.y)

	# 3. 计算格子数量
	var count_x = max_x - min_x + 1
	var count_y = max_y - min_y + 1

	# 4. 计算位置和尺寸
	var rect_pos = Vector2(min_x * t_size.x, min_y * t_size.y)
	var span_x = count_x * t_size.x
	var span_y = count_y * t_size.y
	var rect_size = Vector2(span_x, span_y)

	# --- 赋值 ---
	panel_container.position = rect_pos
	panel_container.size = rect_size

	# 更新文本内容
	if label:
		label.text = "%d * %d" % [count_x, count_y]
	if label_2:
		label_2.text = "%d" % (count_x * count_y)

	# --- 更新字体大小 (随摄像机缩放) ---
	# 安全检查：确保相机存在且 zoom 不为 0
	if camera_2d and label and label_2:
		# 获取相机的缩放值 (取 X 轴即可，通常 X/Y 是一致的)
		var cam_zoom = camera_2d.zoom.x
		
		# 防止除以 0
		if cam_zoom != 0:
			# 基础字体大小设为 16 (你可以根据需要调整这个基数)
			# 公式：基础大小 / 缩放值
			# 例如：缩放 0.5 (缩小) -> 16 / 0.5 = 32 (字体变大)
			# 例如：缩放 2.0 (放大) -> 16 / 2.0 = 8 (字体变小)
			var new_font_size = 48.0 / cam_zoom
			
			# 应用到 Label
			label.label_settings.font_size=new_font_size
			#label_2.label_settings.font_size=new_font_size
		
# 清除选框状态
func clear_draw() -> void:
	Start_coord = Vector2i(0, 0)
	End_coord = Vector2i(0, 0)
	
	# 如果需要清除时也隐藏 UI，可以取消下面这行的注释
	# if nine_patch_rect: nine_patch_rect.visible = false

func _process(_delta: float) -> void:
	pass
