extends SceneTree
## Partite automatiche fra IA: godot --headless -s tests/autoplay.gd -- [partite] [giocatori] [seme]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 3
	var np := int(args[1]) if args.size() > 1 else 3
	var seed0 := int(args[2]) if args.size() > 2 else 1
	var wins := {}
	var turns := []
	for g in games:
		var e := MoVEngine.new()
		e.headless = true
		var seats := []
		for i in np:
			seats.append({"name": "IA%d" % i, "ai": true, "merchant": i})
		e.setup({"seed": seed0 + g, "seats": seats, "goal": 2000, "ai_delay": 0.0})
		root.add_child(e)
		var t0 := Time.get_ticks_msec()
		var guard := [0]
		e.log_added.connect(func(_t): guard[0] += 1)
		await e.run()
		var w = e.result.get("winner", -1)
		wins[w] = wins.get(w, 0) + 1
		turns.append(e.turn)
		var line := "partita %d: vince %s al turno %d (%.1fs)" % [g, str(w), e.turn, (Time.get_ticks_msec() - t0) / 1000.0]
		for s in np:
			var p: Dictionary = e.players[s]
			line += " | %s $%d nw %d %s porti %d fabb %d" % [p["name"], p["money"], e.net_worth(s), p["ship"], p["ports"].size(), p["facts"].size()]
		print(line)
		if OS.get_environment("MOV_LOG") != "":
			for l in e.log_lines:
				print("   ", l)
		e.queue_free()
	print("vittorie: ", wins, " turni: ", turns)
	quit()
