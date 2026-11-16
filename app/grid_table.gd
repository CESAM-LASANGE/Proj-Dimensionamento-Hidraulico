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
## Colunas fixas à esquerda: ao rolar para a direita, uma faixa desenhada por cima repete
## as primeiras colunas (como "congelar painéis" nas planilhas).
var congeladas := 0
var _fixas: Control


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


func set_congeladas(n: int) -> void:
	congeladas = clampi(n, 0, cols.size())
	if congeladas == 0 or _fixas != null:
		return
	_fixas = Control.new()
	_fixas.name = "ColunasFixas"
	_fixas.visible = false
	_fixas.clip_contents = true
	_fixas.mouse_filter = Control.MOUSE_FILTER_PASS
	_fixas.draw.connect(_desenhar_fixas)
	_fixas.gui_input.connect(_fixas_input)
	add_child(_fixas)
	for sb in _scrollbars():
		if sb != null:
			sb.value_changed.connect(func(_v): _atualizar_fixas())
	resized.connect(_atualizar_fixas)
	draw.connect(func(): _atualizar_fixas.call_deferred())


func _hscroll() -> float:
	var sb = _scrollbars()[1]
	return sb.value if sb != null and sb.visible else 0.0


func largura_fixas() -> float:
	var w := 0.0
	for c in congeladas:
		w += get_column_width(c)
	return w


## Estado da faixa de colunas fixas (para os testes).
func fixas_info() -> Dictionary:
	return {"colunas": congeladas, "visivel": _fixas != null and _fixas.visible, "largura": largura_fixas(),
		"margem": get_theme_stylebox("panel").get_margin(SIDE_LEFT),
		"rect": _fixas.get_rect() if _fixas != null else Rect2()}


func _atualizar_fixas() -> void:
	if _fixas == null:
		return
	var root := get_root()
	var mostrar := congeladas > 0 and _hscroll() > 0.5 and root != null and root.get_first_child() != null
	_fixas.visible = mostrar
	if not mostrar:
		return
	var panel := get_theme_stylebox("panel")
	var esq := panel.get_margin(SIDE_LEFT)
	var topo := panel.get_margin(SIDE_TOP)
	var base := panel.get_margin(SIDE_BOTTOM)
	var hs = _scrollbars()[1]
	if hs != null and hs.visible:
		base += hs.size.y
	# a faixa começa em x = 0: o Tree também desenha o conteúdo rolado dentro da margem do painel
	_fixas.position = Vector2(0, topo)
	_fixas.size = Vector2(minf(esq + largura_fixas() + 3.0, size.x * 0.7), maxf(size.y - topo - base, 0.0))
	_fixas.queue_redraw()


