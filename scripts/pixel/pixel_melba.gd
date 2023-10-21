extends Node2D

@onready var mouth_closed = $MouthClosed
@onready var mouth_open = $MouthOpen
@onready var toast = $Toast
@onready var audio_player = $AudioStreamPlayer
@onready var mouth_animation_player = $MouthAnimationPlayer
@onready var blink_animation_player = $BlinkAnimationPlayer
@onready var reading_animation_player = $ReadingAnimationPlayer

enum States {
    LOOKINGSTRAIGHT,
    READINGCHAT
}

var state: States

func _ready() -> void:
    look_at_chat()
    pass

func _process(_delta: float) -> void:
    if state == States.LOOKINGSTRAIGHT:
        var volume = (AudioServer.get_bus_peak_volume_left_db(0,0) + AudioServer.get_bus_peak_volume_right_db(0,0)) / 2.0
        if volume < -60.0:
            close_mouth()
        else:
            blabber_mouth()


# Functions that needs to be able to be called from a python script 
func play_audio(path: String) -> void:
    look_straight()
    
    # Get file 
    var file = FileAccess.open(path, FileAccess.READ)
    var buffer = file.get_buffer(file.get_length())
    file.close()
    
    # Get bytes
    var stream = AudioStreamWAV.new()
    stream.data = buffer
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    
    # Play sound and animations 
    audio_player.stream = stream
    audio_player.play()
    blabber_mouth()

func toast_toggle() -> void: 
    if toast.visible:
        toast.visible = false
    else:
        toast.visible = true 


# Functions for movement and animation 
func look_straight() -> void: 
    if state != States.LOOKINGSTRAIGHT:
        state = States.LOOKINGSTRAIGHT
        reading_animation_player.play_backwards("look_at_chat") 

func look_at_chat() -> void:
    reading_animation_player.play("look_at_chat")
    state = States.READINGCHAT

func close_mouth() -> void:
    mouth_animation_player.stop()
    mouth_closed.visible = true
    mouth_open.visible = false

func blabber_mouth() -> void:
    mouth_animation_player.play("mouth")
    
func blink() -> void:
    blink_animation_player.play("blink")

func _on_audio_stream_player_finished() -> void:
    look_at_chat()
    close_mouth()

func _on_blink_timer_timeout():
    blink()
