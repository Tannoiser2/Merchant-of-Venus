extends RefCounted
## Dati di Merchant of Venus (Avalon Hill, 1988): culture, merci, bonus, segnalini "?", navi,
## equipaggiamento e mercanti. Valori dai segnalini e dalle carte di riferimento del gioco originale.

## Scienze delle culture
const SCI_NAME := {
	"bio": "Bioingegneria",
	"meta": "Metafisica",
	"prim": "Primitiva",
	"ind": "Industria",
	"tech": "Tecnologia",
	"base": "Base",
}

## Le 14 culture. n = numero d'identità (per i compratori), g = merci, f = fabbrica,
## fg = merci di fabbrica, iou = valore del pagherò.
const CULTURES := {
	"1a": {"nome": "Nillis", "n": 1, "sci": "bio", "g": "Profumo bionico", "gc": 80, "gp": 140, "gq": 5, "f": 100, "fg": "Piante da guardia", "fc": 60, "fp": 140, "iou": 80},
	"1b": {"nome": "Volois", "n": 1, "sci": "meta", "g": "Seta Voll", "gc": 140, "gp": 220, "gq": 6, "f": 200, "fg": "Tratti in scatola", "fc": 120, "fp": 240, "iou": 120},
	"2": {"nome": "Graw", "n": 2, "sci": "prim", "g": "Spezie spaziali", "gc": 30, "gp": 80, "gq": 6, "f": 200, "fg": "Robaccia gloriosa", "fc": 100, "fp": 200, "iou": 90},
	"3": {"nome": "Niks", "n": 3, "sci": "bio", "g": "Vino di pacciame", "gc": 20, "gp": 60, "gq": 6, "f": 200, "fg": "Giocattoli viventi", "fc": 80, "fp": 180, "iou": 80},
	"4a": {"nome": "Dell", "n": 4, "sci": "ind", "g": "Polvere finissima", "gc": 10, "gp": 50, "gq": 6, "f": 200, "fg": "Vetro elastico", "fc": 120, "fp": 200, "iou": 60},
	"4b": {"nome": "Umani", "n": 4, "sci": "tech", "g": "Videoclip rock", "gc": 120, "gp": 200, "gq": 5, "f": 100, "fg": "Arte primitiva", "fc": 60, "fp": 160, "iou": 90},
	"5": {"nome": "Shenna", "n": 5, "sci": "prim", "g": "Pellicce di melf", "gc": 50, "gp": 110, "gq": 6, "f": 100, "fg": "Mostri domestici", "fc": 80, "fp": 150, "iou": 90},
	"6": {"nome": "Yxklyx", "n": 6, "sci": "tech", "g": "Grasso immortale", "gc": 50, "gp": 100, "gq": 6, "f": 200, "fg": "Melma lucente", "fc": 100, "fp": 200, "iou": 100},
	"7a": {"nome": "Zum", "n": 7, "sci": "ind", "g": "Liquore di chicle", "gc": 40, "gp": 90, "gq": 6, "f": 200, "fg": "Alveari su misura", "fc": 140, "fp": 220, "iou": 100},
	"7b": {"nome": "Eeepeeep", "n": 7, "sci": "tech", "g": "Servomeccanismi", "gc": 200, "gp": 300, "gq": 4, "f": 100, "fg": "Bulloni di razza", "fc": 100, "fp": 200, "iou": 100},
	"8": {"nome": "Whynom", "n": 8, "sci": "ind", "g": "Mobili impossibili", "gc": 110, "gp": 180, "gq": 5, "f": 100, "fg": "Scarpe di ricambio", "fc": 80, "fp": 160, "iou": 80},
	"9a": {"nome": "Cholos", "n": 9, "sci": "bio", "g": "Geni firmati", "gc": 60, "gp": 120, "gq": 6, "f": 200, "fg": "Progetto vita", "fc": 160, "fp": 240, "iou": 90},
	"9b": {"nome": "Wollow", "n": 9, "sci": "prim", "g": "Fermacarte megalitici", "gc": 90, "gp": 160, "gq": 5, "f": 100, "fg": "Organo a canne portatile", "fc": 80, "fp": 160, "iou": 90},
	"10": {"nome": "Qossuth", "n": 10, "sci": "meta", "g": "Sculture psicotiche", "gc": 160, "gp": 250, "gq": 4, "f": 200, "fg": "Rompicapi infiniti", "fc": 120, "fp": 250, "iou": 120},
}
const CULT_IDS := ["1a", "1b", "2", "3", "4a", "4b", "5", "6", "7a", "7b", "8", "9a", "9b", "10"]

