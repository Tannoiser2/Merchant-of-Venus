extends Control
## Regolamento in italiano (assets/regole.md) e tabelle del gioco. Si apre dal menu o sopra la partita.

const D = preload("res://scripts/data/mov_data.gd")

signal closed

var main
var page := "regole"
var embedded := false
var body: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if embedded:
		var sh := ColorRect.new()
		sh.color = Color(0, 0, 0, 0.7)
		sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(sh)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_top = 40
	panel.offset_right = -40
	panel.offset_bottom = -40
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	top.add_child(UI.title("REGOLE" if page == "regole" else "TABELLE", 40))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	for p in [["regole", "Regole"], ["tabelle", "Culture e merci"]]:
		var pp: String = p[0]
		var b := UI.button(p[1], func():
			page = pp
			_fill(), 17)
		top.add_child(b)
	top.add_child(UI.red_button("Chiudi", _close, 17))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	sc.add_child(body)
	_fill()


func _close() -> void:
	if embedded:
		closed.emit()
		queue_free()
	else:
		main.show_menu()


func _fill() -> void:
	for c in body.get_children():
		c.queue_free()
	if page == "regole":
		_rules()
	else:
		_tables()


func _md(t: String) -> String:
	var out := t
	var re := RegEx.new()
	re.compile("\\*\\*(.+?)\\*\\*")
	out = re.sub(out, "[b]$1[/b]", true)
	return out


func _rules() -> void:
	var f := FileAccess.open("res://assets/regole.md", FileAccess.READ)
	var txt := f.get_as_text()
	var buf := ""
	for line in txt.split("\n"):
		if line.begins_with("# "):
			continue
		if line.begins_with("## "):
			if buf != "":
				_para(buf)
				buf = ""
			body.add_child(UI.head(line.substr(3).to_upper(), 22))
		elif line.begins_with("- "):
			buf += "  -  " + _md(line.substr(2)) + "\n"
		elif line.strip_edges() == "":
			if buf != "":
				_para(buf)
				buf = ""
		else:
			buf += _md(line) + " "
	if buf != "":
		_para(buf)


func _para(t: String) -> void:
	var r := UI.rich(18)
	r.text = t.strip_edges()
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(r)


func _tables() -> void:
	body.add_child(UI.head("LE QUATTORDICI CULTURE", 22))
	_para("Le merci di una cultura le comprano le culture con i tre numeri d'identità successivi (dopo il 10 viene l'1). Il pagherò si spende solo presso la cultura che l'ha emesso.")
	var g := GridContainer.new()
	g.columns = 7
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 6)
	for h in ["Cultura", "Scienza", "Merci (costo / resa)", "Le comprano", "Fabbrica", "Merci di fabbrica", "Pagherò"]:
		g.add_child(UI.label(h, 16, UI.CYAN, UI.font_bold))
	for c in D.CULT_IDS:
		var cd: Dictionary = D.CULTURES[c]
		g.add_child(UI.label("%s %s" % [c, cd["nome"]], 16, UI.TEXT, UI.font_bold))
		g.add_child(UI.label(D.SCI_NAME[cd["sci"]], 16))
		g.add_child(UI.label("%s $%d / $%d" % [cd["g"], int(cd["gc"]), int(cd["gp"])], 16))
		g.add_child(UI.label(", ".join(D.buyers_of(c)), 16))
		g.add_child(UI.label("$%d" % int(cd["f"]), 16))
		g.add_child(UI.label("%s $%d / $%d" % [cd["fg"], int(cd["fc"]), int(cd["fp"])], 16))
		g.add_child(UI.label("$%d" % int(cd["iou"]), 16))
	body.add_child(g)
	body.add_child(UI.head("NAVI", 22))
	var g2 := GridContainer.new()
	g2.columns = 5
	g2.add_theme_constant_override("h_separation", 24)
	for h in ["Nave", "Dadi", "Stive", "Costo / permuta", "La vendono"]:
		g2.add_child(UI.label(h, 16, UI.CYAN, UI.font_bold))
	for sh in D.SHIP_ORDER:
		var s: Dictionary = D.SHIPS[sh]
		g2.add_child(UI.label(s["nome"], 16, UI.TEXT, UI.font_bold))
		g2.add_child(UI.label(str(s["dadi"]), 16))
		g2.add_child(UI.label(str(s["stive"]), 16))
		g2.add_child(UI.label("$%d / $%d" % [int(s["c"]), int(s["t"])], 16))
		g2.add_child(UI.label("%s e Base Galattica" % D.SCI_NAME[s["sci"]], 16))
	body.add_child(g2)
	body.add_child(UI.head("EQUIPAGGIAMENTO", 22))
	for e in D.EQUIP:
		var ed: Dictionary = D.EQUIP[e]
		_para("[b]%s[/b] ($%d, lo vendono le culture di %s): %s" % [ed["nome"], int(ed["c"]), D.SCI_NAME[ed["sci"]], ed["d"]])
	body.add_child(UI.head("RELIQUIE DEL PRIMO IMPERO", 22))
	for r in D.RELICS:
		var rd: Dictionary = D.RELICS[r]
		_para("[b]%s[/b] ($%d): %s" % [rd["nome"], int(rd["v"]), rd["d"]])
