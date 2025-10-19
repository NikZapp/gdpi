extends Control

func remove():
	queue_free()

func set_text(text : String):
	$RichTextLabel.text = text

func _ready() -> void:
	$AnimationPlayer.play("chat_fade")
