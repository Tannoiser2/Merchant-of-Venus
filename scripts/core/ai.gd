class_name MoVAI
extends RefCounted
## Intelligenza artificiale del mercante.
## Movimento: dopo il tiro esplora tutte le strade possibili con i PM a disposizione (rispettando
## cerchi di navigazione, numero pilota, propulsori, penalità e atterraggi) e sceglie il punto
## d'arrivo che vale di più: un mercato dove guadagnare subito, oppure il punto più vicino al
## mercato migliore. Commercio: consegna i passeggeri, vende quello che rende di più, compra le
## merci con il guadagno atteso più alto, poi navi, atti di spazioporti e fabbriche quando il
## denaro avanza.
## Usa solo ciò che il suo giocatore sa: culture scoperte e quelle osservate da lui.

const D = preload("res://scripts/data/mov_data.gd")

var level := 1
var plan: Array = []            # passi pianificati: {to, pilot} / {land} / {pay}
var plan_turn := -1
var dist_cache := {}
var _best := {}
var _seen := {}
var _eng
var _s := 0
var _vals := {}


func _init(lv := 1) -> void:
	level = lv


func decide(eng, s: int, req: Dictionary):
	_eng = eng
	_s = s
	match req["k"]:
		"pre":
			return _pre(eng, s, req)
		"mull":
			return _mull(req)
		"move":
			return _move(eng, s, req)
		"pen":
			return _pen(eng, s, req)
		"trade":
			return _trade(eng, s, req)
	return null


# ---------------------------------------------------------------- inizio turno

func _pre(eng, s: int, req: Dictionary) -> Dictionary:
	plan = []
	var out := {"auto": req.get("auto", false), "off": [], "glock": false, "jump": req.get("jump", false)}
	if req.get("can_stay", false) and req.get("trade", false) and req.get("arrived", false):
		# soggiorno prolungato in città se ci sono più affari da fare qui
		var p: Dictionary = eng.players[s]
		var n: int = p["pos"]
		if Mappa.kind(n) in ["city", "scity", "base"] and _stay_value(eng, s, n) > 220:
			out["stay"] = true
	return out


func _stay_value(eng, s: int, n: int) -> int:
	var c: String = eng.culture_at(n)
	if c == "" or c == "base":
		return 0
	var p: Dictionary = eng.players[s]
	var v := 0
	var buyable := 0
	if eng.cult[c]["stock"] >= 2 and _best_buyer_value(eng, s, c, "g") > int(D.CULTURES[c]["gc"]) + 40:
		buyable += 1
	if p["money"] > 900:
		buyable += 1
	if c in p["ious"]:
		v += 60
	v += buyable * 120
	return v


func _mull(req: Dictionary) -> int:
	var dice: Array = req["dice"]
	var lo := -1
	var lv := 7
	for i in dice.size():
		if req.get("auto", false) and i == dice.size() - 1:
			continue
		if int(dice[i]) < lv:
			lv = int(dice[i])
			lo = i
	return lo if lv <= 2 else -1


# ---------------------------------------------------------------- movimento

func _pen(eng, s: int, req: Dictionary) -> bool:
	var amt: int = req["amt"]
	for st in plan:
		if st.has("pen_at") and int(st["pen_at"]) == int(req["at"]):
			return st["pay"]
	var p: Dictionary = eng.players[s]
	return p["money"] - amt >= 60 and amt <= 30


func _move(eng, s: int, req: Dictionary, again := false) -> Dictionary:
	var steps: Array = req["steps"]
	if req.get("free", false):
		plan = []
	# segue il piano se il prossimo passo è ancora possibile
	while not plan.is_empty():
		var nx: Dictionary = plan[0]
		if nx.has("pen_at"):
			plan.pop_front()
			continue
		if nx.has("land"):
			if req["land"]:
				plan.pop_front()
				return {"land": true}
			plan = []
			break
		for st in steps:
			if int(st["to"]) == int(nx["to"]) and (nx.get("pilot", -1) < 0 or st["pilots"].is_empty() or int(nx["pilot"]) in st["pilots"]):
				plan.pop_front()
				return {"to": nx["to"], "pilot": nx.get("pilot", -1)}
		plan = []
		break
	if not again:
		_make_plan(eng, s, req)
		if not plan.is_empty():
			return _move(eng, s, req, true)
	elif OS.get_environment("MOV_DBG") != "":
		print("AI piano non eseguibile a ", req["at"], " ", str(plan), " passi ", str(steps))
	if req["land"]:
		return {"land": true}
	var st0: Dictionary = steps[0]
	return {"to": st0["to"], "pilot": (st0["pilots"][0] if not st0["pilots"].is_empty() else -1)}


