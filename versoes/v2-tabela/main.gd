extends Control
## Janela principal do DimEsgoto: dimensionamento de redes coletoras de esgoto.

const Calc = preload("res://calc.gd")
const ProfileView = preload("res://profile_view.gd")
const APP_NAME := "DimEsgoto"
const VERSAO := "2.0"

const IN_COLS := [
	{"t": "Nº", "k": "", "w": 44, "f": ""},
	{"t": "Coletor", "k": "coletor", "w": 72, "f": "s"},
	{"t": "Trecho", "k": "trecho", "w": 72, "f": "s"},
	{"t": "PV montante", "k": "pv_m", "w": 104, "f": "s"},
	{"t": "PV jusante", "k": "pv_j", "w": 104, "f": "s"},
	{"t": "Extensão (m)", "k": "L", "w": 104, "f": "f2"},
	{"t": "CT montante (m)", "k": "ct_m", "w": 128, "f": "f3"},
	{"t": "CT jusante (m)", "k": "ct_j", "w": 120, "f": "f3"},
	{"t": "Q conc. inicial (L/s)", "k": "qc_i", "w": 150, "f": "f2"},
	{"t": "Q conc. final (L/s)", "k": "qc_f", "w": 140, "f": "f2"},
	{"t": "DN fixo (mm)", "k": "d_fix", "w": 104, "f": "f0"},
]

const OUT_COLS := [
	{"t": "Coletor", "k": "coletor", "w": 64, "f": "s"},
	{"t": "Trecho", "k": "trecho", "w": 60, "f": "s"},
	{"t": "PV mont.", "k": "pv_m", "w": 72, "f": "s"},
	{"t": "PV jus.", "k": "pv_j", "w": 72, "f": "s"},
	{"t": "L (m)", "k": "L", "w": 64, "f": "f2"},
	{"t": "Qi mont.", "k": "qi_m", "w": 70, "f": "f2"},
	{"t": "Qi jus.", "k": "qi_j", "w": 66, "f": "f2"},
	{"t": "Qf mont.", "k": "qf_m", "w": 70, "f": "f2"},
	{"t": "Qf jus.", "k": "qf_j", "w": 66, "f": "f2"},
	{"t": "DN (mm)", "k": "d", "w": 68, "f": "f0"},
	{"t": "I (m/m)", "k": "i", "w": 70, "f": "f4"},
	{"t": "I mín.", "k": "imin", "w": 66, "f": "f4"},
	{"t": "CT mont.", "k": "ct_m", "w": 76, "f": "f3"},
	{"t": "CT jus.", "k": "ct_j", "w": 76, "f": "f3"},
	{"t": "CC mont.", "k": "cc_m", "w": 76, "f": "f3"},
	{"t": "CC jus.", "k": "cc_j", "w": 76, "f": "f3"},
	{"t": "Prof. m.", "k": "prof_m", "w": 66, "f": "f2"},
	{"t": "Prof. j.", "k": "prof_j", "w": 64, "f": "f2"},
	{"t": "y/D ini.", "k": "yd_i", "w": 64, "f": "f2"},
	{"t": "y/D fin.", "k": "yd_f", "w": 64, "f": "f2"},
	{"t": "V ini.", "k": "v_i", "w": 56, "f": "f2"},
	{"t": "V fin.", "k": "v_f", "w": 56, "f": "f2"},
	{"t": "Vc", "k": "vc", "w": 52, "f": "f2"},
	{"t": "σ (Pa)", "k": "sigma", "w": 60, "f": "f2"},
	{"t": "Situação", "k": "status", "w": 96, "f": "st"},
]

var params: Dictionary
var trechos: Array = []
var results: Dictionary = {}
var current_path := ""
var dirty := false
var classic := false
var updating := false
var pal: Dictionary = {}

var bg_panel: PanelContainer
var header: PanelContainer
var header_title: Label
var header_sub: Label
var tabs: TabContainer
var param_fields := {}
var param_info: Label
var input_tree: Tree
var result_tree: Tree
var result_summary: Label
var detail_label: Label
var avisos_label: Label
var profile_select: OptionButton
var profile_view: Control
var report_text: TextEdit
var status_label: Label
var status_right: Label
var file_dialog: FileDialog
var file_action := ""
var about_dialog: AcceptDialog
var confirm_dialog: ConfirmationDialog
var confirm_action := ""
var view_menu: PopupMenu

var shot_path := ""
var frame_count := 0
var start_tab := 2


func _ready() -> void:
	params = Calc.default_params()
	trechos = Calc.example_trechos()
	_parse_args()
	if shot_path != "":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_apply_theme()
	_refresh_params_ui()
	_refresh_input_tree()
	_calculate()
	_update_title()
	_set_status("Pronto. Exemplo carregado: edite os trechos ou abra um projeto.")


# ---------------------------------------------------------------- captura de tela

func _parse_args() -> void:
	var args: Array = Array(OS.get_cmdline_args()) + Array(OS.get_cmdline_user_args())
	for i in args.size():
		var a := str(args[i])
		if a == "--screenshot" and i + 1 < args.size():
			shot_path = str(args[i + 1])
		elif a.begins_with("--screenshot="):
			shot_path = a.substr(13)
		elif a.begins_with("--aba="):
			start_tab = clampi(a.substr(6).to_int(), 0, 4)
		elif a == "--classico":
			classic = true
	if shot_path != "" and shot_path.is_relative_path():
		var pwd := OS.get_environment("PWD")
		if pwd != "" and DirAccess.dir_exists_absolute(pwd):
			shot_path = pwd.path_join(shot_path)
		else:
			shot_path = ProjectSettings.globalize_path("res://").path_join(shot_path)


func _process(_delta: float) -> void:
	if shot_path == "":
		return
	frame_count += 1
	if frame_count >= 120:
		var path := shot_path
		shot_path = ""
		_take_shot(path)


func _take_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	if err != OK:
		printerr("Falha ao salvar captura em ", path, ": ", err)
	get_tree().quit(0 if err == OK else 1)


# ---------------------------------------------------------------- utilidades

func fmt(v, dec: int) -> String:
	return (("%." + str(dec) + "f") % float(v)).replace(".", ",")


func _num(s: String) -> float:
	return s.strip_edges().replace(" ", "").replace(",", ".").to_float()


func _set_status(s: String) -> void:
	if status_label:
		status_label.text = s


func _update_title() -> void:
	var nome := str(params.get("projeto", ""))
	if nome == "":
		nome = "Sem título"
	var t := "%s — %s%s" % [APP_NAME, nome, " *" if dirty else ""]
	get_window().title = t
	if header_sub:
		var arq := current_path.get_file() if current_path != "" else "projeto não salvo"
		header_sub.text = "%s   •   %s" % [nome, arq]


func _mark_dirty() -> void:
	dirty = true
	_update_title()


# ---------------------------------------------------------------- interface

