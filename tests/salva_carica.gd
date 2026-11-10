extends SceneTree
## Un salvataggio (configurazione + registro delle decisioni) rigioca la stessa partita.

func _init() -> void:
	var cfg := {"seed": 77, "goal": 1000, "ai_delay": 0.0, "seats": [{"ai": true, "merchant": 0}, {"ai": true, "merchant": 4}, {"ai": true, "merchant": 5}]}
	var e := MoVEngine.new()
	e.headless = true
	e.setup(cfg.duplicate(true))
	root.add_child(e)
	await e.run()
	var fp1 := e.fingerprint()
	var saved := {"cfg": var_to_str(cfg), "acts": var_to_str(e.rec_acts)}
	var txt := JSON.stringify(saved)
	var back = JSON.parse_string(txt)
	var cfg2 = str_to_var(back["cfg"])
	var acts = str_to_var(back["acts"])
	var e2 := MoVEngine.new()
	e2.headless = true
	e2.setup(cfg2)
	e2.preload_acts = acts
	root.add_child(e2)
	await e2.run()
	var fp2 := e2.fingerprint()
	print("SALVA ", fp1, " == ", fp2, " -> ", "OK" if fp1 == fp2 else "DIVERSE")
	quit(0 if fp1 == fp2 else 1)
