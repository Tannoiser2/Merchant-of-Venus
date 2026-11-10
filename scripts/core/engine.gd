class_name MoVEngine
extends Node
## Motore di Merchant of Venus (Avalon Hill, 1988), gioco base.
## Ogni mercante muove la sua nave lungo i sentieri del Cluster tirando i dadi, scopre le culture
## nascoste, compra merci dove costano poco e le vende dove le pagano, trasporta passeggeri,
## costruisce spazioporti e fabbriche. Vince chi a fine turno ha un patrimonio (denaro + atti)
## pari almeno all'obiettivo.
## Tutte le scelte passano da decide(): giocatori umani (interfaccia), IA, partite online e
## salvataggi usano lo stesso registro di decisioni; il caso dipende solo dal seme della partita.

const D = preload("res://scripts/data/mov_data.gd")

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(result: Dictionary)
signal fx(kind: String, data: Dictionary)

# ---------------------------------------------------------------- configurazione
var cfg := {}
var players: Array = []      # stato dei giocatori
var ais: Array = []
var online = null
var ai_delay := 0.5
var headless := false
var abort := false
var rng := RandomNumberGenerator.new()
var goal := 2000

# ---------------------------------------------------------------- stato
var sys_cult := {}           # sistema -> cultura che lo abita
var cult := {}               # cultura -> {sys, disc, stock, fg, bon:[], sun:[]}
var base_bon: Array = []     # bonus alla Base Galattica
var cup: Array = []          # bicchiere: {t:"b", i} / {t:"g", c} / {t:"f", c}
var bon_list: Array = []     # i 48 bonus
var qbox := {}               # punto -> {m: segnalino, up, taken}
var ports := {}              # orbita -> proprietario
var factories := {}          # cultura -> {o: proprietario, n: punto}
var bank := {}               # equipaggiamento rimasto in banca
var turn := 0
var cur := 0                 # giocatore di turno
var phase := ""
var over := false
var result := {}
var log_lines: Array = []
var rec_acts: Array = []
var preload_acts: Array = []
var pre_i := 0
var ms := {}                 # movimento in corso (per la vista)
var trade := {}              # commercio in corso (per la vista)


# ================================================================ preparazione

func setup(c: Dictionary) -> void:
	Mappa.load_map()
	cfg = c
	if c.has("seed"):
		rng.seed = int(c["seed"])
	else:
		rng.randomize()
	ai_delay = float(c.get("ai_delay", 0.5))
	goal = int(c.get("goal", 2000))
	var seats: Array = c.get("seats", [])
	var np := seats.size()
	players = []
	for i in np:
		var st: Dictionary = seats[i]
		var m: int = int(st.get("merchant", i))
		var p := {
			"name": str(st.get("name", D.MERCHANTS[m]["nome"])),
			"ai": bool(st.get("ai", false)),
			"level": int(st.get("level", 1)),
			"m": m,
			"own": D.MERCHANTS[m]["c"],
			"money": 20 * np,
			"ship": "scout",
			"cargo": [],
			"ports": [],
			"facts": [],
			"ious": [],
			"pos": Mappa.base_node,
			"obs": {},
			"qk": {},
			"credit": 0,
			"moved": false,
			"buys": 0,
			"sells": 0,
		}
		players.append(p)
		ais.append(MoVAI.new(int(p["level"])))
	# culture nei sistemi, a caso (i pagherò coperti nei riquadri Cultura)
	var ids: Array = D.CULT_IDS.duplicate()
	_shuffle(ids)
	var inh := Mappa.inhabited()
	for i in inh.size():
		sys_cult[inh[i]] = ids[i]
	for cid in D.CULT_IDS:
		var s := ""
		for k in sys_cult:
			if sys_cult[k] == cid:
				s = k
		cult[cid] = {"sys": s, "disc": false, "stock": int(D.CULTURES[cid]["gq"]), "fg": false, "bon": [], "sun": []}
	# segnalini "?"
	var qm := D.qmarkers()
	_shuffle(qm)
	var qb: Array = Mappa.qboxes.duplicate()
	for i in qb.size():
		qbox[int(qb[i])] = {"m": qm[i], "up": false, "taken": false}
	# bonus nel bicchiere
	bon_list = D.bonuses()
	for i in bon_list.size():
		cup.append({"t": "b", "i": i})
	for e in D.EQUIP:
		bank[e] = int(D.EQUIP[e]["q"])


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func d6() -> int:
	return rng.randi_range(1, 6)


func pname(s: int) -> String:
	return str(players[s]["name"])


func log_msg(t: String) -> void:
	log_lines.append(t)
	log_added.emit(t)


# ================================================================ decisioni

func decide(seat: int, req: Dictionary):
	req["seat"] = seat
	req["turn"] = turn
	if abort:
		return ais[seat].decide(self, seat, req)
	if online != null:
		changed.emit()
		var r0 = await online.decide(self, seat, req)
		rec_acts.append(r0)
		return r0
	if pre_i < preload_acts.size():
		var rp = preload_acts[pre_i]
		pre_i += 1
		rec_acts.append(rp)
		return rp
	changed.emit()
	var r = null
	if players[seat]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay * (0.5 if req["k"] == "trade" else 1.0)).timeout
		r = ais[seat].decide(self, seat, req)
	else:
		decision_requested.emit(req)
		r = await decision_provided
		if r == null:
			r = ais[seat].decide(self, seat, req)
	rec_acts.append(r)
	return r


func replaying() -> bool:
	return pre_i < preload_acts.size()


func provide_decision(r) -> void:
	decision_provided.emit(r)


func humans() -> int:
	var n := 0
	for p in players:
		if not p["ai"]:
			n += 1
	return n


