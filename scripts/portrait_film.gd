extends "res://scripts/calm_film.gd"
# Recording-only presentation. Normal game UI and controls are unchanged.
var shot := 0
var caption: Label

func mark(event: String) -> void:
	super.mark(event)
	if event=="opening":
		game.music_player.stop()
		var ui: Control = game.effects.get_parent()
		for child in ui.get_children():
			if child != game.effects and child is CanvasItem: child.hide()
		var title: Label = game.label_at(ui,"回聲庭院",Vector2(0,44),36)
		title.size.x = 900
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var subtitle: Label = game.label_at(ui,"E C H O   C O U R T",Vector2(0,94),10)
		subtitle.size.x = 900
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption = game.label_at(ui,"01   /   喚醒微光",Vector2(0,1120),18)
		caption.size.x = 900
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		frame_shot(0)
	elif event=="bridge_ready":
		caption.text="02   /   轉動歸途"
		frame_shot(1)
	elif event=="lift_ready":
		caption.text="03   /   雲上赴光"
		frame_shot(2)
	elif event=="exit_ready":
		caption.text="04   /   微光相逢"
		frame_shot(3)
	elif event=="complete":
		game.win_panel.hide()
		caption.text="微光相逢，歸途已至。"
	elif event=="end":
		var file := FileAccess.open("res://video/portrait-timeline.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(timeline,"\t"))

func frame_shot(index: int) -> void:
	shot=index
	if camera_tween and camera_tween.is_running(): camera_tween.kill()
	game.view_controls.yaw=deg_to_rad([-32,28,-28,-12][shot])
	game.view_controls.pitch=deg_to_rad([42,52,36,42][shot])
	game.view_controls.zoom=[.80,.68,.80,.94][shot]
	compose()

func compose() -> void:
	game.view_controls.pan=Vector2.ZERO
	game.view_controls.update()
	var focus: Vector3=game.node_position(["key","dial","lift","exit"][shot])
	var screen: Vector2=game.camera.unproject_position(focus)
	var size: Vector2=game.get_viewport().get_visible_rect().size
	var weight: float=[.45,.75,.50,0.0][shot]
	game.view_controls.pan=(Vector2(size.x*.5,size.y*.55)-screen)*weight
	game.view_controls.update()

func view_to(_yaw_degrees: float,_zoom: float,duration: float) -> void:
	if camera_tween and camera_tween.is_running(): camera_tween.kill()
	var yaw_start: float=game.view_controls.yaw
	var zoom_start: float=game.view_controls.zoom
	var yaw_end: float=deg_to_rad([-18,12,-43,8][shot])
	var zoom_end: float=[.74,.73,.88,1.03][shot]
	camera_tween=create_tween()
	camera_tween.tween_method(func(t: float):
		game.view_controls.yaw=lerpf(yaw_start,yaw_end,t)
		game.view_controls.zoom=lerpf(zoom_start,zoom_end,t)
		compose()
	,0.0,1.0,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