func _build_ui() -> void:
	bg_panel = PanelContainer.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	bg_panel.add_child(v)

	v.add_child(_build_menu())

	header = PanelContainer.new()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	header.add_child(hb)
	var logo := ColorRect.new()
	logo.custom_minimum_size = Vector2(6, 0)
	logo.color = Color(1, 1, 1, 0.85)
	hb.add_child(logo)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hb.add_child(hv)
	header_title = Label.new()
	header_title.text = "%s  —  Dimensionamento de redes coletoras de esgoto sanitário" % APP_NAME
	header_title.add_theme_font_size_override("font_size", 18)
	hv.add_child(header_title)
	header_sub = Label.new()
	header_sub.add_theme_font_size_override("font_size", 13)
	hv.add_child(header_sub)
	v.add_child(header)

	v.add_child(_build_toolbar())

	var m := MarginContainer.new()
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	v.add_child(m)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(tabs)
	tabs.add_child(_build_input_tab())
	tabs.add_child(_build_params_tab())
	tabs.add_child(_build_results_tab())
	tabs.add_child(_build_profile_tab())
	tabs.add_child(_build_report_tab())
	var titles := ["1. Trechos da rede", "2. Parâmetros de projeto", "3. Dimensionamento", "4. Perfil longitudinal", "5. Relatório"]
	for i in titles.size():
		tabs.set_tab_title(i, titles[i])
	tabs.current_tab = start_tab
	tabs.tab_changed.connect(_on_tab_changed)

	var sbar := PanelContainer.new()
	sbar.name = "BarraStatus"
	var sh := HBoxContainer.new()
	sbar.add_child(sh)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	sh.add_child(status_label)
	status_right = Label.new()
	sh.add_child(status_right)
	v.add_child(sbar)

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.size = Vector2i(820, 520)
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

	about_dialog = AcceptDialog.new()
	about_dialog.title = "Sobre o %s" % APP_NAME
	add_child(about_dialog)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Alterações não salvas"
	confirm_dialog.dialog_text = "O projeto atual tem alterações não salvas.\nDeseja descartá-las?"
	confirm_dialog.ok_button_text = "Descartar"
	confirm_dialog.cancel_button_text = "Cancelar"
	confirm_dialog.confirmed.connect(func(): _do_action(confirm_action))
	add_child(confirm_dialog)


func _on_tab_changed(_t: int) -> void:
	if profile_view:
		profile_view.queue_redraw()


func _build_menu() -> Control:
	var mb := MenuBar.new()
	mb.flat = true
	var arq := PopupMenu.new()
	arq.name = "Arquivo"
	arq.add_item("Novo projeto", 0, KEY_MASK_CTRL | KEY_N)
	arq.add_item("Abrir projeto…", 1, KEY_MASK_CTRL | KEY_O)
	arq.add_separator()
	arq.add_item("Salvar", 2, KEY_MASK_CTRL | KEY_S)
	arq.add_item("Salvar como…", 3, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_S)
	arq.add_separator()
	arq.add_item("Exportar planilha (CSV)…", 4)
	arq.add_item("Exportar memorial de cálculo (TXT)…", 5)
	arq.add_separator()
	arq.add_item("Sair", 6, KEY_MASK_CTRL | KEY_Q)
	arq.id_pressed.connect(_on_menu)
	mb.add_child(arq)
	var calc := PopupMenu.new()
	calc.name = "Cálculo"
	calc.add_item("Dimensionar rede", 10, KEY_F5)
	calc.add_item("Carregar rede de exemplo", 11)
	calc.id_pressed.connect(_on_menu)
	mb.add_child(calc)
	view_menu = PopupMenu.new()
	view_menu.name = "Exibir"
	view_menu.add_item("Usar visual moderno" if classic else "Usar visual clássico", 20)
	view_menu.id_pressed.connect(_on_menu)
	mb.add_child(view_menu)
	var aj := PopupMenu.new()
	aj.name = "Ajuda"
	aj.add_item("Critérios de cálculo", 31)
	aj.add_item("Sobre", 30)
	aj.id_pressed.connect(_on_menu)
	mb.add_child(aj)
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 4)
	wrap.add_child(mb)
	return wrap


func _build_toolbar() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	m.add_child(h)
	var items := [
		["Novo", 0, "Começar um projeto em branco"],
		["Abrir…", 1, "Abrir um projeto salvo (.esg)"],
		["Salvar", 2, "Salvar o projeto"],
		["|", -1, ""],
		["Dimensionar  (F5)", 10, "Calcular toda a rede"],
		["|", -1, ""],
		["Exportar CSV", 4, "Planilha para Excel/LibreOffice"],
		["Memorial TXT", 5, "Memorial de cálculo em texto"],
	]
	for it in items:
		if it[0] == "|":
			var s := VSeparator.new()
			h.add_child(s)
			continue
		var b := Button.new()
		b.text = it[0]
		b.tooltip_text = it[2]
		b.custom_minimum_size = Vector2(0, 30)
		var id: int = it[1]
		b.pressed.connect(func(): _on_menu(id))
		h.add_child(b)
	return m


func _group(title: String) -> Array:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 15)
	l.set_meta("titulo", true)
	vb.add_child(l)
	vb.add_child(HSeparator.new())
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 6)
	vb.add_child(g)
	return [pc, g, vb]


func _add_num(g: GridContainer, key: String, label: String, minv: float, maxv: float, step: float, tip := "") -> void:
	var l := Label.new()
	l.text = label
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = minv
	sb.max_value = maxv
	sb.step = step
	sb.custom_minimum_size = Vector2(130, 0)
	sb.tooltip_text = tip
	sb.select_all_on_focus = true
	sb.value_changed.connect(func(val): _on_param_changed(key, val))
	g.add_child(sb)
	param_fields[key] = sb


func _add_text(g: GridContainer, key: String, label: String) -> void:
	var l := Label.new()
	l.text = label
	g.add_child(l)
	var le := LineEdit.new()
	le.custom_minimum_size = Vector2(220, 0)
	le.text_changed.connect(func(val): _on_param_changed(key, val))
	g.add_child(le)
	param_fields[key] = le