func fingerprint() -> String:
	var parts := []
	for p in players:
		parts.append("%d/%d/%s/%d" % [p["money"], p["pos"], p["ship"], p["cargo"].size()])
	return "%d|%s|%d" % [turn, ",".join(parts), cup.size()]


# ================================================================ informazioni

func culture_at(n: int) -> String:
	## La cultura con cui si commercia in un punto ("" se non si commercia lì)
	var k := Mappa.kind(n)
	if k == "base":
		return "base"
	var s := Mappa.sys(n)
	if s == "" or not sys_cult.has(s):
		return ""
	if k in ["city", "scity"]:
		return sys_cult[s]
	if Mappa.is_orbit(n) and ports.has(n):
		return sys_cult[s]
	if k == "qbox" and qbox[n]["up"] and qbox[n]["m"]["t"] == "open":
		return sys_cult[s]
	return ""


func is_port(n: int) -> bool:
	if Mappa.is_orbit(n) and ports.has(n):
		return true
	return Mappa.kind(n) == "qbox" and qbox[n]["up"] and qbox[n]["m"]["t"] == "open"


func is_open_port(n: int) -> bool:
	return Mappa.kind(n) == "qbox" and qbox[n]["up"] and qbox[n]["m"]["t"] == "open"


func landable(n: int) -> bool:
	var k := Mappa.kind(n)
	if k in ["city", "scity", "base", "asteroid"]:
		return true
	if is_port(n):
		return true
	if k == "qbox" and qbox[n]["up"] and qbox[n]["m"]["t"] == "relic":
		return true
	return false


func penalty_at(n: int) -> Dictionary:
	var k := Mappa.kind(n)
	if k == "oval":
		return {"c": Mappa.nodes[n]["c"], "v": int(Mappa.nodes[n]["p"])}
	if k == "qbox" and qbox[n]["up"] and qbox[n]["m"]["t"] == "pen":
		return {"c": qbox[n]["m"]["c"], "v": int(qbox[n]["m"]["v"])}
	return {}


func color_at(n: int, glock := false) -> String:
	var k := Mappa.kind(n)
	if k in ["dot", "oval"]:
		return str(Mappa.nodes[n]["c"])
	if k == "qbox" and qbox[n]["up"]:
		var m: Dictionary = qbox[n]["m"]
		if m["t"] == "pen":
			return str(m["c"])
		if m["t"] == "gate" and glock:
			return "b"
	return ""


func is_gate(n: int) -> bool:
	return Mappa.kind(n) == "qbox" and qbox[n]["up"] and qbox[n]["m"]["t"] == "gate"


func gate_num(n: int) -> int:
	return int(qbox[n]["m"]["n"]) if is_gate(n) else 0


func gate_with(num: int) -> int:
	for q in qbox:
		if is_gate(q) and gate_num(q) == num:
			return q
	return -1


func has_relic(s: int, r: String) -> bool:
	for it in players[s]["cargo"]:
		if it["t"] == "r" and it["r"] == r:
			return true
	return false


func has_eq(s: int, e: String) -> int:
	var n := 0
	for it in players[s]["cargo"]:
		if it["t"] == "e" and it["e"] == e:
			n += 1
	return n


func shields(s: int) -> int:
	return has_eq(s, "shield") + (1 if has_relic(s, "shield") else 0)


## Colori che i propulsori fanno saltare: "r", "y"
func drives(s: int) -> Array:
	var out := []
	if has_eq(s, "rdrive") > 0 or has_eq(s, "cdrive") > 0:
		out.append("r")
	if has_eq(s, "ydrive") > 0 or has_eq(s, "cdrive") > 0 or has_relic(s, "ydrive"):
		out.append("y")
	return out


func ship(s: int) -> Dictionary:
	return D.SHIPS[players[s]["ship"]]


## Spazio usato in mezze stive: merci 2, equipaggiamento e passeggeri 1; il primo scudo sta sullo scafo,
## le reliquie sullo scafo.
func used_space(s: int, cargo := []) -> int:
	if cargo.is_empty():
		cargo = players[s]["cargo"]
	var u := 0
	var hull_shield := false
	for it in cargo:
		match it["t"]:
			"g", "f":
				u += 2
			"fare":
				u += 1
			"e":
				if it["e"] == "shield" and not hull_shield:
					hull_shield = true
				else:
					u += 1
	return u


func capacity(s: int, ship_id := "") -> int:
	if ship_id == "":
		ship_id = players[s]["ship"]
	return int(D.SHIPS[ship_id]["stive"]) * 2


func fits(s: int, item: Dictionary) -> bool:
	if item["t"] == "r":
		return true
	var c: Array = players[s]["cargo"].duplicate()
	c.append(item)
	return used_space(s, c) <= capacity(s)


func deed_value(kind: String, key) -> int:
	if kind == "port":
		return D.PORT_COST
	return int(D.CULTURES[key]["f"])


func net_worth(s: int) -> int:
	var p: Dictionary = players[s]
	var v: int = p["money"]
	v += p["ports"].size() * D.PORT_COST
	for c in p["facts"]:
		v += int(D.CULTURES[c]["f"])
	return v


func knows(s: int, sys_id: String) -> String:
	## Cultura del sistema se scoperta o osservata dal giocatore, altrimenti ""
	if not sys_cult.has(sys_id):
		return ""
	var c: String = sys_cult[sys_id]
	if cult[c]["disc"] or players[s]["obs"].has(sys_id):
		return c
	return ""


