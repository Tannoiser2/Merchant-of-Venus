#!/usr/bin/env python3
"""Prepara la grafica del gioco dal modulo Tabletop Simulator di Merchant of Venus.

- tabellone (ridotto per il web)
- segnalini e carte rifatti in italiano nello stile originale (colori pieni con il tratteggio
  diagonale, caratteri pesanti): culture, merci, merci di fabbrica, bonus, reliquie, porte tele,
  spazioporti aperti
- immagini originali senza testo: penalità, retro dei "?", pagherò, creature, segnalini
  spazioporto/fabbrica dei mercanti
- carte nave dei sei mercanti: testo inglese cancellato e riscritto in italiano

Uso: python3 tools/genera_segnalini.py <cartella pieces.json del modulo>
(pieces.json è l'elenco dei pezzi estratto dal salvataggio del modulo, con i percorsi delle immagini).
"""
import json, os, sys, math
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont, ImageFilter

Image.MAX_IMAGE_PIXELS = None
RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else "/home/claude/src"
OUT = os.path.join(RADICE, "assets", "tokens")
os.makedirs(OUT, exist_ok=True)
P = json.load(open(os.path.join(SRC, "pieces.json")))
FONT = os.path.join(RADICE, "assets", "fonts")


def font(name, size):
    return ImageFont.truetype(os.path.join(FONT, name), size)


def src(p):
    return os.path.join(SRC, p)


S = 256  # lato dei segnalini


def hatch(col, size=S, dark=0.07):
    """Colore pieno con il tratteggio diagonale fine dei segnalini originali."""
    im = Image.new("RGB", (size, size), col)
    d = ImageDraw.Draw(im)
    c2 = tuple(max(0, int(v * (1 - dark))) for v in col)
    for k in range(-size, size * 2, 5):
        d.line([(k, 0), (k - size, size)], fill=c2, width=1)
    return im


def centered(d, y, text, f, fill=(20, 20, 20), w=S):
    bb = d.textbbox((0, 0), text, font=f)
    d.text(((w - (bb[2] - bb[0])) / 2 - bb[0], y), text, font=f, fill=fill)


def fit_font(d, text, name, size, maxw):
    while size > 8:
        f = font(name, size)
        bb = d.textbbox((0, 0), text, font=f)
        if bb[2] - bb[0] <= maxw:
            return f
        size -= 1
    return font(name, size)


def wrap(d, text, name, size, maxw, maxlines=3):
    words = text.split()
    for sz in range(size, 10, -1):
        f = font(name, sz)
        lines, cur = [], ""
        for w in words:
            t = (cur + " " + w).strip()
            if d.textbbox((0, 0), t, font=f)[2] <= maxw:
                cur = t
            else:
                if cur:
                    lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
        if len(lines) <= maxlines and all(d.textbbox((0, 0), l, font=f)[2] <= maxw for l in lines):
            return f, lines
    return font(name, 10), lines


sys.path.insert(0, os.path.join(RADICE, "tools"))
import dati_segnalini as DS  # noqa: E402

# ------------------------------------------------------------------ immagini originali

def find(pred):
    for p in P:
        if pred(p):
            return p
    return None


def save_src(path, name, size=None, rgba=False):
    im = Image.open(src(path))
    im = im.convert("RGBA" if rgba else "RGB")
    if size:
        im.thumbnail((size, size), Image.LANCZOS)
    ext = ".png" if rgba else ".jpg"
    if rgba:
        im.save(os.path.join(OUT, name + ext))
    else:
        im.save(os.path.join(OUT, name + ext), quality=88)


# tabellone
board = Image.open(src(find(lambda p: p["name"] == "Custom_Tile" and p["scale"][0] == 29.0)["front"])).convert("RGB")
board.save(os.path.join(RADICE, "assets", "board", "tabellone.jpg"), quality=86)

# retro dei "?"
qb = find(lambda p: p["parent"] == "Exploration (Asteriod) Markers")
save_src(qb["back"], "q_retro", S)