## Colore del segnalino delle merci (come nel gioco originale)
const GOODS_COL := {
	"1a": Color("b9d23a"), "1b": Color("d23a2a"), "2": Color("a466c4"), "3": Color("f0d84a"),
	"4a": Color("a8a8a8"), "4b": Color("a466c4"), "5": Color("d23a2a"), "6": Color("9a6a14"),
	"7a": Color("f0d84a"), "7b": Color("a466c4"), "8": Color("b9d23a"), "9a": Color("d23a2a"),
	"9b": Color("b9d23a"), "10": Color("a466c4"),
}
const SCI_COL := {"bio": Color("8fc93a"), "meta": Color("e8a020"), "prim": Color("e8e4d8"), "ind": Color("f0c020"), "tech": Color("d83a2a"), "base": Color("6ad0f0")}

## Chi compra le merci di una cultura: i tre numeri d'identità successivi (dopo il 10 viene l'1).
static func buyers_of(c: String) -> Array:
	var n: int = CULTURES[c]["n"]
	var nums := []
	for k in [1, 2, 3]:
		nums.append((n - 1 + k) % 10 + 1)
	var out := []
	for id in CULT_IDS:
		if CULTURES[id]["n"] in nums:
			out.append(id)
	return out

static func buys(buyer: String, seller: String) -> bool:
	return buyer in buyers_of(seller)

## 48 segnalini bonus: 10 passeggeri (FARE) e 38 richieste (DEMAND).
## at = cultura dove si mette il segnalino ("base" = Base Galattica), to = destinazione del passeggero.
const FARES := [
	{"at": "base", "to": "2", "v": 160}, {"at": "base", "to": "4a", "v": 140}, {"at": "base", "to": "9a", "v": 110},
	{"at": "2", "to": "10", "v": 120}, {"at": "5", "to": "base", "v": 140}, {"at": "4a", "to": "base", "v": 180},
	{"at": "6", "to": "4b", "v": 120}, {"at": "7b", "to": "base", "v": 110}, {"at": "9b", "to": "5", "v": 110},
	{"at": "10", "to": "base", "v": 150},
]
## [merci della cultura, cultura che paga, bonus, quante]
const DEMANDS := [
	["1a", "3", 60, 2], ["1a", "4b", 60, 1], ["1b", "3", 60, 1], ["2", "3", 60, 2], ["2", "4b", 40, 4],
	["3", "4a", 60, 2], ["3", "5", 40, 3], ["4a", "5", 50, 2], ["4a", "7a", 50, 3], ["4a", "7b", 50, 2],
	["5", "6", 50, 2], ["6", "7b", 50, 3], ["6", "9a", 50, 1], ["6", "9b", 50, 1], ["7a", "8", 60, 1],
	["7a", "9a", 60, 2], ["8", "9b", 70, 1], ["9a", "10", 60, 2], ["9a", "2", 40, 2], ["10", "2", 90, 1],
]

## Elenco completo dei bonus: {t: "fare"/"dem", at, to/g, v}
static func bonuses() -> Array:
	var out := []
	for f in FARES:
		out.append({"t": "fare", "at": f["at"], "to": f["to"], "v": f["v"]})
	for d in DEMANDS:
		for k in d[3]:
			out.append({"t": "dem", "at": d[1], "g": d[0], "v": d[2]})
	return out

## Segnalini "?": 36, se ne usano tanti quante sono le caselle "?" (24), gli altri si scartano.
const RELICS := {
	"airfoil": {"nome": "Profilo alare", "v": 80, "d": "Da una città di superficie si va alle città vicine dello stesso pianeta come se fossero punti adiacenti, senza atterrare; entrare e uscire da una città di superficie costa 1 PM invece di 2."},
	"autopilot": {"nome": "Pilota automatico", "v": 80, "d": "Si può tirare un dado in meno: quel dado vale automaticamente 4 (anche come numero pilota)."},
	"gatelock": {"nome": "Blocco porte", "v": 100, "d": "Prima di tirare si possono spegnere tutte le porte tele per il turno: valgono come punti blu."},
	"jumpstart": {"nome": "Avvio a salto", "v": 120, "d": "A inizio turno si può saltare subito a una porta tele scoperta dichiarandola come prima mossa."},
	"laser": {"nome": "Laser", "v": 100, "d": "Senza le regole di combattimento non ha effetto, ma si può barattare."},
	"mulligan": {"nome": "Ingranaggio della seconda possibilità", "v": 120, "d": "Subito dopo il tiro si può ritirare un dado (una volta per turno)."},
	"shield": {"nome": "Scudo antico", "v": 60, "d": "Uno scudo che sta sullo scafo, in aggiunta allo scudo normale: toglie $20 da ogni penalità."},
	"spyeye": {"nome": "Occhio spia", "v": 100, "d": "Si sbirciano i segnalini \"?\" coperti accanto ai punti attraversati e si osserva la cultura da qualsiasi punto del suo sistema."},
	"switch": {"nome": "Scambia-scambia", "v": 100, "d": "Il numero pilota si può cambiare quando si vuole, fra i numeri tirati."},
	"ydrive": {"nome": "Propulsore giallo antico", "v": 80, "d": "Un propulsore giallo che sta sullo scafo e non occupa la stiva: salta i punti e le penalità gialle."},
}