func item_name(it: Dictionary) -> String:
	match it["t"]:
		"g":
			return "%s (%s)" % [D.CULTURES[it["c"]]["g"], it["c"]]
		"f":
			return "%s (fabbrica %s)" % [D.CULTURES[it["c"]]["fg"], it["c"]]
		"e":
			return D.EQUIP[it["e"]]["nome"]
		"fare":
			return D.fare_text(bon_list[it["b"]])
		"r":
			return D.RELICS[it["r"]]["nome"]
	return "?"


func q_name(m: Dictionary) -> String:
	match m["t"]:
		"relic":
			return "Reliquia: " + D.RELICS[m["r"]]["nome"]
		"open":
			return "Spazioporto aperto"
		"gate":
			return "Porta tele %d" % int(m["n"])
		"pen":
			return "Penalità %s $%d" % [{"r": "rossa", "y": "gialla", "b": "blu"}[m["c"]], int(m["v"])]
	return "?"


# ================================================================ partita

func run() -> void:
	phase = "inizio"
	log_msg("Merchant of Venus: vince chi arriva per primo a un patrimonio di $%d." % goal)
	log_msg("Tutti partono dalla Base Galattica con un Esploratore e $%d." % players[0]["money"])
	fx.emit("start", {})
	turn = 0
	cur = 0
	while not over and not abort:
		turn += 1
		for s in players.size():
			cur = s
			await _player_turn(s)
			if over or abort:
				break
		if not over and turn >= int(cfg.get("max_turns", 150)):
			var best := 0
			for s in players.size():
				if net_worth(s) > net_worth(best):
					best = s
			over = true
			result = {"winner": best, "nw": net_worth(best), "time": true}
			log_msg("Tempo scaduto: vince %s con un patrimonio di $%d." % [pname(best), net_worth(best)])
	if abort:
		return
	phase = "fine"
	changed.emit()
	game_ended.emit(result)


func _player_turn(s: int) -> void:
	var p: Dictionary = players[s]
	var arrived: bool = p["moved"]
	p["credit"] = 0
	p["buys"] = 0
	p["sells"] = 0
	p["moved"] = false
	phase = "turno"
	log_msg("— Turno %d: %s —" % [turn, pname(s)])
	fx.emit("turn", {"s": s})
	var at: int = p["pos"]
	var stayed := false
	var land_ok := landable(at)
	# inizio turno: restare fermi (soggiorno prolungato) o partire, scelte prima del tiro
	var pre = await decide(s, {"k": "pre", "can_stay": land_ok, "trade": culture_at(at) != "", "arrived": arrived,
		"auto": has_relic(s, "autopilot"), "glock": has_relic(s, "gatelock"),
		"jump": has_relic(s, "jumpstart"), "drives": drives(s)})
	if abort:
		return
	if not (pre is Dictionary):
		pre = {}
	if pre.get("stay", false) and land_ok:
		stayed = true
		log_msg("%s resta fermo a %s." % [pname(s), place_name(at)])
	else:
		await _movement(s, pre)
		if abort or over:
			return
	# commercio
	var here: int = p["pos"]
	if ms.get("landed", false) or stayed or (not ms.get("stopped_pen", false) and landable(here)):
		await _trading(s, stayed)
	if abort:
		return
	ms = {}
	trade = {}
	p["credit"] = 0
	_check_win(s)
	changed.emit()


func place_name(n: int) -> String:
	var k := Mappa.kind(n)
	var s := Mappa.sys(n)
	if k == "base":
		return "Base Galattica"
	if Mappa.is_orbit(n):
		return ("spazioporto " if is_port(n) else "orbita ") + Mappa.orbit_name(n)
	match k:
		"city":
			return "città di superficie (%s)" % Mappa.sys_name(s)
		"scity":
			return "città spaziale (%s)" % Mappa.sys_name(s)
		"asteroid":
			return "asteroide"
		"qbox":
			return ("asteroide" if not qbox[n]["up"] or qbox[n]["m"]["t"] == "relic" else q_name(qbox[n]["m"]))
		"nav":
			return "cerchio di navigazione"
		"oval":
			return "ovale di penalità"
	return "spazio"


# ================================================================ movimento

func _movement(s: int, pre: Dictionary) -> void:
	var p: Dictionary = players[s]
	var nd: int = int(ship(s)["dadi"])
	var auto: bool = pre.get("auto", false) and has_relic(s, "autopilot")
	var dice := []
	for k in (nd - 1 if auto else nd):
		dice.append(d6())
	if auto:
		dice.append(4)
	var off: Array = pre.get("off", [])
	var drv := []
	for c in drives(s):
		if not c in off:
			drv.append(c)
	ms = {"s": s, "cur": p["pos"], "start": p["pos"], "dice": dice, "mp": 0, "pilot": -1, "used": {},
		"drv": drv, "glock": pre.get("glock", false) and has_relic(s, "gatelock"),
		"jump": pre.get("jump", false) and has_relic(s, "jumpstart"),
		"switch": has_relic(s, "switch"), "foil": has_relic(s, "airfoil"),
		"landed": false, "stopped_pen": false, "path": [p["pos"]], "first": true, "auto": auto}
	log_msg("%s tira %s%s." % [pname(s), _dice_str(dice), " (pilota automatico)" if auto else ""])
	fx.emit("dice", {"s": s, "dice": dice.duplicate()})
	if has_relic(s, "mulligan"):
		var r = await decide(s, {"k": "mull", "dice": dice.duplicate(), "auto": auto})
		if abort:
			return
		if r is int and r >= 0 and r < dice.size():
			var nv := d6()
			log_msg("Ingranaggio della seconda possibilità: il %d diventa %d." % [dice[r], nv])
			dice[r] = nv
			ms["dice"] = dice
			fx.emit("dice", {"s": s, "dice": dice.duplicate()})
	var tot := 0
	for d in dice:
		tot += int(d)
	ms["mp"] = tot
	# all'inizio, se si parte da una penalità (non si atterra sulle penalità) si deve muovere
	while not abort:
		changed.emit()
		var steps := legal_steps(ms, s)
		var here: int = ms["cur"]
		var can_land: bool = not ms["first"] and landable(here) and here != ms["start"]
		if ms["mp"] <= 0 or steps.is_empty():
			if steps.is_empty() and ms["mp"] > 0:
				log_msg("%s non può proseguire: perde i PM rimasti." % pname(s))
			break
		var r = await decide(s, {"k": "move", "steps": steps, "land": can_land, "mp": ms["mp"],
			"pilot": ms["pilot"], "dice": dice.duplicate(), "at": here})
		if abort:
			return
		if r is Dictionary and r.get("land", false) and can_land:
			ms["landed"] = true
			log_msg("%s atterra a %s." % [pname(s), place_name(here)])
			break
		var st := _pick_step(steps, r)
		if st.is_empty():
			st = steps[0]
		var stop := await _do_step(s, st, r)
		if abort:
			return
		if stop:
			break
	ms["mp"] = 0
	p["pos"] = ms["cur"]
	p["moved"] = ms["cur"] != ms["start"] or ms["path"].size() > 1
	if landable(ms["cur"]) and not ms["stopped_pen"]:
		ms["landed"] = true
	fx.emit("moved", {"s": s, "path": ms["path"].duplicate()})