func _build_params_tab() -> Control:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	sc.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	m.add_child(h)

	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.add_theme_constant_override("separation", 14)
	h.add_child(col1)
	var g1 := _group("Identificação do projeto")
	col1.add_child(g1[0])
	_add_text(g1[1], "projeto", "Nome do projeto")
	_add_text(g1[1], "responsavel", "Responsável técnico")
	_add_text(g1[1], "local", "Município / bairro")
	var gi := _group("Resumo da rede")
	col1.add_child(gi[0])
	param_info = Label.new()
	param_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gi[2].add_child(param_info)

	var g2 := _group("Contribuição de esgoto")
	h.add_child(g2[0])
	var l := Label.new()
	l.text = "Taxa de contribuição"
	g2[1].add_child(l)
	var ob := OptionButton.new()
	ob.add_item("Calcular pela população", 0)
	ob.add_item("Informar taxas lineares", 1)
	ob.item_selected.connect(func(ix): _on_param_changed("modo_taxa", ix))
	g2[1].add_child(ob)
	param_fields["modo_taxa"] = ob
	_add_num(g2[1], "pop_ini", "População inicial (hab)", 0, 10000000, 1)
	_add_num(g2[1], "pop_fin", "População final (hab)", 0, 10000000, 1)
	_add_num(g2[1], "per_capita", "Consumo per capita (L/hab·dia)", 0, 1000, 1)
	_add_num(g2[1], "coef_retorno", "Coeficiente de retorno C", 0, 1, 0.01)
	_add_num(g2[1], "k1", "K1 (dia de maior consumo)", 1, 3, 0.01)
	_add_num(g2[1], "k2", "K2 (hora de maior consumo)", 1, 3, 0.01)
	_add_num(g2[1], "infiltracao", "Taxa de infiltração (L/s·km)", 0, 10, 0.01)
	_add_num(g2[1], "tx_ini", "Taxa linear inicial (L/s·m)", 0, 1, 0.0001)
	_add_num(g2[1], "tx_fin", "Taxa linear final (L/s·m)", 0, 1, 0.0001)

	var g3 := _group("Critérios hidráulicos (NBR 9649)")
	h.add_child(g3[0])
	_add_num(g3[1], "q_min", "Vazão mínima por trecho (L/s)", 0, 100, 0.1)
	_add_num(g3[1], "manning", "Coeficiente de Manning n", 0.009, 0.03, 0.001)
	_add_num(g3[1], "d_min", "Diâmetro mínimo (mm)", 100, 1500, 50)
	_add_num(g3[1], "prof_min", "Profundidade mínima do coletor (m)", 0.3, 10, 0.05)
	_add_num(g3[1], "prof_max", "Profundidade máxima recomendada (m)", 1, 20, 0.1)
	_add_num(g3[1], "yd_max", "Lâmina máxima y/D", 0.2, 0.95, 0.01)
	_add_num(g3[1], "tensao_min", "Tensão trativa mínima (Pa)", 0, 10, 0.1)
	_add_num(g3[1], "v_max", "Velocidade máxima (m/s)", 0.5, 10, 0.1)
	_add_num(g3[1], "degrau_max", "Desnível máx. sem tubo de queda (m)", 0, 5, 0.05)
	var note := Label.new()
	note.text = "Declividade mínima: I = 0,0055 · Qi^-0,47\nVelocidade crítica: Vc = 6 · √(g · Rh); se Vf > Vc, lâmina máx. 50%\nTensão trativa: σ = γ · Rh · I (vazão inicial)"
	note.add_theme_font_size_override("font_size", 12)
	note.set_meta("muted", true)
	g3[2].add_child(note)
	return sc


func _build_input_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	v.add_child(bar)
	var btns := [
		["+ Adicionar trecho", "_on_add_trecho"],
		["Remover", "_on_remove_trecho"],
		["▲ Subir", "_on_move_up"],
		["▼ Descer", "_on_move_down"],
	]
	for b in btns:
		var bt := Button.new()
		bt.text = b[0]
		bt.pressed.connect(Callable(self, b[1]))
		bar.add_child(bt)
	var hint := Label.new()
	hint.text = "  Clique numa célula para editar. Trechos se ligam pelos PVs. CT = cota do terreno; DN fixo 0 = automático."
	hint.set_meta("muted", true)
	hint.add_theme_font_size_override("font_size", 12)
	hint.clip_text = true
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(hint)

	input_tree = Tree.new()
	input_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	input_tree.columns = IN_COLS.size()
	input_tree.column_titles_visible = true
	input_tree.hide_root = true
	input_tree.select_mode = Tree.SELECT_SINGLE
	for c in IN_COLS.size():
		input_tree.set_column_title(c, IN_COLS[c]["t"])
		input_tree.set_column_custom_minimum_width(c, IN_COLS[c]["w"])
		input_tree.set_column_expand(c, c != 0)
		input_tree.set_column_clip_content(c, true)
	input_tree.item_edited.connect(_on_input_edited)
	v.add_child(input_tree)
	return v


func _build_results_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	result_summary = Label.new()
	result_summary.add_theme_font_size_override("font_size", 14)
	v.add_child(result_summary)
	result_tree = Tree.new()
	result_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_tree.columns = OUT_COLS.size()
	result_tree.column_titles_visible = true
	result_tree.hide_root = true
	result_tree.select_mode = Tree.SELECT_ROW
	for c in OUT_COLS.size():
		result_tree.set_column_title(c, OUT_COLS[c]["t"])
		result_tree.set_column_custom_minimum_width(c, OUT_COLS[c]["w"])
		result_tree.set_column_expand(c, true)
		result_tree.set_column_clip_content(c, true)
	result_tree.item_selected.connect(_on_result_selected)
	v.add_child(result_tree)
	var leg := Label.new()
	leg.text = "Vazões em L/s  •  CT = cota do terreno  •  CC = cota do coletor (geratriz inferior)  •  V em m/s  •  y/D = lâmina relativa  •  σ = tensão trativa (vazão inicial)"
	leg.set_meta("muted", true)
	leg.add_theme_font_size_override("font_size", 12)
	leg.clip_text = true
	v.add_child(leg)
	var dp := PanelContainer.new()
	dp.custom_minimum_size = Vector2(0, 64)
	var dv := VBoxContainer.new()
	dp.add_child(dv)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.text = "Selecione um trecho para ver as verificações."
	dv.add_child(detail_label)
	avisos_label = Label.new()
	avisos_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	avisos_label.add_theme_color_override("font_color", Color(0.75, 0.35, 0.0))
	dv.add_child(avisos_label)
	v.add_child(dp)
	return v


func _build_profile_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var h := HBoxContainer.new()
	v.add_child(h)
	var l := Label.new()
	l.text = "Coletor:"
	h.add_child(l)
	profile_select = OptionButton.new()
	profile_select.custom_minimum_size = Vector2(140, 0)
	profile_select.item_selected.connect(func(_i): _refresh_profile())
	h.add_child(profile_select)
	profile_view = ProfileView.new()
	profile_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(profile_view)
	return v


func _build_report_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var b1 := Button.new()
	b1.text = "Exportar memorial (TXT)…"
	b1.pressed.connect(func(): _on_menu(5))
	h.add_child(b1)
	var b2 := Button.new()
	b2.text = "Exportar planilha (CSV)…"
	b2.pressed.connect(func(): _on_menu(4))
	h.add_child(b2)
	var b3 := Button.new()
	b3.text = "Copiar texto"
	b3.pressed.connect(func():
		DisplayServer.clipboard_set(report_text.text)
		_set_status("Memorial copiado para a área de transferência."))
	h.add_child(b3)
	report_text = TextEdit.new()
	report_text.editable = false
	report_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "Consolas", "Courier New", "monospace"])
	report_text.add_theme_font_override("font", mono)
	report_text.add_theme_font_size_override("font_size", 13)
	v.add_child(report_text)
	return v


# ---------------------------------------------------------------- atualizações

func _refresh_params_ui() -> void:
	updating = true
	for key in param_fields.keys():
		var w = param_fields[key]
		if w is SpinBox:
			w.value = float(params.get(key, 0.0))
		elif w is LineEdit:
			w.text = str(params.get(key, ""))
		elif w is OptionButton:
			w.select(int(params.get(key, 0)))
	updating = false
	_update_mode_enabled()


