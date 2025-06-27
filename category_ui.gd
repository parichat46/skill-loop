extends Control

# Initial scores
var knowledge = 0
var money = 0
var emotion = 0
var body = 0
var time = 12 # hours in a day
var energy = 10 # energy per day
var daily_actions = []
var action_impacts = {}
var mission_completed = [] # Store completed missions
var mission_claimed = []   # Store claimed mission rewards

# Reference UI
# Add in @onready section
@onready var scroll_container = $VBoxContainer/ScrollContainer
@onready var action_container = $VBoxContainer/ScrollContainer/ActionContainer
@onready var http_request = $Node2D/HttpRequestFirebase
@onready var category_buttons = $VBoxContainer/CategoryButtons
@onready var end_day_button = $VBoxContainer/EndDayButton
@onready var balance_score_label = $Node2D/BalanceScoreLabel
@onready var knowledge_percent_label = $Node2D/KnowledgePercent
@onready var money_percent_label = $Node2D/MoneyPercent
@onready var health_percent_label = $Node2D/HealthPercent
@onready var emotion_percent_label = $Node2D/EmotionPercent
@onready var character_animation = $Node2D/CharacterSprite
@onready var mission_popup = $DailyMissionPopup
@onready var mission_list = $DailyMissionPopup/VBoxContainer/MissionList
@onready var mission_close_button = $DailyMissionPopup/VBoxContainer/CloseMissionButton
@onready var mission_button = $VBoxContainer/DailyMissionButton
@onready var knowledge_bar = $Node2D/KnowledgeStatBar/KnowledgeBar
@onready var knowledge_value_label = $Node2D/KnowledgeStatBar/KnowledgeValueLabel
@onready var money_bar = $Node2D/MoneyStatBar/MoneyBar
@onready var money_value_label = $Node2D/MoneyStatBar/MoneyValueLabel
@onready var body_bar = $Node2D/BodyStatBar/BodyBar
@onready var body_value_label = $Node2D/BodyStatBar/BodyValueLabel
@onready var emotion_bar = $Node2D/EmotionStatBar/EmotionBar
@onready var emotion_value_label = $Node2D/EmotionStatBar/EmotionValueLabel
@onready var energy_bar = $Node2D/EnergyStatBar/EnergyBar
@onready var energy_value_label = $Node2D/EnergyStatBar/EnergyValueLabel
@onready var time_bar = $Node2D/TimeStatBar/TimeBar
@onready var time_value_label = $Node2D/TimeStatBar/TimeValueLabel

var daily_missions = [
	"Perform 1 health activity",
	"Use at least 6 hours",
	"Collect more than 10 emotion points"
]

var actions_by_category = {
	"Work": [
		{"name": "Write report", "knowledge": 2, "money": 1, "emotion": -1, "body": 0, "time": 3, "energy": 2},
		{"name": "Team meeting", "knowledge": 1, "money": 0, "emotion": -2, "body": 0, "time": 2, "energy": 1},
	],
	"Health": [
		{"name": "Take a nap", "knowledge": 0, "money": 0, "emotion": 1, "body": 2},
		{"name": "Go for a walk", "knowledge": 0, "money": 0, "emotion": 2, "body": 1},
		{"name": "Listen to music", "knowledge": 0, "money": 0, "emotion": 1, "body": 1}
	],
	"Hobby": [
		{"name": "Read a book", "knowledge": 2, "money": 0, "emotion": 1, "body": 0},
		{"name": "Learn a language", "knowledge": 3, "money": -1, "emotion": 0, "body": 0},
		{"name": "Practice coding", "knowledge": 3, "money": 0, "emotion": -1, "body": 0}
	],
	"Relationship": [
		{"name": "Call parents", "knowledge": 0, "money": 0, "emotion": 2, "body": 0},
		{"name": "Dinner with friends", "knowledge": 0, "money": -2, "emotion": 1, "body": 0},
		{"name": "Activity with friends", "knowledge": 3, "money": 0, "emotion": -1, "body": 0}
	]
}

var hidden_knowledge = {
	"Work": "💡: Hard work may increase knowledge and money, but watch out for emotions and health!",
	"Health": "💡: Taking care of health helps restore emotions and body in the long term",
	"Hobby": "💡: Hobby boost knowledge and emotions, but sometimes cost money",
	"Relationship": "💡: Investing in relationships boosts morale and social life, but requires balanced time and energy"
}