func _dice_str(dice: Array) -> String:
	var t := []
	for d in dice:
		t.append(str(d))
	return " ".join(t)


func _pick_step(steps: Array, r) -> Dictionary:
	if not (r is Dictionary):
		return {}
	for st in steps:
		if int(st["to"]) == int(r.get("to", -1)):
			if r.has("pilot") and int(r["pilot"]) >= 0 and not st["pilots"].is_empty() and not int(r["pilot"]) in st["pilots"]:
				continue
			return st
	return {}


## Le mosse possibili dal punto attuale. Ogni mossa: {to, cost, via: punti saltati, pilots: numeri
## pilota che la permettono (vuoto = qualsiasi), gate: salto di porta tele, edges: archi percorsi}
func legal_steps(m: Dictionary, s: int) -> Array:
	var here: int = m["cur"]
	var out := []
	var mp: int = m["mp"]
	var dice_vals := []
	for d in m["dice"]:
		if not int(d) in dice_vals:
			dice_vals.append(int(d))
	var pilot: int = m["pilot"]
	var pilots: Array = dice_vals if (pilot < 0 or m["switch"]) else [pilot]
	var k := Mappa.kind(here)
	var bases := []     # [destinazione, piloti, salto di porta]
	# avvio a salto: prima mossa verso una porta tele scoperta con un numero tirato
	if m.get("first", false) and m.get("jump", false) and not m["glock"]:
		for pv in pilots:
			var g := gate_with(pv)
			if g >= 0 and g != here:
				bases.append([g, [pv], true])
	if k == "nav":
		var ex: Dictionary = Mappa.nodes[here]["ex"]
		var by := {}
		for pv in pilots:
			var t: int = ex.get(int(pv), -1)
			if t < 0:
				continue
			if not by.has(t):
				by[t] = []
			by[t].append(pv)
		for t in by:
			bases.append([t, by[t], false])
	elif is_gate(here) and not m["glock"]:
		var normal := []
		for pv in pilots:
			var g := gate_with(pv)
			if g >= 0 and g != here:
				bases.append([g, [pv], true])
			else:
				normal.append(pv)
		if not normal.is_empty():
			for nb in _neighbors(here, m):
				bases.append([nb, normal, false])
	else:
		for nb in _neighbors(here, m):
			bases.append([nb, [], false])
	for b in bases:
		var t: int = b[0]
		if not b[2] and m["used"].has("%d>%d" % [t, here]):
			continue
		var edges := ["%d>%d" % [here, t]]
		if b[2]:
			edges = []
		# salto dei propulsori (iperspazio) sui punti colorati
		for fin in _expand_skip(here, t, m, [], edges, 0):
			var to: int = fin[0]
			var cost := _step_cost(here, to, m)
			if b[2]:
				cost = 2 if (Mappa.kind(here) == "city" and not m["foil"]) else 1
			if m.get("free", false):
				cost = 0
			if cost > mp:
				continue
			out.append({"to": to, "cost": cost, "via": fin[1], "pilots": b[1], "gate": b[2], "edges": fin[2]})
	return out


func _neighbors(here: int, m: Dictionary) -> Array:
	var out: Array = Mappa.adj[here].duplicate()
	if m["foil"] and Mappa.kind(here) == "city":
		for c in Mappa.foil_adj.get(here, []):
			if not c in out:
				out.append(c)
	return out


func _skippable(n: int, m: Dictionary) -> bool:
	var c := color_at(n, m["glock"])
	if c == "" or not c in m["drv"]:
		return false
	if Mappa.kind(n) == "qbox" and not qbox[n]["up"]:
		return false
	return true


## Restituisce [[destinazione, saltati, archi]] partendo da `frm` verso `t`
func _expand_skip(frm: int, t: int, m: Dictionary, via: Array, edges: Array, depth: int) -> Array:
	if depth > 8 or not _skippable(t, m) or Mappa.kind(t) == "nav":
		return [[t, via, edges]]
	var out := []
	var v2 := via.duplicate()
	v2.append(t)
	for nb in _neighbors(t, m):
		if nb == frm or nb in via:
			continue
		var e := "%d>%d" % [t, nb]
		if m["used"].has("%d>%d" % [nb, t]):
			continue
		var e2 := edges.duplicate()
		e2.append(e)
		out.append_array(_expand_skip(t, nb, m, v2, e2, depth + 1))
	return out


