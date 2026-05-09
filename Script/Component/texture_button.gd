extends TextureButton
class_name Fouc_Button
@export var Name : String

@export var Is_Pressed : bool:
	get:
		return Is_Pressed
	set(value):
		Is_Pressed = value
		border.visible = value

@onready var border: TextureRect = $Border

signal Button_Pressed

func Button_Press():
	Button_Pressed.emit(Name,self)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var Root = get_tree().root.get_child(0)
	var methrd : String = "null"
	button_down.connect(Callable(self,"Button_Press"))
	print(Name+"绑定到："+Root.name)
	Button_Pressed.connect(Callable(Root,"button_press"))
	print(Name+"绑定到："+Root.name)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
