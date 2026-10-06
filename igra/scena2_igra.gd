extends Node2D
## Сцена 2 «под стулом» — как игра (2026-10-06). Картинка и кадры — из Aseprite автора (scena2/raspisanie.json),
## здесь — кто из слоёв что играет на каждом шаге и как сцена отвечает игроку.
## Шаги (раскадровка автора и Клода, 06.10): ждём → наведение на стул: стул отзывается → щелчок: под стулом
## загорается тёплый свет (навсегда) → Фотон сам идёт на тепло справа налево → стоит под стулом, дождь глуше →
## реплика по буквам → курсор к левому краю → гаснет, финальный кадр. R — сначала.

const PAPKA := "res://scena2"

enum Shag { ZHDEM, TEPLO, IDET, POD_STULOM, REPLIKA, KRAJ, UHOD, KONEC }

# Какие слои за что отвечают (префиксы файлов из raspisanie.json).
const FON := "05_fon"
const STUL_ZAD := "07_stul_zadnie"
const STUL_PERED := "20_stul_perednie_nozhki"
const FOTON := "08_foton_idle"
const FOTON_IDET := "18_foton_left"
const OBLAKO := "21_textbubble"
const TEKST_1 := "22_text"
const TEKST_2 := "23_text_copy"
const TEMNOTA := "04_white"
const DOZHD := ["10_dozhdinka_put", "11_dozhdinka_put_2", "12_dozhdinka_put_3", "13_dozhdinka_put_4",
		"14_dozhdinka_put_5", "15_dozhdinka", "16_dozhdinka2", "17_dozhdinka3"]

# Отрезки кадров из ролика автора.
const ZHDET := [0, 15]          # Фотон стоит справа
const IDTI := [16, 45]          # идёт к стулу: 30 шагов
const STOYAT := [46, 83]        # стоит под стулом
const NOZHKI_IDET := [16, 49]   # передние ножки меняются, пока он заходит
const NOZHKI_POD := [49, 83]
const GASNET := [84, 117]       # гаснет и финальный кадр с репликой
const POLNYI_KRUG := [0, 90]    # фон и дождь — по кругу

const ZHDAT_TEPLA := 1.6        # сек от щелчка до первого шага
const ZHDAT_REPLIKI := 2.0      # сек под стулом до реплики
const PECHAT_1 := 1.5           # сек на первую строку
const PAUZA_MEZHDU := 0.7
const PECHAT_2 := 0.7
const KRAJ_ZONA := 26.0         # px от левого края, где появляется намёк
const KRAJ_UHOD := 3.0

var raspisanie := {}
var sloi := {}                  # префикс → {sprite, kadry, tex}
var dorozhki := {}              # префикс → {ot, do, krug, kadr, t}
var shag := Shag.ZHDEM
var v_shage := 0.0              # сек с начала шага
var mysh := Vector2(-100, -100)
var stul_obrazy := []           # [Image, позиция] — для попадания мышью по пикселям стула
var teplo: Sprite2D
var kraj: ColorRect
var navedeno := false


func _ready() -> void:
	raspisanie = JSON.parse_string(FileAccess.open(PAPKA + "/raspisanie.json", FileAccess.READ).get_as_text())
	for sloj in raspisanie["sloi"]:
		var p: String = sloj["fajl_prefiks"]
		if p == "01_stul_copy":
			continue                              # лежит под фоном, его не видно
		var tex := []
		var n := 0
		while ResourceLoader.exists("%s/%s_%d.png" % [PAPKA, p, n]):
			tex.append(load("%s/%s_%d.png" % [PAPKA, p, n]))
			n += 1
		var s := Sprite2D.new()
		s.centered = false
		s.name = p
		add_child(s)
		sloi[p] = {"sprite": s, "kadry": sloj["kadry"], "tex": tex}
		if p == STUL_ZAD:
			teplo = _sloj_tepla()
			add_child(teplo)                      # тепло — над задними ножками, под Фотоном
	kraj = ColorRect.new()
	kraj.color = Color(1.0, 0.86, 0.6, 0.0)
	kraj.size = Vector2(2, 280)
	kraj.mouse_filter = Control.MOUSE_FILTER_IGNORE   # не перехватывать мышь у самого края
	add_child(kraj)
	for p in [STUL_ZAD, STUL_PERED]:
		var k: Array = sloi[p]["kadry"]["0"]
		stul_obrazy.append([sloi[p]["tex"][int(k[0])].get_image(), Vector2(k[1], k[2])])
	_nachat(Shag.ZHDEM)