func _step_cost(a: int, b: int, m: Dictionary) -> int:
	if m["foil"]:
		return 1
	if Mappa.kind(a) == "city" or Mappa.kind(b) == "city":
		return 2
	return 1


## Esegue una mossa. Restituisce true se il movimento finisce.
func _do_step(s: int, st: Dictionary, r) -> bool:
	var p: Dictionary = players[s]
	var to: int = st["to"]
	if not st["pilots"].is_empty() and (ms["pilot"] < 0 or ms["switch"] or not ms["pilot"] in st["pilots"]):
		var pv: int = st["pilots"][0]
		if r is Dictionary and int(r.get("pilot", -1)) in st["pilots"]:
			pv = int(r["pilot"])
		if pv != ms["pilot"]:
			ms["pilot"] = pv
			log_msg("Numero pilota: %d." % pv)
	ms["mp"] = int(ms["mp"]) - int(st["cost"])
	for e in st["edges"]:
		ms["used"][e] = true
	ms["first"] = false
	ms.erase("free")
	ms["cur"] = to
	ms["path"].append(to)
	p["pos"] = to
	if st["gate"]:
		log_msg("%s salta alla porta tele %d." % [pname(s), gate_num(to)])
	fx.emit("step", {"s": s, "to": to, "via": st["via"], "gate": st["gate"]})
	# occhio spia: punti saltati e punto d'arrivo
	if has_relic(s, "spyeye"):
		for v in st["via"]:
			_spy(s, v)
		_spy(s, to)
	return await _arrive(s, to)


func _spy(s: int, n: int) -> void:
	var p: Dictionary = players[s]
	for nb in Mappa.adj[n]:
		if Mappa.kind(nb) == "qbox" and not qbox[nb]["up"]:
			p["qk"][nb] = true
	var sy := Mappa.sys(n)
	if sy != "" and sys_cult.has(sy):
		_observe(s, sy)


func _observe(s: int, sy: String) -> void:
	var p: Dictionary = players[s]
	var c: String = sys_cult[sy]
	if cult[c]["disc"] or p["obs"].has(sy):
		return
	p["obs"][sy] = c
	if not p["ai"] and not headless:
		log_msg("%s osserva in segreto la cultura di %s." % [pname(s), Mappa.sys_name(sy)])
	fx.emit("observe", {"s": s, "sys": sy})


func _arrive(s: int, n: int) -> bool:
	var p: Dictionary = players[s]
	# segnalino "?" coperto: si gira
	if Mappa.kind(n) == "qbox" and not qbox[n]["up"]:
		qbox[n]["up"] = true
		var m: Dictionary = qbox[n]["m"]
		log_msg("%s scopre un segnalino \"?\": %s." % [pname(s), q_name(m)])
		fx.emit("reveal", {"n": n})
		if m["t"] == "pen" and str(m["c"]) in ms["drv"]:
			# penalità del colore del propulsore: la si salta subito, senza spendere PM
			log_msg("Il propulsore la salta senza costi.")
			ms["free"] = true
			var steps := legal_steps(ms, s)
			if steps.is_empty():
				ms.erase("free")
				return false
			var r = await decide(s, {"k": "move", "steps": steps, "land": false, "mp": ms["mp"],
				"pilot": ms["pilot"], "dice": ms["dice"].duplicate(), "at": n, "free": true})
			if abort:
				return true
			var st := _pick_step(steps, r)
			if st.is_empty():
				st = steps[0]
			return await _do_step(s, st, r)
	# osservazione dalle orbite (con l'occhio spia da ogni punto del sistema)
	var sy := Mappa.sys(n)
	if sy != "" and sys_cult.has(sy) and (Mappa.is_orbit(n) or has_relic(s, "spyeye")):
		_observe(s, sy)
	# penalità
	var pen := penalty_at(n)
	if not pen.is_empty():
		var amt: int = maxi(0, int(pen["v"]) - 20 * shields(s))
		if ms["mp"] <= 0:
			ms["stopped_pen"] = true
			return true
		if amt == 0:
			return false
		var pay := false
		if p["money"] >= amt:
			var r = await decide(s, {"k": "pen", "amt": amt, "v": pen["v"], "at": n, "mp": ms["mp"]})
			if abort:
				return true
			pay = r == true
		if pay:
			p["money"] -= amt
			log_msg("%s paga $%d di penalità e prosegue." % [pname(s), amt])
			fx.emit("money", {"s": s, "d": -amt})
		else:
			ms["stopped_pen"] = true
			log_msg("%s si ferma sulla penalità per non pagare." % pname(s))
			return true
	return false


# ================================================================ commercio

func _trading(s: int, stayed: bool) -> void:
	var p: Dictionary = players[s]
	var n: int = p["pos"]
	var c := culture_at(n)
	# scoperta
	if c != "" and c != "base" and not cult[c]["disc"]:
		_discover(s, c)
	var city_limit := (Mappa.kind(n) in ["city", "scity", "base"]) and not stayed
	trade = {"s": s, "n": n, "c": c, "limit": city_limit, "new": []}
	phase = "commercio"
	var guard := 0
	while not abort and guard < 200:
		guard += 1
		var opts := trade_options(s)
		changed.emit()
		var r = await decide(s, {"k": "trade", "opts": opts, "at": n, "c": c, "limit": city_limit})
		if abort:
			return
		if not (r is Dictionary):
			r = {"a": "end"}
		var ok := false
		for o in opts:
			if _same_action(o, r):
				ok = true
				_apply_trade(s, o)
				break
		if r.get("a", "end") == "end" or not ok:
			if used_space(s) > capacity(s):
				_force_jettison(s)
			break
	phase = "turno"


