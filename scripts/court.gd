extends Node3D

const ARM_POS := {"a1":Vector3(-1.4,0,0),"a2":Vector3(-2.8,0,0),"b1":Vector3(0,0,1.4),"b2":Vector3(0,0,2.8)}
const INK := Color("6c586f")
const SECONDARY := Color("79667d")
const PAPER := Color("fdf9f0")
const Icons = preload("res://scripts/icons.gd")
const WATER_Y := -0.38
var book: Dictionary
var level: Dictionary
var chapter := 0
var completed := [false,false,false]
var nodes: Dictionary
var rotors: Dictionary = {}
var current := "start"
var collected: Dictionary = {}
var busy := false
var won := false
var hovered := ""
var turns := 0
var rides := 0
var steps := 0
var clock := 0.0
var film_mode := false
var calm_film := false
var auto_test := false
var capture_mode := false
var muted := false
var world: Node3D
var canvas: CanvasLayer
var camera: Camera3D
var traveler: Node3D
var pawn: Node3D
var portal: MeshInstance3D
var lift: Node3D
var lift_high := false
var gate: Node3D
var sigils: Dictionary = {}
var font := FontVariation.new()
var status: Label
var progress: Label
var turn_label: Label
var hover_label: Label
var left_button: Button
var right_button: Button
var lift_button: Button
var restart_button: Button
var muted_button: Button
var win_panel: PanelContainer
var win_detail: Label
var chapter_buttons: Array[Button] = []
var tone_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var music_duck: Tween
var active_tween: Tween
var effects: Control
var flowers: Dictionary = {}
var view_controls: RefCounted
var water: MeshInstance3D
var water_foundations: Dictionary = {}
var water_last_touch: Dictionary = {}
var water_events := PackedVector4Array()
var water_event_slot := 0

func _ready() -> void:
	font.base_font = load("res://assets/fonts/NotoSerifTC.ttf")
	font.variation_opentype = {"wght":500}
	font.variation_embolden = .45
	book = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"))
	film_mode = "--demo-film" in OS.get_cmdline_user_args()
	calm_film = "--calm-film" in OS.get_cmdline_user_args()
	auto_test = "--self-test" in OS.get_cmdline_user_args()
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	muted = AudioServer.is_bus_mute(0)
	var initial := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chapter="): initial = clampi(int(arg.split("=")[1])-1,0,2)
	tone_player = AudioStreamPlayer.new()
	add_child(tone_player)
	start_music()
	load_level(initial)
	if calm_film: call_deferred("record_calm_demo")
	elif film_mode: call_deferred("record_demo")
	elif "--camera-test" in OS.get_cmdline_user_args(): call_deferred("run_camera_test")
	elif "--effects" in OS.get_cmdline_user_args(): call_deferred("capture_effects")
	elif auto_test: call_deferred("run_self_test")
	elif capture_mode: call_deferred("capture_previews")

func vec(p: Array) -> Vector3:
	return Vector3(float(p[0]),float(p[1]),float(p[2]))

func load_level(index: int) -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	if is_instance_valid(canvas):
		remove_child(canvas)
		canvas.queue_free()
	chapter = index
	level = book.levels[index]
	nodes = level.nodes.duplicate(true)
	current = level.start
	collected.clear()
	for id in level.collectibles: collected[id] = false
	rotors.clear()
	sigils.clear()
	flowers.clear()
	chapter_buttons.clear()
	lift = null
	gate = null
	lift_high = false
	busy = false
	won = false
	hovered = ""
	turns = 0
	rides = 0
	steps = 0
	world = Node3D.new()
	add_child(world)
	build_world()
	build_ui()
	update_ui()

func change_chapter(index: int) -> void:
	if busy: return
	load_level(posmod(index,3))

