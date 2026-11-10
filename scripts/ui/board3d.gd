class_name Board3D
extends Node3D
## Il tabellone in 3D: la mappa originale del Cluster su un piano, le pedine dei mercanti, i segnalini
## "?", spazioporti e fabbriche, le culture scoperte nei loro riquadri con merci e bonus accanto.
## Telecamera: mouse (trascina = sposta, tasto destro o Maiusc = ruota, rotella = zoom) e tocco
## (un dito sposta, due dita pizzicano per lo zoom e ruotano), tastiera (frecce, Q/E, +/-).

const D = preload("res://scripts/data/mov_data.gd")

signal picked_node(n: int)
signal hovered_node(n: int)
signal picked_box(sys_id: String)

var eng: MoVEngine
var viewer := -1                  # giocatore di cui si mostrano le informazioni private
var pivot: Node3D
var cam: Camera3D
var target := Vector3.ZERO
var target_goal := Vector3.ZERO
var yaw := 0.0
var pitch := -1.22
var dist := 38.0
var input_locked := false
var gui_hit: Callable

var pawns := {}                   # giocatore -> Node3D
var pawn_goal := {}
var pawn_path := {}               # giocatore -> punti ancora da percorrere (animazione)
var q_nodes := {}
var build_nodes := {}
var cult_nodes := {}
var stock_root: Node3D
var hl_root: Node3D
var trail_root: Node3D
var hover_n := -1
var hl_steps := {}                # punto -> mossa evidenziata

var _drag := false
var _drag_btn := 0
var _moved := 0.0
var _touches := {}
var _touch_moved := 0.0
var _touch_start := Vector2.ZERO
var _t := 0.0
var _hover_ring: MeshInstance3D
var _cur_ring: MeshInstance3D
const DIST_MIN := 5.0
const DIST_MAX := 62.0
const Q := 0.74                   # lato dei segnalini "?" e delle caselle
const TOK := 0.62


func setup(e: MoVEngine) -> void:
	eng = e
	Mappa.load_map()
	_build_env()
	_build_camera()
	reset_view()
	target = target_goal
	_build_board()
	hl_root = Node3D.new()
	add_child(hl_root)
	trail_root = Node3D.new()
	add_child(trail_root)
	stock_root = Node3D.new()
	add_child(stock_root)
	_hover_ring = _ring(Color(1, 1, 1, 0.9), 0.36, 0.05)
	_hover_ring.visible = false
	add_child(_hover_ring)
	_cur_ring = _ring(Color(1.0, 0.85, 0.2, 0.95), 0.44, 0.07)
	add_child(_cur_ring)
	for s in eng.players.size():
		var p := _pawn(D.MERCHANTS[eng.players[s]["m"]]["col"])
		add_child(p)
		pawns[s] = p
		p.position = _pawn_pos(s, eng.players[s]["pos"])
		pawn_goal[s] = p.position
		pawn_path[s] = []
	refresh()


# ================================================================ scena

