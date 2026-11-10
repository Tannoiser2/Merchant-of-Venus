extends Control
## Menu: nuova partita (da 2 a 6 mercanti, umani o computer), partita online con gli amici,
## partite salvate, regole.

const D = preload("res://scripts/data/mov_data.gd")

var main
var np := 3
var seats: Array = []
var goal_i := 1
var speed_i := 1
var box: VBoxContainer
var on_panel: Control
var on_name: LineEdit
var on_code: LineEdit
var on_lbl: Label
var on_start: Button
var on_join := false
const SPEEDS := [["Lenta", 1.0], ["Normale", 0.5], ["Veloce", 0.15]]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: Dictionary = main.menu_state
	if st.has("seats"):
		seats = st["seats"]
		np = seats.size()
		goal_i = st.get("goal_i", 1)
		speed_i = st.get("speed_i", 1)
	else:
		seats = []
		for i in 6:
			seats.append({"merchant": i, "name": "", "ai": i > 0})
		seats.resize(np)
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(980, 0)
	cc.add_child(box)
	_refresh()


func _store() -> void:
	main.menu_state = {"seats": seats, "goal_i": goal_i, "speed_i": speed_i}


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var t := UI.title("MERCHANT OF VENUS", 76)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var st := UI.head("COMMERCIO INTERSTELLARE NEL CLUSTER", 20, UI.CYAN)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(st)
	var sub := UI.label("Avalon Hill, 1988 - di Richard Hamblen. Scopri le culture perdute del Primo Impero, commercia merci, trasporta passeggeri, costruisci spazioporti e fabbriche: vince il primo che raggiunge il patrimonio stabilito.", 18, UI.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var pc := PanelContainer.new()
	box.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	vb.add_child(UI.head("NUOVA PARTITA", 22))
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	r1.add_child(UI.label("Mercanti:", 19))
	for n in range(2, 7):
		var k := n
		var b := UI.button(str(n), func(): _set_np(k), 18)
		b.custom_minimum_size = Vector2(52, 44)
		if n == np:
			b.add_theme_stylebox_override("normal", UI.box(UI.CYAN_D, UI.CYAN, 2, 6))
		r1.add_child(b)
	vb.add_child(r1)
	for i in np:
		vb.add_child(_seat_row(i))
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 10)
	r2.add_child(UI.label("Lunghezza:", 19))
	var og := OptionButton.new()
	for g in D.GOALS:
		og.add_item("%s ($%d)" % [g["nome"], g["v"]])
	og.selected = goal_i
	og.item_selected.connect(func(i): goal_i = i)
	r2.add_child(og)
	r2.add_child(UI.label("   Velocità del computer:", 19))
	var osp := OptionButton.new()
	for sp in SPEEDS:
		osp.add_item(sp[0])
	osp.selected = speed_i
	osp.item_selected.connect(func(i): speed_i = i)
	r2.add_child(osp)
	vb.add_child(r2)
	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 12)
	var bs := UI.red_button("INIZIA LA PARTITA", _on_start, 22)
	bs.custom_minimum_size = Vector2(360, 60)
	r3.add_child(bs)
	vb.add_child(r3)
	var pc2 := PanelContainer.new()
	box.add_child(pc2)
	var vb2 := VBoxContainer.new()
	vb2.add_theme_constant_override("separation", 10)
	pc2.add_child(vb2)
	vb2.add_child(UI.head("ONLINE E SALVATAGGI", 22))
	var r4 := HFlowContainer.new()
	r4.add_theme_constant_override("h_separation", 12)
	r4.add_theme_constant_override("v_separation", 10)
	for it in [["Crea una stanza online", func(): _online_panel_open(false)], ["Entra in una stanza", func(): _online_panel_open(true)], ["Carica una partita", _load_panel], ["Regole", _rules]]:
		var b := UI.button(it[0], it[1], 18)
		b.custom_minimum_size = Vector2(0, 52)
		r4.add_child(b)
	vb2.add_child(r4)
	vb2.add_child(UI.label("Online: chi crea la stanza riceve un codice di 4 lettere da mandare agli amici; i posti segnati \"Umano\" (tranne il primo, che è il tuo) li occupano loro, gli altri il computer.", 16, UI.MUTED))
	for c in vb2.get_children():
		if c is Label:
			c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _rules() -> void:
	_store()
	main.show_rules()


