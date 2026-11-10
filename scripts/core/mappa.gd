class_name Mappa
extends RefCounted
## La mappa del Cluster: punti di movimento, collegamenti, cerchi di navigazione, sistemi.
## Ricavata dal tabellone originale (assets/data/mappa.json): ogni punto ha il tipo, la posizione
## sul tabellone (0..1), il colore (r, y, b), la penalità degli ovali e il sistema a cui appartiene.

## Dimensioni del tabellone nel mondo 3D (unità)
const W := 32.0
const H := 29.77

static var _data := {}
static var nodes: Array = []
static var adj: Array = []          # elenco dei vicini per punto
static var systems: Array = []
static var sys_index := {}
static var foil: Array = []         # gruppi di città sullo stesso pianeta
static var foil_adj := {}           # città -> altre città dello stesso pianeta
static var base_node := -1
static var orbits_of := {}          # sistema -> [punti orbita]
static var places_of := {}          # sistema -> [città, città spaziali]
static var qboxes: Array = []


static func load_map() -> void:
	if not nodes.is_empty():
		return
	var f := FileAccess.open("res://assets/data/mappa.json", FileAccess.READ)
	_data = JSON.parse_string(f.get_as_text())
	nodes = _data["nodes"]
	for n in nodes:
		n["i"] = int(n["i"])
		if n.has("p"):
			n["p"] = int(n["p"])
		if n.has("ex"):
			var ex := {}
			for k in n["ex"]:
				ex[int(k)] = int(n["ex"][k])
			n["ex"] = ex
		if n.has("j"):
			n["j"] = int(n["j"])
	adj = []
	for i in nodes.size():
		adj.append([])
	for e in _data["edges"]:
		var a := int(e[0])
		var b := int(e[1])
		adj[a].append(b)
		adj[b].append(a)
	systems = _data["systems"]
	for i in systems.size():
		sys_index[systems[i]["id"]] = i
	foil = _data["foil"]
	for grp in foil:
		for c in grp:
			var o := []
			for d in grp:
				if int(d) != int(c):
					o.append(int(d))
			foil_adj[int(c)] = o
	for n in nodes:
		var s: String = n["s"]
		match n["k"]:
			"base":
				base_node = n["i"]
			"orbit":
				if not orbits_of.has(s):
					orbits_of[s] = []
				orbits_of[s].append(n["i"])
			"nav":
				if n.has("o"):
					if not orbits_of.has(s):
						orbits_of[s] = []
					orbits_of[s].append(n["i"])
			"city", "scity":
				if not places_of.has(s):
					places_of[s] = []
				places_of[s].append(n["i"])
			"qbox":
				qboxes.append(n["i"])


static func kind(i: int) -> String:
	return nodes[i]["k"]


static func sys(i: int) -> String:
	return nodes[i]["s"]


static func is_orbit(i: int) -> bool:
	return nodes[i].has("o")


static func orbit_name(i: int) -> String:
	return str(nodes[i].get("o", ""))


static func world(i: int) -> Vector3:
	var n: Dictionary = nodes[i]
	return Vector3((float(n["x"]) - 0.5) * W, 0.0, (float(n["y"]) - 0.5) * H)


static func board_xy(i: int) -> Vector2:
	return Vector2(float(nodes[i]["x"]), float(nodes[i]["y"]))


static func sys_name(s: String) -> String:
	if s == "":
		return "spazio aperto"
	return systems[sys_index[s]]["nome"]


static func box_world(s: String) -> Vector3:
	var b = systems[sys_index[s]]["box"]
	if b == null:
		return Vector3.ZERO
	return Vector3((float(b[0]) - 0.5) * W, 0.0, (float(b[1]) - 0.5) * H)


## Sistemi abitati (con un riquadro Cultura)
static func inhabited() -> Array:
	var out := []
	for s in systems:
		if s["box"] != null:
			out.append(s["id"])
	return out


## Punto più vicino a una posizione del mondo (entro raggio), -1 se nessuno
static func nearest(p: Vector3, radius := 0.6) -> int:
	var best := -1
	var bd := radius
	for n in nodes:
		var w := world(n["i"])
		var d := Vector2(w.x - p.x, w.z - p.z).length()
		if d < bd:
			bd = d
			best = n["i"]
	return best
