extends SceneTree
## Проба настоящим вводом (2026-10-06): события мыши идут через Input, как от руки, а не вызовом методов сцены.

var scena: Node


func _initialize() -> void:
	create_timer(60.0).timeout.connect(quit)
	scena = load("res://scena2_igra.tscn").instantiate()
	root.add_child(scena)
	await _zhdat(1.0)
	var okno := Vector2(DisplayServer.window_get_size())
	var mash := okno / Vector2(480, 280)
	print("окно ", okno, " масштаб ", mash)
	var tochka := Vector2(140, 60) * mash
	var dv := InputEventMouseMotion.new()
	dv.position = tochka
	dv.global_position = tochka
	Input.parse_input_event(dv)
	await _zhdat(0.3)
	print("мышь в сцене ", scena.mysh, " наведено ", scena.navedeno)
	for nazhato in [true, false]:
		var kl := InputEventMouseButton.new()
		kl.button_index = MOUSE_BUTTON_LEFT
		kl.pressed = nazhato
		kl.position = tochka
		kl.global_position = tochka
		Input.parse_input_event(kl)
		await _zhdat(0.05)
	await _zhdat(0.5)
	print("после щелчка шаг = ", scena.shag, " (1 = тепло)")
	quit()


func _zhdat(sek: float) -> void:
	await create_timer(sek).timeout
