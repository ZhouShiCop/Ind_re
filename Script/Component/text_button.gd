extends TextureButton
@export var Gaming: PackedScene
const GAMING = preload("uid://c3tk0vwyi7y2a")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func BePress() -> void:
	print(name+" Be Pressed")
	if(name == "Start"):
		get_tree().change_scene_to_packed(GAMING)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