# penalità: dai segnalini originali (senza testo)
PEN_COL = {"r": (200, 40, 30), "y": (240, 200, 70), "b": (170, 210, 235)}
pen_imgs = {}
for p in P:
    if p["parent"] != "Exploration (Asteriod) Markers":
        continue
    im = Image.open(src(p["front"])).convert("RGB")
    a = np.asarray(im.resize((64, 64))).reshape(-1, 3).mean(0)
    pen_imgs.setdefault(p["front"], (im, a))
# riconoscimento: colore di fondo + numero letto dal confronto con le cifre (fatto a mano: elenco DS)
for key, (c, v) in DS.PENALTY_FILES.items():
    f = find(lambda p, key=key: p["parent"] == "Exploration (Asteriod) Markers" and p["front"].endswith(key))
    if f:
        save_src(f["front"], "pen_%s%d" % (c, v), S)

# pagherò e creature delle culture, segnalini spazioporto/fabbrica dei mercanti
for p in P:
    if p["parent"] == "IOUs":
        pass
for c, key in DS.IOU_FILES.items():
    f = find(lambda p, key=key: p["parent"] == "IOUs" and p["front"].endswith(key))
    save_src(f["front"], "iou_" + c, S)
for p in P:
    if p["parent"] is None and p.get("tags") == ["Culture"]:
        c = p["nick"].split()[0]
        save_src(p["back"], "creatura_" + c, S)
        # simbolo della scienza (nel riquadro originale, senza testo)
        im = Image.open(src(p["front"])).convert("RGB")
        w, h = im.size
        sym = im.crop((int(w * 0.08), int(h * 0.20), int(w * 0.92), int(h * 0.62)))
        sym.save(os.path.join(OUT, "_sym_" + c + ".png"))
for sp, m in DS.SPECIES_BAGS.items():
    f = find(lambda p, sp=sp: p["parent"] == sp and p["nick"] == "Spaceport / Factory")
    save_src(f["front"], "porto_" + m, 160)
    save_src(f["back"], "fabbrica_" + m, 160)

# ------------------------------------------------------------------ segnalini rifatti

BLUE = (176, 214, 236)