## Valori dei possibili mercati per questo giocatore (calcolati una volta per decisione)
func _market_values(eng, s: int) -> Dictionary:
	var out := {}
	for n in Mappa.nodes.size():
		var v := _place_value(eng, s, n)
		if v > 0:
			out[n] = v
	return out


func _place_value(eng, s: int, n: int) -> float:
	var p: Dictionary = eng.players[s]
	var k := Mappa.kind(n)
	var v := 0.0
	if k == "qbox":
		var q: Dictionary = eng.qbox[n]
		if q["up"]:
			if q["m"]["t"] == "relic" and not q["taken"]:
				v += float(D.RELICS[q["m"]["r"]]["v"]) * 0.9
			if q["m"]["t"] != "open":
				return v
		else:
			# un "?" coperto: forse una reliquia (o un'informazione)
			return 18.0 if eng.turn < 12 else 6.0
	var landable_place: bool = k in ["city", "scity", "base"] or eng.is_port(n)
	if not landable_place:
		return v
	var c: String = eng.culture_at(n) if k != "orbit" else ""
	if k == "base":
		c = "base"
	if c == "" and eng.is_port(n):
		c = eng.culture_at(n)
	var sy := Mappa.sys(n)
	var known := c
	if c != "base" and c != "":
		known = eng.knows(s, sy)
	if c != "base" and known == "":
		# cultura sconosciuta: pagherò e scoperta
		if c != "" and not eng.cult[c]["disc"]:
			return 95.0 + (40.0 if eng.turn < 10 else 0.0)
		return 0.0
	c = known
	var unlimited: bool = eng.is_port(n)
	# consegne e vendite
	var sells := []
	for it in p["cargo"]:
		if it["t"] == "fare" and eng.bon_list[it["b"]]["to"] == c:
			v += float(eng.bon_list[it["b"]]["v"])
		if it["t"] in ["g", "f"] and c != "base":
			var pay: int = eng.goods_payoff(c, it)
			if pay >= 0:
				sells.append(float(pay))
	sells.sort()
	sells.reverse()
	if unlimited:
		for x in sells:
			v += x
	elif not sells.is_empty():
		v += sells[0] + (sells.size() - 1) * 0.25 * sells[0]
	# passeggeri da prendere
	var free_half: int = eng.capacity(s) - eng.used_space(s)
	var fares: Array = eng.base_bon if c == "base" else eng.cult[c]["bon"]
	for b in fares:
		if eng.bon_list[b]["t"] == "fare" and free_half > 0:
			v += float(eng.bon_list[b]["v"]) * 0.45
	# acquisti: merci con guadagno
	if c != "base":
		var cash: int = p["money"]
		if c in p["ious"]:
			cash += int(D.CULTURES[c]["iou"])
			v += 40.0
		var holds_after := free_half + sells.size() * 2
		if holds_after >= 2:
			var best := 0.0
			if eng.cult[c]["stock"] > 0 and cash >= int(D.CULTURES[c]["gc"]):
				best = maxf(best, _best_buyer_value(eng, s, c, "g") - float(D.CULTURES[c]["gc"]))
			if eng.cult[c]["fg"] and cash >= int(D.CULTURES[c]["fc"]):
				best = maxf(best, _best_buyer_value(eng, s, c, "f") - float(D.CULTURES[c]["fc"]))
			v += best * 0.7
		# investimenti
		if p["money"] >= 500:
			var sy2: String = eng.cult[c]["sys"]
			for o in Mappa.orbits_of.get(sy2, []):
				if not eng.ports.has(o):
					v += 30.0
					break
			if not eng.factories.has(c):
				v += 30.0
	if eng.ship_sellers(c) and p["ship"] == "scout" and p["money"] >= 300:
		v += 90.0
	return v


## Il miglior prezzo noto per le merci della cultura c (0 se nessun compratore noto)
func _best_buyer_value(eng, s: int, c: String, t: String) -> float:
	var best := 0.0
	var unknown_buyer := false
	for b in D.buyers_of(c):
		var sy: String = eng.cult[b]["sys"]
		var known: bool = eng.cult[b]["disc"] or eng.players[s]["obs"].has(sy)
		var pay: float = float(D.CULTURES[c]["gp"] if t == "g" else D.CULTURES[c]["fp"])
		if t == "g":
			pay += float(eng.demand_bonus(b, c))
		if known:
			best = maxf(best, pay)
		else:
			unknown_buyer = true
	if best == 0.0 and unknown_buyer:
		# compratore non ancora trovato: speculazione a metà valore
		best = float(D.CULTURES[c]["gp"] if t == "g" else D.CULTURES[c]["fp"]) * 0.75
	return best


