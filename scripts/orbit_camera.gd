extends RefCounted

var game: Node3D
var points := PackedVector3Array()
var yaw := 0.0
var pitch := deg_to_rad(42.0)
var zoom := 1.0
var mouse_down := false
var moved := false
var origin := Vector2.ZERO
var pan := Vector2.ZERO
var mouse_pan := false
var touches := {}
var touch_dragged := false

func initialize(owner_game: Node3D, geometry: Node3D) -> void:
	game = owner_game
	points.clear()
	gather(geometry)
	reset()

func gather(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var box := mesh_node.get_aabb()
		for i in range(8): points.append(mesh_node.to_global(box.get_endpoint(i)))
	for child in node.get_children(): gather(child)

func reset() -> void:
	yaw = deg_to_rad([30.0,-18.0,-32.0][game.chapter])
	pitch = deg_to_rad(42.0)
	zoom = 1.0
	pan = Vector2.ZERO
	mouse_down = false
	touches.clear()
	update()

func orbit(delta: Vector2) -> void:
	yaw -= delta.x*.007
	pitch = clampf(pitch+delta.y*.004,deg_to_rad(25),deg_to_rad(68))
	update()

func scale_view(factor: float, anchor := Vector2(-1,-1)) -> void:
	var before := zoom
	zoom = clampf(zoom*factor,.44,1.45)
	if anchor.x>=0:
		var size: Vector2 = game.get_viewport().get_visible_rect().size
		var center := Vector2(size.x/2,(220+size.y-190)/2)
		pan = anchor-center-(anchor-center-pan)/(zoom/before)
	update()

func bounds() -> Rect2:
	var b := Rect2(game.camera.unproject_position(points[0]),Vector2.ZERO)
	for p in points: b = b.expand(game.camera.unproject_position(p))
	return b

func update() -> void:
	if not is_instance_valid(game.camera) or points.is_empty(): return
	var camera: Camera3D = game.camera
	var focus: Vector3 = game.vec(game.level.focus)
	camera.h_offset = 0
	camera.v_offset = 0
	camera.position = focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*38
	camera.look_at(focus)
	camera.size = 30
	var viewport: Vector2 = game.get_viewport().get_visible_rect().size
	var stage := Rect2(38,220,viewport.x-76,viewport.y-410)
	var initial := bounds()
	var fit := maxf(initial.size.x/stage.size.x,initial.size.y/stage.size.y)
	camera.size = 30*fit*zoom
	var framed := bounds()
	var correction := framed.get_center()-stage.get_center()-pan
	var pixel := camera.size/viewport.y
	camera.h_offset = correction.x*pixel
	camera.v_offset = -correction.y*pixel

# Returning true means this event belongs to viewing, not walking.
func input(event: InputEvent) -> bool:
	if event is InputEventMagnifyGesture:
		scale_view(1.0/maxf(event.factor,.01),event.position)
		return true
	if event is InputEventPanGesture:
		orbit(event.delta*9)
		return true
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:
			scale_view(.90,event.position)
			return true
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			scale_view(1.0/.90,event.position)
			return true
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				mouse_down = true
				mouse_pan = event.button_index==MOUSE_BUTTON_MIDDLE or event.shift_pressed
				moved = event.button_index!=MOUSE_BUTTON_LEFT or mouse_pan
				origin = event.position
			else:
				var click: bool = mouse_down and not moved and event.button_index==MOUSE_BUTTON_LEFT
				mouse_down = false
				if click:
					var id: String = game.pick_node(event.position)
					if id!="": game.walk_to(id)
			return true
	if event is InputEventMouseMotion and mouse_down:
		if event.button_mask==0:
			mouse_down = false
			return true
		if event.position.distance_to(origin)>9: moved = true
		if moved:
			if mouse_pan:
				pan += event.relative
				update()
			else: orbit(event.relative)
			game.hovered = ""
			game.hover_label.text = ""
		return true
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size()==1:
				origin = event.position
				touch_dragged = false
			else: touch_dragged = true
		else:
			var click: bool = touches.size()==1 and not touch_dragged
			touches.erase(event.index)
			if click:
				var id: String = game.pick_node(event.position)
				if id!="": game.walk_to(id)
		return true
	if event is InputEventScreenDrag:
		if not touches.has(event.index): return true
		if touches.size()>=2:
			var ids := touches.keys()
			var old: float = (touches[ids[0]] as Vector2).distance_to(touches[ids[1]])
			touches[event.index] = event.position
			var next: float = (touches[ids[0]] as Vector2).distance_to(touches[ids[1]])
			if next>8: scale_view(old/next,((touches[ids[0]] as Vector2)+(touches[ids[1]] as Vector2))*.5)
			touch_dragged = true
		else:
			if event.position.distance_to(origin)>9: touch_dragged = true
			if touch_dragged: orbit(event.relative)
			touches[event.index] = event.position
		return true
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: orbit(Vector2(-12,0));return true
			KEY_RIGHT: orbit(Vector2(12,0));return true
			KEY_UP: orbit(Vector2(0,-10));return true
			KEY_DOWN: orbit(Vector2(0,10));return true
			KEY_EQUAL,KEY_PLUS: scale_view(.9);return true
			KEY_MINUS: scale_view(1/.9);return true
			KEY_HOME: reset();return true
	return false
