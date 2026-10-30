extends TestCase

## TZ v0.3 §3.4 — structure of docs/art/PROMPTS_LOADERS.md

const PATH: String = "res://docs/art/PROMPTS_LOADERS.md"

const HEADERS: PackedStringArray = [
	"## 0. Как пользоваться",
	"## 1. Правила и ограничения",
	"## 2. Общий промпт (GENERAL)",
	"## 3. Промпты рас (RACE)",
	"## 4. Промпты классов (CLASS)",
	"## 5. Сборка промпта",
	"## 6. Матрица «раса × класс»",
	"## 7. Эмоции",
	"## 8. Типажи (психотипы)",
	"## 9. Контроль качества",
	"## 10. Хранение и учёт результатов",
	"## 11. Приложения",
]

const PROMPT_IDS: PackedStringArray = [
	"GENERAL_STYLE", "GENERAL_STYLE_HIRES", "GENERAL_BG", "GENERAL_SAFE",
	"F1_PORTRAIT", "F2_FULLBODY", "F3_TURNAROUND", "F4_EXPRESSIONS", "F5_ACTION",
	"RACE_HUMAN", "RACE_SILICATE", "RACE_ANDROID", "RACE_GEL", "RACE_AVIAN",
	"CLASS_LOADER", "CLASS_DRIVER", "CLASS_CRANE", "CLASS_STOREKEEPER",
	"CLASS_MECHANIC", "CLASS_FOREMAN",
	"EMO_NEUTRAL", "EMO_JOY", "EMO_TIRED", "EMO_IRRITATED", "EMO_PANIC", "EMO_INJURED",
	"ARCH_WORKAHOLIC", "ARCH_PARTY", "ARCH_GRUMBLER", "ARCH_TRICKSTER", "ARCH_QUIET", "ARCH_REBEL",
]

const NEGATIVE_IDS: PackedStringArray = [
	"GENERAL_NEG",
	"RACE_HUMAN_NEG", "RACE_SILICATE_NEG", "RACE_ANDROID_NEG", "RACE_GEL_NEG", "RACE_AVIAN_NEG",
	"CLASS_LOADER_NEG", "CLASS_DRIVER_NEG", "CLASS_CRANE_NEG", "CLASS_STOREKEEPER_NEG",
	"CLASS_MECHANIC_NEG", "CLASS_FOREMAN_NEG",
]

const FORBIDDEN: PackedStringArray = [
	"loli", "shota", "child", "childlike", "teen", "teenager", "schoolgirl",
	"school uniform", "young girl", "little girl", "nsfw", "nude", "nudity",
	"cleavage", "lingerie", "swimsuit", "bikini", "underwear", "midriff",
	"suggestive", "fanservice", "sexualized",
]


func test_file_exists() -> void:
	assert_true(FileAccess.file_exists(PATH), "PROMPTS_LOADERS.md missing")


func test_headers_order() -> void:
	var text: String = FileAccess.get_file_as_string(PATH)
	var last: int = -1
	for h in HEADERS:
		var idx: int = text.find(h)
		assert_true(idx >= 0, "missing header: " + h)
		assert_true(idx > last, "header out of order: " + h)
		last = idx


func test_prompt_and_negative_tags() -> void:
	var blocks: Array = _fenced_blocks()
	var prompt_tags: Dictionary = {}
	var neg_tags: Dictionary = {}
	for b in blocks:
		var first: String = String(b).get_slice("\n", 0).strip_edges()
		if first.begins_with("# PROMPT:"):
			prompt_tags[first.trim_prefix("# PROMPT:")] = true
		elif first.begins_with("# NEGATIVE:"):
			neg_tags[first.trim_prefix("# NEGATIVE:")] = true
	for id in PROMPT_IDS:
		assert_true(prompt_tags.has(id), "missing # PROMPT:" + id)
	for id in NEGATIVE_IDS:
		assert_true(neg_tags.has(id), "missing # NEGATIVE:" + id)
	assert_eq(PROMPT_IDS.size() + NEGATIVE_IDS.size(), 44, "44 tags total")


func test_race_and_class_h3() -> void:
	var text: String = FileAccess.get_file_as_string(PATH)
	for i in range(1, 6):
		assert_true(text.find("### 3.%d" % i) >= 0, "missing ### 3.%d" % i)
	for i in range(1, 7):
		assert_true(text.find("### 4.%d" % i) >= 0, "missing ### 4.%d" % i)


func test_forbidden_only_in_negative() -> void:
	var blocks: Array = _fenced_blocks()
	var text: String = FileAccess.get_file_as_string(PATH)
	# Strip all fenced blocks to get prose + keep only NEGATIVE block bodies for allowlist.
	var outside: String = text
	var neg_bodies: String = ""
	for b in blocks:
		var body: String = String(b)
		var first: String = body.get_slice("\n", 0).strip_edges()
		outside = outside.replace("```text\n" + body + "\n```", "")
		outside = outside.replace("```\n" + body + "\n```", "")
		# Also try generic fence without language.
		outside = outside.replace("```text\r\n" + body + "\r\n```", "")
		if first.begins_with("# NEGATIVE:"):
			neg_bodies += body.to_lower() + "\n"
		elif first.begins_with("# PROMPT:"):
			var lower: String = body.to_lower()
			for w in FORBIDDEN:
				assert_false(lower.contains(w), "forbidden '%s' inside PROMPT block" % w)
	var outside_lower: String = outside.to_lower()
	for w in FORBIDDEN:
		if outside_lower.contains(w):
			# Allowed only if the word appears solely via leftover NEGATIVE content — already stripped.
			assert_true(false, "forbidden '%s' outside NEGATIVE blocks" % w)


func test_prompts_no_cyrillic() -> void:
	var blocks: Array = _fenced_blocks()
	for b in blocks:
		var body: String = String(b)
		var first: String = body.get_slice("\n", 0).strip_edges()
		if not first.begins_with("# PROMPT:"):
			continue
		for i in body.length():
			var code: int = body.unicode_at(i)
			assert_false(code >= 0x0400 and code <= 0x04FF, "Cyrillic in PROMPT block: " + first)


func _fenced_blocks() -> Array:
	var text: String = FileAccess.get_file_as_string(PATH)
	var out: Array = []
	var pos: int = 0
	while true:
		var start: int = text.find("```", pos)
		if start < 0:
			break
		var after: int = text.find("\n", start)
		if after < 0:
			break
		var end: int = text.find("```", after + 1)
		if end < 0:
			break
		out.append(text.substr(after + 1, end - after - 1).strip_edges())
		pos = end + 3
	return out