func _same_action(o: Dictionary, r: Dictionary) -> bool:
	if o["a"] != r.get("a", ""):
		return false
	for k in ["i", "w", "id"]:
		if o.has(k) and str(o[k]) != str(r.get(k, "")):
			return false
	return true


func _discover(s: int, c: String) -> void:
	var p: Dictionary = players[s]
	cult[c]["disc"] = true
	p["ious"].append(c)
	log_msg("%s scopre i %s (%s) e riceve il pagherò da $%d." % [pname(s), D.CULTURES[c]["nome"], c, int(D.CULTURES[c]["iou"])])
	fx.emit("discover", {"s": s, "c": c, "sys": cult[c]["sys"]})


func ship_sellers(c: String) -> bool:
	if c == "base":
		return true
	return D.CULTURES[c]["sci"] in ["tech", "ind"]


func sci_of(c: String) -> String:
	return "base" if c == "base" else str(D.CULTURES[c]["sci"])


func demand_bonus(buyer: String, goods_c: String) -> int:
	var t := 0
	for b in cult[buyer]["bon"]:
		var bb: Dictionary = bon_list[b]
		if bb["t"] == "dem" and bb["g"] == goods_c:
			t += int(bb["v"])
	return t


func goods_payoff(buyer: String, it: Dictionary) -> int:
	var sc: String = it["c"]
	if not D.buys(buyer, sc):
		return -1
	if it["t"] == "g":
		return int(D.CULTURES[sc]["gp"]) + demand_bonus(buyer, sc)
	return int(D.CULTURES[sc]["fp"])


func port_price(s: int, sy: String) -> int:
	var c: String = sys_cult[sy]
	return 160 if c == players[s]["own"] else D.PORT_COST


func factory_price(s: int, c: String) -> int:
	var f: int = int(D.CULTURES[c]["f"])
	return int(f * 0.8) if c == players[s]["own"] else f


## Le azioni di commercio possibili ora. Ogni azione ha a (tipo), etichetta e prezzo/valore.
func trade_options(s: int) -> Array:
	var p: Dictionary = players[s]
	var n: int = trade["n"]
	var c: String = trade["c"]
	var lim: bool = trade["limit"]
	var can_buy: bool = not lim or p["buys"] < 1
	var can_sell: bool = not lim or p["sells"] < 1
	var cash: int = p["money"] + p["credit"]
	var out := []
	if c != "":
		# consegna e presa dei passeggeri (senza limiti)
		for i in p["cargo"].size():
			var it: Dictionary = p["cargo"][i]
			if it["t"] == "fare" and bon_list[it["b"]]["to"] == c:
				out.append({"a": "deliver", "i": i, "v": bon_list[it["b"]]["v"], "lbl": "Consegna: %s" % item_name(it)})
		var fares: Array = base_bon if c == "base" else cult[c]["bon"]
		for b in fares:
			if bon_list[b]["t"] == "fare" and fits(s, {"t": "fare", "b": b}):
				out.append({"a": "pickfare", "id": b, "lbl": "Prendi: %s" % D.fare_text(bon_list[b])})
		# vendite
		if can_sell and c != "base":
			for i in p["cargo"].size():
				var it: Dictionary = p["cargo"][i]
				if it["t"] in ["g", "f"]:
					var v := goods_payoff(c, it)
					if v >= 0:
						out.append({"a": "sell", "i": i, "v": v, "lbl": "Vendi %s: $%d" % [item_name(it), v]})
		if can_sell:
			for i in p["cargo"].size():
				var it: Dictionary = p["cargo"][i]
				if it["t"] in ["e", "r"]:
					var v: int = (int(D.EQUIP[it["e"]]["c"]) if it["t"] == "e" else int(D.RELICS[it["r"]]["v"])) / 2
					out.append({"a": "barter", "i": i, "v": v, "lbl": "Baratta %s: credito $%d" % [item_name(it), v]})
		if c != "base" and c in p["ious"]:
			out.append({"a": "iou", "id": c, "v": int(D.CULTURES[c]["iou"]), "lbl": "Usa il pagherò dei %s: credito $%d" % [D.CULTURES[c]["nome"], int(D.CULTURES[c]["iou"])]})
		# acquisti
		if can_buy:
			if c != "base":
				var cd: Dictionary = D.CULTURES[c]
				if cult[c]["stock"] > 0 and fits(s, {"t": "g", "c": c}) and cash >= int(cd["gc"]):
					out.append({"a": "buy", "w": "g", "id": c, "v": int(cd["gc"]), "lbl": "Compra %s: $%d" % [cd["g"], int(cd["gc"])]})
				if cult[c]["fg"] and fits(s, {"t": "f", "c": c}) and cash >= int(cd["fc"]):
					out.append({"a": "buy", "w": "f", "id": c, "v": int(cd["fc"]), "lbl": "Compra %s (merci di fabbrica): $%d" % [cd["fg"], int(cd["fc"])]})
				for e in D.EQUIP:
					if D.EQUIP[e]["sci"] == cd["sci"] and bank[e] > 0 and cash >= int(D.EQUIP[e]["c"]) and fits(s, {"t": "e", "e": e}):
						out.append({"a": "buy", "w": "e", "id": e, "v": int(D.EQUIP[e]["c"]), "lbl": "Compra %s: $%d" % [D.EQUIP[e]["nome"], int(D.EQUIP[e]["c"])]})
				for r in cult[c]["sun"]:
					var rv: int = int(D.RELICS[r]["v"])
					if cash >= rv:
						out.append({"a": "buy", "w": "r", "id": r, "v": rv, "lbl": "Compra la reliquia %s: $%d" % [D.RELICS[r]["nome"], rv]})
				var sy: String = cult[c]["sys"]
				for o in Mappa.orbits_of.get(sy, []):
					if not ports.has(o):
						var pp := port_price(s, sy)
						if cash >= pp:
							out.append({"a": "buy", "w": "port", "id": o, "v": pp, "lbl": "Atto dello spazioporto %s: $%d" % [Mappa.orbit_name(o), pp]})
				if not factories.has(c):
					var fp := factory_price(s, c)
					if cash >= fp:
						out.append({"a": "buy", "w": "fact", "id": c, "v": fp, "lbl": "Atto della fabbrica dei %s: $%d" % [cd["nome"], fp]})
			if ship_sellers(c):
				var sc := sci_of(c)
				for sh in D.SHIP_ORDER:
					if sh == p["ship"]:
						continue
					if c == "base" or D.SHIPS[sh]["sci"] == sc:
						var price: int = int(D.SHIPS[sh]["c"]) - int(D.SHIPS[p["ship"]]["t"])
						if cash >= price:
							out.append({"a": "buy", "w": "ship", "id": sh, "v": price, "lbl": "Nave %s (permutando la tua): $%d" % [D.SHIPS[sh]["nome"], price]})
	# reliquia sul segnalino "?"
	if Mappa.kind(n) == "qbox" and qbox[n]["up"] and qbox[n]["m"]["t"] == "relic" and not qbox[n]["taken"]:
		out.append({"a": "pickrelic", "lbl": "Raccogli la reliquia: %s" % D.RELICS[qbox[n]["m"]["r"]]["nome"]})
	# merci gettate
	for i in p["cargo"].size():
		var it: Dictionary = p["cargo"][i]
		if it["t"] != "r" and (not it.get("new", false) or used_space(s) > capacity(s)):
			out.append({"a": "jett", "i": i, "lbl": "Getta via %s" % item_name(it)})
	out.append({"a": "end", "lbl": "Fine turno"})
	return out


