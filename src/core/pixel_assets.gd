class_name PixelAssets
extends RefCounted

## Art-pack loader (v0.2 §6.2–6.3). P0: procedural coloured silhouettes (no LRU cache).

const SPECIES_COLORS: Dictionary = {
	"human": Color(0.85, 0.70, 0.55),
	"silicate": Color(0.55, 0.35, 0.70),
	"android": Color(0.40, 0.75, 0.85),
	"gel": Color(0.55, 0.85, 0.40),
	"avian": Color(0.95, 0.85, 0.30),
}
const RARITY_COLORS: Dictionary = {
	0: Color(0.60, 0.62, 0.65),
	1: Color(0.30, 0.70, 0.35),
	2: Color(0.25, 0.48, 1.0),
	3: Color(0.60, 0.30, 0.80),
	4: Color(0.96, 0.70, 0.05),
}


static func portrait(worker: Worker, size: int = 48, emotion: String = "") -> Texture2D:
	if emotion == "":
		emotion = worker.expression_state() if worker != null else "neutral"
	return ImageTexture.create_from_image(make_portrait(worker, size, emotion))


static func head_icon(worker: Worker) -> Texture2D:
	return ImageTexture.create_from_image(make_head(worker, 16))


static func icon(id: String, size: int = 16) -> Texture2D:
	return ImageTexture.create_from_image(make_icon(id, size))


static func frames(_worker: Worker, clip: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation(clip)
	sf.set_animation_speed(clip, 8.0)
	sf.set_animation_loop(clip, true)
	sf.add_frame(clip, icon("clip_" + clip, 16))
	return sf


static func species_color(species: String) -> Color:
	var id: String = "avian" if species == "ovion" else (species if species != "" else "human")
	return SPECIES_COLORS.get(id, Color(0.7, 0.7, 0.7))


static func rarity_color(tier: int) -> Color:
	return RARITY_COLORS.get(clampi(tier, 0, 4), Color.WHITE)


static func make_portrait(worker: Worker, size: int, emotion: String) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var sp: String = worker.species if worker else "human"
	var base: Color = species_color(sp)
	var border: Color = rarity_color(worker.rarity if worker else 0)
	img.fill(Color(0, 0, 0, 0))
	_paint(img, Rect2i(2, 2, size - 4, size - 4), base.darkened(0.35))
	_paint(img, Rect2i(size / 4, size / 3, size / 2, size / 2), base)
	_paint(img, Rect2i(size / 3, size / 8, size / 3, size / 3), base.lightened(0.15))
	var eye_y: int = size / 5 + 2
	var eye_c := Color(0.1, 0.1, 0.15)
	if emotion == "happy":
		eye_c = Color(0.2, 0.4, 0.8)
	elif emotion == "tired":
		eye_c = Color(0.4, 0.35, 0.3)
	elif emotion == "annoyed":
		eye_c = Color(0.7, 0.2, 0.2)
	_paint(img, Rect2i(size / 3 + 2, eye_y, 3, 3), eye_c)
	_paint(img, Rect2i(size * 2 / 3 - 5, eye_y, 3, 3), eye_c)
	for x in size:
		img.set_pixel(x, 0, border)
		img.set_pixel(x, size - 1, border)
	for y in size:
		img.set_pixel(0, y, border)
		img.set_pixel(size - 1, y, border)
	_paint(img, Rect2i(size - 10, size - 10, 8, 8), Color(0.3, 0.4, 0.7))
	return img


static func make_head(worker: Worker, size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base: Color = species_color(worker.species if worker else "human")
	_paint(img, Rect2i(1, 1, size - 2, size - 2), base)
	_paint(img, Rect2i(4, 5, 2, 2), Color(0.1, 0.1, 0.15))
	_paint(img, Rect2i(size - 6, 5, 2, 2), Color(0.1, 0.1, 0.15))
	var border: Color = rarity_color(worker.rarity if worker else 0)
	for x in size:
		img.set_pixel(x, 0, border)
		img.set_pixel(x, size - 1, border)
	for y in size:
		img.set_pixel(0, y, border)
		img.set_pixel(size - 1, y, border)
	return img


static func make_icon(id: String, size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var h: float = float(id.hash() % 360) / 360.0
	var c := Color.from_hsv(h, 0.55, 0.85)
	img.fill(c)
	_paint(img, Rect2i(2, 2, size - 4, size - 4), c.lightened(0.2))
	return img


static func _paint(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(maxi(r.position.y, 0), mini(r.position.y + r.size.y, img.get_height())):
		for x in range(maxi(r.position.x, 0), mini(r.position.x + r.size.x, img.get_width())):
			img.set_pixel(x, y, c)
