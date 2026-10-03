extends RefCounted

static func texture(kind: String, color := Color("b48fac")) -> ImageTexture:
	var paths := {
		"walk":'<path d="M22 13v27c0 8 5 13 12 13h3c8 0 13-5 13-13V29c0-4-7-4-7 0v4-10c0-4-7-4-7 0v8-12c0-4-7-4-7 0v11-17c0-5-7-5-7 0Z"/><path d="m22 37-5-5c-5-4-10 1-6 6l12 13"/><path d="M16 14h-6M19 6l-4-4M34 8l4-4"/>',
		"left":'<path d="M16 24a20 20 0 1 1-1 20"/><path d="M14 10v17h17"/>',
		"right":'<path d="M48 24a20 20 0 1 0 1 20"/><path d="M50 10v17H33"/>',
		"lift":'<path d="M32 8v48M22 18l10-10 10 10M22 46l10 10 10-10"/><path d="M12 31v8h40v-8"/>',
		"star":'<path d="m32 5 7 19 20 8-20 7-7 20-7-20-20-7 20-8Z" fill="COLOR" stroke="none"/>',
		"flower":'<ellipse cx="32" cy="18" rx="7" ry="12"/><ellipse cx="32" cy="46" rx="7" ry="12"/><ellipse cx="18" cy="32" rx="12" ry="7"/><ellipse cx="46" cy="32" rx="12" ry="7"/><circle cx="32" cy="32" r="6" fill="COLOR"/>',
		"sound":'<path d="M10 25h11l13-12v38L21 39H10Z"/><path d="M43 23q10 9 0 18M49 15q18 17 0 34"/>',
		"mute":'<path d="M10 25h11l13-12v38L21 39H10Z"/><path d="m43 25 14 14m0-14L43 39"/>',
		"reset":'<path d="M16 24a20 20 0 1 1-1 20"/><path d="M14 10v17h17"/>',
		"door":'<path d="M15 55V29a17 17 0 0 1 34 0v26M8 55h48"/><path d="M26 51V28a6 6 0 0 1 12 0v23"/>'
	}
	var hex := "#"+color.to_html(false)
	var body: String = paths.get(kind,paths.star).replace("COLOR",hex)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="none" stroke="%s" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>'%[hex,body]
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)
