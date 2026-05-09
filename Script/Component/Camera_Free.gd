extends Camera2D
## 自由相机控制器
## 支持鼠标滚轮缩放和中键拖拽移动

# ============================================================
# 配置常量
# ============================================================
const DEFAULT_ZOOM := Vector2(1.0, 1.0)

# ============================================================
# 导出变量（编辑器可调整）
# ============================================================
@export var zoom_factor := 1.3      ## 缩放倍率（1.1 = 每次放大10%）
@export var min_zoom := 0.2         ## 最小缩放值
@export var max_zoom := 6.0         ## 最大缩放值
@export var lerp_weight := 16      ## 插值速度（越小越慢）

# ============================================================
# 成员变量
# ============================================================
var _target_zoom := DEFAULT_ZOOM         ## 目标缩放值
var _target_position := Vector2.ZERO     ## 目标位置
var _is_animating := false               ## 是否正在动画
var _is_paused := false                  ## 动画是否暂停
var _animation_delay := 0.0              ## 动画延迟时间
var _delay_timer := 0.0                  ## 延迟计时器

# 缩放动画专用（保持鼠标位置精确）
var _zoom_mouse_screen := Vector2.ZERO   ## 鼠标屏幕坐标（相对于视口中心）
var _zoom_start_pos := Vector2.ZERO      ## 缩放起始位置
var _zoom_start_zoom := 1.0              ## 缩放起始zoom

# ============================================================
# 生命周期函数
# ============================================================
func _ready() -> void:
	_target_zoom = zoom
	_target_position = position


func _unhandled_input(event: InputEvent) -> void:
	_handle_zoom_input(event)
	_handle_drag_input(event)


func _process(delta: float) -> void:
	_update_animation(delta)

# ============================================================
# 输入处理
# ============================================================
## 处理滚轮缩放输入（以鼠标位置为中心）
func _handle_zoom_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	var button := event as InputEventMouseButton
	
	# 乘法缩放：每次滚轮按比例放大/缩小
	var old_zoom := zoom.x
	var new_zoom: float
	
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		new_zoom = old_zoom * zoom_factor
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		new_zoom = old_zoom / zoom_factor
	else:
		return
	
	# 限制范围
	new_zoom = clampf(new_zoom, min_zoom, max_zoom)
	
	if absf(new_zoom - old_zoom) < 0.001:
		return
	
	# 记录缩放参数（用于动画中精确计算）
	var viewport_center := get_viewport_rect().size / 2.0
	_zoom_mouse_screen = get_viewport().get_mouse_position() - viewport_center
	_zoom_start_pos = position
	_zoom_start_zoom = old_zoom
	
	# 设置目标值
	_target_zoom = Vector2.ONE * new_zoom
	_target_position = position + _zoom_mouse_screen * (1.0 / old_zoom - 1.0 / new_zoom)
	_is_animating = true


## 处理中键拖拽输入
func _handle_drag_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		return
	
	var motion := event as InputEventMouseMotion
	# 根据当前缩放比例调整移动距离
	position -= motion.relative / zoom
	_target_position = position

# ============================================================
# 动画系统
# ============================================================
## 更新动画（每帧调用）
func _update_animation(delta: float) -> void:
	if not _is_animating:
		return
	
	# 处理暂停
	if _is_paused:
		return
	
	# 处理延迟
	if _delay_timer < _animation_delay:
		_delay_timer += delta
		return
	
	# 插值更新 zoom
	var lerp_factor := 1.0 - exp(-lerp_weight * delta)
	zoom = zoom.lerp(_target_zoom, lerp_factor)
	
	# 根据当前 zoom 精确计算 position（保持鼠标位置不变）
	# 公式：pos = start_pos + screen * (1/start_zoom - 1/current_zoom)
	position = _zoom_start_pos + _zoom_mouse_screen * (1.0 / _zoom_start_zoom - 1.0 / zoom.x)
	
	# 检查是否完成
	var zoom_diff := zoom.distance_to(_target_zoom)
	
	if zoom_diff < 0.001:
		zoom = _target_zoom
		position = _target_position
		_is_animating = false


## 开始动画
func start_animation() -> void:
	_is_animating = true


## 暂停动画
func pause_animation() -> void:
	_is_paused = true


## 恢复动画
func resume_animation() -> void:
	_is_paused = false


## 重置动画（停止并清除目标）
func reset_animation() -> void:
	_is_animating = false
	_is_paused = false
	_delay_timer = 0.0
	_target_zoom = zoom
	_target_position = position


## 设置动画延迟
func set_animation_delay(delay: float) -> void:
	_animation_delay = maxf(delay, 0.0)
	_delay_timer = 0.0


## 直接设置目标（不触发动画）
func set_target_immediately(new_zoom: float, new_position: Vector2) -> void:
	_target_zoom = Vector2.ONE * new_zoom
	_target_position = new_position
	zoom = _target_zoom
	position = _target_position
	_is_animating = false

# ============================================================
# 状态查询
# ============================================================
## 是否正在动画
func is_animating() -> bool:
	return _is_animating and not _is_paused


## 动画是否暂停
func is_paused() -> bool:
	return _is_paused
