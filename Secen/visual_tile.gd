extends TileMapLayer
@export var Is_Action : bool:
	set(v):
		Is_Action = v
	get():
		clear_draw()
		return Is_Action
@export var Is_Press_Middle : bool:
	set(v):
		Is_Press_Middle = v
	get():
		clear_draw()
		return Is_Press_Middle
var Start_coord : Vector2i
var End_coord : Vector2i

func _ready() -> void:
	pass

func clear_draw() -> void:
	Start_coord = Vector2i(0,0)
	End_coord = Vector2i(0,0)
	
func _process(delta: float) -> void:
	
	pass