func material(color: Color, emission := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .85
	if emission:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = .15
	return m

func light_material(color: Color) -> StandardMaterial3D:
	var m := material(color,true)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func is_switch(id: String) -> bool:
	return (level.lift!=null and id==level.lift.key) or (level.has("gate") and id==level.gate.key)

func pearl(parent: Node3D, p: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .5
	sphere.height = 1
	orb.mesh = sphere
	orb.position = p
	orb.scale = size
	orb.material_override = light_material(color)
	parent.add_child(orb)
	return orb

func build_water() -> void:
	water_foundations.clear()
	water_last_touch.clear()
	water_events.clear()
	water_event_slot = 0
	for i in range(12): water_events.append(Vector4(-1,-100,0,0))
	water = MeshInstance3D.new()
	water.name = "PastelShallows"
	var plane := PlaneMesh.new()
	plane.size = Vector2(180,180)
	water.mesh = plane
	water.position.y = WATER_Y
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://shaders/shallow_water.gdshader")
	shader.set_shader_parameter("sky_tint",Color("c2b0dc") if chapter!=2 else Color("deb2c0"))
	shader.set_shader_parameter("pool_tint",Color("9ccddb"))
	shader.set_shader_parameter("mint_tint",Color("afd7bf"))
	shader.set_shader_parameter("foam_tint",Color("fdf9f0"))
	var foundations := PackedVector4Array()
	for id in level.nodes:
		var info: Dictionary = level.nodes[id]
		if info.has("style"):
			var p := vec(info.p)
			water_foundations[id] = foundations.size()
			foundations.append(Vector4(p.x,p.z,.93,0))
	for info in level.rotors:
		var p := vec(info.p)
		water_foundations[info.id] = foundations.size()
		foundations.append(Vector4(p.x,p.z,.44,1))
	if chapter>0:
		foundations.append(Vector4(-6.9,3.7,.36,1) if chapter==1 else Vector4(8,3.3,.36,1))
	shader.set_shader_parameter("footprint_count",foundations.size())
	while foundations.size()<16: foundations.append(Vector4.ZERO)
	shader.set_shader_parameter("footprints",foundations)
	shader.set_shader_parameter("ripple_events",water_events)
	shader.set_shader_parameter("water_time",clock)
	water.material_override = shader
	world.add_child(water)

func touch_water(id: String) -> void:
	var foundation: String = str(nodes.get(id,{}).get("rotor",id))
	if not water_foundations.has(foundation): return
	# A short crossing can touch several path nodes on one bridge. Keep each
	# impulse alive instead of repeatedly restarting the same wavefront.
	if clock-float(water_last_touch.get(foundation,-100.0))<1.4: return
	water_last_touch[foundation] = clock
	water_events[water_event_slot] = Vector4(water_foundations[foundation],clock,1.0,float(steps)*.73)
	water_event_slot = (water_event_slot+1)%12
	water.material_override.set_shader_parameter("ripple_events",water_events)

func build_flower(id: String) -> void:
	var flower := Node3D.new()
	flower.position = node_position(id)+Vector3.UP*.065
	world.add_child(flower)
	flowers[id] = flower
	for k in range(6):
		var a := TAU*k/6
		var petal := pearl(flower,Vector3(cos(a)*.21,.12,sin(a)*.21),Vector3(.25,.13,.36),Color("e1d5ef"))
		petal.rotation.y = -a+PI/2
	pearl(flower,Vector3(0,.17,0),Vector3.ONE*.22,Color("fff3c5"))

func bloom(id: String) -> void:
	if not flowers.has(id): return
	var flower: Node3D = flowers[id]
	var t := flower.create_tween().set_parallel(true)
	for k in range(6):
		var a := TAU*k/6
		var petal: MeshInstance3D = flower.get_child(k)
		petal.material_override = light_material(Color("d2f1e1"))
		t.tween_property(petal,"position",Vector3(cos(a)*.34,.06,sin(a)*.34),action_time(.7)).set_trans(Tween.TRANS_SINE)
		t.tween_property(petal,"scale",Vector3(.30,.12,.44),action_time(.7))
	var destination := node_position(level.lift.id) if level.lift!=null else node_position(level.gate.a)
	effects.send_light(node_position(id)+Vector3.UP*.6,destination+Vector3.UP*.5)

func build_world() -> void:
	var static_scene: Node3D = load("res://assets/court_%d.glb" % (chapter+1)).instantiate()
	world.add_child(static_scene)
	for info in level.rotors:
		var bridge: Node3D = load("res://assets/bridge_%s.glb" % info.tint).instantiate()
		bridge.position = vec(info.p)
		bridge.rotation.y = int(info.orientation)*PI/2
		world.add_child(bridge)
		rotors[info.id] = {"info":info,"mesh":bridge,"orientation":int(info.orientation)}
		nodes[info.id] = {"p":info.p,"name":"中央轉盤" if level.rotors.size()==1 else ("低庭轉盤" if info.id=="lower_dial" else "高庭轉盤")}
		for arm in ARM_POS:
			nodes[info.id+"_"+arm] = {"rotor":info.id,"arm":arm,"hidden":true}
	if level.lift != null:
		lift = load("res://assets/lift.glb").instantiate()
		lift.position = vec(level.lift.p)
		world.add_child(lift)
		nodes[level.lift.id] = {"p":level.lift.p,"name":"升降台"}
	if level.has("gate"):
		gate = Node3D.new()
		gate.position = node_position(level.gate.a) + Vector3(0,0,-1.04)
		world.add_child(gate)
		for k in range(7):
			var x := -.48+k*.16
			pearl(gate,Vector3(x,.35+sin(k*PI/6)*.28,0),Vector3.ONE*.13,Color("f5d4e1"))
	pawn = Node3D.new()
	world.add_child(pawn)
	traveler = load("res://assets/traveler.glb").instantiate()
	traveler.scale = Vector3.ONE * 1.8
	pawn.add_child(traveler)
	pawn.position = node_position(current)
	traveler.rotation.y = PI
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(level.camera_size)
	var focus := vec(level.focus)
	camera.position = focus + Vector3(13,17,22)
	camera.look_at(focus)
	camera.h_offset = -1.6
	camera.current = true
	view_controls = preload("res://scripts/orbit_camera.gd").new()
	view_controls.initialize(self,static_scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(level.background)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d9d2e8")
	env.environment.ambient_light_energy = .32
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	# Match each chapter's opening composition; both visible faces must not be flat-lit.
	sun.rotation_degrees = Vector3(-46,[-28.0,-76.0,-88.0][chapter],0)
	sun.light_color = Color("fff9ee")
	sun.light_energy = .36
	sun.light_angular_distance = 3.0
	sun.shadow_enabled = true
	sun.shadow_bias = .035
	sun.directional_shadow_max_distance = 60
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22,145,0)
	fill.light_color = Color("e1d5ef")
	fill.light_energy = .065
	world.add_child(fill)
	for id in collected:
		var sigil := Node3D.new()
		world.add_child(sigil)
		sigil.position = node_position(id) + Vector3.UP * .70
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = .18
		torus.outer_radius = .225
		torus.rings = 32
		torus.ring_segments = 10
		ring.mesh = torus
		ring.rotation.x = PI/2
		ring.material_override = light_material(Color("fff9e8"))
		ring.visible = false
		sigil.add_child(ring)
		var core := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = .115
		sphere.height = .23
		core.mesh = sphere
		core.material_override = light_material(Color("fff7db"))
		sigil.add_child(core)
		sigils[id] = sigil
	portal = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = .36
	disc.bottom_radius = .36
	disc.height = .025
	portal.mesh = disc
	portal.position = node_position(level.exit) + Vector3.UP * .024
	portal.material_override = light_material(Color("e1d5ef"))
	world.add_child(portal)
	for id in collected:
		if is_switch(id): build_flower(id)
	build_water()

func panel_style(bg: Color, border := Color(0,0,0,0), radius := 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(0)
	s.shadow_color = Color(1,1,.96,.30)
	s.shadow_size = 6
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func label_at(parent: Node, text: String, pos: Vector2, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font",font)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(text: String, action: Callable, width := 130.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width,44)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",16)
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_color_override("font_disabled_color",Color("b5a8b5"))
	b.add_theme_stylebox_override("normal",panel_style(Color("fdf9f0"),Color("ccbdcb")))
	b.add_theme_stylebox_override("hover",panel_style(Color("f5e1e5"),Color("ad8f9e")))
	b.add_theme_stylebox_override("pressed",panel_style(Color("e1d5ef"),INK))
	b.add_theme_stylebox_override("disabled",panel_style(Color("e9e3ea"),Color("dcd4df")))
	b.pressed.connect(action)
	return b

func build_ui() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	canvas.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var marks := Control.new()
	effects = marks
	marks.set_script(preload("res://scripts/markers.gd"))
	marks.game = self
	root.add_child(marks)
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_at(root,"回聲庭院",Vector2(36,24),35)
	label_at(root,"E C H O   C O U R T",Vector2(38,70),11,SECONDARY)
	label_at(root,"%02d   /   %s" % [chapter+1,level.title],Vector2(36,104),18)
	var nav := HBoxContainer.new()
	nav.position = Vector2(36,149)
	nav.add_theme_constant_override("separation",9)
	root.add_child(nav)
	for i in range(3):
		var b := button(("✓ " if completed[i] else "")+"%02d"%(i+1),change_chapter.bind(i),59)
		b.add_theme_font_size_override("font_size",13)
		if i==chapter:
			var selected := panel_style(Color("e1d5ef"))
			selected.shadow_color = Color(1,.99,.9,.8)
			selected.shadow_size = 14
			b.add_theme_stylebox_override("normal",selected)
			b.icon = Icons.texture("star",Color("fff8df"))
			b.add_theme_constant_override("icon_max_width",15)
		nav.add_child(b)
		chapter_buttons.append(b)
	progress = label_at(root,"",Vector2(727,99),15)
	var top := HBoxContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -162
	top.offset_right = -42
	top.offset_top = 29
	top.offset_bottom = 73
	top.add_theme_constant_override("separation",10)
	muted_button = button("",toggle_sound,52)
	muted_button.icon = Icons.texture("mute" if muted else "sound")
	muted_button.add_theme_constant_override("icon_max_width",24)
	muted_button.tooltip_text = "聲音 · M"
	top.add_child(muted_button)
	restart_button = button("",restart,52)
	restart_button.icon = Icons.texture("reset")
	restart_button.add_theme_constant_override("icon_max_width",24)
	restart_button.tooltip_text = "重新開始 · R"
	top.add_child(restart_button)
	var view_bar := HBoxContainer.new()
	root.add_child(view_bar)
	view_bar.position = Vector2(568,149)
	view_bar.add_theme_constant_override("separation",8)
	view_bar.add_child(button("‹",func():view_controls.orbit(Vector2(-30,0)),47))
	view_bar.add_child(button("›",func():view_controls.orbit(Vector2(30,0)),47))
	view_bar.add_child(button("−",func():view_controls.scale_view(1.0/.85),47))
	view_bar.add_child(button("+",func():view_controls.scale_view(.85),47))
	var reset_view := button("⌂",func():view_controls.reset(),47)
	reset_view.tooltip_text = "視角歸位 · Home"
	view_bar.add_child(reset_view)
	label_at(root,"拖動旋轉 · 滾輪 / 雙指縮放",Vector2(334,162),12,SECONDARY)
	hover_label = label_at(root,"",Vector2.ZERO,13,INK)
	var bottom := VBoxContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 28
	bottom.offset_right = -28
	bottom.offset_top = -147
	bottom.offset_bottom = -72
	bottom.add_theme_constant_override("separation",10)
	status = label_at(bottom,"",Vector2.ZERO,17)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation",12)
	bottom.add_child(controls)
	left_button = button("Q",func():rotate_bridge(-1),109)
	left_button.icon = Icons.texture("left")
	left_button.add_theme_constant_override("icon_max_width",25)
	left_button.tooltip_text = "左轉"
	controls.add_child(left_button)
	turn_label = label_at(controls,"",Vector2.ZERO,13,SECONDARY)
	turn_label.custom_minimum_size = Vector2(20,44)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_button = button("E",func():rotate_bridge(1),109)
	right_button.icon = Icons.texture("right")
	right_button.add_theme_constant_override("icon_max_width",25)
	right_button.tooltip_text = "右轉"
	controls.add_child(right_button)
	if level.lift != null:
		lift_button = button("空格",ride_lift,109)
		lift_button.icon = Icons.texture("lift")
		lift_button.add_theme_constant_override("icon_max_width",25)
		controls.add_child(lift_button)
	else: lift_button = null
	var legend := Control.new()
	legend.set_script(preload("res://scripts/legend.gd"))
	legend.game = self
	root.add_child(legend)
	legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -61
	legend.offset_bottom = -12
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_panel = PanelContainer.new()
	root.add_child(win_panel)
	win_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	win_panel.offset_left = -258
	win_panel.offset_right = 258
	win_panel.offset_top = -148
	win_panel.offset_bottom = 148
	win_panel.add_theme_stylebox_override("panel",panel_style(Color(.992,.976,.941,.98),Color("c7b2c8"),18))
	var win_box := VBoxContainer.new()
	win_box.add_theme_constant_override("separation",20)
	win_panel.add_child(win_box)
	var eyebrow := label_at(win_box,"C H A P T E R   %02d   C O M P L E T E"%(chapter+1),Vector2.ZERO,11,SECONDARY)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := label_at(win_box,"微光相逢，歸途已至。" if chapter<2 else "所有微光，終於重逢。",Vector2.ZERO,25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_detail = label_at(win_box,"",Vector2.ZERO,14,SECONDARY)
	win_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_box.add_child(button("下一關  →" if chapter<2 else "回到第一關",func():change_chapter(chapter+1),200))
	win_panel.hide()

func visible_nodes() -> Array:
	var out: Array = []
	for id in nodes:
		if not nodes[id].get("hidden",false): out.append(id)
	return out

func node_position(id: String) -> Vector3:
	if level.lift!=null and id==level.lift.id and is_instance_valid(lift):
		return lift.position + Vector3.UP*.03
	if rotors.has(id): return (rotors[id].mesh as Node3D).position + Vector3.UP*.09
	var nd: Dictionary = nodes[id]
	if nd.has("rotor"):
		return (rotors[nd.rotor].mesh as Node3D).to_global(ARM_POS[nd.arm]) + Vector3.UP*.025
	return vec(nd.p)

func link(graph: Dictionary,a: String,b: String) -> void:
	graph[a].append(b)
	graph[b].append(a)

func connections() -> Dictionary:
	var graph := {}
	for id in nodes: graph[id] = []
	for edge in level.edges:
		if edge in level.gated_edges and not collected[level.gate.key]: continue
		link(graph,edge[0],edge[1])
	for id in rotors:
		var r: Dictionary = rotors[id]
		for arm in ["a","b"]:
			link(graph,id,id+"_"+arm+"1")
			link(graph,id+"_"+arm+"1",id+"_"+arm+"2")
			var tip: Vector3 = vec(r.info.p) + (ARM_POS[arm+"2"] as Vector3).rotated(Vector3.UP,int(r.orientation)*PI/2)
			for port in r.info.ports:
				if tip.distance_to(vec(nodes[port].p)) < 1.5: link(graph,id+"_"+arm+"2",port)
	if level.lift!=null:
		link(graph,level.lift.id,level.lift.upper if lift_high else level.lift.lower)
	return graph

func find_path(start: String,destination: String) -> Array:
	var graph := connections()
	var queue: Array = [start]
	var previous := {start:""}
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if id==destination:
			var route: Array = [id]
			while previous[id]!="":
				id = previous[id]
				route.push_front(id)
			return route
		for next in graph[id]:
			if not previous.has(next):
				previous[next] = id
				queue.append(next)
	return []

func pick_node(pos: Vector2) -> String:
	var best := ""
	var distance := 39.0
	for id in visible_nodes():
		var d := camera.unproject_position(node_position(id)).distance_to(pos)
		if d<distance:
			distance = d
			best = id
	return best

func _unhandled_input(event: InputEvent) -> void:
	if view_controls.input(event): return
	if event is InputEventMouseMotion:
		hovered = pick_node(event.position)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered!="" else Input.CURSOR_ARROW)
		if hovered!="" and not busy and not won:
			hover_label.text = nodes[hovered].get("name","")
			hover_label.position = camera.unproject_position(node_position(hovered)) + Vector2(15,-24)
		else: hover_label.text = ""
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q: rotate_bridge(-1)
			KEY_E: rotate_bridge(1)
			KEY_SPACE: ride_lift()
			KEY_R: restart()
			KEY_M: toggle_sound()
			KEY_ESCAPE: get_tree().quit()

func action_time(seconds: float) -> float:
	if calm_film: return seconds*1.15
	if film_mode: return seconds*.65
	return seconds*.06 if auto_test and not capture_mode else seconds

func walk_to(destination: String) -> void:
	if busy or won: return
	var route := find_path(current,destination)
	if route.is_empty():
		status.text = "先讓路相連 ✦"
		play_tone("soft")
		return
	if destination==current: return
	busy = true
	hover_label.text = ""
	update_ui()
	for i in range(1,route.size()):
		touch_water(current)
		var next: String = route[i]
		var target := node_position(next)
		var direction := target-pawn.position
		if Vector2(direction.x,direction.z).length()>.001: traveler.rotation.y = atan2(direction.x,direction.z)
		active_tween = create_tween()
		# Literal stairs are walked step by step; horizontal treads match Blender geometry.
		if nodes[next].get("hidden",false) and not nodes[next].has("rotor") or nodes[current].get("hidden",false) and not nodes[current].has("rotor"):
			var mid := Vector3(pawn.position.x,target.y,pawn.position.z)
			active_tween.tween_property(pawn,"position",mid,action_time(.035))
			active_tween.tween_property(pawn,"position",target,action_time(maxf(Vector2(direction.x,direction.z).length()/3.0,.035)))
		else:
			active_tween.tween_property(pawn,"position",target,action_time(maxf(direction.length()/3.3,.05))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await active_tween.finished
		current = next
		touch_water(current)
		steps += 1
		collect_at(current)
	busy = false
	traveler.position.y = 0
	if current==level.exit:
		if all_collected():
			won = true
			completed[chapter] = true
			win_detail.text = "%d 枚微光 · %d 次轉橋%s" % [collected.size(),turns," · %d 次升降"%rides if rides>0 else ""]
			win_panel.show()
			play_tone("win")
		else:
			update_ui()
			status.text = "還有微光在等你 ✦"
			return
	update_ui()

func collect_at(id: String) -> void:
	if not collected.has(id) or collected[id]: return
	collected[id] = true
	var sigil: Node3D = sigils[id]
	effects.burst(node_position(id)+Vector3.UP*.7,Color(level.collectibles[id].color))
	bloom(id)
	var t := sigil.create_tween().set_parallel(true)
	t.tween_property(sigil,"scale",Vector3.ONE*.03,action_time(.45))
	t.tween_property(sigil,"position:y",node_position(id).y+1.7,action_time(.45))
	play_tone("collect")
	if level.has("gate") and id==level.gate.key:
		var gt := gate.create_tween()
		gt.tween_property(gate,"scale:y",.02,action_time(.6))
	if all_collected():
		portal.material_override = light_material(Color("fff3ca"))
		effects.send_light(node_position(id)+Vector3.UP*.7,node_position(level.exit)+Vector3.UP*.5)

func rotate_bridge(direction: int) -> void:
	if busy or won: return
	if not rotors.has(current):
		status.text = "先走上發光圓盤"
		return
	busy = true
	hover_label.text = ""
	turns += 1
	update_ui()
	play_tone("turn")
	var r: Dictionary = rotors[current]
	active_tween = create_tween()
	active_tween.tween_property(r.mesh,"rotation:y",r.mesh.rotation.y+direction*PI/2,action_time(.95)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await active_tween.finished
	r.orientation = posmod(int(r.orientation)+direction,4)
	r.mesh.rotation.y = r.orientation*PI/2
	busy = false
	effects.burst(node_position(current),Color("d2f1e1"),10)
	update_ui()

func ride_lift() -> void:
	if busy or won or level.lift==null: return
	if current!=level.lift.id:
		status.text = "先走進升降台"
		return
	if not collected[level.lift.key]:
		status.text = "先點亮花燈 ✦"
		return
	busy = true
	rides += 1
	update_ui()
	play_tone("turn")
	var y: float = float(level.lift.p[1]) if lift_high else float(level.lift.height)
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(lift,"position:y",y,action_time(1.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(pawn,"position:y",y+.03,action_time(1.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await active_tween.finished
	lift_high = not lift_high
	busy = false
	update_ui()

func all_collected() -> bool:
	for value in collected.values():
		if not value: return false
	return true

func update_ui() -> void:
	var count := 0
	for value in collected.values():
		if value: count+=1
	progress.text = "微光  %d / %d" % [count,collected.size()]
	turn_label.text = ""
	left_button.disabled = busy or won or not rotors.has(current)
	right_button.disabled = left_button.disabled
	restart_button.disabled = busy
	for i in range(chapter_buttons.size()):
		chapter_buttons[i].disabled = busy
		chapter_buttons[i].text = ("✓ " if completed[i] else "") + "%02d"%(i+1)
	if is_instance_valid(lift_button):
		lift_button.disabled = busy or won or current!=level.lift.id or not collected[level.lift.key]
		lift_button.text = "空格"
	if won: status.text = "微光相逢 ✦"
	elif busy: status.text = ""
	elif all_collected(): status.text = "前往發光的拱門 ✦"
	elif level.lift!=null and current==level.lift.id:
		status.text = "雲上露台 ✦" if lift_high else ("空格 · 上升" if collected[level.lift.key] else "先點亮花燈 ✦")
	elif rotors.has(current): status.text = "Q / E · 轉橋"
	elif current==level.start: status.text = "點擊微光，出發吧 ✦"
	elif is_switch(current): status.text = "花燈已點亮 ✦"
	else: status.text = ""

func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(water): water.material_override.set_shader_parameter("water_time",clock)
	if not is_instance_valid(pawn): return
	if busy: traveler.position.y = abs(sin(clock*12))*.035
	for id in sigils:
		if not collected[id]:
			var s: Node3D = sigils[id]
			s.position.y = node_position(id).y+.70+sin(clock*1.8+float(id.hash()%5))*.06
			s.rotation.y = clock*.35
	if won: traveler.rotation.y += delta*.35

func play_tone(id: String) -> void:
	if muted or auto_test: return
	tone_player.stream = load("res://assets/"+id+".wav")
	tone_player.play()
	if is_instance_valid(music_player):
		if music_duck and music_duck.is_running(): music_duck.kill()
		music_duck = create_tween()
		music_duck.tween_property(music_player,"volume_db",-14.0,.15)
		music_duck.tween_interval(1.8 if id=="win" else .7)
		music_duck.tween_property(music_player,"volume_db",-10.0,1.4)

func start_music() -> void:
	if auto_test: return
	var track := load("res://assets/courtyard_music.wav") as AudioStreamWAV
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_begin = 0
	track.loop_end = int(track.get_length()*track.mix_rate)
	music_player = AudioStreamPlayer.new()
	music_player.name = "CourtyardMusic"
	music_player.stream = track
	music_player.volume_db = -35
	add_child(music_player)
	music_player.play()
	create_tween().tween_property(music_player,"volume_db",-10.0,3.0)

func toggle_sound() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0,muted)
	muted_button.icon = Icons.texture("mute" if muted else "sound")

func restart() -> void:
	if busy: return
	load_level(chapter)

func save_frame(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("res://preview/"+name+".png")
	assert(result==OK,"Screenshot must save")

func capture_previews() -> void:
	for i in range(3):
		load_level(i)
		await get_tree().process_frame
		for id in visible_nodes():
			assert(pick_node(camera.unproject_position(node_position(id)))==id,"Every visible target must be independently clickable")
		await get_tree().create_timer(.8).timeout
		await save_frame("chapter-%d"%(i+1))
	print("THREE_PREVIEWS_SAVED")
	get_tree().quit()

func run_self_test() -> void:
	for i in range(3):
		load_level(i)
		# Every bridge always connects exactly two ports at all four angles.
		for id in rotors:
			var r: Dictionary = rotors[id]
			for angle in range(4):
				r.orientation = angle
				var graph := connections()
				var connected := 0
				for port in r.info.ports:
					for tip in [id+"_a2",id+"_b2"]:
						if tip in graph[port]: connected+=1
				assert(connected==2,"A turntable must connect precisely two islands")
				r.orientation = 0
		assert(find_path(current,level.exit).is_empty(),"Exit must be disconnected initially")
		var before := current
		await walk_to(level.exit)
		assert(current==before and not won,"A blocked click cannot teleport the traveler")
		var before_turns := turns
		await rotate_bridge(1)
		assert(turns==before_turns,"Cannot rotate while away from a dial")
		if i==1:
			# Check both landings, including the locked state before the key is collected.
			current = "lift"
			pawn.position = node_position(current)
			await ride_lift()
			assert(not lift_high and rides==0,"Lift needs its key")
			assert(find_path("lift","roof").is_empty(),"Lower lift must not connect to roof")
			current = level.start
			pawn.position = node_position(current)
		if i==2:
			assert(find_path("transfer","upper_west").is_empty(),"Grand stair gate must start closed")
		for action in level.solution:
			match action[0]:
				"walk":
					assert(not find_path(current,action[1]).is_empty(),"Walkthrough route must be connected: "+str(action[1]))
					await walk_to(action[1])
					assert(current==action[1])
				"turn": await rotate_bridge(int(action[1]))
				"lift":
					await ride_lift()
					if capture_mode and lift_high: await save_frame("chapter-2-lift-high")
			if i==1 and current=="star":
				assert(lift_high and collected.roof,"Passing a collectible on the route must collect it")
		assert(won and all_collected() and win_panel.visible,"Each chapter must actually complete")
		assert(turns==(4 if i==2 else 2),"Expected solution turn count")
		if i==1: assert(rides==2 and not lift_high,"Lift must support a full round trip")
		if capture_mode: await save_frame("chapter-%d-complete"%(i+1))
		print("CHAPTER_",i+1,"_PASS: steps=",steps," turns=",turns," rides=",rides)
	# A chapter reset must reconstruct every mechanism and collectible.
	load_level(2)
	assert(turns==0 and rides==0 and not won and not all_collected())
	assert(find_path("transfer","upper_west").is_empty())
	load_level(1)
	assert(not lift_high and not collected.key and lift.position.y==2)
	print("SELF_TEST_PASS: three chapters, literal stairs, blocked routes, four rotor states, independent rotors, keyed elevator round trip, gated stairs, intermediate collection, exits, chapter reset")
	get_tree().quit()

func capture_effects() -> void:
	load_level(1)
	await get_tree().create_timer(1.1).timeout
	hovered = "key"
	await save_frame("healing-path")
	await walk_to("key")
	hovered = ""
	await get_tree().create_timer(.23).timeout
	await save_frame("healing-flower-opening")
	await get_tree().create_timer(.65).timeout
	await save_frame("healing-flower-open")
	await walk_to("dial")
	await get_tree().create_timer(.15).timeout
	await save_frame("healing-turn-ready")
	print("HEALING_EFFECTS_CAPTURED: path, flower opening, light transfer, action cue")
	get_tree().quit()

func run_camera_test() -> void:
	auto_test = true
	for i in range(3):
		load_level(i)
		await get_tree().process_frame
		var initial_size: float = camera.size
		for angle in range(8):
			view_controls.yaw = deg_to_rad(angle*45)
			view_controls.update()
			var b: Rect2 = view_controls.bounds()
			var viewport := get_viewport().get_visible_rect().size
			assert(b.position.x>=36 and b.end.x<=viewport.x-36,"Architecture must fit at every yaw")
			assert(b.position.y>=218 and b.end.y<=viewport.y-188,"Portrait framing must protect the HUD")
		view_controls.reset()
		assert(is_equal_approx(camera.size,initial_size))
		var anchor := camera.unproject_position(pawn.position)
		view_controls.scale_view(.7,anchor)
		assert(camera.unproject_position(pawn.position).distance_to(anchor)<.1,"Zoom must stay anchored beneath the pointer")
		assert(camera.size<initial_size*.71)
		view_controls.reset()
		# A real press/move/release sequence rotates without sending a walk action.
		var start := camera.unproject_position(node_position(current))
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = start
		view_controls.input(press)
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = start+Vector2(80,0)
		motion.relative = Vector2(80,0)
		view_controls.input(motion)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = motion.position
		view_controls.input(release)
		assert(not busy and current==level.start,"Dragging must not trigger movement")
		view_controls.reset()
		# Pinching must scale without interpreting the final finger lift as a tap.
		var touch_a := InputEventScreenTouch.new()
		touch_a.index = 0
		touch_a.pressed = true
		touch_a.position = Vector2(400,500)
		var touch_b := InputEventScreenTouch.new()
		touch_b.index = 1
		touch_b.pressed = true
		touch_b.position = Vector2(500,500)
		view_controls.input(touch_a)
		view_controls.input(touch_b)
		var pinch := InputEventScreenDrag.new()
		pinch.index = 1
		pinch.position = Vector2(550,500)
		pinch.relative = Vector2(50,0)
		view_controls.input(pinch)
		assert(view_controls.zoom<.70)
		touch_b.pressed = false
		touch_a.pressed = false
		view_controls.input(touch_b)
		view_controls.input(touch_a)
		assert(not busy and current==level.start)
		view_controls.reset()
		await get_tree().create_timer(.3).timeout
		await save_frame("portrait-%d"%(i+1))
		if i==0:
			var goal := camera.unproject_position(node_position("garden"))
			press.position = goal
			release.position = goal
			view_controls.input(press)
			view_controls.input(release)
			while busy: await get_tree().process_frame
			assert(current=="garden" and collected.garden,"A tap must still walk and collect")
		if i==2:
			view_controls.orbit(Vector2(-95,-14))
			await save_frame("portrait-rotated")
			view_controls.scale_view(.63,camera.unproject_position(pawn.position))
			await save_frame("portrait-closeup")
		print("PORTRAIT_CAMERA_",i+1,"_PASS")
	print("CAMERA_TEST_PASS: 3:4 framing, 24 yaw views, anchored zoom, drag without walking, pinch without false tap, click-to-walk, reset")
	get_tree().quit()

func record_demo() -> void:
	var director := Node.new()
	director.set_script(preload("res://scripts/demo_film.gd"))
	add_child(director)
	director.run(self)

func record_calm_demo() -> void:
	var director := Node.new()
	director.set_script(preload("res://scripts/calm_film.gd"))
	add_child(director)
	director.run(self)
