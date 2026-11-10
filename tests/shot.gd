extends SceneTree
## Screenshot (serve un display: xvfb-run).
## godot --path . -s tests/shot.gd -- secondi file.png [umano 0/-1] [menu|regole|tabelle|zoom] [giocatori]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var secs := float(a[0]) if a.size() > 0 else 6.0
	var out := a[1] if a.size() > 1 else "/tmp/shot.png"
	var human := int(a[2]) if a.size() > 2 else -1
	var extra := a[3] if a.size() > 3 else ""
	var np := int(a[4]) if a.size() > 4 else 4
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if extra == "regole" or extra == "tabelle":
		main.show_rules()
		if extra == "tabelle":
			main.current.page = "tabelle"
			main.current._fill()
	elif extra != "menu":
		var seats := []
		for i in np:
			seats.append({"ai": i != human, "merchant": i})
		main.start_game({"seats": seats, "goal": 2000, "ai_delay": 0.05, "seed": 11})
	await create_timer(secs).timeout
	if extra == "zoom" and main.current != null:
		var b = main.current.board
		b.focus_node(main.current.eng.players[0]["pos"])
		b.dist = 12.0
		b.pitch = -0.8
		await create_timer(1.5).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SALVATO ", out)
	quit()
