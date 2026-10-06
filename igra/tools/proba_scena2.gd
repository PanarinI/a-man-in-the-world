extends SceneTree
## Проба сцены 2 как игры (2026-10-06): проходит все шаги и снимает кадр на каждом — чтобы Клод видел.
## Godot --path igra --script res://tools/proba_scena2.gd -- --out /папка/для/снимков

var out := "user://"
var scena: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out = args[i + 1]
	create_timer(90.0).timeout.connect(quit)   # страховка: если сцена упала, окно не висит
	scena = load("res://scena2_igra.tscn").instantiate()
	root.add_child(scena)
	await _zhdat(1.0)
	_snimok("1_zhdem")
	scena.proba_mysh(Vector2(140, 60))          # спинка стула
	await _zhdat(0.3)
	_snimok("2_navedenie")
	scena.proba_mysh(Vector2(300, 60))          # мимо стула — отклик гаснет
	await _zhdat(0.2)
	_snimok("2b_mimo")
	scena.shchelchok(Vector2(250, 50))          # щелчок мимо — ничего
	await _zhdat(0.3)
	print("после щелчка мимо шаг = ", scena.shag)
	scena.shchelchok(Vector2(140, 60))          # щелчок по стулу
	await _zhdat(1.3)
	_snimok("3_teplo")
	await _zhdat(3.0)
	_snimok("4_idet")
	await _zhdat(4.0)
	_snimok("5_pod_stulom")
	await _zhdat(2.6)
	_snimok("6_pechat")
	await _zhdat(2.0)
	_snimok("7_replika")
	scena.proba_mysh(Vector2(12, 150))
	await _zhdat(0.4)
	_snimok("8_kraj")
	scena.proba_mysh(Vector2(1, 150))
	await _zhdat(0.8)
	_snimok("9_gasnet")
	await _zhdat(7.0)
	_snimok("10_konec")
	print("шаг в конце = ", scena.shag)
	quit()


func _zhdat(sek: float) -> void:
	await create_timer(sek).timeout


func _snimok(imya: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, imya])
	print("снимок ", imya, " шаг=", scena.shag)