func _desenhar_fixas() -> void:
	var root := get_root()
	if root == null or root.get_first_child() == null:
		return
	var c := _fixas
	var vs = _scrollbars()[0]
	var v := float(vs.value) if vs != null else 0.0
	var primeiro := root.get_first_child()
	var hh := get_item_area_rect(primeiro, 0).position.y + v - c.position.y
	var panel := get_theme_stylebox("panel")
	var ox := panel.get_margin(SIDE_LEFT)
	c.draw_style_box(panel, Rect2(0, -c.position.y, c.size.x + 40.0, size.y)) # borda esquerda do painel
	var fundo := (panel as StyleBoxFlat).bg_color if panel is StyleBoxFlat else Color.WHITE
	c.draw_rect(Rect2(ox, 0, c.size.x - ox, c.size.y), fundo)
	var fonte := get_theme_font("font")
	var fs := get_theme_font_size("font_size")
	var cor_txt := get_theme_color("font_color")
	var cor_sel := get_theme_color("font_selected_color")
	var guia := get_theme_color("guide_color")
	var sel_box := get_theme_stylebox("selected_focus" if has_focus() else "selected")
	var asc := fonte.get_ascent(fs)
	var alt := fonte.get_height(fs)
	var it := primeiro
	while it != null:
		var r0 := get_item_area_rect(it, 0)
		var y := r0.position.y - c.position.y
		if y > c.size.y:
			break
		if y + r0.size.y >= hh:
			var x := ox
			for col in congeladas:
				var w := get_column_width(col)
				var cel := Rect2(x, y, w, r0.size.y)
				var bg: Color = it.get_meta("bg%d" % col, Color(0, 0, 0, 0))
				if it.is_selected(col):
					c.draw_style_box(sel_box, cel)
				elif bg.a > 0.0:
					c.draw_rect(cel, bg)
				var txt := it.get_text(col).strip_edges()
				if txt != "":
					var tw := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
					var tx := x + 6.0
					match it.get_text_alignment(col):
						HORIZONTAL_ALIGNMENT_RIGHT:
							tx = x + w - tw - 8.0
						HORIZONTAL_ALIGNMENT_CENTER:
							tx = x + (w - tw) / 2.0
					var cor: Color = it.get_meta("fc%d" % col, Color(0, 0, 0, 0))
					if it.is_selected(col):
						cor = cor_sel
					elif cor.a <= 0.0:
						cor = cor_txt
					c.draw_string(fonte, Vector2(tx, y + (r0.size.y - alt) / 2.0 + asc), txt, HORIZONTAL_ALIGNMENT_LEFT, w - 8.0, fs, cor)
				c.draw_line(Vector2(x + w - 0.5, y), Vector2(x + w - 0.5, y + r0.size.y), guia, 1.0)
				x += w
			c.draw_line(Vector2(ox, y + r0.size.y - 0.5), Vector2(x, y + r0.size.y - 0.5), guia, 1.0)
		it = it.get_next()
	# títulos por cima das linhas
	var tb := get_theme_stylebox("title_button_normal")
	var tf := get_theme_font("title_button_font")
	var tfs := get_theme_font_size("title_button_font_size")
	var tc := get_theme_color("title_button_color")
	var x2 := ox
	for col in congeladas:
		var w := get_column_width(col)
		var rr := Rect2(x2, 0, w, hh)
		c.draw_style_box(tb, rr)
		var linhas := get_column_title(col).split("\n")
		var lh := tf.get_height(tfs)
		var y0 := (hh - lh * linhas.size()) / 2.0 + tf.get_ascent(tfs)
		for k in linhas.size():
			c.draw_string(tf, Vector2(x2, y0 + k * lh), linhas[k], HORIZONTAL_ALIGNMENT_CENTER, w, tfs, tc)
		x2 += w
	# borda que separa as colunas fixas das que rolam
	c.draw_line(Vector2(x2 + 1.0, 0), Vector2(x2 + 1.0, c.size.y), Color(0.35, 0.4, 0.5, 0.9), 2.0)


## Clique na faixa fixa seleciona a célula correspondente sem mexer na rolagem horizontal;
## a roda do mouse segue para a planilha.
func _fixas_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	_fixas.accept_event()
	var p: Vector2 = ev.position + _fixas.position
	var it := get_item_at_position(p)
	if it == null:
		return
	var x := get_theme_stylebox("panel").get_margin(SIDE_LEFT)
	var col := 0
	for k in congeladas:
		x += get_column_width(k)
		if ev.position.x < x:
			col = k
			break
	var hs = _scrollbars()[1]
	var h0: float = hs.value if hs != null else 0.0
	if not ev.is_command_or_control_pressed():
		deselect_all()
	it.select(col)
	grab_focus()
	if hs != null:
		(func(): hs.value = h0).call_deferred()
	_fixas.queue_redraw()


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
		# as cores ficam também nos metadados: get_custom_bg_color()/get_custom_color() devolvem
		# preto opaco quando não há cor própria (usado pela faixa de colunas fixas)
		var bgc := Color(0, 0, 0, 0)
		if st.has("bg"):
			bgc = st["bg"]
		elif tint_readonly:
			bgc = RW_BG if edit else RO_BG
		if bgc.a > 0.0:
			it.set_custom_bg_color(c, bgc)
		it.set_meta("bg%d" % c, bgc)
		var fc := Color(0, 0, 0, 0)
		if st.has("color"):
			fc = st["color"]
		if st.has("cores") and st["cores"].has(k):
			fc = st["cores"][k]
		if fc.a > 0.0:
			it.set_custom_color(c, fc)
		it.set_meta("fc%d" % c, fc)


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