func _update_mode_enabled() -> void:
	var pop := int(params["modo_taxa"]) == 0
	for k in ["pop_ini", "pop_fin", "per_capita", "coef_retorno", "k1", "k2", "infiltracao"]:
		param_fields[k].editable = pop
	for k in ["tx_ini", "tx_fin"]:
		param_fields[k].editable = not pop


func _on_param_changed(key: String, val) -> void:
	if updating:
		return
	params[key] = val
	if key == "modo_taxa":
		params[key] = int(val)
		_update_mode_enabled()
	_mark_dirty()
	if key in ["projeto", "responsavel", "local"]:
		_refresh_report()
		return
	_calculate()


func _refresh_input_tree() -> void:
	input_tree.clear()
	var root := input_tree.create_item()
	for i in trechos.size():
		var t: Dictionary = trechos[i]
		var it := input_tree.create_item(root)
		it.set_metadata(0, i)
		it.set_text(0, str(i + 1))
		it.set_text_alignment(0, HORIZONTAL_ALIGNMENT_CENTER)
		for c in range(1, IN_COLS.size()):
			var spec: Dictionary = IN_COLS[c]
			it.set_editable(c, true)
			if spec["f"] == "s":
				it.set_text(c, str(t.get(spec["k"], "")))
			else:
				it.set_text(c, fmt(t.get(spec["k"], 0.0), int(str(spec["f"]).substr(1))))
				it.set_text_alignment(c, HORIZONTAL_ALIGNMENT_RIGHT)


func _on_input_edited() -> void:
	var it := input_tree.get_edited()
	var col := input_tree.get_edited_column()
	if it == null or col <= 0:
		return
	var idx := int(it.get_metadata(0))
	var spec: Dictionary = IN_COLS[col]
	var txt := it.get_text(col)
	if spec["f"] == "s":
		trechos[idx][spec["k"]] = txt.strip_edges()
	else:
		var v := _num(txt)
		if spec["k"] in ["L", "qc_i", "qc_f", "d_fix"]:
			v = max(v, 0.0)
		trechos[idx][spec["k"]] = v
		it.set_text(col, fmt(v, int(str(spec["f"]).substr(1))))
	_mark_dirty()
	call_deferred("_calculate")


func _selected_input() -> int:
	var it := input_tree.get_selected()
	if it == null:
		return -1
	return int(it.get_metadata(0))


func _on_add_trecho() -> void:
	var sel := _selected_input()
	var base_i := sel if sel >= 0 else trechos.size() - 1
	var novo: Dictionary
	if base_i >= 0:
		var b: Dictionary = trechos[base_i]
		var num := trechos.size() + 1
		novo = Calc.novo_trecho(str(b["coletor"]), "", str(b["pv_j"]), "PV-%02d" % (num + 1), 60.0, float(b["ct_j"]), float(b["ct_j"]) - 0.4)
	else:
		novo = Calc.novo_trecho("1", "1-1", "PV-01", "PV-02", 60.0, 100.0, 99.6)
	trechos.insert(base_i + 1, novo)
	_refresh_input_tree()
	_select_input(base_i + 1)
	_mark_dirty()
	_calculate()
	_set_status("Trecho adicionado. Preencha nome, PV de jusante e cotas.")


func _select_input(i: int) -> void:
	var root := input_tree.get_root()
	if root == null:
		return
	var it := root.get_first_child()
	var k := 0
	while it != null:
		if k == i:
			it.select(1)
			input_tree.scroll_to_item(it)
			return
		it = it.get_next()
		k += 1


func _on_remove_trecho() -> void:
	var sel := _selected_input()
	if sel < 0:
		_set_status("Selecione um trecho para remover.")
		return
	trechos.remove_at(sel)
	_refresh_input_tree()
	_select_input(min(sel, trechos.size() - 1))
	_mark_dirty()
	_calculate()


func _move(delta: int) -> void:
	var sel := _selected_input()
	var to := sel + delta
	if sel < 0 or to < 0 or to >= trechos.size():
		return
	var t = trechos[sel]
	trechos[sel] = trechos[to]
	trechos[to] = t
	_refresh_input_tree()
	_select_input(to)
	_mark_dirty()
	_calculate()


func _on_move_up() -> void:
	_move(-1)


func _on_move_down() -> void:
	_move(1)


func _calculate() -> void:
	results = Calc.calcular(params, trechos)
	_refresh_results()
	_refresh_profile_list()
	_refresh_report()
	_refresh_param_info()
	var n := trechos.size()
	status_right.text = "%d trechos  •  %d OK  •  %d atenção  •  %d não atendem  " % [n, results["n_ok"], results["n_warn"], results["n_err"]]


func _status_color(st: int) -> Color:
	if st == 0:
		return Color(0.80, 0.93, 0.80) if not classic else Color(0.6, 1.0, 0.6)
	if st == 1:
		return Color(1.0, 0.93, 0.72) if not classic else Color(1.0, 1.0, 0.5)
	return Color(0.98, 0.78, 0.78) if not classic else Color(1.0, 0.55, 0.55)


func _refresh_results() -> void:
	result_tree.clear()
	var root := result_tree.create_item()
	var rows: Array = results["rows"]
	var st_names := ["OK", "Atenção", "Não atende"]
	for idx in rows.size():
		var r = rows[idx]
		var it := result_tree.create_item(root)
		it.set_metadata(0, idx)
		if r == null:
			var t: Dictionary = trechos[idx]
			it.set_text(0, str(t["coletor"]))
			it.set_text(1, str(t["trecho"]))
			it.set_text(2, str(t["pv_m"]))
			it.set_text(3, str(t["pv_j"]))
			var lc := OUT_COLS.size() - 1
			it.set_text(lc, "Não calculado")
			it.set_custom_bg_color(lc, _status_color(2))
			continue
		for c in OUT_COLS.size():
			var spec: Dictionary = OUT_COLS[c]
			var f: String = spec["f"]
			if f == "s":
				it.set_text(c, str(r[spec["k"]]))
			elif f == "st":
				it.set_text(c, st_names[int(r["status"])])
				it.set_text_alignment(c, HORIZONTAL_ALIGNMENT_CENTER)
				it.set_custom_bg_color(c, _status_color(int(r["status"])))
				it.set_custom_color(c, Color(0.1, 0.1, 0.1))
			else:
				it.set_text(c, fmt(r[spec["k"]], int(f.substr(1))))
				it.set_text_alignment(c, HORIZONTAL_ALIGNMENT_RIGHT)
			if spec["k"] in r["bad"]:
				it.set_custom_color(c, Color(0.85, 0.1, 0.1))
			elif spec["k"] in r["warn"]:
				it.set_custom_color(c, Color(0.85, 0.45, 0.0))
	result_summary.text = "Rede com %s m de extensão  •  taxa linear inicial %s L/s·m  •  final %s L/s·m  •  vazão final na saída: %s L/s" % [
		fmt(results["ltot"], 2), fmt(results["tx_i"], 5), fmt(results["tx_f"], 5), fmt(_vazao_saida(), 2)]
	var av: Array = results["avisos"]
	avisos_label.text = "" if av.is_empty() else "Avisos: " + " ".join(av)


