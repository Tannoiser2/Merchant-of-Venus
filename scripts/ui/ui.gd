class_name UI
extends RefCounted
## Grafica condivisa. Tema "Avalon Hill 1988": il nero dello spazio profondo del tabellone, il
## ciano dei cerchi di navigazione e delle caselle, il rosso cromato del logo MERCHANT OF VENUS.
## Caratteri liberi (OFL): Audiowide per i titoli (lettering cromato anni Ottanta), Orbitron per le
## intestazioni e i pulsanti, Exo 2 per i testi, Share Tech Mono per i numeri.

const SPACE := Color("#05060f")
const PANEL := Color("#0c1124")
const PANEL_L := Color("#16203d")
const CYAN := Color("#62e3f0")
const CYAN_D := Color("#1f7f95")
const CYAN_L := Color("#b8f4fa")
const RED := Color("#ff2b2b")
const RED_D := Color("#9c1010")
const GOLD := Color("#ffd23a")
const BLUE := Color("#3db0cf")
const TEXT := Color("#e6ecff")
const MUTED := Color("#8e9bc0")
const GREEN := Color("#58e07a")
const WHITE := Color("#ffffff")

static var font_title: Font
static var font_head: Font
static var font_body: Font
static var font_bold: Font
static var font_mono: Font
static var _tex := {}


static func init_fonts() -> void:
	if font_title != null:
		return
	font_title = load("res://assets/fonts/Audiowide-Regular.ttf")
	font_head = load("res://assets/fonts/Orbitron-Bold.ttf")
	font_body = load("res://assets/fonts/Exo2-Regular.ttf")
	font_bold = load("res://assets/fonts/Exo2-Bold.ttf")
	font_mono = load("res://assets/fonts/ShareTechMono-Regular.ttf")


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func make_theme() -> Theme:
	init_fonts()
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", CYAN_L)
	t.set_color("font_hover_color", "Button", WHITE)
	t.set_color("font_pressed_color", "Button", SPACE)
	t.set_color("font_hover_pressed_color", "Button", SPACE)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.45, 0.6))
	t.set_font("font", "Button", font_head)
	t.set_font_size("font_size", "Button", 17)
	t.set_stylebox("normal", "Button", box(Color("#0e1a33"), CYAN_D, 2, 6))
	t.set_stylebox("hover", "Button", box(Color("#15284a"), CYAN, 2, 6))
	t.set_stylebox("pressed", "Button", box(CYAN, CYAN_L, 2, 6))
	t.set_stylebox("disabled", "Button", box(Color("#0b1020"), Color("#26304a"), 1, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("normal", "LineEdit", box(Color("#070b18"), CYAN_D, 2, 6))
	t.set_stylebox("focus", "LineEdit", box(Color("#070b18"), CYAN, 2, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", CYAN)
	t.set_stylebox("panel", "PopupMenu", box(PANEL, CYAN_D, 2, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", CYAN)
	t.set_stylebox("hover", "PopupMenu", box(PANEL_L, CYAN_D, 0, 4))
	t.set_stylebox("normal", "OptionButton", box(Color("#0e1a33"), CYAN_D, 2, 6))
	t.set_stylebox("hover", "OptionButton", box(Color("#15284a"), CYAN, 2, 6))
	t.set_stylebox("pressed", "OptionButton", box(Color("#15284a"), CYAN, 2, 6))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_font("font", "OptionButton", font_bold)
	t.set_stylebox("scroll", "VScrollBar", box(Color("#0a0f1e"), Color("#0a0f1e"), 0, 4, 2))
	t.set_stylebox("grabber", "VScrollBar", box(CYAN_D, CYAN_D, 0, 4, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(CYAN, CYAN, 0, 4, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(CYAN_L, CYAN_L, 0, 4, 2))
	t.set_stylebox("scroll", "HScrollBar", box(Color("#0a0f1e"), Color("#0a0f1e"), 0, 4, 2))
	t.set_stylebox("grabber", "HScrollBar", box(CYAN_D, CYAN_D, 0, 4, 2))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, CYAN, 2, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 17)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", CYAN)
	t.set_color("font_pressed_color", "CheckBox", CYAN_L)
	t.set_color("font_hover_pressed_color", "CheckBox", CYAN)
	t.set_font("font", "CheckBox", font_body)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font_body)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_font("mono_font", "RichTextLabel", font_mono)
	t.set_stylebox("panel", "TabContainer", panel_style())
	return t


static func box(bg: Color, border: Color, bw := 2, radius := 6, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 2
	s.content_margin_right = pad + 2
	s.content_margin_top = pad - 3
	s.content_margin_bottom = pad - 3
	return s


static func panel_style(alpha := 0.92) -> StyleBoxFlat:
	var s := box(Color(PANEL, alpha), Color(CYAN_D, 0.9), 2, 10, 12)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 8
	return s


static func label(text: String, size := 20, col := TEXT, f: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if f != null:
		l.add_theme_font_override("font", f)
	return l


static func title(text: String, size := 40) -> Label:
	var l := label(text, size, RED, font_title)
	l.add_theme_color_override("font_outline_color", Color("#ffe4e4"))
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_shadow_color", Color(0.5, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


static func head(text: String, size := 20, col := CYAN) -> Label:
	return label(text, size, col, font_head)


static func button(text: String, cb: Callable, size := 17) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	return b


static func red_button(text: String, cb: Callable, size := 18) -> Button:
	var b := button(text, cb, size)
	b.add_theme_stylebox_override("normal", box(RED_D, RED, 2, 6))
	b.add_theme_stylebox_override("hover", box(Color("#c41818"), Color("#ffb0b0"), 2, 6))
	b.add_theme_stylebox_override("pressed", box(Color("#ffdddd"), WHITE, 2, 6))
	b.add_theme_color_override("font_color", WHITE)
	return b


static func rich(size := 18) -> RichTextLabel:
	init_fonts()
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("mono_font_size", size)
	return r


static func money(v: int) -> String:
	return "$%d" % v


## Sfondo di stelle (menu e regole): campo stellato con la nebulosa azzurra del tabellone
class Starfield:
	extends Control
	var stars: Array = []
	var t := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := RandomNumberGenerator.new()
		g.seed = 1988
		for i in 420:
			stars.append([Vector2(g.randf(), g.randf()), g.randf_range(0.6, 2.4), g.randf(), g.randf_range(0.5, 3.0)])

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var r := get_rect()
		draw_rect(Rect2(Vector2.ZERO, r.size), SPACE)
		# nebulosa
		for i in 7:
			var c := Vector2(r.size.x * (0.2 + 0.11 * i), r.size.y * (0.5 + 0.18 * sin(i * 1.7)))
			draw_circle(c, r.size.y * (0.22 + 0.04 * (i % 3)), Color(0.25, 0.55, 0.85, 0.035))
		for s in stars:
			var p: Vector2 = s[0] * r.size
			var a := 0.55 + 0.45 * sin(t * s[3] + s[2] * 10.0)
			draw_circle(p, s[1], Color(0.85, 0.92, 1.0, a))
