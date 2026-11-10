extends Control
## La partita: mappa 3D al centro, mercanti a sinistra, plancia (carta nave con le stive) e diario a
## destra, pannello delle scelte in basso. Le scelte dei giocatori umani arrivano dal motore come
## richieste (decision_requested) e tornano con provide_decision.

const D = preload("res://scripts/data/mov_data.gd")

var main
var config := {}
var eng: MoVEngine
var board: Board3D
var online: OnlineSession
var req := {}
var viewer := 0                  # giocatore di cui si mostrano le informazioni private
var shown := 0                   # giocatore mostrato nella plancia
var holds := {}

var top_lbl: Label
var goal_lbl: Label
var players_box: VBoxContainer
var right_panel: PanelContainer
var plancia: VBoxContainer
var log_box: RichTextLabel
var log_lines: Array = []
var action: PanelContainer
var action_box: VBoxContainer
var info_lbl: RichTextLabel
var info_panel: PanelContainer
var toast: Label
var toast_t := 0.0
var popup: PanelContainer
var dice_box: HBoxContainer
var _pilot_pick := {}
var _pre_opts := {}
var _last_dice: Array = []
var _end_shown := false
var _left: PanelContainer
var _right_open := true
var top_panel: PanelContainer
var action_scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hf = JSON.parse_string(FileAccess.open("res://assets/data/stive.json", FileAccess.READ).get_as_text())
	holds = hf
	eng = MoVEngine.new()
	eng.setup(config)
	add_child(eng)
	if config.has("acts"):
		eng.preload_acts = config["acts"].duplicate()
	board = Board3D.new()
	add_child(board)
	board.setup(eng)
	board.gui_hit = _gui_hit
	board.picked_node.connect(_on_pick)
	board.hovered_node.connect(_on_hover)
	board.picked_box.connect(_show_culture)
	_build_ui()
	eng.changed.connect(_refresh)
	eng.log_added.connect(_log)
	eng.decision_requested.connect(_on_request)
	eng.fx.connect(_on_fx)
	eng.game_ended.connect(_on_end)
	viewer = _first_human()
	shown = viewer
	board.viewer = viewer
	if config.has("online"):
		var o: Dictionary = config["online"]
		online = OnlineSession.new()
		add_child(online)
		online.setup(main.get_net(), o["code"], int(o["seat"]), o["role"], o.get("backlog", []))
		online.view = self
		eng.online = online
		viewer = int(o["seat"])
		shown = viewer
		board.viewer = viewer
		online.heartbeat_loop()
	_refresh()
	_start.call_deferred()


func _start() -> void:
	await get_tree().process_frame
	await eng.run()


func _first_human() -> int:
	for s in eng.players.size():
		if not eng.players[s]["ai"]:
			return s
	return 0


func _exit_tree() -> void:
	if eng != null:
		eng.abort = true
		eng.provide_decision(null)


# ================================================================ interfaccia

func _gui_hit(sp: Vector2) -> bool:
	for c in [_left, right_panel, action, popup, top_panel]:
		if c != null and is_instance_valid(c) and c.visible and c.get_global_rect().has_point(sp):
			return true
	return false


func _build_ui() -> void:
	# barra in alto
	var top := PanelContainer.new()
	top_panel = top
	top.add_theme_stylebox_override("panel", UI.box(Color(UI.SPACE, 0.88), UI.CYAN_D, 0, 0, 8))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 58
	add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	top.add_child(hb)
	hb.add_child(UI.title("MERCHANT OF VENUS", 26))
	top_lbl = UI.head("", 18, UI.TEXT)
	top_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(top_lbl)
	goal_lbl = UI.label("", 17, UI.GOLD, UI.font_bold)
	hb.add_child(goal_lbl)
	hb.add_child(UI.button("Vista", func(): board.reset_view()))
	hb.add_child(UI.button("Plancia", _toggle_right))
	hb.add_child(UI.button("Regole", _rules))
	hb.add_child(UI.button("Salva", _save))
	hb.add_child(UI.button("Menu", func(): _confirm_menu()))
	# mercanti
	_left = PanelContainer.new()
	_left.position = Vector2(10, 68)
	_left.custom_minimum_size = Vector2(318, 0)
	add_child(_left)
	var lv := VBoxContainer.new()
	_left.add_child(lv)
	lv.add_child(UI.head("MERCANTI", 18))
	players_box = VBoxContainer.new()
	players_box.add_theme_constant_override("separation", 6)
	lv.add_child(players_box)
	# plancia e diario a destra
	right_panel = PanelContainer.new()
	right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_panel.offset_left = -520
	right_panel.offset_right = -10
	right_panel.offset_top = 68
	add_child(right_panel)
	var rs := ScrollContainer.new()
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rs.custom_minimum_size = Vector2(490, 0)
	right_panel.add_child(rs)
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(rv)
	plancia = VBoxContainer.new()
	plancia.add_theme_constant_override("separation", 6)
	rv.add_child(plancia)
	rv.add_child(UI.head("DIARIO DI BORDO", 16))
	log_box = UI.rich(16)
	log_box.custom_minimum_size = Vector2(470, 0)
	rv.add_child(log_box)
	# pannello delle scelte
	action = PanelContainer.new()
	action.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL, 0.95), UI.CYAN, 2, 12, 14))
	add_child(action)
	var as_ := ScrollContainer.new()
	as_.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action.add_child(as_)
	action_scroll = as_
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 8)
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	as_.add_child(action_box)
	# informazioni sul punto sotto il mouse
	info_panel = PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UI.box(Color(UI.SPACE, 0.85), UI.CYAN_D, 1, 8, 8))
	info_panel.visible = false
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_panel)
	info_lbl = UI.rich(16)
	info_lbl.custom_minimum_size = Vector2(320, 0)
	info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(info_lbl)
	toast = UI.label("", 34, UI.GOLD, UI.font_title)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast.add_theme_constant_override("outline_size", 10)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.visible = false
	add_child(toast)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var lw := 338.0
	var rw := 530.0 if _right_open else 0.0
	right_panel.visible = _right_open
	right_panel.offset_bottom = vs.y - 10
	right_panel.offset_top = 68
	var aw := clampf(vs.x - lw - rw - 30, 420, 900)
	action.position.x = lw + (vs.x - lw - rw - aw) / 2.0
	action.custom_minimum_size = Vector2(aw, 0)
	action.size.x = aw
	_left.size.y = 0
	info_panel.position = Vector2(lw + 10, 70)
	toast.position = Vector2(0, vs.y * 0.3)
	toast.size = Vector2(vs.x, 60)


