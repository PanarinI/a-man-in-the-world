extends Node2D
## Сцена по расписанию слоёв (2026-10-06). Расписание и картинки делает tools/scena_iz_aseprite.py из файла
## Aseprite автора: каждый видимый слой — свой Sprite2D, в каждом кадре — своя картинка и место.
## Сейчас сцена проигрывается как у автора (кадр за кадром); отклики на мышь и звук встраиваются поверх слоёв.

@export var papka := "res://scena2"   ## папка с raspisanie.json и картинками слоёв
@export var povtor := false           ## крутить по кругу или остановиться на последнем кадре

var raspisanie := {}
var spraity := []                     # по слою: [Sprite2D, словарь кадров, массив текстур]
var kadr := 0
var vremya_v_kadre := 0.0


func _ready() -> void:
	var f := FileAccess.open(papka + "/raspisanie.json", FileAccess.READ)
	raspisanie = JSON.parse_string(f.get_as_text())
	for sloj in raspisanie["sloi"]:
		var tekstury := []
		var n := 0
		while ResourceLoader.exists("%s/%s_%d.png" % [papka, sloj["fajl_prefiks"], n]):
			tekstury.append(load("%s/%s_%d.png" % [papka, sloj["fajl_prefiks"], n]))
			n += 1
		var s := Sprite2D.new()
		s.centered = false
		s.name = sloj["fajl_prefiks"]
		add_child(s)
		spraity.append([s, sloj["kadry"], tekstury])
	pokazat_kadr(0)


func pokazat_kadr(n: int) -> void:
	kadr = n
	var klyuch := str(n)
	for zapis in spraity:
		var s: Sprite2D = zapis[0]
		var kadry: Dictionary = zapis[1]
		if kadry.has(klyuch):
			var k: Array = kadry[klyuch]
			s.texture = zapis[2][int(k[0])]
			s.position = Vector2(k[1], k[2])
			s.visible = true
		else:
			s.visible = false


func _process(delta: float) -> void:
	var dlit: Array = raspisanie["dlit"]
	vremya_v_kadre += delta * 1000.0
	if vremya_v_kadre < float(dlit[kadr]):
		return
	vremya_v_kadre = 0.0
	if kadr + 1 < dlit.size():
		pokazat_kadr(kadr + 1)
	elif povtor:
		pokazat_kadr(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		pokazat_kadr(0)   # R — сначала (для проверки)