func _ready():
	load_actions_from_json()
	load_missions_from_json()
	
	if http_request == null:
		print("❌ HttpRequestFirebase not found")
	else:
		print("✅ http_request ready =", http_request)
	
	http_request.request_completed.connect(_on_http_request_firebase_request_completed)
	# Connect category buttons
	for button in category_buttons.get_children():
		button.pressed.connect(func(): on_category_button_pressed(button.text))
		
	if end_day_button:
		end_day_button.pressed.connect(on_end_day_pressed)

	update_status()
	setup_stat_bar($Node2D/KnowledgeStatBar, "Knowledge", knowledge_bar, knowledge_value_label)
	setup_stat_bar($Node2D/MoneyStatBar, "Money", money_bar, money_value_label)
	setup_stat_bar($Node2D/BodyStatBar, "Body", body_bar, body_value_label)
	setup_stat_bar($Node2D/EmotionStatBar, "Emotion", emotion_bar, emotion_value_label)
	setup_stat_bar($Node2D/TimeStatBar, "Time", time_bar, time_value_label)
	setup_stat_bar($Node2D/EnergyStatBar, "Energy", energy_bar, energy_value_label)

	# ✅ Show tutorial popup (if not permanently closed)
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	var show_tutorial = true
	if err == OK:
		show_tutorial = config.get_value("settings", "show_tutorial", true)

	mission_button.visible = false
	
	mission_button.pressed.connect(show_daily_missions)

	mission_close_button.pressed.connect(func():
		mission_popup.hide()
	)

	if show_tutorial:
		var popup_scene = preload("res://popup_panel.tscn")
		var popup = popup_scene.instantiate()
		add_child(popup)
		popup.popup_centered()

		var start_button = popup.get_node("VBoxContainer/HBoxContainer/Button")
		start_button.pressed.connect(func():
			mission_button.visible = true  # ✅ Show mission button
			mission_button.pressed.connect(show_daily_missions)
			popup.queue_free()  # ✅ Close popup
	)