func _toggle_right() -> void:
	_right_open = not _right_open
	_layout()


func _process(dt: float) -> void:
	# il pannello delle scelte cresce con il contenuto, fino a poco meno di metà schermo
	var vs := get_viewport_rect().size
	var want := minf(action_box.get_combined_minimum_size().y, vs.y * 0.45)
	if absf(action_scroll.custom_minimum_size.y - want) > 1.0:
		action_scroll.custom_minimum_size.y = want
		action.size.y = 0
	action.position.y = vs.y - action.size.y - 10
	if toast_t > 0:
		toast_t -= dt
		toast.modulate.a = clampf(toast_t, 0.0, 1.0)
		if toast_t <= 0:
			toast.visible = false


func _toast(t: String, sec := 2.5) -> void:
	toast.text = t
	toast.visible = true
	toast.modulate.a = 1.0
	toast_t = sec


func _log(t: String) -> void:
	log_lines.append(t)
	if log_lines.size() > 120:
		log_lines = log_lines.slice(log_lines.size() - 120)
	var out := ""
	for i in range(log_lines.size() - 1, -1, -1):
		var l: String = log_lines[i]
		if l.begins_with("—"):
			out += "[color=#62e3f0][b]%s[/b][/color]\n" % l
		else:
			out += l + "\n"
	log_box.text = out


# ================================================================ aggiornamento

func _refresh() -> void:
	if eng == null:
		return
	var p: Dictionary = eng.players[eng.cur]
	top_lbl.text = "Turno %d  -  tocca a %s" % [eng.turn, p["name"]]
	goal_lbl.text = "Obiettivo: patrimonio $%d" % eng.goal
	if not eng.players[eng.cur]["ai"] and online == null:
		if viewer != eng.cur:
			viewer = eng.cur
			shown = viewer
			board.viewer = viewer
	board.refresh()
	_refresh_players()
	_refresh_plancia()
	if req.is_empty():
		_show_waiting()


func _refresh_players() -> void:
	for c in players_box.get_children():
		c.queue_free()
	for s in eng.players.size():
		var p: Dictionary = eng.players[s]
		var row := PanelContainer.new()
		var cur: bool = s == eng.cur
		row.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL_L, 0.9) if cur else Color(UI.PANEL, 0.6), UI.GOLD if cur else (UI.CYAN if s == shown else UI.CYAN_D), 2 if cur or s == shown else 1, 8, 8))
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(func(ev): if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed): _show_player(s))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(hb)
		var sw := ColorRect.new()
		sw.color = D.MERCHANTS[p["m"]]["col"]
		sw.custom_minimum_size = Vector2(16, 0)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(sw)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(vb)
		var nm := "%s%s" % [p["name"], "  (IA)" if p["ai"] else ""]
		var l1 := UI.label(nm, 18, UI.TEXT, UI.font_bold)
		l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(l1)
		var l2 := UI.label("$%d   patrimonio $%d" % [p["money"], eng.net_worth(s)], 17, UI.GOLD, UI.font_mono)
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(l2)
		var l3 := UI.label("%s - porti %d, fabbriche %d" % [D.SHIPS[p["ship"]]["nome"], p["ports"].size(), p["facts"].size()], 15, UI.MUTED)
		l3.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(l3)
		players_box.add_child(row)


