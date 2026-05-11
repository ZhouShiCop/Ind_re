extends TextureButton
class_name mode_button
## 通用按钮控制器
## 处理按钮点击并触发对应场景切换

#region 导出变量
@export var game_scene: PackedScene  ## 游戏场景引用
#endregion

#region 常量
const GAME_SCENE_UID := "uid://c3tk0vwyi7y2a"
#endregion

#region 生命周期
func _ready() -> void:
	# 如果未设置场景，尝试预加载
	if game_scene == null:
		game_scene = load(GAME_SCENE_UID)
#endregion

#region 信号处理
## 按钮被按下时调用（由动画或信号触发）
func be_pressed() -> void:
	print("[%s] 按钮被按下" % name)

	match name:
		"Start":
			if game_scene:
				get_tree().change_scene_to_packed(game_scene)
			print("[%s] 未定义的按钮行为" % name)
#endregion