def culture_tile(c):
    d0 = DS.CULT[c]
    im = hatch(BLUE)
    d = ImageDraw.Draw(im)
    f = fit_font(d, "%s %s" % (c, d0["nome"].upper()), "Exo2-Bold.ttf", 40, S - 20)
    d.text((14, 10), "%s %s" % (c, d0["nome"].upper()), font=f, fill=(15, 15, 15))
    sym = Image.open(os.path.join(OUT, "_sym_" + c + ".png"))
    sym.thumbnail((S - 60, 104))
    im.paste(sym, ((S - sym.width) // 2, 64))
    f2 = fit_font(d, "%s: $%d" % (d0["corto"], d0["gc"]), "Exo2-Bold.ttf", 30, S - 24)
    d.text((14, 176), "%s: $%d" % (d0["corto"], d0["gc"]), font=f2, fill=(15, 15, 15))
    d.text((14, 212), "Fabbrica: $%d" % d0["f"], font=font("Exo2-Bold.ttf", 28), fill=(15, 15, 15))
    im.save(os.path.join(OUT, "cultura_%s.png" % c))


def goods_token(c, factory=False):
    d0 = DS.CULT[c]
    col = (226, 112, 40) if factory else DS.GOODS_COL[c]
    im = hatch(col)
    d = ImageDraw.Draw(im)
    cost = d0["fc"] if factory else d0["gc"]
    pay = d0["fp"] if factory else d0["gp"]
    name = d0["fg"] if factory else d0["g"]
    fh = font("Exo2-Bold.ttf", 54)
    d.text((14, 6), c, font=font("Exo2-Bold.ttf", 54), fill=(20, 20, 20))
    bb = d.textbbox((0, 0), "$%d" % cost, font=fh)
    d.text((S - 14 - bb[2], 6), "$%d" % cost, font=fh, fill=(20, 20, 20))
    f, lines = wrap(d, name, "Exo2-Bold.ttf", 40, S - 22, 3)
    lh = f.size + 2
    y0 = 128 - len(lines) * lh // 2 + 6
    for i, l in enumerate(lines):
        centered(d, y0 + i * lh, l, f)
    centered(d, 190, "$%d" % pay, font("Exo2-Bold.ttf", 54))
    if factory:
        d.rectangle([0, 0, S - 1, S - 1], outline=(120, 50, 10), width=3)
    im.save(os.path.join(OUT, ("fabbr_" if factory else "merci_") + c + ".png"))


def bonus_token(i, b):
    im = hatch(BLUE)
    d = ImageDraw.Draw(im)
    if b["t"] == "fare":
        band = DS.GOODS_COL.get(b["to"], (120, 200, 90)) if b["to"] != "base" else (120, 200, 90)
        d.rectangle([0, 0, S, 104], fill=band)
        hb = hatch(band, S)
        im.paste(hb.crop((0, 0, S, 104)), (0, 0))
        d = ImageDraw.Draw(im)
        centered(d, 6, "PASSEGGERO", fit_font(d, "PASSEGGERO", "Exo2-Bold.ttf", 44, S - 16))
        to = "BASE" if b["to"] == "base" else b["to"]
        centered(d, 56, "per " + to, font("Exo2-Bold.ttf", 40))
        centered(d, 140, "$%d" % b["v"], font("Exo2-Bold.ttf", 64))
    else:
        band = DS.GOODS_COL[b["g"]]
        hb = hatch(band, S)
        im.paste(hb.crop((0, 0, S, 150)), (0, 0))
        d = ImageDraw.Draw(im)
        centered(d, 6, "RICHIESTA", fit_font(d, "RICHIESTA", "Exo2-Bold.ttf", 44, S - 16))
        f, lines = wrap(d, DS.CULT[b["g"]]["g"], "Exo2-Bold.ttf", 34, S - 20, 2)
        for k, l in enumerate(lines):
            centered(d, 58 + k * (f.size + 2), l, f)
        centered(d, 160, "+$%d" % b["v"], font("Exo2-Bold.ttf", 64))
    im.save(os.path.join(OUT, "bonus_%d.png" % i))


def relic_token(r):
    d0 = DS.RELICS[r]
    im = hatch(d0["col"])
    d = ImageDraw.Draw(im)
    centered(d, 14, "RELIQUIA", font("Exo2-Bold.ttf", 40))
    f, lines = wrap(d, d0["nome"], "Exo2-Bold.ttf", 40, S - 24, 3)
    lh = f.size + 2
    y0 = 124 - len(lines) * lh // 2
    for k, l in enumerate(lines):
        centered(d, y0 + k * lh, l, f)
    centered(d, 192, "$%d" % d0["v"], font("Exo2-Bold.ttf", 48))
    im.save(os.path.join(OUT, "reliquia_%s.png" % r))


def bolt(d, x, y, s, fill):
    pts = [(x, y), (x + 0.55 * s, y + 0.38 * s), (x + 0.35 * s, y + 0.42 * s), (x + 0.95 * s, y + s),
           (x + 0.32 * s, y + 0.58 * s), (x + 0.52 * s, y + 0.54 * s)]
    d.polygon(pts, fill=fill)


def gate_token(n):
    im = hatch(BLUE)
    d = ImageDraw.Draw(im)
    d.text((22, 8), "PORTA", font=font("Exo2-Bold.ttf", 52), fill=(15, 15, 15))
    d.ellipse([78, 76, 178, 176], fill=(250, 250, 245), outline=(15, 15, 15), width=4)
    centered(d, 84, str(n), font("Exo2-Bold.ttf", 70), fill=(200, 130, 40))
    bolt(d, 178, 48, 54, (15, 15, 15))
    bolt(d, 30, 150, 54, (15, 15, 15))
    bb = d.textbbox((0, 0), "TELE", font=font("Exo2-Bold.ttf", 52))
    d.text((S - 22 - bb[2], 186), "TELE", font=font("Exo2-Bold.ttf", 52), fill=(15, 15, 15))
    im.save(os.path.join(OUT, "porta_%d.png" % n))


def open_port_token():
    f0 = find(lambda p: p["parent"] == "Exploration (Asteriod) Markers" and p["front"].endswith(DS.OPEN_FILE))
    orig = Image.open(src(f0["front"])).convert("RGB")
    w, h = orig.size
    sym = orig.crop((int(w * 0.2), int(h * 0.36), int(w * 0.8), int(h * 0.66)))
    sym = sym.resize((150, int(150 * sym.height / sym.width)))
    im = hatch(BLUE)
    d = ImageDraw.Draw(im)
    centered(d, 10, "SPAZIOPORTO", fit_font(d, "SPAZIOPORTO", "Exo2-Bold.ttf", 44, S - 16))
    im.paste(sym, ((S - sym.width) // 2, 92))
    centered(d, 184, "APERTO", font("Exo2-Bold.ttf", 52))
    im.save(os.path.join(OUT, "porto_aperto.png"))


for c in DS.CULT:
    culture_tile(c)
    goods_token(c)
    goods_token(c, True)
for i, b in enumerate(DS.bonuses()):
    bonus_token(i, b)
for r in DS.RELICS:
    relic_token(r)
for n in range(1, 7):
    gate_token(n)
open_port_token()

# equipaggiamento
def eq_token(e, name, col, col2=None, sub=""):
    im = hatch(col)
    if col2:
        h2 = hatch(col2)
        im.paste(h2.crop((S // 2, 0, S, S)), (S // 2, 0))
    d = ImageDraw.Draw(im)
    f, lines = wrap(d, name, "Exo2-Bold.ttf", 46, S - 24, 3)
    lh = f.size + 2
    y0 = 118 - len(lines) * lh // 2
    for k, l in enumerate(lines):
        centered(d, y0 + k * lh, l, f)
    if sub:
        centered(d, 186, sub, font("Exo2-Bold.ttf", 48))
    im.save(os.path.join(OUT, "eq_%s.png" % e))


eq_token("shield", "SCUDO", (200, 214, 60), sub="-20")
eq_token("ydrive", "PROPULSORE GIALLO", (245, 220, 60), sub="$80")
eq_token("rdrive", "PROPULSORE ROSSO", (214, 60, 44), sub="$120")
eq_token("cdrive", "PROPULSORE COMBINATO", (214, 60, 44), (245, 220, 60), sub="$300")

# retro dei pagherò (cultura ancora nascosta)
im = hatch((236, 236, 230))
d = ImageDraw.Draw(im)
centered(d, 92, "PAGHERÒ", fit_font(d, "PAGHERÒ", "Exo2-Bold.ttf", 56, S - 30))
im.save(os.path.join(OUT, "iou_retro.png"))

# ------------------------------------------------------------------ carte nave in italiano

def ship_card(sp, m, ship, path):
    pim = Image.open(src(path)).convert("RGB")
    w, h = pim.size
    L = DS.SHIP_LAYOUT[ship]
    full = np.asarray(pim)
    samples = []
    for (x0, y0, x1, y1) in L["holds"]:
        X0, Y0, X1, Y1 = int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)
        samples.append(full[Y0 + 10:Y1 - 10, X0 + 10:X1 - 10].reshape(-1, 3))
    arr = np.concatenate(samples)
    lum = arr.mean(1)
    bg = tuple(int(v) for v in np.median(arr[lum >= np.percentile(lum, 50)], 0))
    tex = Image.new("RGB", (w, h), bg)
    td = ImageDraw.Draw(tex)
    c2 = tuple(max(0, int(v * 0.92)) for v in bg)
    for k in range(-h, w + h, 7):
        td.line([(k, 0), (k - h, h)], fill=c2, width=2)
    rects = []
    for (x0, y0, x1, y1) in L["text"]:
        rects.append((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    for (x0, y0, x1, y1) in L["holds"]:
        X0, Y0, X1, Y1 = int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)
        px, py = int((X1 - X0) * 0.07), int((Y1 - Y0) * 0.07)
        rects.append((X0 + px, Y0 + py, X1 - px, Y1 - py))
    # area della carta (le immagini hanno un bordo bianco)
    nonw = (full.astype(int).min(2) < 225) if sum(bg) / 3 > 60 else (full.astype(int).max(2) < 230)
    if sum(bg) / 3 < 60:
        nonw = full.astype(int).max(2) < 200
    rows = np.where(nonw.mean(1) > 0.5)[0]
    cols = np.where(nonw.mean(0) > 0.5)[0]
    if len(rows) < h * 0.3 or len(cols) < w * 0.3 or sum(bg) / 3 > 225:
        cx0, cx1, cy0, cy1 = 0, w, 0, h
    else:
        cx0, cx1, cy0, cy1 = cols.min() + 3, cols.max() - 3, rows.min() + 3, rows.max() - 3
    for r in rects:
        r2 = (max(r[0], cx0), max(r[1], cy0), min(r[2], cx1), min(r[3], cy1))
        if r2[2] > r2[0] and r2[3] > r2[1]:
            pim.paste(tex.crop(r2), r2[:2])
    d = ImageDraw.Draw(pim)
    k = w / 1797.0
    ink = (20, 20, 20) if sum(bg) / 3 > 90 else (235, 235, 230)
    x, y, sz = L["title"]
    d.text((x * w, y * h), DS.SHIP_NAME[ship], font=font("Audiowide-Regular.ttf", int(sz * k)), fill=ink)
    x, y, sz = L["dice"]
    d.text((x * w, y * h), str(DS.SHIP_DICE[ship]), font=font("Audiowide-Regular.ttf", int(sz * k)), fill=ink)
    x, y = L["cost"]
    fc = font("Exo2-Regular.ttf", int(54 * k))
    d.text((x * w, y * h), "Costo: $%d" % DS.SHIP_COST[ship], font=fc, fill=ink)
    d.text((x * w, y * h + 62 * k), "Permuta: $%d" % DS.SHIP_TRADE[ship], font=fc, fill=ink)
    x, y, maxw = L["per"]
    fp = font("Exo2-Regular.ttf", int(40 * k))
    lines = ["Ogni stiva: 1 merce oppure", "2 equipaggiamenti/passeggeri"] if L.get("per2") else ["Ogni stiva: 1 merce oppure 2 equipaggiamenti/passeggeri"]
    for i, l in enumerate(lines):
        d.text((x * w, y * h + i * 46 * k), l, font=fp, fill=ink)
    x, y = L["hull"]
    lines = ["Scafo: 1 scudo", "e tutte le reliquie"] if L.get("hull2") else ["Scafo: 1 scudo e tutte le reliquie"]
    for i, l in enumerate(lines):
        d.text((x * w, y * h + i * 46 * k), l, font=fp, fill=ink)
    for i, (x0, y0, x1, y1) in enumerate(L["holds"]):
        fh = font("Exo2-Bold.ttf", int(46 * k))
        t = "STIVA %d" % (i + 1)
        bb = d.textbbox((0, 0), t, font=fh)
        cx = (x0 + x1) / 2 * w
        d.text((cx - (bb[2] - bb[0]) / 2, y0 * h + 10 * k), t, font=fh, fill=ink)
    pim.thumbnail((900, 900), Image.LANCZOS)
    pim.save(os.path.join(OUT, "nave_%s_%s.jpg" % (m, ship)), quality=88)


for sp, m in DS.SPECIES_BAGS.items():
    for ship, nick in [("scout", "Ship Scout"), ("clipper", "Ship Clipper"), ("transport", "Ship Transport"), ("freighter", "Ship Freighter")]:
        f = find(lambda p, sp=sp, nick=nick: p["parent"] == sp and p["nick"] == nick)
        ship_card(sp, m, ship, f["front"])

json.dump({s: DS.SHIP_LAYOUT[s]["holds"] for s in DS.SHIP_LAYOUT}, open(os.path.join(RADICE, "assets", "data", "stive.json"), "w"))
for f in os.listdir(OUT):
    if f.startswith("_sym_"):
        os.remove(os.path.join(OUT, f))
print("fatto:", len(os.listdir(OUT)), "immagini")