func _seat_row(i: int) -> Control:
	var s: Dictionary = seats[i]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var sw := ColorRect.new()
	sw.color = D.MERCHANTS[s["merchant"]]["col"]
	sw.custom_minimum_size = Vector2(22, 40)
	hb.add_child(sw)
	var om := OptionButton.new()
	for m in D.MERCHANTS:
		om.add_item("%s (%s)" % [m["nome"], D.CULTURES[m["c"]]["nome"]])
	om.selected = int(s["merchant"])
	om.custom_minimum_size = Vector2(250, 0)
	om.item_selected.connect(func(k):
		for j in seats.size():
			if j != i and int(seats[j]["merchant"]) == k:
				seats[j]["merchant"] = s["merchant"]
		s["merchant"] = k
		_refresh())
	hb.add_child(om)
	var le := LineEdit.new()
	le.placeholder_text = "Nome (facoltativo)"
	le.text = str(s.get("name", ""))
	le.max_length = 20
	le.custom_minimum_size = Vector2(260, 0)
	le.text_changed.connect(func(tx): s["name"] = tx)
	hb.add_child(le)
	var oa := OptionButton.new()
	oa.add_item("Umano")
	oa.add_item("Computer")
	oa.selected = 1 if s["ai"] else 0
	oa.item_selected.connect(func(k): s["ai"] = k == 1)
	hb.add_child(oa)
	return hb


func _set_np(n: int) -> void:
	var used := []
	for s in seats:
		used.append(int(s["merchant"]))
	while seats.size() < n:
		var m := 0
		while m in used:
			m += 1
		used.append(m)
		seats.append({"merchant": m, "name": "", "ai": true})
	seats.resize(n)
	np = n
	_refresh()


func _config() -> Dictionary:
	var ss := []
	for s in seats:
		var nm := str(s.get("name", "")).strip_edges()
		if nm == "":
			nm = D.MERCHANTS[int(s["merchant"])]["nome"]
		ss.append({"name": nm, "ai": bool(s["ai"]), "merchant": int(s["merchant"]), "level": 1})
	return {"seats": ss, "goal": int(D.GOALS[goal_i]["v"]), "ai_delay": float(SPEEDS[speed_i][1])}


func _on_start() -> void:
	_store()
	var cfg := _config()
	cfg["seed"] = 1 + randi() % 2000000000
	main.start_game(cfg)


# ---------------------------------------------------------------- pannelli

func _overlay() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(760, 0)
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	pc.add_child(vb)
	bg.set_meta("vb", vb)
	return bg


func _line(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 52)
	le.add_theme_font_size_override("font_size", 24)
	return le


func _load_panel() -> void:
	_store()
	var p := _overlay()
	var vb: VBoxContainer = p.get_meta("vb")
	vb.add_child(UI.title("CARICA UNA PARTITA", 36))
	vb.add_child(UI.label("Scrivi il codice di sei lettere che hai ricevuto quando hai salvato.", 18))
	var le := _line("Codice", 6)
	le.text_changed.connect(func(t):
		le.text = t.to_upper()
		le.caret_column = t.length())
	vb.add_child(le)
	var msg := UI.label("", 18, UI.RED)
	vb.add_child(msg)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	vb.add_child(r)
	var bo := UI.red_button("Carica", func(): pass, 20)
	r.add_child(bo)
	r.add_child(UI.button("Indietro", func(): p.queue_free(), 18))
	bo.pressed.connect(func():
		var code := le.text.strip_edges().to_upper()
		if code.length() != 6:
			msg.text = "Il codice ha sei lettere."
			return
		msg.text = "Carico..."
		var net: Net = main.get_net()
		var d: Dictionary = await net.load_game(code)
		if d.is_empty():
			msg.text = "Partita %s non trovata. %s" % [code, net.last_error]
			return
		var cfg = str_to_var(str(d.get("cfg", "")))
		var acts = str_to_var(str(d.get("acts", "")))
		if not (cfg is Dictionary) or not (acts is Array):
			msg.text = "Salvataggio non leggibile."
			return
		cfg["acts"] = acts
		main.start_game(cfg))


func _online_panel_open(join: bool) -> void:
	on_join = join
	_online_panel()


