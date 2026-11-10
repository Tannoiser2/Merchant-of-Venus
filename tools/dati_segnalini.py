"""Dati per genera_segnalini.py (gli stessi di scripts/data/mov_data.gd, in Python)."""

CULT = {
    "1a": {"nome": "Nillis", "g": "Profumo bionico", "corto": "Profumo", "gc": 80, "gp": 140, "f": 100, "fg": "Piante da guardia", "fc": 60, "fp": 140},
    "1b": {"nome": "Volois", "g": "Seta Voll", "corto": "Seta", "gc": 140, "gp": 220, "f": 200, "fg": "Tratti in scatola", "fc": 120, "fp": 240},
    "2": {"nome": "Graw", "g": "Spezie spaziali", "corto": "Spezie", "gc": 30, "gp": 80, "f": 200, "fg": "Robaccia gloriosa", "fc": 100, "fp": 200},
    "3": {"nome": "Niks", "g": "Vino di pacciame", "corto": "Vino", "gc": 20, "gp": 60, "f": 200, "fg": "Giocattoli viventi", "fc": 80, "fp": 180},
    "4a": {"nome": "Dell", "g": "Polvere finissima", "corto": "Polvere", "gc": 10, "gp": 50, "f": 200, "fg": "Vetro elastico", "fc": 120, "fp": 200},
    "4b": {"nome": "Umani", "g": "Videoclip rock", "corto": "Video", "gc": 120, "gp": 200, "f": 100, "fg": "Arte primitiva", "fc": 60, "fp": 160},
    "5": {"nome": "Shenna", "g": "Pellicce di melf", "corto": "Pellicce", "gc": 50, "gp": 110, "f": 100, "fg": "Mostri domestici", "fc": 80, "fp": 150},
    "6": {"nome": "Yxklyx", "g": "Grasso immortale", "corto": "Grasso", "gc": 50, "gp": 100, "f": 200, "fg": "Melma lucente", "fc": 100, "fp": 200},
    "7a": {"nome": "Zum", "g": "Liquore di chicle", "corto": "Liquore", "gc": 40, "gp": 90, "f": 200, "fg": "Alveari su misura", "fc": 140, "fp": 220},
    "7b": {"nome": "Eeepeeep", "g": "Servomeccanismi", "corto": "Servo", "gc": 200, "gp": 300, "f": 100, "fg": "Bulloni di razza", "fc": 100, "fp": 200},
    "8": {"nome": "Whynom", "g": "Mobili impossibili", "corto": "Mobili", "gc": 110, "gp": 180, "f": 100, "fg": "Scarpe di ricambio", "fc": 80, "fp": 160},
    "9a": {"nome": "Cholos", "g": "Geni firmati", "corto": "Geni", "gc": 60, "gp": 120, "f": 200, "fg": "Progetto vita", "fc": 160, "fp": 240},
    "9b": {"nome": "Wollow", "g": "Fermacarte megalitici", "corto": "Fermacarte", "gc": 90, "gp": 160, "f": 100, "fg": "Organo a canne portatile", "fc": 80, "fp": 160},
    "10": {"nome": "Qossuth", "g": "Sculture psicotiche", "corto": "Sculture", "gc": 160, "gp": 250, "f": 200, "fg": "Rompicapi infiniti", "fc": 120, "fp": 250},
}

GOODS_COL = {
    "1a": (185, 210, 58), "1b": (210, 58, 42), "2": (164, 102, 196), "3": (240, 216, 74),
    "4a": (168, 168, 168), "4b": (164, 102, 196), "5": (210, 58, 42), "6": (154, 106, 20),
    "7a": (240, 216, 74), "7b": (164, 102, 196), "8": (185, 210, 58), "9a": (210, 58, 42),
    "9b": (185, 210, 58), "10": (164, 102, 196),
}

FARES = [
    ("base", "2", 160), ("base", "4a", 140), ("base", "9a", 110), ("2", "10", 120), ("5", "base", 140),
    ("4a", "base", 180), ("6", "4b", 120), ("7b", "base", 110), ("9b", "5", 110), ("10", "base", 150),
]
DEMANDS = [
    ("1a", "3", 60, 2), ("1a", "4b", 60, 1), ("1b", "3", 60, 1), ("2", "3", 60, 2), ("2", "4b", 40, 4),
    ("3", "4a", 60, 2), ("3", "5", 40, 3), ("4a", "5", 50, 2), ("4a", "7a", 50, 3), ("4a", "7b", 50, 2),
    ("5", "6", 50, 2), ("6", "7b", 50, 3), ("6", "9a", 50, 1), ("6", "9b", 50, 1), ("7a", "8", 60, 1),
    ("7a", "9a", 60, 2), ("8", "9b", 70, 1), ("9a", "10", 60, 2), ("9a", "2", 40, 2), ("10", "2", 90, 1),
]


def bonuses():
    out = []
    for at, to, v in FARES:
        out.append({"t": "fare", "at": at, "to": to, "v": v})
    for g, at, v, n in DEMANDS:
        for k in range(n):
            out.append({"t": "dem", "at": at, "g": g, "v": v})
    return out


RELICS = {
    "airfoil": {"nome": "Profilo alare", "v": 80, "col": (170, 92, 190)},
    "autopilot": {"nome": "Pilota automatico", "v": 80, "col": (170, 92, 190)},
    "gatelock": {"nome": "Blocco porte", "v": 100, "col": (226, 112, 48)},
    "jumpstart": {"nome": "Avvio a salto", "v": 120, "col": (226, 112, 48)},
    "laser": {"nome": "Laser 20", "v": 100, "col": (160, 108, 36)},
    "mulligan": {"nome": "Ingranaggio seconda possibilità", "v": 120, "col": (170, 92, 190)},
    "shield": {"nome": "Scudo -20", "v": 60, "col": (200, 214, 60)},
    "spyeye": {"nome": "Occhio spia", "v": 100, "col": (170, 92, 190)},
    "switch": {"nome": "Scambia-scambia", "v": 100, "col": (170, 92, 190)},
    "ydrive": {"nome": "Propulsore giallo", "v": 80, "col": (160, 108, 36)},
}

