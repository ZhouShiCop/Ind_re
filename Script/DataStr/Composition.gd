extends Node
class_name Composition
## 材质组成数据结构
## 用于定义瓦片/物体的材质属性

# ============================================================
# 属性
# ============================================================
var composition: String = ""          ## 材质组成类型
var thermal_conductivity: float = 0.0 ## 热导率 (W/m·K)

# ============================================================
# 构造函数
# ============================================================
func _init(
	p_composition: String = "",
	p_thermal_conductivity: float = 0.0
) -> void:
	composition = p_composition
	thermal_conductivity = p_thermal_conductivity

# ============================================================
# 公共方法
# ============================================================
## 获取材质信息字符串
func get_info() -> String:
	return "Composition: %s, Thermal Conductivity: %.2f W/m·K" % [
		composition,
		thermal_conductivity
	]