func _vazao_saida() -> float:
	var rows: Array = results["rows"]
	var total := 0.0
	for r in rows:
		if r == null:
			continue
		var tem_jusante := false
		for t in trechos:
			if str(t["pv_m"]) == str(r["pv_j"]):
				tem_jusante = true
				break
		if not tem_jusante:
			total += float(r["qf_j"])
	return total


func _on_result_selected() -> void:
	var it := result_tree.get_selected()
	if it == null:
		return
	var idx := int(it.get_metadata(0))
	var r = results["rows"][idx]
	if r == null:
		detail_label.text = "Trecho %s não pôde ser calculado (verifique a ligação entre PVs)." % str(trechos[idx]["trecho"])
		return
	var msgs: Array = r["msgs"]
	var s := "Trecho %s (%s → %s): DN %d mm, I = %s m/m, vazão de projeto inicial %s L/s e final %s L/s, lâmina limite %s." % [
		r["trecho"], r["pv_m"], r["pv_j"], int(r["d"]), fmt(r["i"], 4), fmt(r["qi_d"], 2), fmt(r["qf_d"], 2), fmt(r["yd_lim"], 2)]
	if msgs.is_empty():
		s += "\nAtende a todos os critérios."
	else:
		s += "\n• " + "\n• ".join(msgs)
	detail_label.text = s


func _coletores() -> Array:
	var out: Array = []
	for t in trechos:
		var c := str(t["coletor"])
		if not c in out:
			out.append(c)
	return out


func _refresh_profile_list() -> void:
	var prev := ""
	if profile_select.item_count > 0 and profile_select.selected >= 0:
		prev = profile_select.get_item_text(profile_select.selected)
	profile_select.clear()
	var cols := _coletores()
	for c in cols:
		profile_select.add_item(c)
	var sel := cols.find(prev)
	if sel < 0 and cols.size() > 0:
		sel = 0
	if sel >= 0:
		profile_select.select(sel)
	_refresh_profile()


func _refresh_profile() -> void:
	var c := ""
	if profile_select.selected >= 0:
		c = profile_select.get_item_text(profile_select.selected)
	var rows: Array = []
	for idx in results.get("order", []):
		var r = results["rows"][idx]
		if r != null and str(r["coletor"]) == c:
			rows.append(r)
	profile_view.set_data(rows, c, pal)


func _refresh_param_info() -> void:
	if param_info == null:
		return
	var n_pv := {}
	for t in trechos:
		n_pv[str(t["pv_m"])] = true
		n_pv[str(t["pv_j"])] = true
	param_info.text = "Trechos: %d   •   PVs: %d   •   Coletores: %d\nExtensão total: %s m\nTaxa linear inicial adotada: %s L/s·m\nTaxa linear final adotada: %s L/s·m\nVazão final na saída da rede: %s L/s" % [
		trechos.size(), n_pv.size(), _coletores().size(), fmt(results["ltot"], 2), fmt(results["tx_i"], 6), fmt(results["tx_f"], 6), fmt(_vazao_saida(), 2)]


# ---------------------------------------------------------------- relatórios

func _data_br() -> String:
	var d := Time.get_date_dict_from_system()
	return "%02d/%02d/%04d" % [d["day"], d["month"], d["year"]]


func _build_report() -> String:
	var p := params
	var s := ""
	var linha := "=".repeat(150) + "\n"
	s += linha
	s += "MEMORIAL DE CÁLCULO — REDE COLETORA DE ESGOTO SANITÁRIO\n"
	s += linha
	s += "Projeto:      %s\n" % str(p["projeto"])
	s += "Responsável:  %s\n" % str(p["responsavel"])
	s += "Local:        %s\n" % str(p["local"])
	s += "Data:         %s        Gerado por %s %s\n\n" % [_data_br(), APP_NAME, VERSAO]
	s += "1. PARÂMETROS DE PROJETO\n"
	if int(p["modo_taxa"]) == 0:
		s += "   População inicial / final ........ %s / %s hab\n" % [fmt(p["pop_ini"], 0), fmt(p["pop_fin"], 0)]
		s += "   Consumo per capita ................ %s L/hab·dia\n" % fmt(p["per_capita"], 1)
		s += "   Coeficiente de retorno C .......... %s\n" % fmt(p["coef_retorno"], 2)
		s += "   K1 / K2 ........................... %s / %s\n" % [fmt(p["k1"], 2), fmt(p["k2"], 2)]
		s += "   Taxa de infiltração ............... %s L/s·km\n" % fmt(p["infiltracao"], 3)
	else:
		s += "   Taxas lineares informadas pelo usuário.\n"
	s += "   Vazão mínima ...................... %s L/s\n" % fmt(p["q_min"], 2)
	s += "   Coeficiente de Manning n .......... %s\n" % fmt(p["manning"], 3)
	s += "   Diâmetro mínimo ................... %s mm\n" % fmt(p["d_min"], 0)
	s += "   Profundidade mínima / máxima ...... %s / %s m\n" % [fmt(p["prof_min"], 2), fmt(p["prof_max"], 2)]
	s += "   Lâmina máxima y/D ................. %s\n" % fmt(p["yd_max"], 2)
	s += "   Tensão trativa mínima ............. %s Pa\n" % fmt(p["tensao_min"], 2)
	s += "   Velocidade máxima ................. %s m/s\n\n" % fmt(p["v_max"], 2)
	s += "2. TAXAS DE CONTRIBUIÇÃO\n"
	s += "   Extensão total da rede ............ %s m\n" % fmt(results["ltot"], 2)
	s += "   Taxa linear inicial ............... %s L/s·m\n" % fmt(results["tx_i"], 6)
	s += "   Taxa linear final ................. %s L/s·m\n\n" % fmt(results["tx_f"], 6)
	s += "3. PLANILHA DE DIMENSIONAMENTO\n"
	var heads := ["Col", "Trecho", "PV mont", "PV jus", "L(m)", "Qi jus", "Qf jus", "DN", "I(m/m)", "CT mont", "CT jus", "CC mont", "CC jus", "Pr.m", "Pr.j", "y/Di", "y/Df", "Vi", "Vf", "Vc", "Tens", "Sit"]
	var widths := [4, 7, 8, 8, 7, 7, 7, 5, 7, 8, 8, 8, 8, 5, 5, 5, 5, 5, 5, 5, 5, 4]
	var hl := ""
	for i in heads.size():
		hl += str(heads[i]).lpad(widths[i]) + " "
	s += hl + "\n" + "-".repeat(hl.length()) + "\n"
	var st_short := ["OK", "AT", "NA"]
	for idx in results["order"]:
		var r = results["rows"][idx]
		var vals := [str(r["coletor"]), str(r["trecho"]), str(r["pv_m"]), str(r["pv_j"]), fmt(r["L"], 1),
			fmt(r["qi_j"], 2), fmt(r["qf_j"], 2), fmt(r["d"], 0), fmt(r["i"], 4), fmt(r["ct_m"], 3), fmt(r["ct_j"], 3),
			fmt(r["cc_m"], 3), fmt(r["cc_j"], 3), fmt(r["prof_m"], 2), fmt(r["prof_j"], 2), fmt(r["yd_i"], 2), fmt(r["yd_f"], 2),
			fmt(r["v_i"], 2), fmt(r["v_f"], 2), fmt(r["vc"], 2), fmt(r["sigma"], 2), st_short[int(r["status"])]]
		var ln := ""
		for i in vals.size():
			ln += str(vals[i]).lpad(widths[i]) + " "
		s += ln + "\n"
	s += "   (OK = atende; AT = atenção; NA = não atende)\n\n"
	s += "4. VERIFICAÇÕES POR TRECHO\n"
	var alguma := false
	for idx in results["order"]:
		var r = results["rows"][idx]
		var msgs: Array = r["msgs"]
		if msgs.is_empty():
			continue
		alguma = true
		s += "   Trecho %s (%s → %s):\n" % [r["trecho"], r["pv_m"], r["pv_j"]]
		for m in msgs:
			s += "      - %s\n" % m
	if not alguma:
		s += "   Todos os trechos atendem aos critérios.\n"
	for a in results["avisos"]:
		s += "   AVISO: %s\n" % a
	s += "\n5. QUANTITATIVO DE TUBULAÇÃO\n"
	var por_dn := {}
	var prof_soma := 0.0
	var n := 0
	for r in results["rows"]:
		if r == null:
			continue
		var dn := int(r["d"])
		por_dn[dn] = float(por_dn.get(dn, 0.0)) + float(r["L"])
		prof_soma += (float(r["prof_m"]) + float(r["prof_j"])) / 2.0
		n += 1
	var dns := por_dn.keys()
	dns.sort()
	for dn in dns:
		s += "   DN %4d mm ........................ %s m\n" % [dn, fmt(por_dn[dn], 2)]
	if n > 0:
		s += "   Profundidade média dos coletores .. %s m\n" % fmt(prof_soma / n, 2)
	s += "   Vazão final na saída da rede ...... %s L/s\n" % fmt(_vazao_saida(), 2)
	return s


