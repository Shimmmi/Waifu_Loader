extends SceneTree

## Stub atlas builder — writes pack.json for the placeholder pack (v0.2 §5.2).

func _init() -> void:
	var out_dir := "res://assets/packs/placeholder"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var pack := {
		"id": "placeholder",
		"phase": "P0",
		"generated_at": Time.get_datetime_string_from_system(),
		"sheets": [],
	}
	var f := FileAccess.open(out_dir.path_join("pack.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(pack, "\t"))
	f.close()
	print("atlas_build: wrote ", out_dir.path_join("pack.json"))
	quit(0)