func _show_player(s: int) -> void:
	shown = s
	if not _right_open:
		_toggle_right()
	_refresh_players()
	_refresh_plancia()


func _token_rect(path: String, sz: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UI.tex(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(sz, sz)
	return t


func item_tex(it: Dictionary) -> String:
	match it["t"]:
		"g":
			return "res://assets/tokens/merci_%s.png" % it["c"]
		"f":
			return "res://assets/tokens/fabbr_%s.png" % it["c"]
		"fare":
			return "res://assets/tokens/bonus_%d.png" % it["b"]
		"r":
			return "res://assets/tokens/reliquia_%s.png" % it["r"]
		"e":
			return "res://assets/tokens/eq_%s.png" % it["e"]
	return ""


func _refresh_plancia() -> void:
	for c in plancia.get_children():
		c.queue_free()
	var s := shown
	var p: Dictionary = eng.players[s]
	var m: String = D.MERCHANTS[p["m"]]["id"]
	var hdr := HBoxContainer.new()
	hdr.add_child(UI.head("PLANCIA DI %s" % str(p["name"]).to_upper(), 17, D.MERCHANTS[p["m"]]["col"].lightened(0.3)))
	plancia.add_child(hdr)
	plancia.add_child(UI.label("Mercante %s - sconto del 20%% sugli atti dei %s" % [D.MERCHANTS[p["m"]]["nome"], D.CULTURES[p["own"]]["nome"]], 15, UI.MUTED))
	# carta nave con le stive
	var card := Control.new()
	var cw := 470.0
	var tex: Texture2D = UI.tex("res://assets/tokens/nave_%s_%s.jpg" % [m, p["ship"]])
	var ch := cw * float(tex.get_height()) / float(tex.get_width()) if tex != null else 280.0
	card.custom_minimum_size = Vector2(cw, ch)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(cw, ch)
	card.add_child(tr)
	plancia.add_child(card)
	var hr: Array = holds[p["ship"]]
	var hull := []
	var full := []
	var halves := []
	var hull_shield := false
	for it in p["cargo"]:
		if it["t"] == "r":
			hull.append(it)
		elif it["t"] == "e" and it["e"] == "shield" and not hull_shield:
			hull_shield = true
			hull.append(it)
		elif it["t"] in ["g", "f"]:
			full.append(it)
		else:
			halves.append(it)
	var hi := 0
	for it in full:
		if hi >= hr.size():
			break
		var r: Array = hr[hi]
		var t := _token_rect(item_tex(it), 10)
		var w := (float(r[2]) - float(r[0])) * cw
		var h := (float(r[3]) - float(r[1])) * ch
		var sz := minf(w, h) * 0.84
		t.position = Vector2(float(r[0]) * cw + (w - sz) / 2, float(r[1]) * ch + (h - sz) / 2)
		t.size = Vector2(sz, sz)
		t.tooltip_text = eng.item_name(it)
		card.add_child(t)
		hi += 1
	var half_i := 0
	for it in halves:
		var hidx := hi + half_i / 2
		if hidx >= hr.size():
			break
		var r: Array = hr[hidx]
		var w := (float(r[2]) - float(r[0])) * cw
		var h := (float(r[3]) - float(r[1])) * ch
		var sz := minf(w / 2.0, h) * 0.86
		var t := _token_rect(item_tex(it), 10)
		t.position = Vector2(float(r[0]) * cw + (half_i % 2) * w / 2.0 + (w / 2.0 - sz) / 2, float(r[1]) * ch + (h - sz) / 2)
		t.size = Vector2(sz, sz)
		t.tooltip_text = eng.item_name(it)
		card.add_child(t)
		half_i += 1
	plancia.add_child(UI.label("Spazio usato: %d stive e mezza su %d" % [eng.used_space(s) / 2, eng.capacity(s) / 2] if eng.used_space(s) % 2 == 1 else "Spazio usato: %d stive su %d" % [eng.used_space(s) / 2, eng.capacity(s) / 2], 15, UI.MUTED))
	if not hull.is_empty():
		plancia.add_child(UI.label("Scafo", 16, UI.CYAN, UI.font_bold))
		var hbh := HFlowContainer.new()
		for it in hull:
			var t := _token_rect(item_tex(it), 62)
			t.tooltip_text = eng.item_name(it) + ("\n" + D.RELICS[it["r"]]["d"] if it["t"] == "r" else "")
			hbh.add_child(t)
		plancia.add_child(hbh)
	if not p["ious"].is_empty():
		plancia.add_child(UI.label("Pagherò", 16, UI.CYAN, UI.font_bold))
		var hbi := HFlowContainer.new()
		for c in p["ious"]:
			var t := _token_rect("res://assets/tokens/iou_%s.jpg" % c, 56)
			t.tooltip_text = "Pagherò dei %s: $%d da spendere presso di loro" % [D.CULTURES[c]["nome"], int(D.CULTURES[c]["iou"])]
			hbi.add_child(t)
		plancia.add_child(hbi)
	if not p["ports"].is_empty() or not p["facts"].is_empty():
		var tx := []
		for o in p["ports"]:
			tx.append("spazioporto " + Mappa.orbit_name(o))
		for c in p["facts"]:
			tx.append("fabbrica dei %s" % D.CULTURES[c]["nome"])
		var r2 := UI.rich(15)
		r2.text = "[b][color=#62e3f0]Atti:[/color][/b] " + ", ".join(tx)
		plancia.add_child(r2)
	if s == viewer and not p["obs"].is_empty():
		var tx2 := []
		for sy in p["obs"]:
			var c: String = p["obs"][sy]
			if not eng.cult[c]["disc"]:
				tx2.append("%s: %s (%s)" % [Mappa.sys_name(sy), D.CULTURES[c]["nome"], c])
		if not tx2.is_empty():
			var r3 := UI.rich(15)
			r3.text = "[b][color=#ffd23a]Osservate in segreto:[/color][/b] " + ", ".join(tx2)
			plancia.add_child(r3)


# ================================================================ scelte

func _clear_action() -> void:
	for c in action_box.get_children():
		c.queue_free()


func _show_waiting() -> void:
	_clear_action()
	var p: Dictionary = eng.players[eng.cur]
	if eng.over:
		return
	var who: String = p["name"]
	var t := "%s sta giocando..." % who
	if online != null and not p["ai"] and eng.cur != online.seat:
		t = "In attesa di %s..." % who
	action_box.add_child(UI.head(t, 20, UI.CYAN))
	_add_dice()
	if not eng.ms.is_empty() and eng.ms.get("s", -1) == eng.cur:
		action_box.add_child(UI.label("PM rimasti: %d" % int(eng.ms.get("mp", 0)), 17, UI.TEXT, UI.font_mono))


func _add_dice() -> void:
	if _last_dice.is_empty():
		return
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.add_child(UI.label("Dadi:", 17, UI.MUTED))
	for d in _last_dice:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UI.box(Color("#f4f4ee"), Color("#222"), 2, 6, 6))
		pc.custom_minimum_size = Vector2(38, 38)
		var l := UI.label(str(d), 22, Color("#111"), UI.font_head)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pc.add_child(l)
		hb.add_child(pc)
	action_box.add_child(hb)


func _on_request(r: Dictionary) -> void:
	req = r
	_clear_action()
	board.clear_steps()
	var s: int = r["seat"]
	if online == null and viewer != s:
		viewer = s
		shown = s
		board.viewer = s
		_refresh_plancia()
		board.refresh()
	match r["k"]:
		"pre":
			_ui_pre(r)
		"mull":
			_ui_mull(r)
		"move":
			_ui_move(r)
		"pen":
			_ui_pen(r)
		"trade":
			_ui_trade(r)


func _finish_decision(r) -> void:
	req = {}
	_pilot_pick = {}
	board.clear_steps()
	_clear_action()
	eng.provide_decision(r)


func _ui_pre(r: Dictionary) -> void:
	var s: int = r["seat"]
	var p: Dictionary = eng.players[s]
	_pre_opts = {"auto": r.get("auto", false), "glock": false, "jump": r.get("jump", false), "off": []}
	action_box.add_child(UI.head("TOCCA A %s" % str(p["name"]).to_upper(), 20, D.MERCHANTS[p["m"]]["col"].lightened(0.3)))
	action_box.add_child(UI.label("Sei a %s. %s" % [eng.place_name(p["pos"]), "Puoi partire tirando %d dadi%s." % [int(eng.ship(s)["dadi"]), " oppure restare fermo a commerciare" if r["can_stay"] else ""]], 17))
	var opts := HFlowContainer.new()
	if r.get("auto", false):
		opts.add_child(_check("Pilota automatico (un dado vale 4)", true, func(v): _pre_opts["auto"] = v))
	if r.get("glock", false):
		opts.add_child(_check("Spegni le porte tele", false, func(v): _pre_opts["glock"] = v))
	if r.get("jump", false):
		opts.add_child(_check("Avvio a salto verso una porta tele", true, func(v): _pre_opts["jump"] = v))
	for c in r.get("drives", []):
		var nm: String = "rosso" if c == "r" else "giallo"
		opts.add_child(_check("Spegni il propulsore %s" % nm, false, func(v): (_pre_opts["off"].append(c) if v else _pre_opts["off"].erase(c))))
	if opts.get_child_count() > 0:
		action_box.add_child(opts)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.add_child(UI.red_button("PARTI: TIRA I DADI", func(): _finish_decision(_pre_opts.duplicate())))
	if r["can_stay"]:
		var lbl := "RESTA QUI A COMMERCIARE" if r.get("trade", false) else "RESTA QUI"
		hb.add_child(UI.button(lbl, func():
			var o := _pre_opts.duplicate()
			o["stay"] = true
			_finish_decision(o)))
	action_box.add_child(hb)
	if r["can_stay"] and r.get("trade", false) and Mappa.kind(p["pos"]) in ["city", "scity", "base"]:
		action_box.add_child(UI.label("Restando un turno intero in città si può comprare e vendere senza limiti.", 15, UI.MUTED))
	board.focus_node(p["pos"])


func _check(t: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = t
	c.button_pressed = on
	c.toggled.connect(cb)
	return c


func _ui_mull(r: Dictionary) -> void:
	action_box.add_child(UI.head("INGRANAGGIO DELLA SECONDA POSSIBILITÀ", 18))
	action_box.add_child(UI.label("Puoi ritirare un dado.", 17))
	var hb := HBoxContainer.new()
	var dice: Array = r["dice"]
	for i in dice.size():
		if r.get("auto", false) and i == dice.size() - 1:
			continue
		var idx := i
		hb.add_child(UI.button("Ritira il %d" % int(dice[i]), func(): _finish_decision(idx)))
	hb.add_child(UI.red_button("Tieni i dadi", func(): _finish_decision(-1)))
	action_box.add_child(hb)


func _ui_move(r: Dictionary) -> void:
	var s: int = r["seat"]
	var here: int = r["at"]
	action_box.add_child(UI.head("MOVIMENTO", 18))
	_add_dice()
	var info := "PM rimasti: %d" % int(r["mp"])
	if int(r["pilot"]) >= 0:
		info += "   -   numero pilota: %d" % int(r["pilot"])
	if r.get("free", false):
		info = "Il propulsore salta la penalità: scegli dove proseguire (gratis)."
	action_box.add_child(UI.label(info, 18, UI.GOLD, UI.font_mono))
	action_box.add_child(UI.label("Tocca un punto evidenziato sulla mappa (o scegli qui sotto). Sei a %s." % eng.place_name(here), 16, UI.MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	for st in r["steps"]:
		var stc: Dictionary = st
		var t := "%s (%d PM)" % [_short_place(int(st["to"])), int(st["cost"])]
		if st.get("gate", false):
			t = "Salto: " + t
		if not st["via"].is_empty():
			t += " saltando %d" % st["via"].size()
		flow.add_child(UI.button(t, func(): _choose_step(stc), 15))
	action_box.add_child(flow)
	var hb := HBoxContainer.new()
	if r["land"]:
		hb.add_child(UI.red_button("ATTERRA QUI", func(): _finish_decision({"land": true})))
	action_box.add_child(hb)
	board.show_steps(r["steps"], here if r["land"] else -1)
	board.show_trail(eng.ms.get("path", []))
	if r["steps"].size() > 0 and int(r["mp"]) == eng.ms.get("mp", 0) and eng.ms.get("first", false):
		board.focus_node(here)


func _short_place(n: int) -> String:
	var k := Mappa.kind(n)
	match k:
		"dot":
			return "punto %s" % {"r": "rosso", "y": "giallo", "b": "blu"}[Mappa.nodes[n]["c"]]
		"oval":
			return "ovale $%d" % int(Mappa.nodes[n]["p"])
	return eng.place_name(n)


func _on_pick(n: int) -> void:
	if req.is_empty() or req.get("k", "") != "move":
		_show_node_info(n, true)
		return
	if board.hl_steps.has(n):
		_choose_step(board.hl_steps[n])
	elif req["land"] and n == int(req["at"]):
		_finish_decision({"land": true})
	else:
		_show_node_info(n, true)


func _choose_step(st: Dictionary) -> void:
	var pilots: Array = st["pilots"]
	var cur_pilot := int(req.get("pilot", -1))
	var need := pilots.size() > 1 and (cur_pilot < 0 or not cur_pilot in pilots)
	if need:
		# scelta del numero pilota
		_clear_action()
		action_box.add_child(UI.head("NUMERO PILOTA", 18))
		action_box.add_child(UI.label("Scegli il numero pilota fra i dadi tirati: varrà per tutti i cerchi di navigazione e le porte tele di questo turno.", 16))
		var hb := HBoxContainer.new()
		for pv in pilots:
			var pvv: int = pv
			hb.add_child(UI.button("Pilota %d" % pvv, func(): _finish_decision({"to": st["to"], "pilot": pvv})))
		hb.add_child(UI.button("Indietro", func(): _on_request(req)))
		action_box.add_child(hb)
		return
	var pv0 := -1
	if not pilots.is_empty():
		pv0 = cur_pilot if cur_pilot in pilots else int(pilots[0])
	_finish_decision({"to": st["to"], "pilot": pv0})


func _ui_pen(r: Dictionary) -> void:
	action_box.add_child(UI.head("PENALITÀ", 18, UI.RED))
	action_box.add_child(UI.label("Questo punto infligge una penalità di $%d%s. Paghi e prosegui o ti fermi qui (senza pagare, ma il movimento finisce)?" % [int(r["amt"]), " (già ridotta dagli scudi)" if int(r["amt"]) < int(r["v"]) else ""], 17))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.add_child(UI.red_button("PAGA $%d E PROSEGUI" % int(r["amt"]), func(): _finish_decision(true)))
	hb.add_child(UI.button("FERMATI QUI", func(): _finish_decision(false)))
	action_box.add_child(hb)


func _ui_trade(r: Dictionary) -> void:
	var s: int = r["seat"]
	var p: Dictionary = eng.players[s]
	var c: String = r["c"]
	var title := "COMMERCIO"
	if c == "base":
		title = "BASE GALATTICA - I TINKERER VENDONO TUTTE LE NAVI"
	elif c != "":
		title = "COMMERCIO CON I %s (%s, %s)" % [D.CULTURES[c]["nome"].to_upper(), c, D.SCI_NAME[D.CULTURES[c]["sci"]]]
	else:
		title = "ATTERRATO: %s" % eng.place_name(r["at"]).to_upper()
	var hh := HBoxContainer.new()
	var tl := UI.head(title, 17)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hh.add_child(tl)
	if c != "" and c != "base":
		hh.add_child(UI.button("Scheda", func(): _show_culture(eng.cult[c]["sys"]), 14))
	action_box.add_child(hh)
	var st := "Denaro $%d" % p["money"]
	if p["credit"] > 0:
		st += "   credito da baratto $%d (vale solo in questo turno)" % p["credit"]
	action_box.add_child(UI.label(st, 17, UI.GOLD, UI.font_mono))
	if r["limit"] and c != "":
		action_box.add_child(UI.label("Appena arrivato in città: %s, %s (pagherò e passeggeri senza limiti)." % ["acquisto già fatto" if p["buys"] >= 1 else "un solo acquisto", "vendita o baratto già fatti" if p["sells"] >= 1 else "una sola vendita o baratto"], 15, UI.MUTED))
	var groups := [["deliver", "Consegna passeggeri"], ["sell", "Vendi"], ["iou", "Pagherò"], ["barter", "Baratta"], ["buy", "Compra"], ["pickfare", "Prendi passeggeri"], ["pickrelic", "Reliquia"], ["jett", "Getta via"]]
	for g in groups:
		var items := []
		for o in r["opts"]:
			if o["a"] == g[0]:
				items.append(o)
		if items.is_empty():
			continue
		action_box.add_child(UI.label(g[1], 16, UI.CYAN, UI.font_bold))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 6)
		for o in items:
			var oo: Dictionary = o
			var b := UI.button(o["lbl"], func(): _finish_decision(oo), 15)
			flow.add_child(b)
		action_box.add_child(flow)
	var over_cap := eng.used_space(s) > eng.capacity(s)
	var endb := UI.red_button("FINE TURNO", func(): _finish_decision({"a": "end"}))
	if over_cap:
		action_box.add_child(UI.label("La nave è troppo carica: getta via qualcosa (altrimenti lo farà il computer).", 15, UI.RED))
	action_box.add_child(endb)


# ================================================================ effetti

func _on_fx(kind: String, d: Dictionary) -> void:
	match kind:
		"dice":
			_last_dice = d["dice"]
		"turn":
			_last_dice = []
			board.show_trail([])
			if eng.players[d["s"]]["ai"] or (online != null and d["s"] != online.seat):
				board.focus_node(eng.players[d["s"]]["pos"])
		"step":
			board.move_pawn(d["s"], d["via"] + [d["to"]])
			board.show_trail(eng.ms.get("path", []))
			if eng.players[d["s"]]["ai"]:
				board.focus_node(d["to"])
		"reveal":
			board.refresh()
		"discover":
			_toast("%s scopre i %s!" % [eng.pname(d["s"]), D.CULTURES[d["c"]]["nome"]])
			board.refresh()
		"build":
			board.refresh()
		"win":
			_toast("%s VINCE!" % eng.pname(d["s"]).to_upper(), 5.0)


func _on_hover(n: int) -> void:
	if n < 0:
		info_panel.visible = false
		return
	_show_node_info(n, false)


func _show_node_info(n: int, sticky: bool) -> void:
	var k := Mappa.kind(n)
	var lines := ["[b]%s[/b]" % eng.place_name(n).capitalize() if k != "dot" else "[b]Punto %s[/b]" % {"r": "rosso", "y": "giallo", "b": "blu"}[Mappa.nodes[n]["c"]]]
	var sy := Mappa.sys(n)
	if sy != "":
		lines.append("Sistema: %s" % Mappa.sys_name(sy))
		var c := eng.knows(viewer, sy)
		if c != "":
			lines.append("Abitato dai %s (%s)%s" % [D.CULTURES[c]["nome"], c, "" if eng.cult[c]["disc"] else " - osservati in segreto"])
	var pen := eng.penalty_at(n)
	if not pen.is_empty():
		lines.append("[color=#ff6b6b]Penalità $%d[/color] (colore %s)" % [int(pen["v"]), {"r": "rosso", "y": "giallo", "b": "blu"}[pen["c"]]])
	if k in ["dot", "oval"]:
		lines.append("I propulsori %s lo saltano." % ("rossi" if Mappa.nodes[n]["c"] == "r" else ("gialli" if Mappa.nodes[n]["c"] == "y" else "non")) if Mappa.nodes[n]["c"] != "b" else "Nessun propulsore salta i punti blu.")
	if k == "city":
		lines.append("Città di superficie: entrare e uscire costa 2 PM.")
	if k == "nav":
		var ex: Dictionary = Mappa.nodes[n]["ex"]
		lines.append("Cerchio di navigazione: si esce dalla freccia del proprio numero pilota.")
		if Mappa.nodes[n].has("o"):
			lines.append("Orbita: %s%s" % [Mappa.orbit_name(n), " (spazioporto di %s)" % eng.pname(eng.ports[n]) if eng.ports.has(n) else ""])
	if Mappa.is_orbit(n) and k == "orbit":
		lines.append("Orbita: qui si può costruire uno spazioporto." if not eng.ports.has(n) else "Spazioporto di %s: commercio senza limiti, commissione del 10%% al proprietario." % eng.pname(eng.ports[n]))
	if k == "qbox":
		var q: Dictionary = eng.qbox[n]
		if q["up"]:
			lines.append(eng.q_name(q["m"]))
			if q["m"]["t"] == "relic":
				lines.append("Già raccolta." if q["taken"] else D.RELICS[q["m"]["r"]]["d"])
		elif eng.players[viewer]["qk"].has(n):
			lines.append("Sbirciato con l'occhio spia: " + eng.q_name(q["m"]))
		else:
			lines.append("Segnalino \"?\" coperto: si gira quando ci si passa sopra.")
	var here := []
	for s in eng.players.size():
		if eng.players[s]["pos"] == n:
			here.append(eng.pname(s))
	if not here.is_empty():
		lines.append("Qui: " + ", ".join(here))
	info_lbl.text = "\n".join(lines)
	info_panel.visible = true
	if sticky and k in ["city", "scity"] and sy != "" and eng.knows(viewer, sy) != "":
		_show_culture(sy)


func _show_culture(sy: String) -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	var c := eng.knows(viewer, sy)
	popup = PanelContainer.new()
	popup.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL, 0.97), UI.CYAN, 2, 12, 16))
	add_child(popup)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	popup.add_child(vb)
	if c == "":
		vb.add_child(UI.head(Mappa.sys_name(sy).to_upper(), 20))
		vb.add_child(UI.label("La cultura di questo sistema è ancora nascosta: la scopre il primo che atterra in una sua città o spazioporto (e riceve il pagherò). Dalle orbite la si osserva in segreto.", 17))
	else:
		var cd: Dictionary = D.CULTURES[c]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		vb.add_child(hb)
		hb.add_child(_token_rect("res://assets/tokens/creatura_%s.jpg" % c, 120))
		var v2 := VBoxContainer.new()
		hb.add_child(v2)
		v2.add_child(UI.head("%s %s" % [c, cd["nome"].to_upper()], 22))
		v2.add_child(UI.label("%s - scienza: %s%s" % [Mappa.sys_name(sy), D.SCI_NAME[cd["sci"]], "" if eng.cult[c]["disc"] else " (osservati in segreto)"], 16, UI.MUTED))
		var r := UI.rich(16)
		r.custom_minimum_size = Vector2(560, 0)
		var buyers := []
		for b in D.buyers_of(c):
			buyers.append(b)
		var t := "[b]Merci:[/b] %s, costo $%d, rendono $%d. Disponibili: %d.\n" % [cd["g"], int(cd["gc"]), int(cd["gp"]), int(eng.cult[c]["stock"])]
		t += "[b]Le comprano:[/b] %s\n" % ", ".join(buyers)
		var who := []
		for k in D.CULT_IDS:
			if D.buys(c, k):
				who.append(k)
		t += "[b]Comprano le merci di:[/b] %s\n" % ", ".join(who)
		if eng.factories.has(c):
			t += "[b]Fabbrica[/b] di %s: %s a $%d (rende $%d)%s.\n" % [eng.pname(eng.factories[c]["o"]), cd["fg"], int(cd["fc"]), int(cd["fp"]), "" if eng.cult[c]["fg"] else ", al momento esaurite"]
		else:
			t += "[b]Atto della fabbrica:[/b] $%d (%s a $%d, rende $%d).\n" % [int(cd["f"]), cd["fg"], int(cd["fc"]), int(cd["fp"])]
		t += "[b]Pagherò:[/b] $%d.\n" % int(cd["iou"])
		var sells := []
		if eng.ship_sellers(c):
			for sh in D.SHIP_ORDER:
				if D.SHIPS[sh]["sci"] == cd["sci"]:
					sells.append("nave %s $%d" % [D.SHIPS[sh]["nome"], int(D.SHIPS[sh]["c"])])
		for e in D.EQUIP:
			if D.EQUIP[e]["sci"] == cd["sci"]:
				sells.append("%s $%d" % [D.EQUIP[e]["nome"], int(D.EQUIP[e]["c"])])
		if not sells.is_empty():
			t += "[b]Vendono anche:[/b] %s.\n" % ", ".join(sells)
		var bon := []
		for b in eng.cult[c]["bon"]:
			var bb: Dictionary = eng.bon_list[b]
			bon.append(D.fare_text(bb) if bb["t"] == "fare" else D.dem_text(bb))
		if not bon.is_empty():
			t += "[b]Bonus:[/b] %s.\n" % "; ".join(bon)
		if not eng.cult[c]["sun"].is_empty():
			var rl := []
			for rr in eng.cult[c]["sun"]:
				rl.append("%s $%d" % [D.RELICS[rr]["nome"], int(D.RELICS[rr]["v"])])
			t += "[b]Reliquie in vendita:[/b] %s.\n" % ", ".join(rl)
		var orbs := []
		for o in Mappa.orbits_of.get(sy, []):
			orbs.append("%s%s" % [Mappa.orbit_name(o), " (di %s)" % eng.pname(eng.ports[o]) if eng.ports.has(o) else " (libero, $200)"])
		t += "[b]Spazioporti:[/b] %s." % ", ".join(orbs)
		r.text = t
		vb.add_child(r)
	vb.add_child(UI.button("Chiudi", func(): popup.queue_free()))
	popup.reset_size()
	var vs := get_viewport_rect().size
	popup.position = Vector2(350, 80)
	popup.custom_minimum_size = Vector2(minf(640, vs.x - 380), 0)