func _refresh_report() -> void:
	if report_text:
		report_text.text = _build_report()


func _build_csv() -> String:
	var lines: Array = []
	var head: Array = []
	for c in OUT_COLS:
		head.append(c["t"])
	head.append("Observações")
	lines.append(";".join(head))
	var st_names := ["OK", "Atenção", "Não atende"]
	for idx in results["order"]:
		var r = results["rows"][idx]
		var vals: Array = []
		for c in OUT_COLS:
			var f: String = c["f"]
			if f == "s":
				vals.append(str(r[c["k"]]))
			elif f == "st":
				vals.append(st_names[int(r["status"])])
			else:
				vals.append(fmt(r[c["k"]], int(f.substr(1))))
		vals.append(" | ".join(r["msgs"]).replace(";", ","))
		lines.append(";".join(vals))
	return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- arquivos e menus

func _on_menu(id: int) -> void:
	match id:
		0:
			_ask_discard("novo")
		1:
			_ask_discard("abrir")
		2:
			if current_path == "":
				_open_dialog("salvar")
			else:
				_save_to(current_path)
		3:
			_open_dialog("salvar")
		4:
			_open_dialog("csv")
		5:
			_open_dialog("txt")
		6:
			get_tree().quit()
		10:
			_calculate()
			tabs.current_tab = 2
			_set_status("Rede dimensionada.")
		11:
			_ask_discard("exemplo")
		20:
			classic = not classic
			view_menu.set_item_text(0, "Usar visual moderno" if classic else "Usar visual clássico")
			_apply_theme()
			_refresh_results()
			_refresh_profile()
		30:
			about_dialog.dialog_text = "%s %s\n\nDimensionamento hidráulico de redes coletoras de esgoto sanitário\n(critérios da NBR 9649), com perfil longitudinal, memorial de cálculo,\nexportação para planilha e projetos salvos em arquivo.\n\nVersão modernizada inspirada num programa clássico de dimensionamento." % [APP_NAME, VERSAO]
			about_dialog.popup_centered()
		31:
			about_dialog.dialog_text = "Critérios de cálculo\n\n• Vazões: Qi = Tx_i·L + Q montante;  Qf = Tx_f·L + Q montante (mínimo de 1,5 L/s)\n• Tx_i = C·q·K2·Pi / (86400·L_total) + infiltração;  Tx_f usa K1·K2·Pf\n• Declividade mínima: I = 0,0055·Qi^-0,47 (m/m); acompanha o terreno quando possível\n• Escoamento: fórmula de Manning em seção circular parcialmente cheia\n• Lâmina final ≤ 75% (ou 50% se Vf > Vc = 6·√(g·Rh))\n• Tensão trativa σ = γ·Rh·I ≥ 1,0 Pa com a vazão inicial\n• Profundidade mínima do coletor e alinhamento pela geratriz superior nos PVs"
			about_dialog.popup_centered()


func _ask_discard(action: String) -> void:
	if dirty:
		confirm_action = action
		confirm_dialog.popup_centered()
	else:
		_do_action(action)


func _do_action(action: String) -> void:
	match action:
		"novo":
			params = Calc.default_params()
			params["projeto"] = "Novo projeto"
			trechos = [Calc.novo_trecho("1", "1-1", "PV-01", "PV-02", 60.0, 100.0, 99.6)]
			current_path = ""
			_after_load("Novo projeto criado.")
			tabs.current_tab = 0
		"exemplo":
			params = Calc.default_params()
			trechos = Calc.example_trechos()
			current_path = ""
			_after_load("Rede de exemplo carregada.")
		"abrir":
			_open_dialog("abrir")


func _after_load(msg: String) -> void:
	dirty = false
	_refresh_params_ui()
	_refresh_input_tree()
	_calculate()
	_update_title()
	_set_status(msg)


func _open_dialog(action: String) -> void:
	file_action = action
	file_dialog.clear_filters()
	match action:
		"abrir":
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.title = "Abrir projeto"
			file_dialog.add_filter("*.esg", "Projeto de esgoto")
			file_dialog.add_filter("*.json", "JSON")
		"salvar":
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.title = "Salvar projeto"
			file_dialog.add_filter("*.esg", "Projeto de esgoto")
			file_dialog.current_file = _safe_name() + ".esg"
		"csv":
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.title = "Exportar planilha"
			file_dialog.add_filter("*.csv", "Planilha CSV")
			file_dialog.current_file = _safe_name() + ".csv"
		"txt":
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.title = "Exportar memorial de cálculo"
			file_dialog.add_filter("*.txt", "Texto")
			file_dialog.current_file = _safe_name() + "-memorial.txt"
	file_dialog.popup_centered()


func _safe_name() -> String:
	var n := str(params.get("projeto", "projeto")).strip_edges()
	if n == "":
		n = "projeto"
	return n.validate_filename()


