class_name Shop
extends RefCounted

## Cosmetics shop (spec §12.5): buy skins/frames/titles/banners/avatars with
## Tokens and equip one per category. Owned items come from achievements too.

var cats: Dictionary = {}


static func from_data(d: Dictionary) -> Shop:
	var s := Shop.new()
	s.cats = d.get("categories", {})
	return s


func category_names() -> Array:
	return cats.keys()


func items(cat: String) -> Array:
	return cats.get(cat, [])


func price(cat: String, id: String) -> int:
	for row in cats.get(cat, []):
		if row["id"] == id:
			return int(row.get("price", 0))
	return 0


func key_of(cat: String, id: String) -> String:
	for row in cats.get(cat, []):
		if row["id"] == id:
			return String(row.get("key", id))
	return id


## Returns the Token cost if buyable, else -1 (already owned or too expensive).
func cost_if_buyable(cat: String, id: String, owned: Array, tokens: float) -> int:
	if owned.has(id):
		return -1
	var p: int = price(cat, id)
	if p <= 0 or tokens < float(p):
		return -1
	return p


func equip(cat: String, id: String, equipped: Dictionary, owned: Array) -> bool:
	if not owned.has(id):
		return false
	equipped[cat] = id
	return true