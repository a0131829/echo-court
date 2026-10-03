extends Control

const Icons = preload("res://scripts/icons.gd")
var game: Node3D
var clock := 0.0
var glow: GradientTexture2D
var icons := {}
var particles: Array = []
var ribbons: Array = []
var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.seed = 907
	glow = GradientTexture2D.new()
	glow.width = 96
	glow.height = 96
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(.5,.5)
	glow.fill_to = Vector2(1,.5)
	glow.gradient = Gradient.new()
	glow.gradient.offsets = PackedFloat32Array([0,.23,.60,1])
	glow.gradient.colors = PackedColorArray([Color(1,1,1,.75),Color(1,1,1,.45),Color(1,1,1,.12),Color(1,1,1,0)])
	for kind in ["walk","left","lift","flower","star","door"]: icons[kind] = Icons.texture(kind,Color("c29cbe"))

func _process(delta: float) -> void:
	clock += delta
	for p in particles:
		p.age += delta
	for r in ribbons:
		r.age += delta
	particles = particles.filter(func(p):return p.age<p.life)
	ribbons = ribbons.filter(func(r):return r.age<r.life)
	queue_redraw()

func burst(at: Vector3, tint: Color, count := 22) -> void:
	for i in range(count):
		var a := random.randf_range(0,TAU)
		var speed := random.randf_range(14,45)
		particles.append({"origin":at,"velocity":Vector2(cos(a),sin(a))*speed+Vector2(0,-15),"age":0.0,"life":random.randf_range(1.1,2.0),"radius":random.randf_range(1.3,3.7),"tint":tint})

func send_light(from: Vector3,to: Vector3) -> void:
	ribbons.append({"from":from,"to":to,"age":0.0,"life":1.8})

func aura(p: Vector2,radius: float,tint: Color,flatten := 1.0) -> void:
	var half := Vector2(radius,radius*flatten)
	draw_texture_rect(glow,Rect2(p-half,half*2),false,tint)

func star(p: Vector2,radius: float,tint: Color,angle := 0.0) -> void:
	var points := PackedVector2Array()
	for i in range(8):
		var a := i*PI/4+angle
		var r := radius if i%2==0 else radius*.27
		points.append(p+Vector2(cos(a),sin(a))*r)
	draw_colored_polygon(points,tint)

func ground_halo(id: String,active: bool,selected: bool) -> void:
	var world: Vector3 = game.node_position(id)+Vector3.UP*.035
	var p: Vector2 = game.camera.unproject_position(world)
	var phase := clock*1.8+float(id.hash()%11)
	var is_dial: bool = game.rotors.has(id)
	var radius := (.46 if is_dial else .28)*(1.0+sin(phase)*.055)
	var points := PackedVector2Array()
	for i in range(49):
		var a := TAU*i/48
		points.append(game.camera.unproject_position(world+Vector3(cos(a)*radius,0,sin(a)*radius)))
	var tint := Color("c1dee8") if active else Color("e1d5ef")
	if selected: tint = Color("f2e5c1")
	var strength := .95 if active or selected else .40
	aura(p,30 if is_dial else 22,Color(tint,strength),.52)
	draw_colored_polygon(points,Color(tint,.58 if active else .23))
	draw_polyline(points,Color(tint,.13*strength),8,true)
	draw_polyline(points,Color(1,.99,.94,.40*strength),4,true)
	draw_polyline(points,Color(1,.99,.95,.9*strength),1.8,true)
	if active and not selected:
		aura(p,6,Color(1,.99,.88,.9))
		draw_circle(p,2.1,Color("fffbed"))
	if selected and is_dial:
		for k in range(2):
			var a := clock*.55+k*PI
			var q: Vector2 = game.camera.unproject_position(world+Vector3(cos(a)*.50,.01,sin(a)*.50))
			star(q,3,Color("fffbed"),clock*.2)