static func qmarkers() -> Array:
	var out := []
	for r in RELICS:
		out.append({"t": "relic", "r": r})
	for k in 3:
		out.append({"t": "open"})
	for g in range(1, 7):
		out.append({"t": "gate", "n": g})
	for v in [10, 10, 20, 20, 30, 30, 40]:
		out.append({"t": "pen", "c": "b", "v": v})
	for v in [10, 20, 20, 30, 30, 40]:
		out.append({"t": "pen", "c": "r", "v": v})
	for v in [10, 20, 30, 40]:
		out.append({"t": "pen", "c": "y", "v": v})
	return out

## Navi: dadi, stive, costo, valore di permuta, scienze che le vendono (la Base le vende tutte)
const SHIPS := {
	"scout": {"nome": "Esploratore", "dadi": 3, "stive": 2, "c": 60, "t": 30, "sci": "tech"},
	"clipper": {"nome": "Clipper", "dadi": 4, "stive": 2, "c": 120, "t": 60, "sci": "tech"},
	"transport": {"nome": "Trasporto", "dadi": 3, "stive": 3, "c": 240, "t": 120, "sci": "ind"},
	"freighter": {"nome": "Mercantile", "dadi": 2, "stive": 5, "c": 300, "t": 150, "sci": "ind"},
}
const SHIP_ORDER := ["scout", "clipper", "transport", "freighter"]

## Equipaggiamento in vendita (gioco base: niente armi). q = quanti ce ne sono in banca.
const EQUIP := {
	"shield": {"nome": "Scudo", "c": 60, "sci": "bio", "q": 15, "d": "Toglie $20 da ogni penalità. Uno sta sullo scafo, gli altri in stiva."},
	"ydrive": {"nome": "Propulsore giallo", "c": 80, "sci": "ind", "q": 6, "d": "Salta i punti gialli, gli ovali e le penalità gialle."},
	"rdrive": {"nome": "Propulsore rosso", "c": 120, "sci": "tech", "q": 6, "d": "Salta i punti rossi, gli ovali e le penalità rosse."},
	"cdrive": {"nome": "Propulsore combinato", "c": 300, "sci": "meta", "q": 6, "d": "Salta tutti i punti, gli ovali e le penalità rossi e gialli."},
}

## I sei mercanti (pedine). c = cultura della propria specie (sconto del 20% sugli atti).
const MERCHANTS := [
	{"id": "nik", "nome": "Nik", "c": "3", "col": Color("33b32b")},
	{"id": "dell", "nome": "Dell", "c": "4a", "col": Color("e6e62b")},
	{"id": "qossuth", "nome": "Qossuth", "c": "10", "col": Color("db1a17")},
	{"id": "human", "nome": "Umano", "c": "4b", "col": Color("1f87ff")},
	{"id": "eeep", "nome": "Eeepeeep", "c": "7b", "col": Color("f2f2f2")},
	{"id": "whynom", "nome": "Whynom", "c": "8", "col": Color("2a2a2a")},
]

const PORT_COST := 200

## Lunghezza della partita (patrimonio per vincere)
const GOALS := [
	{"v": 1000, "nome": "Apprendista mercante"},
	{"v": 2000, "nome": "Mercante esperto"},
	{"v": 3000, "nome": "Maestro mercante"},
	{"v": 4000, "nome": "Barone del commercio"},
]


static func fare_text(b: Dictionary) -> String:
	return "Passeggero per %s ($%d)" % [cult_short(b["to"]), b["v"]]


static func dem_text(b: Dictionary) -> String:
	return "Richiesta di %s +$%d" % [CULTURES[b["g"]]["g"], b["v"]]


static func cult_short(c: String) -> String:
	if c == "base":
		return "Base Galattica"
	return "%s %s" % [c, CULTURES[c]["nome"]]