func load_actions_from_json():
	var file = FileAccess.open("res://data/actions.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var new_data = JSON.parse_string(content)
		
		# Merge new data into existing actions_by_category
		for category in new_data.keys():
			if not actions_by_category.has(category):
				actions_by_category[category] = []
			actions_by_category[category] += new_data[category]  # Merge lists
		print("✅ Actions loaded and merged successfully")

func load_missions_from_json():
	var path = "res://data/daily_missions.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		var parsed = JSON.parse_string(content)
		if typeof(parsed) == TYPE_ARRAY:
			daily_missions = parsed
			print("✅ Missions loaded successfully")

func setup_stat_bar(container: HBoxContainer, label_text: String, bar: ProgressBar, value_label: Label):
	for child in container.get_children():
		container.remove_child(child)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(60, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(label)

	container.add_child(bar)
	container.add_child(value_label)
	knowledge_bar.show_percentage = false
	money_bar.show_percentage = false
	body_bar.show_percentage = false
	emotion_bar.show_percentage = false

func on_category_button_pressed(category_name):
	if not actions_by_category.has(category_name):
		print("❌ Category not found:", category_name)
		return
	for child in action_container.get_children():
		child.queue_free()

	var knowledge_label = RichTextLabel.new()
	knowledge_label.text = hidden_knowledge.get(category_name, "No hidden knowledge available")
	knowledge_label.custom_minimum_size = Vector2(300, 50)
	action_container.add_child(knowledge_label)

	await get_tree().create_timer(1.0).timeout

	for action in actions_by_category[category_name]:
		add_action_button(action)

func add_action_button(action_data):
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var btn = Button.new()
	btn.text = action_data.name
	btn.custom_minimum_size = Vector2(200, 0)

	var fv = FontVariation.new()
	fv.set_base_font(load("res://fonts/IBMPlexSansThai-Bold.ttf"))
	btn.add_theme_font_override("font",fv)

	btn.pressed.connect(func(): apply_action(action_data))
	hbox.add_child(btn)
	# Display impact for 4 cycles
	for stat in ["knowledge", "money", "emotion", "body"]:
		var value = action_data.get(stat, 0)
		if value == 0:
			continue

		var dot_box = VBoxContainer.new()
		dot_box.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Number of dots: 1 if abs < 3, 2 if abs >= 3
		var dot_count = 1
		if abs(value) >= 3:
			dot_count = 2

		for i in range(dot_count):
			var circle = Panel.new()
			circle.custom_minimum_size = Vector2(10, 10)
			circle.set("theme_override_styles/panel", get_circle_style())
			circle.modulate = get_color(value)
			dot_box.add_child(circle)

		# Add small label under dots: K / M / E / B
		var stat_label = Label.new()
		match stat:
			"knowledge":
				stat_label.text = "K"
			"money":
				stat_label.text = "M"
			"emotion":
				stat_label.text = "E"
			"body":
				stat_label.text = "B"
			_:
				stat_label.text = ""

		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_label.set("theme_override_colors/font_color", get_color(value))
		dot_box.add_child(stat_label)

		hbox.add_child(dot_box)

	# Add this HBox to ActionContainer
	action_container.add_child(hbox)

func apply_action(action_data):
	var action_time = action_data.get("time", 1)
	var action_energy = action_data.get("energy", 1)

	if time < action_time:
		show_warning("Not enough time for the next activity")
		return
	if energy < action_energy:
		show_warning("Not enough energy")
		return

	time -= action_time
	energy -= action_energy

	daily_actions.append(action_data["name"])
	var impact = {}
	for stat in ["knowledge", "money", "emotion", "body"]:
		impact[stat] = action_data.get(stat, 0)
	action_impacts[action_data["name"]] = impact

	knowledge += impact["knowledge"]
	money += impact["money"]
	emotion += impact["emotion"]
	body += impact["body"]

	# 🎬 Play animation based on the highest positive stat
	var top_stat = ""
	var top_value = -999
	for stat in ["knowledge", "money", "emotion", "body"]:
		if impact[stat] > top_value:
			top_value = impact[stat]
			top_stat = stat

	if top_value > 0:
		var anim_map = {
			"knowledge": "gain_knowledge",
			"money": "gain_money",
			"emotion": "gain_emotion",
			"body": "gain_body"
		}
		$Node2D/CharacterSprite.play(anim_map.get(top_stat, "idle"))

	if time <= 0 or energy <= 0:
		send_data_to_firebase()  # ✅ Send data before ending day automatically
		show_game_over()
	else:
		update_status()
		
	check_daily_mission_progress()

func update_status():
	knowledge_bar.value = knowledge
	knowledge_value_label.text = str(knowledge)
	knowledge_bar.add_theme_stylebox_override("fill", get_stat_fill_style(knowledge, Color(0.2, 0.6, 1)))  # Blue
	# Hide percentage
	knowledge_bar.max_value = 20
	knowledge_bar.value = knowledge
	knowledge_bar.show_percentage = false
	knowledge_value_label.text = str(knowledge)
	
	money_bar.value = money
	money_value_label.text = str(money)
	money_bar.add_theme_stylebox_override("fill", get_stat_fill_style(money, Color(1, 0.8, 0.2)))  # Gold
	
	money_bar.max_value = 20
	money_bar.value = money
	money_bar.show_percentage = false
	money_value_label.text = str(money)
	
	body_bar.value = body
	body_value_label.text = str(body)
	body_bar.add_theme_stylebox_override("fill", get_stat_fill_style(body, Color(0.3, 1, 0.4)))  # Green
	
	body_bar.max_value = 20
	body_bar.value = body
	body_bar.show_percentage = false
	body_value_label.text = str(body)
	
	emotion_bar.value = emotion
	emotion_value_label.text = str(emotion)
	emotion_bar.add_theme_stylebox_override("fill", get_stat_fill_style(emotion, Color(1, 0.5, 1)))  # Pink
	
	emotion_bar.max_value = 20
	emotion_bar.value = emotion
	emotion_bar.show_percentage = false
	emotion_value_label.text = str(emotion)
	
	energy_bar.value = energy
	energy_value_label.text = str(energy)
	energy_bar.add_theme_stylebox_override("fill", get_stat_fill_style(energy, Color(1, 0.5, 1)))  # Pink
	
	energy_bar.value = energy
	energy_value_label.text = str(energy)
	
	time_bar.value = time
	time_value_label.text = str(time)
	time_bar.add_theme_stylebox_override("fill", get_stat_fill_style(time, Color(1, 0.5, 1)))  # Pink
	
	time_bar.value = time
	time_value_label.text = str(time)

func show_game_over():
	var summary = get_summary_text()

	var popup = ConfirmationDialog.new()
	popup.dialog_text = summary
	popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# ✅ Set OK button text
	popup.get_ok_button().text = "OK"

	# ✅ Add popup to scene
	add_child(popup)
	popup.popup_centered()

	# ✅ When player presses "OK"
	popup.connect("confirmed", func():
		get_tree().paused = false
		popup.queue_free()
	)

	# ✅ Pause game (for player to read results)
	get_tree().paused = true

	# 👉 Connect signal to resume game when OK is pressed
	popup.connect("confirmed", func():
		get_tree().paused = false  # Resume game
		popup.queue_free()
	)

func get_summary_text() -> String:
	var summary = "Summary of today:\n"
	for action in daily_actions:
		summary += "- " + action + ": "
		var impact = action_impacts.get(action, {})
		var impacts_text = []
		for stat in ["knowledge", "money", "emotion", "body"]:
			var value = impact.get(stat, 0)
			if value != 0:
				impacts_text.append(str(value) + " " + stat)
		summary += ", ".join(impacts_text) + "\n"

	var result = calculate_balance_custom(knowledge, money, body, emotion)
	var percentages = result["percentages"]
	var balance_score = result["score"]
	var message = result["message"]

	summary += "\nPercent on each side of the circuit:\n"
	summary += "- knowledge: %.1f%%\n" % percentages[0]
	summary += "- money: %.1f%%\n" % percentages[1]
	summary += "- health: %.1f%%\n" % percentages[2]
	summary += "- emotion: %.1f%%\n" % percentages[3]
	summary += "\nBalance score: %d/100\n" % balance_score
	summary += message

	return summary

func show_warning(msg: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()

func show_daily_summary():
	print(">>> Displaying missions")
	check_daily_mission_progress() # ✅ Call again to update mission_completed

	print("Total missions:", mission_list.get_child_count())
	print(">>> daily_missions before start:", daily_missions)
	print("mission_list =", mission_list)

	if not mission_list:
		print("Error: mission_list is null!")
		return
	var summary = "Summary of today:\n"
	for action in daily_actions:
		summary += "- " + action + ": "
		var impact = action_impacts.get(action, {})
		var impacts_text = []
		for stat in ["knowledge", "money", "emotion", "body"]:
			var value = impact.get(stat, 0)
			if value != 0:
				impacts_text.append(str(value) + " " + stat)
		summary += ", ".join(impacts_text) + "\n"

	var result = calculate_balance_custom(knowledge, money, body, emotion)
	var percentages = result["percentages"]
	var balance_score = result["score"]
	var message = result["message"]

	summary += "\nPercent on each side of the circuit:\n"
	summary += "- knowledge: %.1f%%\n" % percentages[0]
	summary += "- money: %.1f%%\n" % percentages[1]
	summary += "- health: %.1f%%\n" % percentages[2]
	summary += "- emotion: %.1f%%\n" % percentages[3]
	summary += "\nBalance score: %d/100\n" % balance_score
	summary += message

	var popup = AcceptDialog.new()
	popup.dialog_text = summary
	add_child(popup)
	popup.popup_centered()

func check_daily_mission_progress():
	mission_completed.clear()
	for mission in daily_missions:
		var cond = mission.get("condition", "")
		var title = mission.get("title", "")

		if cond.begins_with("category="):
			var target_cat = cond.split("=")[1]
			for action_name in daily_actions:
				if get_category_from_action(action_name) == target_cat:
					mission_completed.append(title)
					break
		elif cond == "time_used>=6":
			if (12 - time) >= 6:
				mission_completed.append(title)
		elif cond == "emotion>10":
			if emotion > 10:
				mission_completed.append(title)

func get_category_from_action(action_name: String) -> String:
	for category_name in actions_by_category.keys():
		for action_data in actions_by_category[category_name]:
			if action_data.get("name", "") == action_name:
				return category_name
	return ""

func on_end_day_pressed():
	show_daily_summary()
	send_data_to_firebase()  # Send data to Firebase

	# Start new day: reset values
	knowledge = 0
	money = 0
	emotion = 0
	body = 0
	time = 12
	energy = 10
	
	daily_actions.clear()
	action_impacts.clear()
	update_status()
	$Node2D/CharacterAnimation.play("neutral")

func send_data_to_firebase():
	print("📡 Sending data to Firebase...")

	# ✅ Create a unique user ID (choose method based on your implementation)
	var user_uid = OS.get_unique_id()  # Or Firebase.Auth.get_current_user().uid

	# ✅ Include UID in URL
	var url = "https://skill-loop-546f0-default-rtdb.firebaseio.com/Database2/users/%s.json" % user_uid
	var http_request = http_request

	var category = "Not specified"
	if daily_actions.size() > 0:
		category = get_category_from_action(daily_actions[0])  # Or other logic

	# 👇 Convert every element in daily_actions to string before join
	var action_names = []
	for action in daily_actions:
		action_names.append(str(action))

	var data = {
		"display_name": "FF",
		"today_category": category,
		"today_action": ", ".join(action_names),  # ✅ Comma is important
		"timestamp": Time.get_date_string_from_system()
	}

	var json_data = JSON.stringify(data)

	http_request.request(
		url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_PUT,
		json_data
	)

func show_daily_missions():
	print("✅ Calling show_daily_missions")
	print("=== DEBUG: Completed missions =", mission_completed)
	print("=== DEBUG: Claimed rewards =", mission_claimed)

	mission_popup.popup_centered()

	for child in mission_list.get_children():
		mission_list.remove_child(child)
		child.queue_free()

	for mission in daily_missions:
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.text = mission["title"]
		hbox.add_child(label)

		var reward = mission.get("reward", {})
		for key in reward.keys():
			var reward_label = Label.new()
			reward_label.text = "🎁 " + key.capitalize() + " +" + str(reward[key])
			hbox.add_child(reward_label)

		if mission["title"] in mission_completed and mission["title"] not in mission_claimed:
			var claim_button = Button.new()
			claim_button.text = "accept"
			claim_button.pressed.connect(func():
				claim_mission_reward(mission)
			)
			hbox.add_child(claim_button)

		mission_list.add_child(hbox)

func claim_mission_reward(mission_data: Dictionary):
	var title = mission_data.get("title", "")
	mission_claimed.append(title)

	var reward = mission_data.get("reward", {})
	for stat in reward.keys():
		match stat:
			"knowledge":
				knowledge += reward[stat]
			"money":
				money += reward[stat]
			"emotion":
				emotion += reward[stat]
			"body":
				body += reward[stat]
			"energy":
				energy += reward[stat]
	# Update values
	update_status()
	show_daily_missions()

func get_circle_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.set_border_width_all(0)
	return style

func get_stat_fill_style(value: int, color_normal: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	
	if value < 0:
		style.bg_color = Color(1, 0, 0)  # Red
	else:
		style.bg_color = color_normal  # Normal color you set
	
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.set_border_width_all(0)

	return style

func get_color(value):
	if value > 0:
		return Color(0, 1, 0)  # Green
	elif value < 0:
		return Color(1, 0, 0)  # Red
	else:
		return Color(0.5, 0.5, 0.5)  # Gray

func calculate_balance_custom(k: int, m: int, h: int, e: int) -> Dictionary:
	var x = k + m + h + e
	if x == 0:
		return {"score": 0, "percentages": [0, 0, 0, 0], "message": "Not enough data"}

	var xe_k = float(k) / x * 100
	var xe_m = float(m) / x * 100
	var xe_h = float(h) / x * 100
	var xe_e = float(e) / x * 100

	var xz = abs(25 - xe_k) + abs(25 - xe_m) + abs(25 - xe_h) + abs(25 - xe_e)
	var yy = max(0, 100 - int(xz))

	var message := ""
	if yy >= 90:
		message = "Very balanced, great, you take care of every aspect of life."
	elif yy >= 75:
		message = "Quite balanced, very good, but there are still a few aspects that should be added"
	elif yy >= 60:
		message = "Moderate balance. Try to observe the circuits that you may overlook."
	else:
		message = "Unbalanced. Try to observe the circuits that you may overlook."

	return {
		"score": yy,
		"percentages": [xe_k, xe_m, xe_h, xe_e],
		"message": message
	}

func _on_daily_mission_button_pressed() -> void:
	show_daily_missions()

func _on_http_request_firebase_request_completed(result, response_code, headers, body):
	if response_code == 200:
		print("✅ Data sent to Firebase successfully")
	else:
		print("❌ Failed to send data:", response_code)
