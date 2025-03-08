extends Node2D

func _ready():
    var platform_scene = load("res://Platform_3d_test.twscn").instance()
    $SubViewport.set_world_3d(platform_scene)
    $SubViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

    var camera_3d = platform_scene.get_node("Camera3D")
    camera_3d.current = true

func _process(delta):
    var char_position = $Char.global_position
    var camera_3d = $SubViewport.world_3d.get_node("Camera3D")

    if camera_3d:
        camera_3d.global_transform.origin.x = char_position.x