func _on_end(res: Dictionary) -> void:
	if _end_shown:
		return
	_end_shown = true
	if online != null:
		online.finish()
	_clear_action()
	var w: int = res.get("winner", 0)
	action_box.add_child(UI.title("%s VINCE!" % eng.pname(w).to_upper(), 30))
	var rank := []
	for s in eng.players.size():
		rank.append([eng.net_worth(s), s])
	rank.sort()
	rank.reverse()
	var t := ""
	for i in rank.size():
		t += "%d. %s - patrimonio $%d\n" % [i + 1, eng.pname(rank[i][1]), rank[i][0]]
	action_box.add_child(UI.label(t, 18))
	var hb := HBoxContainer.new()
	hb.add_child(UI.red_button("TORNA AL MENU", func(): main.show_menu()))
	action_box.add_child(hb)


# ================================================================ menu, regole, salvataggio

func _rules() -> void:
	var rv := preload("res://scripts/ui/rules_view.gd").new()
	rv.embedded = true
	rv.main = main
	add_child(rv)
	board.input_locked = true
	rv.closed.connect(func(): board.input_locked = false)


func _confirm_menu() -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = PanelContainer.new()
	add_child(popup)
	var vb := VBoxContainer.new()
	popup.add_child(vb)
	vb.add_child(UI.head("TORNARE AL MENU?", 20))
	vb.add_child(UI.label("La partita in corso si chiude. Se vuoi riprenderla più tardi, salvala prima.", 17))
	var hb := HBoxContainer.new()
	hb.add_child(UI.red_button("Torna al menu", func(): main.show_menu()))
	hb.add_child(UI.button("Annulla", func(): popup.queue_free()))
	vb.add_child(hb)
	popup.position = get_viewport_rect().size / 2 - Vector2(260, 80)


