extends Tree
## Planilha editável (manual 1.5.2 e cap. 3): colunas brancas editáveis, amarelas
## somente leitura, lista de opções no botão direito aplicada a todas as células
## selecionadas da coluna, copiar/colar (Ctrl+C / Ctrl+V) e localizar.

signal cells_changed(changes: Array) # [[meta, chave, valor], ...]

const RO_BG := Color(1.0, 0.98, 0.83)
const RW_BG := Color(1.0, 1.0, 1.0)
const PAD := "  "

var cols: Array = []
var choices_fn: Callable # func(chave: String) -> Array
var tint_readonly := true
var _popup: PopupMenu
var _popup_col := -1
var _popup_items: Array = []
var _popup_opts: Array = []


func setup(c: Array) -> void:
	cols = c
	columns = c.size()
	column_titles_visible = true
	hide_root = true
	select_mode = Tree.SELECT_MULTI
	for i in c.size():
		set_column_title(i, str(c[i]["t"]))
		set_column_custom_minimum_width(i, int(c[i].get("w", 80)))
		set_column_expand(i, true)
		set_column_clip_content(i, true)
		set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_CENTER)
	if not item_edited.is_connected(_on_edited):
		item_edited.connect(_on_edited)
	if _popup == null:
		_popup = PopupMenu.new()
		add_child(_popup)
		_popup.id_pressed.connect(_on_popup)


static func fmt(v, dec: int) -> String:
	return (("%." + str(dec) + "f") % float(v)).replace(".", ",")


static func num(s: String) -> float:
	return s.strip_edges().replace(" ", "").replace(",", ".").to_float()


func _scrollbars() -> Array:
	var out := [null, null]
	for ch in get_children(true):
		if ch is VScrollBar:
			out[0] = ch
		elif ch is HScrollBar:
			out[1] = ch
	return out


func set_rows(rows: Array) -> void:
	var sb := _scrollbars()
	var v0: float = sb[0].value if sb[0] != null else 0.0
	var h0: float = sb[1].value if sb[1] != null else 0.0
	clear()
	var root := create_item()
	for r in rows:
		var it := create_item(root)
		_fill(it, r)
	if sb[0] != null:
		_restore_scroll.call_deferred(v0, h0)


func _restore_scroll(v0: float, h0: float) -> void:
	var sb := _scrollbars()
	if sb[0] != null:
		sb[0].value = v0
	if sb[1] != null:
		sb[1].value = h0


func _fill(it: TreeItem, r: Dictionary) -> void:
	it.set_metadata(0, r.get("_meta"))
	var st: Dictionary = r.get("_st", {})
	var ro: Array = r.get("_ro", [])
	for c in cols.size():
		var spec: Dictionary = cols[c]
		var k: String = spec["k"]
		var f: String = spec["f"]
		var edit: bool = bool(spec.get("edit", false)) and not k in ro and r.has(k)
		var val = r.get(k, "")
		it.set_meta("ed%d" % c, edit)
		if f == "chk":
			it.set_cell_mode(c, TreeItem.CELL_MODE_CHECK)
			if r.has(k):
				it.set_checked(c, bool(val))
			it.set_editable(c, edit)
		else:
			it.set_cell_mode(c, TreeItem.CELL_MODE_STRING)
			if f == "s" or f == "choice":
				it.set_text(c, str(val))
			elif val is String:
				it.set_text(c, str(val) + PAD if str(val) != "" else "")
			else:
				it.set_text(c, fmt(val, int(f.substr(1))) + PAD)
			if f.begins_with("f"):
				it.set_text_alignment(c, HORIZONTAL_ALIGNMENT_RIGHT)
			elif spec.has("align"):
				it.set_text_alignment(c, spec["align"])
			it.set_editable(c, edit and f != "choice")
		if st.has("bg"):
			it.set_custom_bg_color(c, st["bg"])
		elif tint_readonly:
			it.set_custom_bg_color(c, RW_BG if edit else RO_BG)
		if st.has("color"):
			it.set_custom_color(c, st["color"])
		if st.has("cores") and st["cores"].has(k):
			it.set_custom_color(c, st["cores"][k])


func _on_edited() -> void:
	var it := get_edited()
	var c := get_edited_column()
	if it == null or c < 0:
		return
	var spec: Dictionary = cols[c]
	var f: String = spec["f"]
	var v
	if f == "chk":
		v = it.is_checked(c)
	elif f == "s":
		v = it.get_text(c).strip_edges()
	else:
		v = num(it.get_text(c))
		it.set_text(c, fmt(v, int(f.substr(1))) + PAD)
	cells_changed.emit([[it.get_metadata(0), spec["k"], v]])


