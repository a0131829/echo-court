extends Node

var game: Node3D
var elapsed := 0.0
var timeline: Array = []

func _process(delta: float) -> void:
	elapsed += delta

func mark(event: String) -> void:
	timeline.append({"seconds":snappedf(elapsed,.001),"event":event})
	print("DEMO_CUE ",elapsed," ",event)

func until(seconds: float) -> void:
	while elapsed<seconds: await get_tree().process_frame

func run(owner_game: Node3D) -> void:
	game = owner_game
	game.muted = false
	AudioServer.set_bus_mute(0,false)
	game.hovered = "garden"
	mark("Initial scene; star path shows destination")
	await until(.6)
	game.play_tone("soft")
	mark("Walk from the starting island")
	await game.walk_to("garden")
	game.hovered = ""
	mark("Collect light; sparkle burst and bell")
	await get_tree().create_timer(.4).timeout
	game.hovered = "dial"
	await get_tree().create_timer(.15).timeout
	await game.walk_to("dial")
	game.hovered = ""
	mark("Turntable reached; action icon appears")
	await get_tree().create_timer(.15).timeout
	await game.rotate_bridge(-1)
	mark("Bridge rotation complete; new route is open")
	assert(game.collected.garden and game.current=="dial" and game.turns==1)
	var yaw: float = game.view_controls.yaw
	var pitch: float = game.view_controls.pitch
	var tween := create_tween()
	var duration := maxf(9.65-elapsed,.3)
	mark("Orbit and zoom toward traveler")
	game.play_tone("soft")
	tween.tween_method(func(t: float):
		game.view_controls.yaw = lerpf(yaw,yaw-deg_to_rad(52),t)
		game.view_controls.pitch = lerpf(pitch,deg_to_rad(48),t)
		game.view_controls.zoom = lerpf(1,.84,t)
		game.view_controls.pan = Vector2.ZERO
		game.view_controls.update()
		var viewport: Vector2 = game.get_viewport().get_visible_rect().size
		var center := Vector2(viewport.x*.5,viewport.y*.52)
		var player: Vector2 = game.camera.unproject_position(game.pawn.position)
		game.view_controls.pan = (center-player)*t*.30
		game.view_controls.update()
	,0.0,1.0,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	mark("Final close view; water and star effects continue")
	var file := FileAccess.open("res://video/demo-timeline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(timeline,"\t"))
	print("DEMO_DIRECTOR_FINISHED")