## Distanza in PM fra due punti (Dijkstra senza colori; i cerchi portano a tutte le uscite)
func _dist_from(n: int) -> Dictionary:
	if dist_cache.has(n):
		return dist_cache[n]
	var dist := {n: 0}
	var open := [n]
	while not open.is_empty():
		var best_i := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best_i]]:
				best_i = i
		var u: int = open[best_i]
		open.remove_at(best_i)
		var nbs: Array = Mappa.adj[u].duplicate()
		if Mappa.kind(u) == "nav" and Mappa.nodes[u].has("j"):
			nbs.append(Mappa.nodes[u]["j"])
		for w in nbs:
			var c := 2 if (Mappa.kind(u) == "city" or Mappa.kind(w) == "city") else 1
			if Mappa.kind(w) == "nav":
				c += 1
			var nd: int = dist[u] + c
			if not dist.has(w) or nd < dist[w]:
				dist[w] = nd
				open.append(w)
	dist_cache[n] = dist
	return dist


## Valore di finire il movimento in un punto: subito se si atterra su un mercato, altrimenti il
## migliore dei mercati scontato per la distanza.
func _end_value(n: int, landed: bool) -> float:
	var direct := 0.0
	if landed and _vals.has(n):
		direct = _vals[n]
	var dist := _dist_from(n)
	var best := 0.0
	for m in _vals:
		if m == n and landed:
			continue
		var d: int = dist.get(m, 99)
		var turns := float(d) / 10.0
		var vv: float = _vals[m] / (1.0 + turns * 1.2)
		best = maxf(best, vv)
	return direct + best * (0.55 if landed and direct > 0.0 else 0.85)


func _make_plan(eng, s: int, req: Dictionary) -> void:
	plan = []
	_vals = _market_values(eng, s)
	_best = {"score": -1e9, "path": []}
	_seen = {}
	var m: Dictionary = eng.ms.duplicate(true)
	var money: int = eng.players[s]["money"]
	_dfs(eng, s, m, [], 0, money, 0)
	plan = _best["path"]
	if OS.get_environment("MOV_DBG") == str(s):
		var top := []
		for k in _vals:
			top.append([_vals[k], k])
		top.sort()
		top.reverse()
		print("DBG t%d s%d at %d (%s) mp %d money %d plan %s score %.1f top %s" % [eng.turn, s, eng.ms["cur"], Mappa.kind(eng.ms["cur"]), eng.ms["mp"], money, str(plan), _best["score"], str(top.slice(0, 5))])


func _dfs(eng, s: int, m: Dictionary, path: Array, paid: int, money: int, depth: int) -> void:
	var here: int = m["cur"]
	var key := "%d|%d|%d|%d" % [here, m["mp"], m["pilot"], int(path.size() > 0)]
	var prev: Array = _seen.get(key, [])
	# stessi punto, PM e pilota: si scarta se già visto con meno penalità pagate
	for pv in prev:
		if pv <= paid:
			return
	prev.append(paid)
	_seen[key] = prev
	if depth > 40:
		return
	var steps: Array = eng.legal_steps(m, s)
	var at_land: bool = path.size() > 0 and eng.landable(here) and here != m["start"]
	# atterrare qui
	if at_land:
		var sc := _end_value(here, true) - paid
		if sc > _best["score"]:
			var pp := path.duplicate()
			pp.append({"land": true})
			_best = {"score": sc, "path": pp}
	if steps.is_empty() or m["mp"] <= 0:
		var sc2 := _end_value(here, eng.landable(here)) - paid
		if path.is_empty():
			sc2 -= 5.0
		if sc2 > _best["score"]:
			_best = {"score": sc2, "path": path.duplicate()}
		return
	for st in steps:
		var to: int = st["to"]
		var pilots: Array = st["pilots"]
		var plist: Array = [-1] if pilots.is_empty() else pilots
		if m["pilot"] >= 0 and not m["switch"] and not pilots.is_empty():
			plist = [m["pilot"]]
		for pv in plist:
			var m2 := m.duplicate()
			m2["used"] = m["used"].duplicate()
			for e in st["edges"]:
				m2["used"][e] = true
			m2["mp"] = int(m["mp"]) - int(st["cost"])
			m2["cur"] = to
			m2["first"] = false
			m2.erase("free")
			if pv >= 0:
				m2["pilot"] = pv
			var p2 := path.duplicate()
			p2.append({"to": to, "pilot": pv})
			var pen: Dictionary = eng.penalty_at(to)
			if not pen.is_empty() and m2["mp"] > 0:
				var amt: int = maxi(0, int(pen["v"]) - 20 * eng.shields(s))
				# fermarsi sulla penalità
				var sc := _end_value(to, false) - paid
				if sc > _best["score"]:
					var pf := p2.duplicate()
					pf.append({"pen_at": to, "pay": false})
					_best = {"score": sc, "path": pf}
				if amt > 0 and money - amt < 0:
					continue
				if amt > 0:
					p2.append({"pen_at": to, "pay": true})
				_dfs(eng, s, m2, p2, paid + amt, money - amt, depth + 1)
			else:
				_dfs(eng, s, m2, p2, paid, money, depth + 1)


