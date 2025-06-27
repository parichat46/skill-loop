extends Control

@onready var email_input = $VBoxContainer/EmailInput
@onready var login_button = $VBoxContainer/LoginButton
@onready var error_label = $VBoxContainer/ErrorLabel

func _ready():
	login_button.pressed.connect(_on_login_pressed)

func _on_login_pressed():
	var email = email_input.text.strip_edges()
	
	if email == "":
		error_label.text = "Please fill in the name."
	else:
		error_label.text = "Successful login"
		get_tree().change_scene_to_file("res://category_ui.tscn")  # ไปหน้าเกม


		
