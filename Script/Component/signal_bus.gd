extends Node
## 全局信号总线 —— 集中定义、管理与追踪所有跨组件信号
## 已注册为 Autoload 单例，全局通过 SignalBus 访问

# ============================================================
# 信号定义
# ============================================================

## 工具栏按钮被按下 (button_name: 按钮标识, button_node: 按钮节点)
signal toolbar_button_pressed(button_name: String, button_node: fouc_button)

## 操作模式变更 (mode_name: 模式名, is_active: 是否激活)
signal mode_changed(mode_name: String, is_active: bool)

## 瓦片绘制事件 (coord: 坐标, source_id: 图集ID, atlas_coords: 纹理坐标)
signal tile_painted(coord: Vector2i, source_id: int, atlas_coords: Vector2i)

## 瓦片删除事件 (coord: 坐标)
signal tile_erased(coord: Vector2i)

## 场景切换请求 (scene_path: 目标场景路径)
signal scene_change_requested(scene_path: String)

# ============================================================
# 连接追踪
# ============================================================

## 已注册连接记录: [信号名 -> { listener, method } ]
var _connections: Dictionary = {}

@export var debug_logging: bool = false ## 是否启用调试日志

# ============================================================
# 公共接口 —— 安全连接 / 断开
# ============================================================

## 注册信号监听（自动追踪）
func connect_safe(signal_name: StringName, callable: Callable, flags: int = 0) -> int:
	if not has_signal(signal_name):
		push_error("SignalBus: 未注册的信号 [%s]" % signal_name)
		return ERR_INVALID_PARAMETER

	var err := connect(signal_name, callable, flags)
	if err == OK:
		_track_connection(signal_name, callable)
		if debug_logging:
			print("[SignalBus] 已连接: %s -> %s" % [signal_name, _callable_path(callable)])
	return err


## 断开指定信号连接（自动清除追踪）
func disconnect_safe(signal_name: StringName, callable: Callable) -> void:
	if not has_signal(signal_name):
		push_error("SignalBus: 未注册的信号 [%s]" % signal_name)
		return

	disconnect(signal_name, callable)
	_untrack_connection(signal_name, callable)
	if debug_logging:
		print("[SignalBus] 已断开: %s -> %s" % [signal_name, _callable_path(callable)])


## 断开某对象的所有已注册连接
func disconnect_listener(listener: Object) -> void:
	var removed_count := 0
	for signal_name in _connections.keys():
		var to_remove: Array[Callable] = []
		for entry in _connections[signal_name]:
			var conn_callable: Callable = entry.callable
			if conn_callable.get_object() == listener:
				to_remove.append(conn_callable)

		for conn_callable in to_remove:
			disconnect_safe(signal_name, conn_callable)
			removed_count += 1

	if debug_logging and removed_count > 0:
		print("[SignalBus] 已清理 %d 个连接 (listener: %s)" % [removed_count, listener])

# ============================================================
# 发射封装（带日志）
# ============================================================

## 发射工具栏按钮按下信号
func emit_toolbar_button_pressed(button_name: String, button_node: fouc_button) -> void:
	if debug_logging:
		print("[SignalBus] emit toolbar_button_pressed(%s)" % button_name)
	toolbar_button_pressed.emit(button_name, button_node)


## 发射操作模式变更信号
func emit_mode_changed(mode_name: String, is_active: bool) -> void:
	if debug_logging:
		print("[SignalBus] emit mode_changed(%s, %s)" % [mode_name, is_active])
	mode_changed.emit(mode_name, is_active)


## 发射瓦片绘制信号
func emit_tile_painted(coord: Vector2i, source_id: int, atlas_coords: Vector2i) -> void:
	if debug_logging:
		print("[SignalBus] emit tile_painted(%s)" % coord)
	tile_painted.emit(coord, source_id, atlas_coords)


## 发射瓦片删除信号
func emit_tile_erased(coord: Vector2i) -> void:
	if debug_logging:
		print("[SignalBus] emit tile_erased(%s)" % coord)
	tile_erased.emit(coord)


## 发射场景切换请求信号
func emit_scene_change_requested(scene_path: String) -> void:
	if debug_logging:
		print("[SignalBus] emit scene_change_requested(%s)" % scene_path)
	scene_change_requested.emit(scene_path)


# ============================================================


## 打印当前所有已注册连接
func print_all_connections() -> void:
	print("=" .repeat(50))
	print("[SignalBus] 当前连接列表 (%d 个信号):" % _connections.size())
	for signal_name in _connections.keys():
		var entries: Array = _connections[signal_name]
		print("  [%s] (%d 个监听者):" % [signal_name, entries.size()])
		for entry in entries:
			print("    -> %s" % _callable_path(entry.callable))
	print("=" .repeat(50))


## 获取指定信号的监听者数量
func get_connection_count(signal_name: StringName) -> int:
	if _connections.has(signal_name):
		return _connections[signal_name].size()
	return 0

# ============================================================
# 内部工具
# ============================================================

func _track_connection(sig: StringName, callable: Callable) -> void:
	if not _connections.has(sig):
		_connections[sig] = []
	_connections[sig].append({ "callable": callable })


func _untrack_connection(sig: StringName, callable: Callable) -> void:
	if not _connections.has(sig):
		return
	var entries: Array = _connections[sig]
	for i in range(entries.size() - 1, -1, -1):
		if entries[i].callable == callable:
			entries.remove_at(i)
	if entries.is_empty():
		_connections.erase(sig)


static func _callable_path(c: Callable) -> String:
	var obj := c.get_object()
	var method := c.get_method()
	if obj == null or not is_instance_valid(obj):
		return "<invalid>::%s" % method
	return "%s::%s" % [obj.name if obj.name else obj.get_class(), method]


func _exit_tree() -> void:
	_connections.clear()
