class_name SpoutManager

var spout: Spout
var spout_texture: ViewportTexture

func init(texture: ViewportTexture) -> void:
	spout = Spout.new()
	spout.set_sender_name("Melba Toaster")
	spout_texture = texture
	print("Spout2 initialized")

func send_texture() -> void:
	var img := spout_texture.get_image()
	spout.send_image(img, img.get_width(), img.get_height(), Spout.FORMAT_RGBA, false)
