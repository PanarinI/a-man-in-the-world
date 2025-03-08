extends CharacterBody2D

# Скорость движения персонажа
var speed = 200

# Узел AnimatedSprite2D
@onready var sprite = $AnimatedSprite2D

func _physics_process(delta):
    # Обновляем горизонтальное движение
    velocity.x = 0
    if Input.is_action_pressed("left"):
        velocity.x -= speed
        sprite.play("left")  # Запуск анимации "left"
    elif Input.is_action_pressed("right"):
        velocity.x += speed
        sprite.play("right")  # Запуск анимации "right"
    else:
        sprite.play("idle")  # Запуск анимации "idle", если нет движения

    # Применяем движение
    move_and_slide()
