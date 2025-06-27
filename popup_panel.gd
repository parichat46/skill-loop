extends PopupPanel

@onready var dont_show_check = $VBoxContainer/HBoxContainer/CheckBox
@onready var close_button = $VBoxContainer/HBoxContainer/Button

func _ready():
	popup_centered()
	# เชื่อม signal ด้วยโค้ด (หรือจะทำใน Editor ก็ได้)
	close_button.pressed.connect(_on_close_pressed)

func _on_close_pressed():
	if dont_show_check.button_pressed:
		var config = ConfigFile.new()
		config.set_value("settings", "show_tutorial", false)
		config.save("user://settings.cfg")
	queue_free()  # ปิด popup (ลบทิ้ง)


func _on_close_button_pressed() -> void:
	pass # Replace with function body.