PENALTY_FILES = {"E3A460384D091D12F366.png": ("r", 30), "FA6CA5C93C7D3574A88F.png": ("r", 10), "0EB61A17A697A71CD3CF.png": ("y", 30), "DFDBA368E227282885AB.png": ("b", 10), "B9732C0952994E13C006.png": ("b", 40), "69002617669086BFA7B1.png": ("r", 40), "871FF5898249A69830AC.png": ("y", 20), "5F2E5B34F6616B411149.png": ("b", 20), "97764ECD5D4489D40422.png": ("y", 10), "D6BE77F76AE6F8865613.png": ("y", 40), "CB4244461116162D5990.png": ("r", 20), "52DCC682D2A2B9D1F79E.png": ("b", 30)}
IOU_FILES = {"7a": "172F6A1E940B1C00F4D5.png", "5": "B89BB18B2FF5C818B930.png", "10": "B1A6E67C0F9F9A5396BA.png", "8": "ADE3223244D8330407F4.png", "1b": "9B1BB83D4CD31DEFA48A.png", "9b": "2B81E942FF8CDD5DFDD9.png", "6": "347F590DB749DE68EDBB.png", "1a": "D391C201BD0989C93C12.png", "7b": "93716F577DA58D3B93B9.png", "3": "56E052430DC0DF3D9C36.png", "9a": "9895D94B93E81C25F26A.png", "2": "361A32F89DB6A8F7B230.png", "4a": "D14B36CB7E233F414E88.png", "4b": "D4E47D4B1BC2CB24B760.png"}
OPEN_FILE = "B0EC39FFCD29267C641D.png"

SPECIES_BAGS = {"Niks": "nik", "Dell": "dell", "Qossuth": "qossuth", "Humans": "human", "Eeepeeep": "eeep", "Whynoms": "whynom"}

SHIP_NAME = {"scout": "Esploratore", "clipper": "Clipper", "transport": "Trasporto", "freighter": "Mercantile"}
SHIP_DICE = {"scout": 3, "clipper": 4, "transport": 3, "freighter": 2}
SHIP_COST = {"scout": 60, "clipper": 120, "transport": 240, "freighter": 300}
SHIP_TRADE = {"scout": 30, "clipper": 60, "transport": 120, "freighter": 150}

# Posizioni relative (0..1) sulle carte originali: testo da cancellare, stive, testo nuovo.
SHIP_LAYOUT = {
    "freighter": {
        "text": [(0.0, 0.0, 0.66, 0.21), (0.0, 0.20, 0.65, 0.27), (0.82, 0.0, 1.0, 0.25), (0.74, 0.23, 1.0, 0.37), (0.0, 0.83, 0.37, 0.98)],
        "holds": [(0.298, 0.384, 0.455, 0.639), (0.455, 0.384, 0.612, 0.639), (0.612, 0.384, 0.768, 0.639), (0.455, 0.639, 0.612, 0.894), (0.612, 0.639, 0.768, 0.894)],
        "title": (0.03, 0.02, 150), "dice": (0.86, 0.0, 190), "cost": (0.70, 0.24), "per": (0.03, 0.21, 0.6), "hull": (0.03, 0.85), "hull2": True,
    },
    "transport": {
        "text": [(0.0, 0.0, 0.70, 0.18), (0.41, 0.17, 0.74, 0.30), (0.81, 0.0, 1.0, 0.22), (0.72, 0.24, 1.0, 0.39), (0.60, 0.84, 1.0, 0.97)],
        "holds": [(0.122, 0.452, 0.283, 0.707), (0.283, 0.452, 0.444, 0.707), (0.444, 0.452, 0.600, 0.707)],
        "title": (0.03, 0.02, 150), "dice": (0.85, 0.0, 190), "cost": (0.70, 0.25), "per": (0.40, 0.17, 0.3), "per2": True, "hull": (0.60, 0.85), "hull2": True,
    },
    "clipper": {
        "text": [(0.0, 0.0, 0.48, 0.26), (0.48, 0.05, 0.82, 0.24), (0.81, 0.06, 1.0, 0.32), (0.74, 0.30, 1.0, 0.47), (0.62, 0.82, 1.0, 0.98)],
        "holds": [(0.211, 0.441, 0.372, 0.826), (0.372, 0.441, 0.525, 0.826)],
        "title": (0.03, 0.04, 150), "dice": (0.84, 0.03, 190), "cost": (0.70, 0.31), "per": (0.48, 0.07, 0.3), "per2": True, "hull": (0.62, 0.84), "hull2": True,
    },
    "scout": {
        "text": [(0.0, 0.04, 0.44, 0.22), (0.0, 0.22, 0.64, 0.31), (0.81, 0.03, 1.0, 0.29), (0.76, 0.31, 1.0, 0.47), (0.0, 0.86, 0.72, 0.99)],
        "holds": [(0.267, 0.400, 0.420, 0.724), (0.420, 0.400, 0.574, 0.724)],
        "title": (0.03, 0.05, 150), "dice": (0.84, 0.02, 190), "cost": (0.71, 0.31), "per": (0.03, 0.22, 0.6), "hull": (0.03, 0.88),
    },
}