func _selected_in_col(c: int) -> Array:
	var out: Array = []
	var it := get_next_selected(null)
	while it != null:
		if it.is_selected(c):
			out.append(it)
		it = get_next_selected(it)
	return out


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var it := get_item_at_position(event.position)
		var c := get_column_at_position(event.position)
		if it == null or c < 0:
			return
		var spec: Dictionary = cols[c]
		if str(spec["f"]) != "choice" or not bool(it.get_meta("ed%d" % c, false)):
			return
		if not it.is_selected(c):
			deselect_all()
			it.select(c)
		_popup_col = c
		_popup_items = _selected_in_col(c)
		_popup_opts = choices_fn.call(str(spec["k"])) if choices_fn.is_valid() else []
		_popup.clear()
		_popup.add_separator(str(spec["t"]))
		for i in _popup_opts.size():
			_popup.add_item(str(_popup_opts[i]), i)
		_popup.position = Vector2i(get_tree().root.get_mouse_position())
		_popup.reset_size()
		_popup.popup()
		accept_event()
	elif event is InputEventKey and event.pressed and event.is_command_or_control_pressed():
		if event.keycode == KEY_C or event.keycode == KEY_INSERT:
			copiar()
			accept_event()
		elif event.keycode == KEY_V:
			colar()
			accept_event()
	elif event is InputEventKey and event.pressed and event.shift_pressed and event.keycode == KEY_INSERT:
		colar()
		accept_event()


func _on_popup(id: int) -> void:
	if id < 0 or id >= _popup_opts.size():
		return
	var v = _popup_opts[id]
	var changes: Array = []
	for it in _popup_items:
		if not is_instance_valid(it) or not bool(it.get_meta("ed%d" % _popup_col, false)):
			continue
		it.set_text(_popup_col, str(v))
		changes.append([it.get_metadata(0), cols[_popup_col]["k"], v])
	if not changes.is_empty():
		cells_changed.emit(changes)


func _cell_text(it: TreeItem, c: int) -> String:
	if it.get_cell_mode(c) == TreeItem.CELL_MODE_CHECK:
		return "Sim" if it.is_checked(c) else "Não"
	return it.get_text(c).strip_edges()


func copiar() -> void:
	var linhas: Array = []
	var it := get_next_selected(null)
	while it != null:
		var cel: Array = []
		for c in cols.size():
			if it.is_selected(c):
				cel.append(_cell_text(it, c))
		if not cel.is_empty():
			linhas.append("\t".join(PackedStringArray(cel)))
		it = get_next_selected(it)
	if not linhas.is_empty():
		DisplayServer.clipboard_set("\n".join(PackedStringArray(linhas)))


func colar() -> void:
	var start := get_selected()
	var c0 := get_selected_column()
	if start == null or c0 < 0:
		return
	var txt := DisplayServer.clipboard_get().replace("\r", "")
	if txt.ends_with("\n"):
		txt = txt.substr(0, txt.length() - 1)
	var changes: Array = []
	var it := start
	for linha in txt.split("\n"):
		if it == null:
			break
		var partes := linha.split("\t")
		for j in partes.size():
			var c := c0 + j
			if c >= cols.size():
				break
			var spec: Dictionary = cols[c]
			var f: String = spec["f"]
			var s := partes[j].strip_edges()
			if f == "chk":
				if not it.is_editable(c):
					continue
				var b := s.to_lower() in ["sim", "s", "1", "true", "x", "verdadeiro"]
				it.set_checked(c, b)
				changes.append([it.get_metadata(0), spec["k"], b])
			elif f == "choice":
				if not bool(it.get_meta("ed%d" % c, false)):
					continue
				var ops: Array = choices_fn.call(str(spec["k"])) if choices_fn.is_valid() else []
				if s in ops:
					it.set_text(c, s)
					changes.append([it.get_metadata(0), spec["k"], s])
			elif it.is_editable(c):
				if f == "s":
					it.set_text(c, s)
					changes.append([it.get_metadata(0), spec["k"], s])
				else:
					var v := num(s)
					it.set_text(c, fmt(v, int(f.substr(1))) + PAD)
					changes.append([it.get_metadata(0), spec["k"], v])
		it = it.get_next()
	if not changes.is_empty():
		cells_changed.emit(changes)


## Seleciona a próxima célula que contém o texto. Retorna true se achou.
func localizar(texto: String, proxima: bool) -> bool:
	var root := get_root()
	if root == null or texto == "":
		return false
	var alvo := texto.to_lower()
	var cells: Array = []
	var it := root.get_first_child()
	while it != null:
		for c in cols.size():
			cells.append([it, c])
		it = it.get_next()
	var ini := 0
	if proxima:
		var cur := get_selected()
		var cc := get_selected_column()
		for k in cells.size():
			if cells[k][0] == cur and cells[k][1] == cc:
				ini = k + 1
				break
	for k in cells.size():
		var idx := (ini + k) % cells.size()
		var cell: Array = cells[idx]
		if _cell_text(cell[0], cell[1]).to_lower().contains(alvo):
			deselect_all()
			cell[0].select(cell[1])
			scroll_to_item(cell[0], true)
			return true
	return false


## Cabeçalho e linhas como texto (para exportar).
func dados() -> Array:
	var out: Array = []
	var head: Array = []
	for c in cols:
		head.append(str(c["t"]))
	out.append(head)
	var root := get_root()
	if root == null:
		return out
	var it := root.get_first_child()
	while it != null:
		var linha: Array = []
		for c in cols.size():
			linha.append(_cell_text(it, c))
		out.append(linha)
		it = it.get_next()
	return out