# ---------------------------------------------------------------- commercio

func _trade(eng, s: int, req: Dictionary) -> Dictionary:
	var opts: Array = req["opts"]
	var p: Dictionary = eng.players[s]
	var c: String = req["c"]
	var by := {}
	for o in opts:
		if not by.has(o["a"]):
			by[o["a"]] = []
		by[o["a"]].append(o)
	# 1. consegne
	if by.has("deliver"):
		return by["deliver"][0]
	# 2. reliquia sul posto
	if by.has("pickrelic"):
		return by["pickrelic"][0]
	# 3. vendite: la più redditizia
	if by.has("sell"):
		var best: Dictionary = by["sell"][0]
		for o in by["sell"]:
			if o["v"] > best["v"]:
				best = o
		return best
	# 4. passeggeri da prendere, se la destinazione è nota o è la Base
	if by.has("pickfare"):
		for o in by["pickfare"]:
			var to: String = eng.bon_list[o["id"]]["to"]
			if to == "base" or eng.cult[to]["disc"] or p["obs"].has(eng.cult[to]["sys"]):
				return o
	# 5. acquisti (il pagherò di questa cultura si usa qui, prima di comprare)
	if by.has("iou") and (eng.cult[c]["stock"] > 0 or p["money"] + int(by["iou"][0]["v"]) >= 160):
		return by["iou"][0]
	var buys: Array = by.get("buy", [])
	var choice := _choose_buy(eng, s, c, buys, req)
	if not choice.is_empty():
		# prima il pagherò, se serve per pagare
		if by.has("iou") and int(choice["v"]) > p["credit"]:
			return by["iou"][0]
		return choice
	return {"a": "end"}


func _choose_buy(eng, s: int, c: String, buys: Array, req: Dictionary) -> Dictionary:
	var p: Dictionary = eng.players[s]
	var money: int = p["money"] + p["credit"]
	if c != "base" and c in p["ious"]:
		money += int(D.CULTURES[c]["iou"])
	var holds: int = eng.capacity(s) / 2
	var reserve: int = 80 + 60 * holds
	var best := {}
	var bscore := 0.0
	for o in buys:
		var sc := 0.0
		var price: int = o["v"]
		match o["w"]:
			"ship":
				var sh: String = o["id"]
				var cur_sh: String = p["ship"]
				if D.SHIP_ORDER.find(sh) <= D.SHIP_ORDER.find(cur_sh) and not (cur_sh == "freighter"):
					continue
				if cur_sh in ["transport", "freighter"] and sh in ["scout", "clipper"]:
					continue
				if sh == "freighter" and money - price >= 120:
					sc = 400.0
				elif sh == "transport" and money - price >= 100 and cur_sh in ["scout", "clipper"]:
					sc = 300.0
				elif sh == "clipper" and cur_sh == "scout" and money - price >= 150 and money < 500:
					sc = 120.0
			"g", "f":
				var pay := _best_buyer_value(eng, s, o["id"], o["w"])
				var profit := pay - float(price)
				if profit > 15.0:
					sc = 100.0 + profit
			"port", "fact":
				# un atto vale il suo prezzo nel patrimonio e porta commissioni
				var val: int = eng.deed_value(o["w"], o["id"] if o["w"] == "fact" else 0)
				if money - price >= reserve or eng.net_worth(s) + (val - price) >= eng.goal:
					sc = 80.0 + float(val - price) + (40.0 if o["w"] == "fact" else 20.0)
					if p["money"] - price > 900:
						sc += 150.0
			"e":
				var e: String = o["id"]
				if e == "shield" and eng.shields(s) == 0 and money - price >= reserve + 100:
					sc = 60.0
				elif e in ["ydrive", "rdrive", "cdrive"] and eng.drives(s).size() == 0 and money - price >= reserve + 250:
					sc = 70.0
			"r":
				if o["id"] in ["airfoil", "autopilot", "mulligan", "switch"] and money - price >= reserve + 200:
					sc = 50.0
		if sc > bscore:
			bscore = sc
			best = o
	return best
