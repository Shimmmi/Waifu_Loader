extends Node

## Autoload "Loc" — localization (spec §15.9): RU primary, EN secondary.
## All user-facing text goes through t(); data keys (e.g. TREE_CLEARING) are
## themselves localization keys. Named helpers hide raw data ids from UI (v0.2 §2.2).

signal locale_changed(code: String)

const DEFAULT_CODE: String = "ru"

## Canonical species ids (v0.2 §2.3).
const SPECIES_IDS: Array[String] = ["human", "silicate", "android", "gel", "avian"]

var code: String = DEFAULT_CODE
var _tables: Dictionary = {}


func _ready() -> void:
	_tables = Data.table("strings")
	# Apply the saved locale (SaveSystem loads before this autoload).
	var saved: String = String(SaveSystem.settings().get("locale", DEFAULT_CODE))
	if _tables.has(saved):
		code = saved


func t(key: String, args: Array = []) -> String:
	var text: String = _lookup(key)
	if args.is_empty():
		return text
	return text % args


## Short/scaled key: prefers `key_S1|S2|S3` then falls back to `key` (TZ §2.7 G15).
func tr_s(key: String, args: Array = []) -> String:
	var scaled: String = key + "_" + UiScale.mode
	if _tables.get(code, {}).has(scaled) or _tables.get(DEFAULT_CODE, {}).has(scaled):
		return t(scaled, args)
	return t(key, args)


func _lookup(key: String) -> String:
	var table: Dictionary = _tables.get(code, {})
	if table.has(key):
		return String(table[key])
	var fallback: Dictionary = _tables.get(DEFAULT_CODE, {})
	if fallback.has(key):
		return String(fallback[key])
	return key  # visible key so missing strings are obvious


func set_locale(new_code: String) -> void:
	if new_code == code or not _tables.has(new_code):
		return
	code = new_code
	locale_changed.emit(code)


func available() -> Array:
	return _tables.keys()


## Short language code from the OS (best effort; default RU).
func detected() -> String:
	var sys: String = OS.get_locale_language()
	return sys if _tables.has(sys) else DEFAULT_CODE


## Resolve a data-table row's `key` field, or fall back to a synthetic key.
func _key_of(table_name: String, id: String, id_field: String = "id") -> String:
	var table: Dictionary = Data.table(table_name)
	# Most tables nest under a plural array named after the file.
	for nest in [table_name, table_name.trim_suffix("s"), ""]:
		var rows: Variant = table if nest == "" else table.get(nest, null)
		if rows is Array:
			for row in rows:
				if String(row.get(id_field, "")) == id:
					return String(row.get("key", id))
		elif rows is Dictionary and nest == "":
			pass
	# Nested under common plural keys.
	for nest_key in ["classes", "species", "rarities", "sectors", "currencies", "modifiers"]:
		var rows2: Variant = table.get(nest_key, null)
		if rows2 is Array:
			for row2 in rows2:
				if String(row2.get(id_field, "")) == id or (nest_key == "rarities" and String(row2.get("id", "")) == id):
					return String(row2.get("key", id))
	return id


func class_name_of(class_id: String) -> String:
	return t(_key_of("classes", class_id))


func species_name(species_id: String) -> String:
	var id: String = normalize_species(species_id)
	return t(_key_of("species", id))


func rarity_name(tier_or_id: Variant) -> String:
	if tier_or_id is int or tier_or_id is float:
		var rarities: Array = Data.table("rarity").get("rarities", [])
		var idx: int = clampi(int(tier_or_id), 0, maxi(rarities.size() - 1, 0))
		if rarities.is_empty():
			return str(tier_or_id)
		return t(String(rarities[idx].get("key", rarities[idx].get("id", ""))))
	return t(_key_of("rarity", String(tier_or_id)))


func sector_name(type_id: String) -> String:
	return t(_key_of("sectors", type_id))


func station_name(station_id: String) -> String:
	return t("STA_" + station_id.to_upper())


func board_name(board_id: String) -> String:
	return t("BOARD_" + board_id.to_upper())


func mode_name(mode_id: String) -> String:
	return t("MODE_" + mode_id.to_upper())


func modifier_name(mod_id: String) -> String:
	if mod_id.is_empty() or mod_id == "none":
		return ""
	return t(_key_of("sectors", mod_id))  # modifiers live in sectors.json


func currency_name(currency_id: String) -> String:
	return t(_key_of("currencies", currency_id))


## Canonical species id; maps legacy `ovion` → `avian` (v0.2 §2.3).
static func normalize_species(species_id: String) -> String:
	if species_id == "ovion":
		return "avian"
	return species_id
