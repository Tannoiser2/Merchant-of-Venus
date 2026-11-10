extends SceneTree
## Prova dell'interfaccia: una partita con un giocatore "umano" le cui scelte le prende l'IA passando
## dalla vista (come farebbe un clic). Scatta foto in alcuni momenti. Serve xvfb-run.
## godot --path . -s tests/ui_auto.gd -- [turni] [cartella foto]

var ai := MoVAI.new(1)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var turns := int(a[0]) if a.size() > 0 else 6
	var dir := a[1] if a.size() > 1 else "/tmp"
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game({"seats": [{"ai": false, "merchant": 3}, {"ai": true, "merchant": 1}, {"ai": true, "merchant": 5}], "goal": 2000, "ai_delay": 0.02, "seed": 5})
	var view = main.current
	var shots := {"move": 0, "trade": 0, "pre": 0, "pen": 0}
	var t0 := Time.get_ticks_msec()
	while view.eng.turn <= turns and not view.eng.over:
		await process_frame
		if Time.get_ticks_msec() - t0 > 240000:
			print("UITEST tempo scaduto")
			break
		var req: Dictionary = view.req
		if req.is_empty():
			continue
		var k: String = req["k"]
		if shots.has(k) and shots[k] < 1:
			await create_timer(0.8).timeout
			var img := root.get_viewport().get_texture().get_image()
			img.save_png("%s/ui_%s.png" % [dir, k])
			print("UITEST foto ", k)
			shots[k] += 1
		var r = ai.decide(view.eng, int(req["seat"]), req)
		view._finish_decision(r)
	print("UITEST fine turno ", view.eng.turn, " ", view.eng.fingerprint())
	quit()
