extends SceneTree

## Temporary probe: does an HTTPRequest reach the live backend from this machine?

func _init() -> void:
	_probe()


func _probe() -> void:
	await process_frame
	var req := HTTPRequest.new()
	get_root().add_child(req)
	req.request_completed.connect(_done)
	print("probe: inside_tree=", req.is_inside_tree(), " root=", get_root())
	var url := "https://shimmirpgbot.ru/tupik9/api/v1/global"
	var err := req.request(url)
	print("probe: request() returned err=", err, " for ", url)


func _done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("probe: result=", result, " code=", code, " body=", body.get_string_from_utf8().substr(0, 200))
	quit(0)