func _commission(n: int, amount: int) -> void:
	if is_open_port(n) or not ports.has(n) or amount <= 0:
		return
	var o: int = ports[n]
	var cm := amount / 10
	if cm > 0:
		players[o]["money"] += cm
		fx.emit("money", {"s": o, "d": cm})
		log_msg("Commissione di $%d a %s (spazioporto)." % [cm, pname(o)])


func _pay(s: int, amount: int) -> void:
	var p: Dictionary = players[s]
	var from_credit: int = mini(p["credit"], amount)
	p["credit"] -= from_credit
	p["money"] -= amount - from_credit
	fx.emit("money", {"s": s, "d": -(amount - from_credit)})


func _apply_trade(s: int, o: Dictionary) -> void:
	var p: Dictionary = players[s]
	var n: int = trade["n"]
	var c: String = trade["c"]
	match o["a"]:
		"deliver":
			var it: Dictionary = p["cargo"][o["i"]]
			var v: int = bon_list[it["b"]]["v"]
			p["cargo"].remove_at(o["i"])
			p["money"] += v
			log_msg("%s consegna il passeggero e incassa $%d." % [pname(s), v])
			fx.emit("money", {"s": s, "d": v})
			_to_cup({"t": "b", "i": it["b"]})
		"pickfare":
			var b: int = int(o["id"])
			if c == "base":
				base_bon.erase(b)
			else:
				cult[c]["bon"].erase(b)
			p["cargo"].append({"t": "fare", "b": b, "new": true})
			log_msg("%s imbarca un passeggero per %s." % [pname(s), D.cult_short(bon_list[b]["to"])])
		"sell":
			var it: Dictionary = p["cargo"][o["i"]]
			var v := goods_payoff(c, it)
			p["cargo"].remove_at(o["i"])
			p["money"] += v
			p["sells"] += 1
			log_msg("%s vende %s per $%d." % [pname(s), item_name(it), v])
			fx.emit("money", {"s": s, "d": v})
			_commission(n, v)
			# una richiesta usata torna nel bicchiere
			if it["t"] == "g" and demand_bonus(c, it["c"]) > 0:
				for b in cult[c]["bon"]:
					if bon_list[b]["t"] == "dem" and bon_list[b]["g"] == it["c"]:
						cult[c]["bon"].erase(b)
						_to_cup({"t": "b", "i": b})
						break
			_to_cup({"t": it["t"], "c": it["c"]})
		"barter":
			var it: Dictionary = p["cargo"][o["i"]]
			p["cargo"].remove_at(o["i"])
			p["credit"] += int(o["v"])
			p["sells"] += 1
			log_msg("%s baratta %s: credito di $%d." % [pname(s), item_name(it), int(o["v"])])
			_commission(n, int(o["v"]))
			if it["t"] == "e":
				bank[it["e"]] += 1
			else:
				cult[c]["sun"].append(it["r"])
		"iou":
			p["ious"].erase(c)
			p["credit"] += int(o["v"])
			log_msg("%s usa il pagherò dei %s: credito di $%d." % [pname(s), D.CULTURES[c]["nome"], int(o["v"])])
			_commission(n, int(o["v"]))
		"buy":
			var v: int = int(o["v"])
			_pay(s, v)
			p["buys"] += 1
			match o["w"]:
				"g":
					cult[c]["stock"] -= 1
					p["cargo"].append({"t": "g", "c": c, "new": true})
					log_msg("%s compra %s per $%d." % [pname(s), D.CULTURES[c]["g"], v])
					_commission(n, v)
				"f":
					cult[c]["fg"] = false
					p["cargo"].append({"t": "f", "c": c, "new": true})
					log_msg("%s compra %s per $%d." % [pname(s), D.CULTURES[c]["fg"], v])
					_commission(n, v)
					var fo: int = factories[c]["o"]
					var fc: int = int(D.CULTURES[c]["fc"]) / 2
					players[fo]["money"] += fc
					fx.emit("money", {"s": fo, "d": fc})
					log_msg("Commissione di fabbrica di $%d a %s." % [fc, pname(fo)])
				"e":
					bank[o["id"]] -= 1
					p["cargo"].append({"t": "e", "e": o["id"], "new": true})
					log_msg("%s compra %s per $%d." % [pname(s), D.EQUIP[o["id"]]["nome"], v])
					_commission(n, v)
				"r":
					cult[c]["sun"].erase(o["id"])
					p["cargo"].append({"t": "r", "r": o["id"], "new": true})
					log_msg("%s compra la reliquia %s per $%d." % [pname(s), D.RELICS[o["id"]]["nome"], v])
					_commission(n, v)
				"ship":
					var old: String = p["ship"]
					p["ship"] = o["id"]
					p["sells"] += 1
					log_msg("%s permuta il suo %s e compra un %s ($%d)." % [pname(s), D.SHIPS[old]["nome"], D.SHIPS[o["id"]]["nome"], v])
					_commission(n, int(D.SHIPS[o["id"]]["c"]))
					fx.emit("ship", {"s": s})
				"port":
					var orb: int = int(o["id"])
					ports[orb] = s
					p["ports"].append(orb)
					log_msg("%s compra l'atto dello spazioporto %s per $%d." % [pname(s), Mappa.orbit_name(orb), v])
					_commission(n, v)
					fx.emit("build", {"s": s, "n": orb, "w": "port"})
				"fact":
					var site := n if (Mappa.kind(n) in ["city", "scity"] or is_port(n)) else int(Mappa.places_of.get(cult[c]["sys"], [n])[0])
					factories[c] = {"o": s, "n": site}
					p["facts"].append(c)
					cult[c]["fg"] = true
					log_msg("%s costruisce la fabbrica dei %s per $%d: ora vendono %s." % [pname(s), D.CULTURES[c]["nome"], v, D.CULTURES[c]["fg"]])
					_commission(n, v)
					fx.emit("build", {"s": s, "n": site, "w": "fact"})
		"pickrelic":
			qbox[n]["taken"] = true
			var r: String = qbox[n]["m"]["r"]
			p["cargo"].append({"t": "r", "r": r, "new": true})
			log_msg("%s raccoglie la reliquia %s." % [pname(s), D.RELICS[r]["nome"]])
			fx.emit("reveal", {"n": n})
		"jett":
			_jettison(s, int(o["i"]))
	changed.emit()


