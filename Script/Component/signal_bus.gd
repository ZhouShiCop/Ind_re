extends Node
## 全局信号总线 —— 集中定义、管理与追踪所有跨组件信号
## 已注册为 Autoload 单例，全局通过 SignalBus 访问
##
## 设计原则:
##   1. 信号名统一用 StringName 常量 —— 拼写安全、IDE 补全、零运行时开销
##   2. 按功能域分组 —— 新增信号只需在对应域追加常量 + signal 声明
##   3. connect_safe / disconnect_safe 自动追踪 —— 断开时无需手动维护
##   4. 统一发射接口 emit(SIGNAL, ...) —— 调试日志一行搞定，不再写 emit_xxx 包装

#region ═══════════════════════════════════════════════
## 信号名常量（按功能域分组）
## 新增信号时: 1) 在对应域加常量  2) 在下方 signal 区加声明  3) 完成
#region ═══════════════════════════════════════════════

## ── UI 域 ──
const S_TOOLBAR_BUTTON_PRESSED: StringName = &"toolbar_button_pressed"
const S_MODE_CHANGED:            StringName = &"mode_changed"

## ── 地图域 ──
const S_TILE_PAINTED:   StringName = &"tile_painted"
const S_TILE_ERASED:    StringName = &"tile_erased"

## ── 场景域 ──
const S_SCENE_CHANGE_REQUESTED: StringName = &"scene_change_requested"

#endregion

#region ═══════════════════════════════════════════════
## 信号声明（与常量一一对应）
#region ═══════════════════════════════════════════════

## ── UI 值域 ──
## 工具栏按钮被按下 (button_name: 按钮标识, button_node: 按钮节点)
signal toolbar_button_pressed(button_name: String, button_node: fouc_button)

## 操作模式变更 (mode: 目标模式枚举值)
signal mode_changed(mode: Main_Games.Operator_Mode)

## ── 地图域 ──
## 瓦片绘制事件 (coord: 坐标, source_id: 图集ID, atlas_coords: 纹理坐标)
signal tile_painted(coord: Vector2i, source_id: int, atlas_coords: Vector2i)

## 瓦片删除事件 (coord: 坐标)
signal tile_erased(coord: Vector2i)

## ── 场景域 ──
## 场景切换请求 (scene_path: 目标场景路径)
signal scene_change_requested(scene_path: String)

#endregion

#region ═══════════════════════════════════════════════
## 属性
#region ═══════════════════════════════════════════════

## 已注册连接记录: [信号名 -> Callable 列表]
var _connections: Dictionary = {}  ## Dictionary[StringName, Array[Callable]]

@export var debug_logging: bool = true ## 是否启用调试日志

#endregion

#region ═══════════════════════════════════════════════
## 连接 / 断开
#region ═══════════════════════════════════════════════

## 注册信号监听（自动追踪）
## 用法: SignalBus.connect_safe(SignalBus.S_MODE_CHANGED, _on_mode_changed)
func connect_safe(sig: StringName, callable: Callable, flags: int = 0) -> int:
	if not has_signal(sig):
		push_error("SignalBus: 未注册的信号 [%s]" % sig)
		return ERR_INVALID_PARAMETER

	var err := connect(sig, callable, flags)
	if err == OK:
		_track(sig, callable)
		if debug_logging:
			print("[SignalBus] +连接: %s -> %s" % [sig, _callable_path(callable)])
	return err


## 断开指定信号连接（自动清除追踪）
func disconnect_safe(sig: StringName, callable: Callable) -> void:
	if not has_signal(sig):
		push_error("SignalBus: 未注册的信号 [%s]" % sig)
		return

	disconnect(sig, callable)
	_untrack(sig, callable)
	if debug_logging:
		print("[SignalBus] -断开: %s -> %s" % [sig, _callable_path(callable)])


## 断开某对象的所有已注册连接
func disconnect_listener(listener: Object) -> void:
	var removed := 0
	for sig in _connections.keys():
		var to_remove: Array[Callable] = []
		for cb: Callable in _connections[sig]:
			if cb.get_object() == listener:
				to_remove.append(cb)
		for cb in to_remove:
			disconnect_safe(sig, cb)
			removed += 1
	if debug_logging and removed > 0:
		print("[SignalBus] 清理 %d 连接 (listener: %s)" % [removed, listener])

#endregion

#region ═══════════════════════════════════════════════
## 统一发射接口
## 用法: SignalBus.emit(SignalBus.S_MODE_CHANGED, mode)
## 调试日志自动打印，不再需要写 emit_xxx 包装方法
#region ═══════════════════════════════════════════════

func emit(sig: StringName, args: Array = []) -> void:
	if debug_logging:
		print("[SignalBus] emit %s(%s)" % [sig, str(args).replace("[", "").replace("]", "")])
	# emit_signal 需要逐个传递参数，不能整体传 Array
	match args.size():
		0: emit_signal(sig)
		1: emit_signal(sig, args[0])
		2: emit_signal(sig, args[0], args[1])
		3: emit_signal(sig, args[0], args[1], args[2])
		4: emit_signal(sig, args[0], args[1], args[2], args[3])
		5: emit_signal(sig, args[0], args[1], args[2], args[3], args[4])
		_:
			push_error("SignalBus.emit: 信号参数超过5个，请扩展 match 分支")

#endregion

#region ═══════════════════════════════════════════════
## 调试工具
#region ═══════════════════════════════════════════════

## 打印当前所有已注册连接
func print_all_connections() -> void:
	print("=" .repeat(60))
	print("[SignalBus] 连接列表 (%d 个信号):" % _connections.size())
	for sig in _connections.keys():
		var listeners: Array[Callable] = _connections[sig]
		print("  [%s] (%d 监听者):" % [sig, listeners.size()])
		for cb in listeners:
			print("    -> %s" % _callable_path(cb))
	print("=" .repeat(60))


## 获取指定信号的监听者数量
func get_connection_count(sig: StringName) -> int:
	if _connections.has(sig):
		return _connections[sig].size()
	return 0

#endregion

#region ═══════════════════════════════════════════════
## 内部工具
#region ═══════════════════════════════════════════════

func _track(sig: StringName, callable: Callable) -> void:
	if not _connections.has(sig):
		_connections[sig] = [] as Array[Callable]
	(_connections[sig] as Array[Callable]).append(callable)


func _untrack(sig: StringName, callable: Callable) -> void:
	if not _connections.has(sig):
		return
	var arr: Array[Callable] = _connections[sig]
	for i in range(arr.size() - 1, -1, -1):
		if arr[i] == callable:
			arr.remove_at(i)
	if arr.is_empty():
		_connections.erase(sig)


static func _callable_path(c: Callable) -> String:
	var obj := c.get_object()
	var method := c.get_method()
	if obj == null or not is_instance_valid(obj):
		return "<invalid>::%s" % method
	return "%s::%s" % [obj.name if obj.name else obj.get_class(), method]


func _exit_tree() -> void:
	_connections.clear()

#endregion