func _save() -> void:
	if online != null:
		_toast("Le partite online restano nella loro stanza", 3.0)
		return
	_toast("Salvataggio in corso...", 2.0)
	var cfg := config.duplicate(true)
	cfg.erase("acts")
	cfg.erase("online")
	var code: String = await main.get_net().save_game({"cfg": var_to_str(cfg), "acts": var_to_str(eng.rec_acts)})
	if code == "":
		_toast("Salvataggio non riuscito: %s" % main.get_net().last_error, 4.0)
		return
	if is_instance_valid(popup):
		popup.queue_free()
	popup = PanelContainer.new()
	add_child(popup)
	var vb := VBoxContainer.new()
	popup.add_child(vb)
	vb.add_child(UI.head("PARTITA SALVATA", 20))
	vb.add_child(UI.label("Codice della partita:", 17))
	var l := UI.label(code, 44, UI.GOLD, UI.font_head)
	vb.add_child(l)
	vb.add_child(UI.label("Dal menu, Carica partita, scrivi questo codice per riprenderla\nda qualsiasi dispositivo.", 16, UI.MUTED))
	vb.add_child(UI.button("Chiudi", func(): popup.queue_free()))
	popup.position = get_viewport_rect().size / 2 - Vector2(240, 120)


# ---------------------------------------------------------------- online (richiami di OnlineSession)

func online_caught_up() -> void:
	_toast("Partita ripresa", 2.0)


func online_status(t: String) -> void:
	_toast(t, 3.0)


func online_waiting(s: int, slow: bool) -> void:
	if s < 0:
		return
	if slow:
		_toast("%s ci sta mettendo un po'..." % eng.pname(s), 2.0)