func _jettison(s: int, i: int) -> void:
	var p: Dictionary = players[s]
	var it: Dictionary = p["cargo"][i]
	p["cargo"].remove_at(i)
	log_msg("%s getta via %s." % [pname(s), item_name(it)])
	match it["t"]:
		"e":
			bank[it["e"]] += 1
		"g", "f":
			_to_cup({"t": it["t"], "c": it["c"]})
		"fare":
			var c := culture_at(p["pos"])
			if c != "" and bon_list[it["b"]]["to"] == c:
				p["money"] += int(bon_list[it["b"]]["v"])
			_to_cup({"t": "b", "i": it["b"]})


func _force_jettison(s: int) -> void:
	var p: Dictionary = players[s]
	while used_space(s) > capacity(s):
		# getta per primo l'oggetto che vale meno
		var best := -1
		var bv := 1 << 30
		for i in p["cargo"].size():
			var it: Dictionary = p["cargo"][i]
			if it["t"] == "r":
				continue
			var v := 0
			match it["t"]:
				"g":
					v = int(D.CULTURES[it["c"]]["gc"])
				"f":
					v = int(D.CULTURES[it["c"]]["fc"])
				"e":
					v = int(D.EQUIP[it["e"]]["c"])
				"fare":
					v = int(bon_list[it["b"]]["v"])
			if v < bv:
				bv = v
				best = i
		if best < 0:
			break
		_jettison(s, best)


## Un segnalino va nel bicchiere e se ne pesca subito un altro, che va alla sua cultura.
func _to_cup(tok: Dictionary) -> void:
	cup.append(tok)
	var i := rng.randi_range(0, cup.size() - 1)
	var d: Dictionary = cup[i]
	cup.remove_at(i)
	match d["t"]:
		"g":
			cult[d["c"]]["stock"] += 1
			_note_draw("merci %s" % D.CULTURES[d["c"]]["g"], d["c"])
		"f":
			cult[d["c"]]["fg"] = true
			_note_draw("merci di fabbrica %s" % D.CULTURES[d["c"]]["fg"], d["c"])
		"b":
			var b: Dictionary = bon_list[d["i"]]
			if b["at"] == "base":
				base_bon.append(d["i"])
			else:
				cult[b["at"]]["bon"].append(d["i"])
			var txt := D.fare_text(b) if b["t"] == "fare" else D.dem_text(b)
			_note_draw(txt, b["at"])


func _note_draw(what: String, c: String) -> void:
	var where := "alla Base Galattica"
	if c != "base":
		where = "ai %s" % D.CULTURES[c]["nome"] if cult[c]["disc"] else "a una cultura non ancora scoperta"
	log_msg("Dal bicchiere: %s, %s." % [what, where])


func _check_win(s: int) -> void:
	for it in players[s]["cargo"]:
		it.erase("new")
	var nw := net_worth(s)
	if nw >= goal:
		over = true
		result = {"winner": s, "nw": nw}
		log_msg("%s raggiunge un patrimonio di $%d e vince la partita!" % [pname(s), nw])
		fx.emit("win", {"s": s})