func _build_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#020309")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.5, 0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	# stelle sotto e attorno al tabellone
	var g := RandomNumberGenerator.new()
	g.seed = 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	sm.material = mat
	mm.mesh = sm
	mm.instance_count = 900
	for i in 900:
		var ang := g.randf() * TAU
		var r := g.randf_range(22.0, 90.0)
		var y := g.randf_range(-40.0, 10.0)
		var tr := Transform3D(Basis().scaled(Vector3.ONE * g.randf_range(0.5, 2.2)), Vector3(cos(ang) * r, y, sin(ang) * r))
		mm.set_instance_transform(i, tr)
		var b := g.randf_range(0.5, 1.0)
		mm.set_instance_color(i, Color(b, b, minf(1.0, b * 1.15)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_camera() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.far = 400.0
	cam.near = 0.1
	pivot.add_child(cam)
	cam.current = true
	_update_cam()


func _build_board() -> void:
	var tex: Texture2D = UI.tex("res://assets/board/tabellone.jpg")
	var bm := BoxMesh.new()
	bm.size = Vector3(Mappa.W, 0.3, Mappa.H)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var side := StandardMaterial3D.new()
	side.albedo_color = Color("#101420")
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position.y = -0.15
	# faccia superiore con la mappa, i lati scuri
	mi.material_override = null
	bm.material = side
	add_child(mi)
	var top := PlaneMesh.new()
	top.size = Vector2(Mappa.W, Mappa.H)
	top.material = mat
	var ti := MeshInstance3D.new()
	ti.mesh = top
	ti.position.y = 0.002
	add_child(ti)
	# cornice
	var fr := StandardMaterial3D.new()
	fr.albedo_color = Color("#1a2238")
	fr.metallic = 0.6
	fr.roughness = 0.35
	for k in 4:
		var b := BoxMesh.new()
		var horiz := k < 2
		b.size = Vector3(Mappa.W + 0.8 if horiz else 0.4, 0.42, 0.4 if horiz else Mappa.H)
		b.material = fr
		var f := MeshInstance3D.new()
		f.mesh = b
		f.position = Vector3(0 if horiz else (Mappa.W / 2 + 0.2) * (1 if k == 2 else -1), -0.08, (Mappa.H / 2 + 0.2) * (1 if k == 0 else -1) if horiz else 0)
		add_child(f)


func _pawn(col: Color) -> Node3D:
	## Pedina come quelle del gioco: base, corpo conico, collare e testa
	var root := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.25
	m.roughness = 0.35
	if col.v < 0.25:
		m.albedo_color = Color(0.13, 0.13, 0.15)
		m.metallic = 0.7
		m.roughness = 0.25
	var parts := [
		[CylinderMesh.new(), Vector3(0, 0.05, 0), {"top_radius": 0.26, "bottom_radius": 0.28, "height": 0.1}],
		[CylinderMesh.new(), Vector3(0, 0.33, 0), {"top_radius": 0.1, "bottom_radius": 0.22, "height": 0.48}],
		[CylinderMesh.new(), Vector3(0, 0.58, 0), {"top_radius": 0.15, "bottom_radius": 0.15, "height": 0.05}],
		[SphereMesh.new(), Vector3(0, 0.76, 0), {"radius": 0.16, "height": 0.32}],
	]
	for pr in parts:
		var mesh: PrimitiveMesh = pr[0]
		for k in pr[2]:
			mesh.set(k, pr[2][k])
		mesh.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = pr[1]
		root.add_child(mi)
	return root


func _ring(col: Color, r: float, w: float) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r - w
	t.outer_radius = r
	t.rings = 32
	t.ring_segments = 8
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	t.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _tile(path: String, size: float, thick := 0.05, back := "") -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = Vector3(size, thick, size)
	var side := StandardMaterial3D.new()
	side.albedo_color = Color("#d8d4c4")
	bm.material = side
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	var top := PlaneMesh.new()
	top.size = Vector2(size * 0.98, size * 0.98)
	var m := StandardMaterial3D.new()
	m.albedo_texture = UI.tex(path)
	m.roughness = 0.6
	top.material = m
	var ti := MeshInstance3D.new()
	ti.mesh = top
	ti.position.y = thick / 2 + 0.002
	ti.name = "faccia"
	mi.add_child(ti)
	return mi


func _set_tile_tex(t: MeshInstance3D, path: String) -> void:
	var f: MeshInstance3D = t.get_node("faccia")
	var m: StandardMaterial3D = (f.mesh as PlaneMesh).material
	m.albedo_texture = UI.tex(path)


func _label3d(text: String, size := 48, col := Color.WHITE) -> Label3D:
	UI.init_fonts()
	var l := Label3D.new()
	l.text = text
	l.font = UI.font_head
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l


# ================================================================ telecamera e input

func _update_cam() -> void:
	pivot.position = target
	pivot.rotation = Vector3(pitch, yaw, 0)
	cam.position = Vector3(0, 0, dist)


func focus(p: Vector3, d := -1.0) -> void:
	target_goal = Vector3(p.x, 0, p.z)
	if d > 0:
		dist = d


func focus_node(n: int, d := -1.0) -> void:
	if n >= 0:
		focus(Mappa.world(n), d)


func reset_view() -> void:
	target_goal = Vector3(1.5, 0, 1.0)
	yaw = 0.0
	pitch = -1.22
	dist = 38.0


func _process(dt: float) -> void:
	_t += dt
	target = target.lerp(target_goal, minf(1.0, dt * 5.0))
	_update_cam()
	for s in pawns:
		var n: Node3D = pawns[s]
		var path: Array = pawn_path[s]
		var goal: Vector3 = pawn_goal[s]
		if not path.is_empty():
			goal = path[0]
			if n.position.distance_to(goal) < 0.08:
				path.pop_front()
		var sp := 9.0 if path.size() > 0 else 6.0
		n.position = n.position.move_toward(goal, dt * sp) if n.position.distance_to(goal) > 0.01 else goal
		n.position.y = 0.0 + (0.18 * sin(_t * 6.0) if s == eng.cur and not eng.over else 0.0) * 0.4
	if is_instance_valid(_cur_ring) and pawns.has(eng.cur):
		var pp: Vector3 = pawns[eng.cur].position
		_cur_ring.position = Vector3(pp.x, 0.03, pp.z)
		var k := 1.0 + 0.1 * sin(_t * 4.0)
		_cur_ring.scale = Vector3(k, 1, k)
	for c in hl_root.get_children():
		if c is MeshInstance3D:
			var k2 := 1.0 + 0.12 * sin(_t * 5.0)
			c.scale = Vector3(k2, 1, k2)


func _over_gui(sp: Vector2) -> bool:
	var c := get_viewport().gui_get_hovered_control()
	if c == null:
		return false
	return c.get_global_rect().has_point(sp) and c.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _gui_at(sp: Vector2) -> bool:
	if gui_hit.is_valid():
		return gui_hit.call(sp)
	return _over_gui(sp)


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or input_locked:
		_drag = false
		_touches.clear()
		return
	# tocco (iPad): un dito sposta, due dita pizzicano e ruotano, un tocco breve seleziona
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if _touches.is_empty() and _gui_at(ev.position):
				return
			_touches[ev.index] = ev.position
			if _touches.size() == 1:
				_touch_moved = 0.0
				_touch_start = ev.position
		else:
			if _touches.has(ev.index):
				_touches.erase(ev.index)
				if _touches.is_empty() and _touch_moved < 14.0 and ev.position.distance_to(_touch_start) < 18.0:
					_click(ev.position)
		return
	if ev is InputEventScreenDrag:
		if not _touches.has(ev.index):
			return
		var old: Vector2 = _touches[ev.index]
		_touch_moved += ev.relative.length()
		if _touches.size() == 1:
			_pan(ev.position - old)
		else:
			var other := Vector2.ZERO
			for k in _touches:
				if k != ev.index:
					other = _touches[k]
			var d0 := old.distance_to(other)
			var d1: float = ev.position.distance_to(other)
			if d0 > 1.0:
				dist = clampf(dist * d0 / maxf(d1, 1.0), DIST_MIN, DIST_MAX)
			var a0 := (old - other).angle()
			var a1: float = (ev.position - other).angle()
			yaw += wrapf(a1 - a0, -PI, PI)
			_pan((ev.position - old) * 0.5)
		_touches[ev.index] = ev.position
		return
	if ev is InputEventMagnifyGesture:
		if not _over_gui(ev.position):
			dist = clampf(dist / ev.factor, DIST_MIN, DIST_MAX)
		return
	if ev is InputEventPanGesture:
		if not _over_gui(ev.position):
			_pan(-ev.delta * 12.0)
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		match ev.keycode:
			KEY_Q:
				yaw += 0.26
			KEY_E:
				yaw -= 0.26
			KEY_LEFT:
				_pan(Vector2(80, 0))
			KEY_RIGHT:
				_pan(Vector2(-80, 0))
			KEY_UP:
				_pan(Vector2(0, 80))
			KEY_DOWN:
				_pan(Vector2(0, -80))
			KEY_EQUAL, KEY_KP_ADD:
				dist = clampf(dist * 0.85, DIST_MIN, DIST_MAX)
			KEY_MINUS, KEY_KP_SUBTRACT:
				dist = clampf(dist * 1.18, DIST_MIN, DIST_MAX)
		return
	# il mouse emulato dal tocco si ignora: il tocco ha già i suoi comandi
	if ev is InputEventMouse and ev.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if ev is InputEventMouseButton:
		if ev.pressed and _over_gui(ev.position):
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = clampf(dist * 0.9, DIST_MIN, DIST_MAX)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = clampf(dist * 1.1, DIST_MIN, DIST_MAX)
		elif ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if ev.pressed:
				_drag = true
				_drag_btn = ev.button_index
				_moved = 0.0
			elif _drag and ev.button_index == _drag_btn:
				_drag = false
				if ev.button_index == MOUSE_BUTTON_LEFT and _moved < 7.0 and not _over_gui(ev.position):
					_click(ev.position)
	elif ev is InputEventMouseMotion:
		if _drag and ev.button_mask == 0:
			_drag = false
		if _drag:
			_moved += ev.relative.length()
			if _moved > 5.0:
				if _drag_btn == MOUSE_BUTTON_RIGHT or (_drag_btn == MOUSE_BUTTON_LEFT and ev.shift_pressed):
					yaw -= ev.relative.x * 0.006
					pitch = clampf(pitch - ev.relative.y * 0.005, -1.52, -0.3)
				else:
					_pan(ev.relative)
		elif not _over_gui(ev.position):
			_hover(ev.position)


func _pan(rel: Vector2) -> void:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var k := dist * 0.0013
	target_goal += (-right * rel.x + fwd * rel.y) * k
	target_goal.y = 0.0
	target_goal.x = clampf(target_goal.x, -17.0, 17.0)
	target_goal.z = clampf(target_goal.z, -16.0, 16.0)


func _ray_plane(sp: Vector2, h := 0.0) -> Variant:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if absf(d.y) < 1e-4:
		return null
	var t := (h - o.y) / d.y
	if t < 0:
		return null
	return o + d * t


func _node_at(sp: Vector2) -> int:
	var p = _ray_plane(sp)
	if p == null:
		return -1
	# i punti evidenziati hanno la precedenza
	var best := -1
	var bd := 0.75
	for n in hl_steps:
		var w := Mappa.world(n)
		var d := Vector2(w.x - p.x, w.z - p.z).length()
		if d < bd:
			bd = d
			best = n
	if best >= 0:
		return best
	return Mappa.nearest(p, 0.5)


func _hover(sp: Vector2) -> void:
	var n := _node_at(sp)
	if n != hover_n:
		hover_n = n
		_hover_ring.visible = n >= 0
		if n >= 0:
			var w := Mappa.world(n)
			_hover_ring.position = Vector3(w.x, 0.04, w.z)
		hovered_node.emit(n)


func _click(sp: Vector2) -> void:
	var n := _node_at(sp)
	if n >= 0:
		picked_node.emit(n)
		return
	var p = _ray_plane(sp)
	if p == null:
		return
	for sy in Mappa.inhabited():
		var b := Mappa.box_world(sy)
		if absf(b.x - p.x) < 0.75 and absf(b.z - p.z) < 0.75:
			picked_box.emit(sy)
			return


# ================================================================ stato

func _pawn_pos(s: int, n: int) -> Vector3:
	var w := Mappa.world(n)
	var same := []
	for k in eng.players.size():
		if eng.players[k]["pos"] == n:
			same.append(k)
	var i := same.find(s)
	if same.size() > 1 and i >= 0:
		var a := TAU * float(i) / float(same.size())
		w += Vector3(cos(a), 0, sin(a)) * 0.32
	return w


func move_pawn(s: int, path_nodes: Array) -> void:
	var pts := []
	for n in path_nodes:
		pts.append(Mappa.world(n))
	pawn_path[s] = pts
	pawn_goal[s] = _pawn_pos(s, eng.players[s]["pos"])


func refresh() -> void:
	for s in eng.players.size():
		if pawn_path[s].is_empty():
			pawn_goal[s] = _pawn_pos(s, eng.players[s]["pos"])
	_refresh_q()
	_refresh_builds()
	_refresh_cultures()


func _refresh_q() -> void:
	for n in eng.qbox:
		var q: Dictionary = eng.qbox[n]
		var path := "res://assets/tokens/q_retro.jpg"
		if q["up"]:
			path = token_path(q["m"])
			if q["m"]["t"] == "relic" and q["taken"]:
				path = ""
		if not q_nodes.has(n):
			var t := _tile("res://assets/tokens/q_retro.jpg", Q * 0.92, 0.06)
			var w := Mappa.world(n)
			t.position = Vector3(w.x, 0.03, w.z)
			add_child(t)
			q_nodes[n] = [t, ""]
		var rec: Array = q_nodes[n]
		var t: MeshInstance3D = rec[0]
		t.visible = path != ""
		if path != "" and rec[1] != path:
			_set_tile_tex(t, path)
			rec[1] = path


static func token_path(m: Dictionary) -> String:
	match m["t"]:
		"relic":
			return "res://assets/tokens/reliquia_%s.png" % m["r"]
		"open":
			return "res://assets/tokens/porto_aperto.png"
		"gate":
			return "res://assets/tokens/porta_%d.png" % int(m["n"])
		"pen":
			return "res://assets/tokens/pen_%s%d.jpg" % [m["c"], int(m["v"])]
	return "res://assets/tokens/q_retro.jpg"


func _refresh_builds() -> void:
	var want := {}
	for o in eng.ports:
		want["p%d" % o] = [o, "porto", eng.ports[o]]
	for c in eng.factories:
		want["f" + c] = [eng.factories[c]["n"], "fabbrica", eng.factories[c]["o"]]
	for k in want:
		if build_nodes.has(k):
			continue
		var info: Array = want[k]
		var m: String = D.MERCHANTS[eng.players[info[2]]["m"]]["id"]
		var t := _tile("res://assets/tokens/%s_%s.jpg" % [info[1], m], 0.5, 0.08)
		var w := Mappa.world(info[0])
		var off := Vector3(0.36, 0.06, -0.36) if info[1] == "fabbrica" else Vector3(-0.3, 0.06, -0.34)
		t.position = w + off
		add_child(t)
		build_nodes[k] = t


func _refresh_cultures() -> void:
	for c in stock_root.get_children():
		c.queue_free()
	for sy in Mappa.inhabited():
		var c: String = eng.sys_cult[sy]
		var b := Mappa.box_world(sy)
		var shown := c if eng.cult[c]["disc"] else ""
		if shown == "" and viewer >= 0 and eng.players[viewer]["obs"].has(sy):
			shown = c
		var path := "res://assets/tokens/cultura_%s.png" % shown if shown != "" else "res://assets/tokens/iou_retro.png"
		if not cult_nodes.has(sy):
			var t := _tile(path, 1.12, 0.08)
			t.position = b + Vector3(0, 0.05, 0)
			add_child(t)
			cult_nodes[sy] = [t, path]
		var rec: Array = cult_nodes[sy]
		if rec[1] != path:
			_set_tile_tex(rec[0], path)
			rec[1] = path
		var tile: MeshInstance3D = rec[0]
		var mat: StandardMaterial3D = ((tile.get_node("faccia") as MeshInstance3D).mesh as PlaneMesh).material
		mat.albedo_color = Color(1, 1, 1) if eng.cult[c]["disc"] else Color(0.72, 0.72, 0.78)
		if not eng.cult[c]["disc"]:
			continue
		# merci, merci di fabbrica, bonus e reliquie accanto al riquadro
		var items := []
		if eng.cult[c]["stock"] > 0:
			items.append(["res://assets/tokens/merci_%s.png" % c, "x%d" % eng.cult[c]["stock"]])
		if eng.cult[c]["fg"]:
			items.append(["res://assets/tokens/fabbr_%s.png" % c, ""])
		for bi in eng.cult[c]["bon"]:
			items.append(["res://assets/tokens/bonus_%d.png" % bi, ""])
		for r in eng.cult[c]["sun"]:
			items.append(["res://assets/tokens/reliquia_%s.png" % r, ""])
		_stack_row(b, items)
	if not eng.base_bon.is_empty():
		var items2 := []
		for bi in eng.base_bon:
			items2.append(["res://assets/tokens/bonus_%d.png" % bi, ""])
		_stack_row(Mappa.world(Mappa.base_node) + Vector3(0, 0, 1.7), items2)


func _stack_row(b: Vector3, items: Array) -> void:
	var cols := 4
	for i in items.size():
		var t := _tile(items[i][0], 0.52, 0.04)
		var row := i / cols
		var col := i % cols
		t.position = b + Vector3(-0.84 + col * 0.56, 0.04, 0.9 + row * 0.56)
		stock_root.add_child(t)
		if items[i][1] != "":
			var l := _label3d(items[i][1], 40, UI.GOLD)
			l.position = t.position + Vector3(0.2, 0.25, 0.2)
			stock_root.add_child(l)


## Evidenzia le mosse possibili: anelli sui punti d'arrivo con il costo in PM
func show_steps(steps: Array, land_at := -1) -> void:
	clear_steps()
	for st in steps:
		var n: int = st["to"]
		if hl_steps.has(n):
			continue
		hl_steps[n] = st
		var w := Mappa.world(n)
		var col := UI.CYAN if not st.get("gate", false) else UI.GOLD
		var r := _ring(col, 0.42, 0.08)
		r.position = Vector3(w.x, 0.05, w.z)
		hl_root.add_child(r)
		var l := _label3d("%d PM" % int(st["cost"]) if int(st["cost"]) > 0 else "gratis", 38, col)
		l.position = Vector3(w.x, 0.7, w.z)
		hl_root.add_child(l)
	if land_at >= 0:
		var w2 := Mappa.world(land_at)
		var r2 := _ring(UI.GREEN, 0.55, 0.09)
		r2.position = Vector3(w2.x, 0.05, w2.z)
		hl_root.add_child(r2)


func clear_steps() -> void:
	hl_steps = {}
	for c in hl_root.get_children():
		c.queue_free()


func show_trail(path: Array) -> void:
	for c in trail_root.get_children():
		c.queue_free()
	if path.size() < 2:
		return
	var im := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.25, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, m)
	for i in path.size() - 1:
		var a := Mappa.world(path[i]) + Vector3(0, 0.06, 0)
		var b := Mappa.world(path[i + 1]) + Vector3(0, 0.06, 0)
		var dir := (b - a)
		if dir.length() < 0.01:
			continue
		var side := Vector3(-dir.z, 0, dir.x).normalized() * 0.06
		im.surface_add_vertex(a - side)
		im.surface_add_vertex(a + side)
		im.surface_add_vertex(b + side)
		im.surface_add_vertex(a - side)
		im.surface_add_vertex(b + side)
		im.surface_add_vertex(b - side)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_root.add_child(mi)


## Posizione sullo schermo di un punto (per i messaggi che compaiono sulla mappa)
func screen_pos(n: int) -> Vector2:
	var w := Mappa.world(n)
	if cam.is_position_behind(w):
		return Vector2(-1000, -1000)
	return cam.unproject_position(w)
