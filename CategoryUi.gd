extends Control

@onready var category_buttons = $VBoxContainer/CategoryButtons
@onready var action_list = $VBoxContainer/ActionList  # ← ต้องเป็น ItemList

var actions_by_category = {
	"ทำงาน": ["เขียนรายงาน", "ประชุมทีม", "ตอบอีเมล"],
	"พักผ่อน": ["ฟังเพลง", "งีบหลับ", "เดินเล่น"],
	"พัฒนา": ["เรียนภาษา", "อ่านหนังสือ", "ฝึกเขียนโค้ด"] 
}

func _ready():
	print("ระบบเริ่มทำงาน")
	for button in category_buttons.get_children():
		button.pressed.connect(func(): on_category_button_pressed(button.text))
		print("เชื่อมต่อปุ่ม: ", button.text)


func on_category_button_pressed(category_name: String):
	print("หมวดที่เลือก:", category_name)
	action_list.clear()

	if actions_by_category.has(category_name):
		for action in actions_by_category[category_name]:
			print("เพิ่ม:", action)
			action_list.add_item(action)
	else:
		print("ไม่พบหมวดนี้ใน dictionary")
