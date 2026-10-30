extends TestCase


func test_manifest_and_required_clips() -> void:
	var manifest: Dictionary = load_json("art_manifest")
	var anims: Dictionary = load_json("animations")
	assert_true(not manifest.is_empty())
	var have: Dictionary = {}
	for c in anims.get("clips", []):
		have[String(c["id"])] = true
	for req in manifest.get("required_clips", []):
		assert_true(have.has(String(req)), "missing clip " + String(req))


func test_pixel_assets_fallback_portrait() -> void:
	var w := Worker.new()
	w.id = "art_test"
	w.species = "avian"
	w.class_id = "loader"
	w.rarity = 2
	w.full_name = "Test"
	var tex: Texture2D = PixelAssets.portrait(w, 48, "neutral")
	assert_true(tex != null)
	assert_eq(tex.get_width(), 48)
	var head: Texture2D = PixelAssets.head_icon(w)
	assert_true(head != null)
	assert_eq(head.get_width(), 16)
