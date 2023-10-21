extends Window


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _on_close_requested():
	%CloseConfirm.visible = true
	pass

func _on_close_confirm_confirmed():
	get_tree().quit()
	pass
