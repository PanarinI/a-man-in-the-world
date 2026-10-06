extends SceneTree
## Снимок кадра сцены — чтобы Клод видел, что собрал (2026-10-06).
## Godot --path igra --script res://tools/snimok.gd -- --scena res://scena2.tscn --kadr 70 --out /путь/к.png

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scena := "res://scena2.tscn"
	var kadr := 0
	var out := "user://snimok.png"
	for i in args.size():
		match args[i]:
			"--scena": scena = args[i + 1]
			"--kadr": kadr = int(args[i + 1])
			"--out": out = args[i + 1]
	var uzel: Node = load(scena).instantiate()
	root.add_child(uzel)
	await process_frame
	if uzel.has_method("pokazat_kadr"):
		uzel.set_process(false)
		uzel.pokazat_kadr(kadr)
	for _i in 4:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("снимок: ", out, " ", img.get_size())
	quit()