func _write_text(path: String, text: String, bom := false) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_set_status("Não foi possível gravar em %s (erro %d)." % [path, FileAccess.get_open_error()])
		return false
	if bom:
		f.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
	f.store_string(text)
	f.close()
	return true


func _on_file_selected(path: String) -> void:
	match file_action:
		"abrir":
			_load_from(path)
		"salvar":
			if path.get_extension() == "":
				path += ".esg"
			_save_to(path)
		"csv":
			if _write_text(path, _build_csv(), true):
				_set_status("Planilha exportada: " + path)
		"txt":
			if _write_text(path, _build_report()):
				_set_status("Memorial exportado: " + path)


func _save_to(path: String) -> void:
	var data := {"formato": "dimesgoto", "versao": 1, "parametros": params, "trechos": trechos}
	if _write_text(path, JSON.stringify(data, "  ")):
		current_path = path
		dirty = false
		_update_title()
		_set_status("Projeto salvo: " + path)


func _load_from(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_set_status("Não foi possível abrir %s." % path)
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary or not data.has("trechos"):
		_set_status("Arquivo inválido: não é um projeto do %s." % APP_NAME)
		return
	var p := Calc.default_params()
	var lp = data.get("parametros", {})
	if lp is Dictionary:
		for k in lp.keys():
			if p.has(k):
				p[k] = lp[k]
	p["modo_taxa"] = int(p["modo_taxa"])
	var ts: Array = []
	for t in data["trechos"]:
		if not t is Dictionary:
			continue
		var n := Calc.novo_trecho("", "", "", "", 0.0, 0.0, 0.0)
		for k in n.keys():
			if t.has(k):
				n[k] = str(t[k]) if n[k] is String else float(t[k])
		ts.append(n)
	params = p
	trechos = ts
	current_path = path
	_after_load("Projeto aberto: " + path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


# ---------------------------------------------------------------- aparência

func _palette(c: bool) -> Dictionary:
	if c:
		return {
			"bg": Color("c0c0c0"), "panel": Color("c0c0c0"), "field": Color("ffffff"), "text": Color("000000"),
			"muted": Color("404040"), "accent": Color("000080"), "accent_text": Color("ffffff"), "border": Color("808080"),
			"button": Color("c0c0c0"), "button_hover": Color("d4d0c8"), "header": Color("000080"), "header_text": Color("ffffff"),
			"select": Color("000080"), "select_text": Color("ffffff"), "title_bg": Color("c0c0c0"), "status": Color("c0c0c0"),
		}
	return {
		"bg": Color("eef2f6"), "panel": Color("ffffff"), "field": Color("ffffff"), "text": Color("1d2733"),
		"muted": Color("5b6b7c"), "accent": Color("1f6fb2"), "accent_text": Color("ffffff"), "border": Color("c9d3de"),
		"button": Color("ffffff"), "button_hover": Color("e6f0fa"), "header": Color("17496f"), "header_text": Color("ffffff"),
		"select": Color("cfe3f6"), "select_text": Color("0f2740"), "title_bg": Color("e3eaf2"), "status": Color("e3eaf2"),
	}


func _sb(bgc: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 0, mx := 8, my := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bgc
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	return s


func _bevel(bgc: Color, sunken := false, mx := 8, my := 4) -> StyleBoxFlat:
	var s := _sb(bgc, Color("ffffff") if not sunken else Color("808080"), 1, 0, mx, my)
	s.shadow_color = Color("000000") if not sunken else Color("ffffff")
	s.shadow_size = 1
	s.shadow_offset = Vector2(1, 1)
	return s


func _arrow_tex(col: Color, up: bool, w := 10, h := 6) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row := (h - 1 - y) if up else y
		var half := (w / 2.0) * (1.0 - float(row) / h)
		for x in w:
			if abs(x + 0.5 - w / 2.0) <= half:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _make_theme(c: bool) -> Theme:
	var p := _palette(c)
	var t := Theme.new()
	t.default_font_size = 14
	if c:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Tahoma", "MS Sans Serif", "Liberation Sans", "DejaVu Sans", "Sans"])
		t.default_font = f
		t.default_font_size = 13
	var r := 0 if c else 4
	var field_sb: StyleBoxFlat = _bevel(p["field"], true, 6, 4) if c else _sb(p["field"], p["border"], 1, r, 6, 4)
	var field_focus: StyleBoxFlat = _bevel(p["field"], true, 6, 4) if c else _sb(p["field"], p["accent"], 1, r, 6, 4)
	var btn: StyleBoxFlat = _bevel(p["button"], false, 10, 4) if c else _sb(p["button"], p["border"], 1, r, 10, 4)
	var btn_h: StyleBoxFlat = _bevel(p["button_hover"], false, 10, 4) if c else _sb(p["button_hover"], p["accent"], 1, r, 10, 4)
	var btn_p: StyleBoxFlat = _bevel(p["button"], true, 10, 4) if c else _sb(p["select"], p["accent"], 1, r, 10, 4)

	t.set_stylebox("panel", "PanelContainer", _sb(p["panel"], p["border"], 0 if c else 1, r, 12, 10))
	t.set_stylebox("panel", "Panel", _sb(p["panel"]))
	for typ in ["Label", "CheckBox", "CheckButton"]:
		t.set_color("font_color", typ, p["text"])
	for typ in ["Button", "OptionButton"]:
		t.set_stylebox("normal", typ, btn)
		t.set_stylebox("hover", typ, btn_h)
		t.set_stylebox("pressed", typ, btn_p)
		t.set_stylebox("hover_pressed", typ, btn_p)
		t.set_stylebox("focus", typ, StyleBoxEmpty.new())
		t.set_stylebox("disabled", typ, btn)
		t.set_color("font_color", typ, p["text"])
		t.set_color("font_hover_color", typ, p["text"])
		t.set_color("font_pressed_color", typ, p["text"])
		t.set_color("font_hover_pressed_color", typ, p["text"])
		t.set_color("font_focus_color", typ, p["text"])
		t.set_color("font_disabled_color", typ, p["muted"])
	t.set_icon("arrow", "OptionButton", _arrow_tex(p["text"], false))
	# Menus
	t.set_stylebox("normal", "MenuBar", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 10, 4))
	t.set_stylebox("hover", "MenuBar", _sb(p["select"], Color(0, 0, 0, 0), 0, 0, 10, 4))
	t.set_stylebox("pressed", "MenuBar", _sb(p["select"], Color(0, 0, 0, 0), 0, 0, 10, 4))
	t.set_stylebox("disabled", "MenuBar", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 10, 4))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(k, "MenuBar", p["text"])
	if c:
		t.set_color("font_hover_color", "MenuBar", p["select_text"])
		t.set_color("font_pressed_color", "MenuBar", p["select_text"])
	t.set_stylebox("panel", "PopupMenu", _bevel(p["panel"], false, 4, 4) if c else _sb(p["panel"], p["border"], 1, r, 4, 4))
	t.set_stylebox("hover", "PopupMenu", _sb(p["select"], Color(0, 0, 0, 0), 0, 0, 8, 4))
	t.set_color("font_color", "PopupMenu", p["text"])
	t.set_color("font_hover_color", "PopupMenu", p["select_text"])
	t.set_color("font_accelerator_color", "PopupMenu", p["muted"])
	t.set_color("font_separator_color", "PopupMenu", p["muted"])
	var sep := StyleBoxLine.new()
	sep.color = p["border"]
	sep.thickness = 1
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_stylebox("separator", "HSeparator", sep)
	var vsep := StyleBoxLine.new()
	vsep.color = p["border"]
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)
	# Campos
	for typ in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", typ, field_sb)
		t.set_stylebox("focus", typ, field_focus)
		t.set_stylebox("read_only", typ, field_sb if typ == "TextEdit" else _sb(p["bg"], p["border"], 1, r, 6, 4))
		t.set_color("font_color", typ, p["text"])
		t.set_color("font_readonly_color", typ, p["muted"])
		t.set_color("caret_color", typ, p["text"])
		t.set_color("selection_color", typ, Color(p["accent"], 0.35))
		t.set_color("font_selected_color", typ, p["text"])
		t.set_color("font_placeholder_color", typ, p["muted"])
	t.set_color("font_readonly_color", "TextEdit", p["text"])
	t.set_color("background_color", "TextEdit", p["field"])
	for nm in ["up", "up_hover", "up_pressed", "up_disabled"]:
		t.set_icon(nm, "SpinBox", _arrow_tex(p["text"], true, 8, 5))
	for nm in ["down", "down_hover", "down_pressed", "down_disabled"]:
		t.set_icon(nm, "SpinBox", _arrow_tex(p["text"], false, 8, 5))
	# Tabelas
	t.set_stylebox("panel", "Tree", _bevel(p["field"], true, 2, 2) if c else _sb(p["field"], p["border"], 1, r, 2, 2))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("selected", "Tree", _sb(p["select"]))
	t.set_stylebox("selected_focus", "Tree", _sb(p["select"]))
	t.set_stylebox("cursor", "Tree", _sb(Color(0, 0, 0, 0), p["accent"], 1))
	t.set_stylebox("cursor_unfocused", "Tree", _sb(Color(0, 0, 0, 0), p["border"], 1))
	var tb: StyleBoxFlat = _bevel(p["title_bg"], false, 4, 4) if c else _sb(p["title_bg"], p["border"], 0, 0, 4, 5)
	if not c:
		tb.border_width_bottom = 1
		tb.border_width_right = 1
	t.set_stylebox("title_button_normal", "Tree", tb)
	t.set_stylebox("title_button_hover", "Tree", tb)
	t.set_stylebox("title_button_pressed", "Tree", tb)
	t.set_color("title_button_color", "Tree", p["text"])
	t.set_color("font_color", "Tree", p["text"])
	t.set_color("font_selected_color", "Tree", p["select_text"])
	t.set_color("guide_color", "Tree", Color(p["border"], 0.7))
	t.set_constant("draw_guides", "Tree", 1)
	t.set_constant("v_separation", "Tree", 6)
	t.set_constant("item_margin", "Tree", 0)
	t.set_font_size("title_button_font_size", "Tree", 13)
	# Abas
	var tab_sel: StyleBoxFlat = _bevel(p["panel"], false, 14, 6) if c else _sb(p["panel"], p["border"], 1, 0, 14, 6)
	if not c:
		tab_sel.border_width_bottom = 0
		tab_sel.border_width_top = 3
		tab_sel.border_color = p["border"]
		tab_sel.corner_radius_top_left = r
		tab_sel.corner_radius_top_right = r
	var tab_un: StyleBoxFlat = _bevel(p["bg"] if not c else Color("b0b0b0"), false, 14, 6) if c else _sb(p["bg"], Color(0, 0, 0, 0), 0, 0, 14, 6)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", _sb(p["button_hover"], Color(0, 0, 0, 0), 0, 0, 14, 6))
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TabContainer", _bevel(p["panel"], false, 10, 10) if c else _sb(p["panel"], p["border"], 1, r, 10, 10))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", p["accent"] if not c else p["text"])
	t.set_color("font_unselected_color", "TabContainer", p["muted"])
	t.set_color("font_hovered_color", "TabContainer", p["text"])
	# Barras de rolagem
	for typ in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", typ, _sb(Color(p["border"], 0.25), Color(0, 0, 0, 0), 0, 4, 4, 4))
		t.set_stylebox("grabber", typ, _sb(Color(p["muted"], 0.55), Color(0, 0, 0, 0), 0, 4, 4, 4))
		t.set_stylebox("grabber_highlight", typ, _sb(Color(p["muted"], 0.8), Color(0, 0, 0, 0), 0, 4, 4, 4))
		t.set_stylebox("grabber_pressed", typ, _sb(p["accent"], Color(0, 0, 0, 0), 0, 4, 4, 4))
	# Dicas e janelas
	t.set_stylebox("panel", "TooltipPanel", _sb(Color("ffffe1") if c else Color("1d2733"), p["border"], 1, r, 8, 5))
	t.set_color("font_color", "TooltipLabel", Color("000000") if c else Color("ffffff"))
	var win := _sb(p["header"], p["border"], 1, r, 0, 0)
	win.expand_margin_left = 6
	win.expand_margin_right = 6
	win.expand_margin_bottom = 6
	win.expand_margin_top = 30
	t.set_stylebox("embedded_border", "Window", win)
	t.set_stylebox("embedded_unfocused_border", "Window", win)
	t.set_color("title_color", "Window", p["header_text"])
	t.set_stylebox("panel", "AcceptDialog", _sb(p["panel"], Color(0, 0, 0, 0), 0, 0, 12, 12))
	return t


