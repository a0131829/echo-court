extends Node

var game: Node3D
var elapsed := 0.0
var timeline: Array = []
var camera_tween: Tween

func _process(delta: float) -> void:
	elapsed += delta

func mark(event: String) -> void:
	timeline.append({"seconds":snappedf(elapsed,.001),"event":event})
	print("CALM_CUE ",elapsed," ",event)

func pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func view_to(yaw_degrees: float, zoom: float, duration: float) -> void:
	if camera_tween and camera_tween.is_running(): camera_tween.kill()
	var start_yaw: float = game.view_controls.yaw
	var start_zoom: float = game.view_controls.zoom
	camera_tween = create_tween()
	camera_tween.tween_method(func(t: float):
		game.view_controls.yaw = lerpf(start_yaw,deg_to_rad(yaw_degrees),t)
		game.view_controls.zoom = lerpf(start_zoom,zoom,t)
		game.view_controls.update()
	,0.0,1.0,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func run(owner_game: Node3D) -> void:
	game = owner_game
	game.load_level(1)
	game.muted = false
	AudioServer.set_bus_mute(0,false)
	mark("opening")
	game.hovered = "key"
	view_to(-27,.94,9.0)
	await pause(1.5)
	mark("walk_key_start")
	game.play_tone("soft")
	await game.walk_to("key")
	mark("switch_open")
	await pause(2.5)
	mark("switch_hold_end")
	game.hovered = "dial"
	await game.walk_to("dial")
	game.hovered = ""
	mark("bridge_ready")
	await pause(1.2)
	view_to(-12,.95,7)
	mark("bridge_start")
	await game.rotate_bridge(-1)
	mark("bridge_end")
	await pause(1.8)
	mark("bridge_hold_end")
	game.hovered = "lift"
	await game.walk_to("lift")
	game.hovered = ""
	mark("lift_ready")
	view_to(-24,.91,10)
	await pause(1.3)
	mark("lift_start")
	await game.ride_lift()
	mark("lift_end")
	await pause(1.2)
	game.hovered = "star"
	await game.walk_to("star")
	game.hovered = ""
	mark("star_collected")
	await pause(2.2)
	mark("star_hold_end")
	await game.walk_to("lift")
	await game.ride_lift()
	await game.walk_to("dial")
	await game.rotate_bridge(-1)
	mark("exit_ready")
	view_to(0,1.04,12)
	game.hovered = "exit"
	await pause(1.5)
	mark("exit_walk")
	await game.walk_to("exit")
	game.hovered = ""
	assert(game.won and game.all_collected() and game.rides==2 and game.turns==2)
	mark("complete")
	await pause(4.5)
	mark("end")
	var file := FileAccess.open("res://video/calm-timeline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(timeline,"\t"))
	print("CALM_FILM_COMPLETE")
	get_tree().quit()
