extends Area2D

@onready var kill_timer: Timer = $KillTimer

func _on_body_entered(body: Node2D) -> void:
	kill_timer.start()

func _on_kill_timer_timeout() -> void:
	get_tree().reload_current_scene()