func _apply_theme() -> void:
	pal = _palette(classic)
	theme = _make_theme(classic)
	bg_panel.add_theme_stylebox_override("panel", _sb(pal["bg"], Color(0, 0, 0, 0), 0, 0, 0, 0))
	var hs := _sb(pal["header"], Color(0, 0, 0, 0), 0, 0, 16, 8)
	header.add_theme_stylebox_override("panel", hs)
	header_title.add_theme_color_override("font_color", pal["header_text"])
	header_sub.add_theme_color_override("font_color", Color(pal["header_text"], 0.8))
	var sbar: PanelContainer = bg_panel.find_child("BarraStatus", true, false)
	if sbar:
		var ss: StyleBoxFlat = _bevel(pal["status"], true, 10, 3) if classic else _sb(pal["status"], pal["border"], 0, 0, 10, 4)
		if not classic:
			ss.border_width_top = 1
		sbar.add_theme_stylebox_override("panel", ss)
	_apply_meta_colors(self)
	if file_dialog:
		file_dialog.theme = ThemeDB.get_default_theme()


func _apply_meta_colors(n: Node) -> void:
	for ch in n.get_children():
		if ch is Label:
			if ch.has_meta("muted"):
				ch.add_theme_color_override("font_color", pal["muted"])
			elif ch.has_meta("titulo"):
				ch.add_theme_color_override("font_color", pal["accent"])
		_apply_meta_colors(ch)
