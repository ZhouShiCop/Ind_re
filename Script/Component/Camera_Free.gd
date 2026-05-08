extends Camera2D


# 在编辑器中可调整的导出变量
@export var zoom_speed := 0.1       # 每次滚动的缩放增量
@export var min_zoom := 0.2         # 最小缩放值
@export var max_zoom := 6.0         # 最大缩放值
@export var zoom_duration := 0.2    # 平滑过渡的耗时（秒）

var target_zoom := Vector2(1, 1)    # 目标缩放值

func _ready():
	# 初始化目标缩放值为相机当前值
	target_zoom = zoom

func _unhandled_input(event):
	# 监听鼠标滚轮事件
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# 滚轮向上，放大
			target_zoom += Vector2(zoom_speed, zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 滚轮向下，缩小
			target_zoom -= Vector2(zoom_speed, zoom_speed)
		
		# 使用 clamp 函数限制目标缩放值的范围
		target_zoom = target_zoom.clamp(Vector2.ONE * min_zoom, Vector2.ONE * max_zoom)
		
		# 创建并执行平滑缩放的补间动画
		_create_zoom_tween()
		
	if event is InputEventMouseMotion:
		# 2. 询问系统：当前中键是否处于“按下”状态？
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			# 获取相对位移
			var relative_move = event.relative
			
			# 你的逻辑：根据缩放比例移动位置
			# 注意：这里假设 position 是当前节点的属性
			position.x -= relative_move.x * 1/zoom.x
			position.y -= relative_move.y * 1/zoom.y
# 创建缩放补间动画的函数
func _create_zoom_tween():
	# 如果已有补间动画在运行，先将其杀死，避免冲突
	if is_instance_valid(get_node_or_null("ZoomTween")):
		get_node("ZoomTween").kill()
	
	# 创建一个新的补间动画
	var tween = create_tween()
	
	# 设置补间属性：目标节点、属性名、最终值、耗时
	tween.tween_property(self, "zoom", target_zoom, zoom_duration)