func _sloj_tepla() -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = load(PAPKA + "/teplo.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.modulate.a = 0.0
	return s


# ---------- дорожки: какой слой какой отрезок ролика играет ----------
func igrat(p: String, otrezok: Array, krug: bool) -> void:
	dorozhki[p] = {"ot": otrezok[0], "do": otrezok[1], "krug": krug, "kadr": otrezok[0], "t": 0.0}
	_pokazat(p, otrezok[0])


func ubrat(p: String) -> void:
	dorozhki.erase(p)
	sloi[p]["sprite"].visible = false


func _pokazat(p: String, kadr: int) -> void:
	var s: Sprite2D = sloi[p]["sprite"]
	var kadry: Dictionary = sloi[p]["kadry"]
	if kadry.has(str(kadr)):
		var k: Array = kadry[str(kadr)]
		s.texture = sloi[p]["tex"][int(k[0])]
		s.position = Vector2(k[1], k[2])
		s.visible = true
	else:
		s.visible = false


func _dorozhki(delta: float) -> Array:
	# Двигает все дорожки; возвращает слои, у которых разовый отрезок только что кончился.
	var konchilis := []
	var dlit: Array = raspisanie["dlit"]
	for p in dorozhki.keys():
		var d: Dictionary = dorozhki[p]
		d["t"] += delta * 1000.0
		if d["t"] < float(dlit[d["kadr"]]):
			continue
		d["t"] = 0.0
		if d["kadr"] < d["do"]:
			d["kadr"] += 1
		elif d["krug"]:
			d["kadr"] = d["ot"]
		else:
			if not d.get("konchilsya", false):
				d["konchilsya"] = true
				konchilis.append(p)
			continue
		_pokazat(p, d["kadr"])
	return konchilis


# ---------- шаги ----------
func _nachat(novyi: Shag) -> void:
	shag = novyi
	v_shage = 0.0
	match novyi:
		Shag.ZHDEM:
			igrat(FON, [0, 83], true)
			igrat(STUL_ZAD, [0, 83], true)
			igrat(STUL_PERED, [0, 0], true)
			igrat(FOTON, ZHDET, true)
			for p in DOZHD:
				igrat(p, POLNYI_KRUG, true)
			for p in [FOTON_IDET, OBLAKO, TEKST_1, TEKST_2, TEMNOTA]:
				ubrat(p)
		Shag.TEPLO:
			_stul_svet(false)
		Shag.IDET:
			ubrat(FOTON)
			igrat(FOTON_IDET, IDTI, false)
			igrat(STUL_PERED, NOZHKI_IDET, false)
		Shag.POD_STULOM:
			ubrat(FOTON_IDET)
			igrat(FOTON, STOYAT, true)
			igrat(STUL_PERED, NOZHKI_POD, true)
		Shag.REPLIKA:
			for p in [OBLAKO, TEKST_1, TEKST_2]:
				igrat(p, [56, 56], true)
			_pechat(TEKST_1, 0.0)
			_pechat(TEKST_2, 0.0)
		Shag.UHOD:
			kraj.color.a = 0.0
			for p in sloi.keys():
				if sloi[p]["kadry"].has(str(GASNET[0])) or p == FON:
					igrat(p, GASNET, false)
				else:
					ubrat(p)


func _process(delta: float) -> void:
	v_shage += delta
	var konchilis := _dorozhki(delta)
	match shag:
		Shag.ZHDEM:
			var na_stule := _na_stule(mysh)
			if na_stule != navedeno:
				navedeno = na_stule
				_stul_svet(na_stule)
		Shag.TEPLO:
			teplo.modulate.a = max(0.25, _stupenyami(v_shage / 1.2))
			if v_shage >= ZHDAT_TEPLA:
				_nachat(Shag.IDET)
		Shag.IDET:
			if FOTON_IDET in konchilis:
				_nachat(Shag.POD_STULOM)
		Shag.POD_STULOM:
			_dozhd_glushe(_stupenyami(v_shage / 1.5))
			if v_shage >= ZHDAT_REPLIKI:
				_nachat(Shag.REPLIKA)
		Shag.REPLIKA:
			_pechat(TEKST_1, v_shage / PECHAT_1)
			_pechat(TEKST_2, (v_shage - PECHAT_1 - PAUZA_MEZHDU) / PECHAT_2)
			if v_shage >= PECHAT_1 + PAUZA_MEZHDU + PECHAT_2:
				_nachat(Shag.KRAJ)
		Shag.KRAJ:
			var blizko := clampf(1.0 - mysh.x / KRAJ_ZONA, 0.0, 1.0) if mysh.x >= 0 else 0.0
			kraj.color.a = 0.0 if blizko <= 0.0 else 0.35 + 0.25 * sin(v_shage * 2.4)
			if mysh.x >= 0 and mysh.x <= KRAJ_UHOD:
				_nachat(Shag.UHOD)
		Shag.UHOD:
			teplo.modulate.a = max(0.0, 1.0 - _stupenyami(v_shage / 1.0))
			if TEMNOTA in konchilis:
				shag = Shag.KONEC


# ---------- отклики ----------
func _na_stule(tochka: Vector2) -> bool:
	# Попадание по пикселям стула, а не по прямоугольнику: пустота между ножками — не стул.
	for o in stul_obrazy:
		var img: Image = o[0]
		var lok: Vector2 = (tochka - (o[1] as Vector2)).floor()
		if lok.x >= 0 and lok.y >= 0 and lok.x < img.get_width() and lok.y < img.get_height():
			if img.get_pixelv(Vector2i(lok)).a > 0.5:
				return true
	return false


func _stul_svet(vkl: bool) -> void:
	# Наведение: стул чуть светлеет, под сиденьем едва теплеет — намёк на то, что даст щелчок.
	var c := Color(1.22, 1.16, 1.04) if vkl else Color(1, 1, 1)
	for p in [STUL_ZAD, STUL_PERED]:
		sloi[p]["sprite"].modulate = c
	if shag == Shag.ZHDEM:
		teplo.modulate.a = 0.25 if vkl else 0.0


func _dozhd_glushe(dolya: float) -> void:
	for p in DOZHD:
		sloi[p]["sprite"].modulate.a = 1.0 - 0.45 * dolya


func _pechat(p: String, dolya: float) -> void:
	# Реплика проявляется по буквам: картинка текста открывается слева направо.
	var s: Sprite2D = sloi[p]["sprite"]
	if s.texture == null:
		return
	var w := s.texture.get_width()
	s.region_enabled = true
	var shirina: float = float(w) if dolya >= 1.0 else floor(w * clampf(dolya, 0.0, 1.0) / 3.0) * 3.0
	s.region_rect = Rect2(0, 0, shirina, s.texture.get_height())


func _stupenyami(dolya: float) -> float:
	# Пиксельная игра — и свет включается ступенями, а не плавно.
	return floor(clampf(dolya, 0.0, 1.0) * 4.0) / 4.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		mysh = make_input_local(event).position
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		shchelchok(make_input_local(event).position)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func shchelchok(tochka: Vector2) -> void:
	mysh = tochka
	if shag == Shag.ZHDEM and _na_stule(tochka):
		_nachat(Shag.TEPLO)


# ---------- для проверки (tools/proba_scena2.gd) ----------
func proba_mysh(tochka: Vector2) -> void:
	mysh = tochka