func _online_panel() -> void:
	_store()
	if is_instance_valid(on_panel):
		on_panel.queue_free()
	on_panel = _overlay()
	var vb: VBoxContainer = on_panel.get_meta("vb")
	vb.add_child(UI.title("ENTRA IN UNA STANZA" if on_join else "CREA UNA STANZA ONLINE", 34))
	var txt := "Scrivi il tuo nome e il codice di quattro lettere che ti ha mandato chi ha creato la stanza." if on_join else "Si gioca con i mercanti scelti nel menu: tu prendi il primo posto, gli altri posti \"Umano\" sono per i tuoi amici. I posti rimasti liberi alla partenza li gioca il computer."
	var l0 := UI.label(txt, 18, UI.MUTED)
	l0.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l0)
	var ses: Dictionary = main.get_net().load_session()
	on_name = _line("Il tuo nome", 20)
	on_name.text = str(ses.get("name", ""))
	vb.add_child(on_name)
	if not on_join:
		vb.add_child(UI.red_button("Crea la stanza", _online_create, 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 4)
	on_code.custom_minimum_size.x = 220
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	row.add_child(UI.red_button("Entra", _online_join, 20))
	row.visible = on_join
	vb.add_child(row)
	on_lbl = UI.label("", 19)
	on_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	on_lbl.custom_minimum_size = Vector2(700, 90)
	vb.add_child(on_lbl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	on_start = UI.red_button("Inizia online", _online_start, 22)
	on_start.visible = main.lobby.get("role", "") == "host"
	row2.add_child(on_start)
	row2.add_child(UI.button("Indietro", func():
		main.lobby = {}
		on_panel.queue_free(), 18))
	vb.add_child(row2)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		on_lbl.text = "Stanza %s..." % main.lobby["code"]
	elif str(ses.get("room", "")) != "" and on_join:
		on_code.text = str(ses["room"])
		on_lbl.text = "Eri nella stanza %s: premi Entra per rientrare." % ses["room"]


func _say(t: String) -> void:
	if is_instance_valid(on_lbl):
		on_lbl.text = t


func _seat_names() -> Array:
	var out := []
	for s in seats:
		out.append(D.MERCHANTS[int(s["merchant"])]["nome"])
	return out


func _seats_text(room: Dictionary) -> String:
	var ss := Net._as_dict(room.get("seats", {}))
	var parts := []
	var names: Array = main.lobby.get("names", [])
	for i in names.size():
		var k := str(i)
		var w := str(ss[k].get("name", "?")) if ss.has(k) and ss[k] is Dictionary else ("computer" if not i in room.get("open", []) else "libero")
		parts.append("%s: %s" % [names[i], w])
	return ", ".join(parts)


func _online_create() -> void:
	var nm := on_name.text.strip_edges()
	if nm == "":
		_say("Scrivi il tuo nome.")
		return
	var open := [0]
	for i in range(1, seats.size()):
		if not seats[i]["ai"]:
			open.append(i)
	if open.size() < 2:
		_say("Nel menu segna come \"Umano\" almeno un altro posto per gli amici.")
		return
	_say("Creo la stanza...")
	var net: Net = main.get_net()
	var code := await net.create_room(nm, open)
	if code == "":
		_say("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": 0, "names": _seat_names()}
	net.remember_room(code, 0)
	net._save({"name": nm})
	if is_instance_valid(on_code):
		on_code.text = code
	if is_instance_valid(on_start):
		on_start.visible = true
	_lobby_poll(code)


func _online_join() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_name.text.strip_edges()
	if nm == "" or code.length() != 4:
		_say("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_say("Entro nella stanza %s..." % code)
	var net: Net = main.get_net()
	var s := await net.join_room(code, nm)
	if s == -2:
		_say("Stanza %s non trovata, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if s == -1:
		_say("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": s, "names": []}
	net.remember_room(code, s)
	net._save({"name": nm})
	if room.get("status", "") in ["playing", "over"] and room.has("game"):
		_say("Rientro nella partita della stanza %s..." % code)
		_begin(room["game"], true)
		return
	if is_instance_valid(on_start):
		on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_say("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		if main.lobby["role"] == "host":
			_say("Stanza [ %s ]: manda il codice ai tuoi amici.\nPosti: %s.\nQuando ci sono tutti premi Inizia online." % [code, _seats_text(room)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_begin(room["game"], false)
				return
			_say("Sei nella stanza [ %s ].\nAspetta che chi l'ha creata avvii la partita." % code)
		await get_tree().create_timer(2.0).timeout


func _online_start() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_say("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var ss := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	for i in cfg["seats"].size():
		var k := str(i)
		if ss.has(k) and ss[k] is Dictionary:
			cfg["seats"][i]["name"] = str(ss[k].get("name", ""))
			cfg["seats"][i]["ai"] = false
		else:
			cfg["seats"][i]["ai"] = true
	cfg["seed"] = 1 + randi() % 2000000000
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_say("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_begin(g, false)


func _begin(g: Dictionary, rejoin: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_say("Configurazione della partita non valida.")
		return
	cfg["online"] = {"code": lob["code"], "seat": int(lob["seat"]), "role": lob["role"], "backlog": backlog}
	main.lobby = {}
	main.start_game(cfg)