func _draw() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.camera) or glow==null: return
	if not game.won:
		for id in game.visible_nodes():
			var reachable: bool = not game.busy and not game.find_path(game.current,id).is_empty()
			ground_halo(id,reachable,id==game.current)
			var has_light: bool = game.collected.has(id) and not game.collected[id]
			var is_switch: bool = game.is_switch(id)
			var p: Vector2 = game.camera.unproject_position(game.node_position(id)+Vector3.UP*.79)
			if has_light:
				var tint := Color(game.level.collectibles[id].color)
				var breathe := .84+sin(clock*1.8+float(id.hash()%7))*.16
				aura(p,30*breathe,Color(tint,.8))
				aura(p,16,Color(1,.99,.92,.62))
				star(p,8.5*breathe,Color("efd4a1"),PI/2)
				star(p,4.0*breathe,Color("fffbed"),PI/2)
				if is_switch:
					draw_texture_rect(icons.flower,Rect2(p-Vector2(14,14),Vector2(28,28)),false,Color(1,1,1,.85))
				for k in range(4):
					var t := fmod(clock*.22+k*.25+float(id.hash()%9)*.13,1.0)
					var q := p+Vector2(sin(float(k)*2.4+clock*.4)*19,-4-t*28)
					var alpha := sin(t*PI)*.85
					aura(q,7,Color(tint,alpha*.8))
					star(q,1.4+1.2*sin(t*PI),Color(1,.99,.95,alpha),clock*.2)
			if id==game.level.exit and game.all_collected():
				aura(p,44,Color(1,.94,.74,.7))
				draw_texture_rect(icons.door,Rect2(p-Vector2(16,17),Vector2(32,34)),false,Color(1,1,1,.9))
		# Positive action feedback floats above the character only when useful.
		var operation := ""
		if not game.busy and game.rotors.has(game.current): operation = "left"
		if not game.busy and game.level.lift!=null and game.current==game.level.lift.id and game.collected[game.level.lift.key]: operation = "lift"
		if operation!="":
			var at: Vector2 = game.camera.unproject_position(game.pawn.position+Vector3.UP*1.65)
			aura(at,28,Color(1,.98,.86,.68))
			draw_texture_rect(icons[operation],Rect2(at-Vector2(12,12),Vector2(24,24)),false)
		var destination: String = game.hovered
		if destination!="" and not game.busy:
			var route: Array = game.find_path(game.current,destination)
			for i in range(route.size()-1):
				var a: Vector2 = game.camera.unproject_position(game.node_position(route[i])+Vector3.UP*.06)
				var b: Vector2 = game.camera.unproject_position(game.node_position(route[i+1])+Vector3.UP*.06)
				var n := maxi(1,int(a.distance_to(b)/12))
				for j in range(n):
					var t := fmod(float(j)/n+clock*.30,1.0)
					var q := a.lerp(b,t)
					aura(q,5,Color(1,.99,.89,.48))
					draw_circle(q,1.7,Color(1,.99,.93,.80))
			if not route.is_empty() and destination!=game.current:
				var p: Vector2 = game.camera.unproject_position(game.node_position(destination))+Vector2(22,-30)
				aura(p,24,Color(1,1,1,.5))
				draw_texture_rect(icons.walk,Rect2(p-Vector2(12,12),Vector2(24,24)),false)
	# Sidebar collection legend: the same stars used in the world, no hollow dark rings.
	var index := 0
	for id in game.collected:
		var p := Vector2(735+index*31,127)
		var tint := Color(game.level.collectibles[id].color)
		if game.collected[id]:
			aura(p,22,Color(1,.96,.80,.78))
			star(p,10,Color("f2d79d"))
			star(p,5,Color("fffced"))
		else:
			aura(p,15,Color(tint,.52))
			star(p,8,Color(tint,.95))
		index+=1
	for r in ribbons:
		var a: Vector2 = game.camera.unproject_position(r.from)
		var b: Vector2 = game.camera.unproject_position(r.to)
		for j in range(12):
			var t: float = clampf(r.age/r.life-float(j)*.014,0,1)
			var p := a.lerp(b,t)+Vector2(0,-sin(t*PI)*55)
			var alpha := sin(t*PI)*(1-float(j)/13)
			aura(p,11,Color(1,.97,.83,alpha*.7))
			star(p,3,Color(1,.99,.92,alpha))
	for part in particles:
		var p: Vector2 = game.camera.unproject_position(part.origin)+part.velocity*part.age+Vector2(0,part.age*part.age*7)
		var alpha: float = pow(1-part.age/part.life,1.4)
		aura(p,part.radius*4,Color(part.tint,alpha*.65))
		star(p,part.radius,Color(1,.99,.92,alpha),part.age*.7)
