extends TestCase

## v0.2 §2.3 — ovion → avian on Worker.from_dict.


func test_worker_from_dict_rewrites_ovion() -> void:
	var w := Worker.from_dict({
		"id": "w_old", "full_name": "Bird", "species": "ovion", "class_id": "loader",
	})
	assert_eq(w.species, "avian")


func test_worker_avian_unchanged() -> void:
	var w := Worker.from_dict({
		"id": "w_new", "full_name": "Bird", "species": "avian", "class_id": "loader",
	})
	assert_eq(w.species, "avian")
