extends Control

const Icons = preload("res://scripts/icons.gd")
var game: Node3D
var entries: Array = []
var pulse := 0.0

func _ready() -> void:
	entries = [{"kind":"walk","text":"點擊 · 行走"},{"kind":"left","text":"Q / E · 轉橋"},{"kind":"star","text":"微光 · 收集"}]
	if game.chapter>0: entries.append({"kind":"flower","text":"花燈 · 喚醒"})
	if game.level.lift!=null: entries.append({"kind":"lift","text":"空格 · 升降"})
	for entry in entries: entry.icon = Icons.texture(entry.kind)

func _process(dt: float) -> void:
	pulse += dt
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(game): return
	var width := 152.0
	var start := (size.x-(width+10)*entries.size()+10)/2.0
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var active: bool = not game.busy and ((entry.kind=="walk" and not game.rotors.has(game.current)) or (entry.kind=="left" and game.rotors.has(game.current)) or (entry.kind=="lift" and game.level.lift!=null and game.current==game.level.lift.id))
		var rect := Rect2(start+i*(width+10),0,width,46)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1,.99,.96,.93 if active else .70)
		style.set_corner_radius_all(18)
		if active:
			style.shadow_color = Color(1,.99,.86,.38+.12*sin(pulse*1.6))
			style.shadow_size = 9
		draw_style_box(style,rect)
		draw_texture_rect(entry.icon,Rect2(rect.position+Vector2(10,7),Vector2(31,31)),false)
		draw_string(game.font,rect.position+Vector2(49,29),entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("85728e"))
