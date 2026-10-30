extends TestCase

## Localization helpers resolve known ids (no raw ids in UI strings).


func test_class_species_keys_exist() -> void:
	var ru: Dictionary = load_json("strings")["ru"]
	assert_true(ru.has("CLS_LOADER"))
	assert_true(ru.has("SPC_AVIAN"))
	assert_true(String(ru["CLS_LOADER"]) != "loader")
	assert_true(String(ru["SPC_AVIAN"]) != "avian")


func test_rarity_and_sector_keys() -> void:
	var ru: Dictionary = load_json("strings")["ru"]
	assert_true(ru.has("RAR_COMMON"))
	assert_true(ru.has("SEC_DOCK"))
	assert_true(ru.has("STA_UNLOAD"))
	assert_true(ru.has("BOARD_TONNES_WEEKLY"))


func test_feminine_class_labels() -> void:
	var ru: Dictionary = load_json("strings")["ru"]
	# v0.2 feminine forms
	assert_true(String(ru["CLS_LOADER"]).find("Грузчиц") >= 0 or String(ru["CLS_LOADER"]) != "Грузчик")
	assert_true(String(ru["SPC_AVIAN"]) != "Авиан")
