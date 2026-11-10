extends Control
## Janela principal do DimEsgoto: projeto de redes de esgoto sanitário
## no estilo do CEsg (traçado gráfico, planilhas, dimensionamento, banco de dados).

const Calc = preload("res://calc.gd")
const Net = preload("res://net.gd")
const Db = preload("res://db.gd")
const Topo = preload("res://topo.gd")
const Dxf = preload("res://dxf.gd")
const Report = preload("res://report.gd")
const PlanView = preload("res://plan_view.gd")
const GridTable = preload("res://grid_table.gd")
const Icons = preload("res://icons.gd")
const Dialogs = preload("res://dialogs.gd")
const Registro = preload("res://registro.gd")
const Cadastro = preload("res://cadastro.gd")
const Geo = preload("res://geo.gd")

const APP_NAME := "DimEsgoto"
const VERSAO := "0.1.0-alpha"
const CFG := "user://dimesgoto.cfg"
const DB_PADRAO := "user://cesgcust.json"

# ------------------------------------------------------------------ planilhas (cap. 3 do manual)
const SH_TRECHOS := [
	{"t": "Coletor", "k": "coletor", "w": 70, "f": "s"},
	{"t": "Nó Inicial", "k": "ni_nome", "w": 80, "f": "s"},
	{"t": "Nó Final", "k": "nf_nome", "w": 80, "f": "s"},
	{"t": "Extensão (m)", "k": "L", "w": 95, "f": "f2", "edit": true},
	{"t": "Nome do Trecho", "k": "nome", "w": 110, "f": "s", "edit": true},
	{"t": "Diâmetro (mm)", "k": "d", "w": 95, "f": "f0", "edit": true},
	{"t": "Cota Mon. (m)", "k": "cc_m", "w": 100, "f": "f3", "edit": true},
	{"t": "Cota Jus. (m)", "k": "cc_j", "w": 100, "f": "f3", "edit": true},
	{"t": "Fixa Diam.", "k": "fixa_d", "w": 75, "f": "chk", "edit": true},
	{"t": "Fixa Cotas", "k": "fixa_cotas", "w": 75, "f": "chk", "edit": true},
	{"t": "Fixa Ext.", "k": "fixa_ext", "w": 75, "f": "chk", "edit": true},
]
const SH_NOS := [
	{"t": "Nome do Coletor", "k": "coletor", "w": 100, "f": "s"},
	{"t": "Nó", "k": "nome", "w": 80, "f": "s", "edit": true},
	{"t": "Coordenada N (m)", "k": "n", "w": 120, "f": "f2", "edit": true},
	{"t": "Coordenada E (m)", "k": "e", "w": 120, "f": "f2", "edit": true},
	{"t": "Cota Terreno (m)", "k": "ct", "w": 110, "f": "f3", "edit": true},
	{"t": "Qpontual Ini (l/s)", "k": "qp_i", "w": 115, "f": "f4", "edit": true},
	{"t": "Qpontual Fim (l/s)", "k": "qp_f", "w": 115, "f": "f4", "edit": true},
	{"t": "Tipo do Nó", "k": "tipo", "w": 80, "f": "choice", "edit": true},
	{"t": "Cota confirmada", "k": "ct_ok", "w": 105, "f": "chk", "edit": true},
]
const SH_DIMENS := [
	{"t": "Coletor", "k": "coletor", "w": 70, "f": "s"},
	{"t": "Nó Inicial", "k": "ni_nome", "w": 80, "f": "s"},
	{"t": "Nó Final", "k": "nf_nome", "w": 80, "f": "s"},
	{"t": "Extensão (m)", "k": "L", "w": 95, "f": "f2"},
	{"t": "Nome do Trecho", "k": "nome", "w": 110, "f": "s"},
	{"t": "Recobr. Mín. (m)", "k": "recob", "w": 110, "f": "f3", "edit": true},
	{"t": "Prof. Máx. (m)", "k": "pmax", "w": 100, "f": "f2", "edit": true},
	{"t": "Situação", "k": "situacao", "w": 140, "f": "choice", "edit": true},
	{"t": "Crit. Interp.", "k": "crit", "w": 130, "f": "choice", "edit": true},
]
const SH_QUANT := [
	{"t": "Coletor", "k": "coletor", "w": 70, "f": "s"},
	{"t": "Nó Inicial", "k": "ni_nome", "w": 75, "f": "s"},
	{"t": "Nó Final", "k": "nf_nome", "w": 75, "f": "s"},
	{"t": "Extensão (m)", "k": "L", "w": 90, "f": "f2"},
	{"t": "Nome do Trecho", "k": "nome", "w": 100, "f": "s"},
	{"t": "Material", "k": "material", "w": 230, "f": "choice", "edit": true},
	{"t": "Tipo de Superfície", "k": "superficie", "w": 150, "f": "choice", "edit": true},
	{"t": "Tipo de Escoramento", "k": "escoramento", "w": 150, "f": "choice", "edit": true},
	{"t": "Aterro Compactado", "k": "aterro", "w": 115, "f": "chk", "edit": true},
]
const SH_RES := [
	{"t": "Col.", "k": "col", "w": 46, "f": "s"},
	{"t": "Trecho", "k": "tr", "w": 56, "f": "s"},
	{"t": "PV Ini\nPV Fim", "k": "pv", "w": 56, "f": "s"},
	{"t": "Ext.\n(m)", "k": "L", "w": 62, "f": "f2"},
	{"t": "Cont.Lin\n(l/s·km)", "k": "tx", "w": 70, "f": "f3"},
	{"t": "Cont.Tre\n(l/s)", "k": "ctr", "w": 64, "f": "f3"},
	{"t": "Q Pontual\n(l/s)", "k": "qp", "w": 66, "f": "f3"},
	{"t": "Q Mont.\n(l/s)", "k": "qm", "w": 64, "f": "f3"},
	{"t": "Q Jus.\n(l/s)", "k": "qj", "w": 64, "f": "f3"},
	{"t": "Diam.\n(mm)", "k": "d", "w": 52, "f": "f0"},
	{"t": "Decliv.\n(m/m)", "k": "i", "w": 64, "f": "f4"},
	{"t": "Cota Ter.\n(m)", "k": "ct", "w": 76, "f": "f3"},
	{"t": "Cota Col.\n(m)", "k": "cc", "w": 76, "f": "f3"},
	{"t": "Rec.Col.\n(m) mon/jus", "k": "rec", "w": 72, "f": "f3"},
	{"t": "Prof.Vala\n(m) mon/jus", "k": "pv_", "w": 76, "f": "f3"},
	{"t": "y/D\nini/fim", "k": "yd", "w": 52, "f": "f2"},
	{"t": "V (m/s)\nini/fim", "k": "v", "w": 56, "f": "f2"},
	{"t": "Arr.In (Pa)\nVc (m/s)", "k": "sv", "w": 70, "f": "f2"},
	{"t": "n ou k\nini/fim", "k": "rug", "w": 60, "f": "f4"},
	{"t": "Larg.Vala\n(m)", "k": "larg", "w": 64, "f": "f2"},
	{"t": "Escoramento", "k": "esc", "w": 120, "f": "s"},
]
const SH_ORC := [
	{"t": "Descrição", "k": "desc", "w": 380, "f": "s"},
	{"t": "Quant.", "k": "q", "w": 100, "f": "f2"},
	{"t": "Unidade", "k": "un", "w": 70, "f": "s", "align": HORIZONTAL_ALIGNMENT_CENTER},
	{"t": "Custo (R$)\nUnitário", "k": "c1", "w": 120, "f": "f2"},
	{"t": "Custo (R$)\nUnitário", "k": "c2", "w": 120, "f": "f2"},
	{"t": "Custo (R$)\nTotal", "k": "total", "w": 130, "f": "f2"},
]
const SH_OBS := [
	{"t": "Trecho", "k": "trecho", "w": 90, "f": "s"},
	{"t": "Observações", "k": "obs", "w": 760, "f": "s"},
]
const SHEETS := [["trechos", "Plan. Trechos"], ["nos", "Plan. Nós"], ["dimens", "Plan. Dimens."], ["quant", "Plan. Quant."],
	["res", "Resultados"], ["orc", "Orçamento"], ["obs", "Observações"]]

var proj: Dictionary
var db: Dictionary
var topo = Topo.new()
var results: Dictionary = {}
var resultados_validos := false
var resultados_atuais := false
var opts: Dictionary = {}
var current_path := ""
var dirty := false
var classic := false
var pal: Dictionary = {}
var ultimo_res := "Ainda não definido"
var dlg

var bg_panel: PanelContainer
var menu_of := {}
var menus := {}
var tool_btns := {}
var plan
var sheets: TabContainer
var tables := {}
var view := "tracado"
var status_label: Label
var stale_label: Label
var coord_labels := {}
var modo_btns := {}
var file_dialog: FileDialog
var file_cb: Callable
var file_ext := ""
var confirm_dialog: ConfirmationDialog
var confirm_action := ""
var busca := ""
var _mono: SystemFont
var undo_stack: Array = []
var registro
var erro_btn: Button
var arg_simular_erro := false
var redo_stack: Array = []
var _estado: Dictionary = {}

var shot_path := ""
var frame_count := 0
var arg_vista := ""
var arg_aba := -1
var arg_dialogo := ""


func _ready() -> void:
	registro = Registro.new()
	registro.name = "Registro"
	add_child(registro)
	registro.iniciar(APP_NAME, VERSAO)
	opts = _default_opts()
	_carregar_config()
	classic = bool(opts.get("classico", false))
	_parse_args()
	if shot_path != "":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	if not FileAccess.file_exists(_db_file()) and _db_file() == DB_PADRAO:
		Db.salvar(DB_PADRAO, Db.defaults())
	db = Db.carregar(_db_file())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dlg = Dialogs.new(self)
	_build_ui()
	_apply_theme()
	_set_projeto(Net.exemplo(Calc.default_params(), db), "")
	executar_calculo(false)
	_reiniciar_historico()
	dirty = false
	_update_title()
	_mostrar(arg_vista if arg_vista != "" else "tracado")
	if arg_aba >= 0:
		sheets.current_tab = clampi(arg_aba, 0, SHEETS.size() - 1)
	set_status("Pronto. Rede de exemplo carregada — botão 2 numa área vazia inicia um coletor; F1 mostra os comandos.")
	await get_tree().process_frame
	plan.ajuste_maximo()
	plan.hist.clear()
	registro.erros_mudaram.connect(_on_erros)
	if arg_simular_erro:
		_simular_erro()
		await get_tree().process_frame
		registro.verificar_godot_log()
	if arg_dialogo != "":
		_abrir_dialogo_teste(arg_dialogo)


## Só para diagnóstico (--simular-erro): provoca um erro de script de propósito.
func _simular_erro() -> void:
	registro.acao("Diagnóstico: simulando um erro de script")
	var vazio := {}
	var _x = vazio["chave_inexistente"]


func _on_erros(n: int) -> void:
	erro_btn.visible = n > 0
	erro_btn.text = "  %d erro%s — ver registro  " % [n, "" if n == 1 else "s"]


func _abrir_dialogo_teste(qual: String) -> void:
	match qual:
		"dimensionamento":
			dlg.abrir_dimensionamento()
		"banco":
			dlg.abrir_banco()
		"no":
			dlg.abrir_no(int(proj["nodes"][3]["id"]))
		"trecho":
			dlg.abrir_trecho(int(proj["trechos"][2]["id"]))
		"perfil":
			for t in proj["trechos"]:
				if str(t["coletor"]) == "C1":
					plan.marked[int(t["id"])] = true
			perfil()
		"area":
			dlg.abrir_area()
		"registro":
			dlg.abrir_registro()


# ------------------------------------------------------------------ captura de tela (testes)

func _parse_args() -> void:
	var args: Array = Array(OS.get_cmdline_args()) + Array(OS.get_cmdline_user_args())
	for i in args.size():
		var a := str(args[i])
		if a == "--screenshot" and i + 1 < args.size():
			shot_path = str(args[i + 1])
		elif a.begins_with("--screenshot="):
			shot_path = a.substr(13)
		elif a.begins_with("--vista="):
			arg_vista = a.substr(8)
		elif a.begins_with("--aba="):
			arg_aba = a.substr(6).to_int()
			if arg_vista == "":
				arg_vista = "planilhas"
		elif a.begins_with("--dialogo="):
			arg_dialogo = a.substr(10)
		elif a == "--simular-erro":
			arg_simular_erro = true
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


# ------------------------------------------------------------------ utilidades

func fmt(v, dec: int) -> String:
	return (("%." + str(dec) + "f") % float(v)).replace(".", ",")


func num(s: String) -> float:
	return s.strip_edges().replace(" ", "").replace(",", ".").to_float()


func fonte_mono() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "Consolas", "Courier New", "monospace"])
	return _mono


func set_status(s: String) -> void:
	if status_label:
		status_label.text = s


func _update_title() -> void:
	var nome := current_path.get_file() if current_path != "" else str(proj.get("info", {}).get("projeto", "Sem título"))
	get_window().title = "%s - Cálculo de Redes de Esgotos - %s%s" % [APP_NAME, nome, " *" if dirty else ""]


func marcar_alterado(acao := "dados") -> void:
	dirty = true
	resultados_atuais = false
	_registrar(acao)
	_update_title()
	_atualizar_menus()
	_atualizar_stale()


func on_changed(kind: String) -> void:
	dirty = true
	if kind != "visual":
		resultados_atuais = false
	registro.acao("Alteração: " + str(ROTULOS_ACAO.get(kind, kind)))
	_registrar(kind)
	_update_title()
	plan.redesenhar()
	if view == "planilhas":
		_refresh_sheet(sheets.current_tab)
	_atualizar_menus()
	_atualizar_stale()


func on_marcados() -> void:
	_atualizar_menus()
	var n: int = plan.marked.size()
	if n > 0:
		set_status("%d trecho(s) marcado(s). Use Trechos › Apaga / Divide / Desloca / Perfil." % n)


func _atualizar_stale() -> void:
	if stale_label == null:
		return
	if resultados_validos and not resultados_atuais:
		stale_label.text = "  Resultados desatualizados — Ctrl+D  "
		stale_label.visible = true
	else:
		stale_label.visible = false


# ------------------------------------------------------------------ desfazer / refazer

const ROTULOS_ACAO := {
	"traçado": "traçado", "mover": "mover nó", "no": "edição do nó", "trecho": "edição do trecho",
	"planilha": "edição na planilha", "apagar": "apagar trechos", "dividir": "dividir trecho",
	"deslocar": "deslocar trecho", "cotas": "recalcular cotas", "topo": "base topográfica",
	"dimensionamento": "dimensionamento", "dados": "dados do projeto", "banco": "banco de dados",
	"cadastro": "cadastro / SIG",
}
const MAX_DESFAZER := 100


## Foto do projeto: tudo copiado, menos a topografia (que só é trocada por inteiro e
## por isso pode ser guardada por referência) e os resultados (idem).
func _foto() -> Dictionary:
	var p := {}
	for k in proj.keys():
		if k == "topo":
			continue
		var v = proj[k]
		p[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return {"p": p, "topo": proj.get("topo", {}), "res": results, "rv": resultados_validos, "ra": resultados_atuais}


func _reiniciar_historico() -> void:
	undo_stack.clear()
	redo_stack.clear()
	_estado = _foto()
	if plan != null:
		_atualizar_menus()


## Chamado depois de cada alteração: guarda o estado anterior na pilha de desfazer.
func _registrar(acao: String) -> void:
	var novo := _foto()
	if _estado.is_empty():
		_estado = novo
		return
	if novo["p"] == _estado["p"] and is_same(novo["topo"], _estado["topo"]) and is_same(novo["res"], _estado["res"]):
		_estado = novo
		return
	_estado["acao"] = acao
	undo_stack.append(_estado)
	while undo_stack.size() > MAX_DESFAZER:
		undo_stack.pop_front()
	redo_stack.clear()
	_estado = novo


func _dialogo_aberto() -> bool:
	for ch in get_children():
		if ch is AcceptDialog and ch.visible:
			return true
	return false


func desfazer() -> void:
	if undo_stack.is_empty():
		set_status("Nada para desfazer.")
		return
	if _dialogo_aberto():
		return
	plan.cancelar()
	var alvo: Dictionary = undo_stack.pop_back()
	var acao := str(alvo.get("acao", ""))
	var atual := _foto()
	atual["acao"] = acao
	redo_stack.append(atual)
	_restaurar(alvo)
	set_status("Desfeito: %s.  (Ctrl+Y refaz)" % ROTULOS_ACAO.get(acao, acao))


func refazer() -> void:
	if redo_stack.is_empty():
		set_status("Nada para refazer.")
		return
	if _dialogo_aberto():
		return
	plan.cancelar()
	var alvo: Dictionary = redo_stack.pop_back()
	var acao := str(alvo.get("acao", ""))
	var atual := _foto()
	atual["acao"] = acao
	undo_stack.append(atual)
	_restaurar(alvo)
	set_status("Refeito: %s." % ROTULOS_ACAO.get(acao, acao))


func _restaurar(f: Dictionary) -> void:
	var topo_antigo = proj.get("topo", {})
	var p: Dictionary = f["p"].duplicate(true)
	p["topo"] = f["topo"]
	proj = p
	if not is_same(topo_antigo, f["topo"]):
		topo.from_dict(proj["topo"])
	results = f["res"]
	resultados_validos = bool(f["rv"])
	resultados_atuais = bool(f["ra"])
	_estado = f
	_estado.erase("acao")
	plan.marked.clear()
	plan.rastro = {}
	plan.set_imagem(str(proj.get("imagem", "")))
	dirty = true
	_update_title()
	plan.redesenhar()
	if view == "planilhas":
		_refresh_sheet(sheets.current_tab)
	_atualizar_menus()
	_atualizar_stale()


func _shortcut_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.is_command_or_control_pressed() \
			and ev.shift_pressed and ev.keycode == KEY_Z:
		refazer()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ configuração

func _default_opts() -> Dictionary:
	return {
		"mostra_grid": true, "mostra_imagem": true, "rotulo_no": true, "rotulo_trecho": true, "rotulo_resultado": true, "espessura": 2,
		"topo_desenho": 0, "topo_texto": false, "topo_legenda": true, "topo_leg_int": 5.0,
		"cor_principal": "ee7340", "cor_secundaria": "f5cf4c", "ruas_desenho": true, "cor_ruas": "339eb8",
		"pontos_desenho": true, "pontos_valor": true, "cor_pontos": "2673bf",
		"exp_rede": true, "exp_ruas": true, "exp_topo": true, "exp_malha": true, "exp_margem": true, "exp_pontos": true, "exp_escala": 1000.0,
		"cota_modo": "int", "raio": 100.0, "precisao": 3, "rastro": true, "raio_pontos": 100.0,
		"grava_res": true, "prefixo": "CESG", "res_num": 0, "data_dir": "", "db_path": "", "classico": false, "recentes": [],
	}


func _carregar_config() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG) != OK:
		return
	for k in opts.keys():
		if cf.has_section_key("opts", k):
			opts[k] = cf.get_value("opts", k)


func salvar_config() -> void:
	opts["classico"] = classic
	var cf := ConfigFile.new()
	for k in opts.keys():
		cf.set_value("opts", k, opts[k])
	cf.save(CFG)


func _db_file() -> String:
	var p := str(opts.get("db_path", ""))
	return p if p != "" else DB_PADRAO


func db_path_exibicao() -> String:
	return ProjectSettings.globalize_path(_db_file())


func aplicar_banco(novo: Dictionary) -> void:
	db = novo
	if not Db.salvar(_db_file(), db):
		set_status("Não foi possível gravar o banco em %s." % db_path_exibicao())
	else:
		set_status("Banco de itens de custo atualizado.")
	on_changed("banco")


func _data_dir() -> String:
	var d := str(opts.get("data_dir", ""))
	if d != "" and DirAccess.dir_exists_absolute(d):
		return d
	if current_path != "":
		return current_path.get_base_dir()
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)


# ------------------------------------------------------------------ interface

func _build_ui() -> void:
	bg_panel = PanelContainer.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	bg_panel.add_child(v)
	v.add_child(_build_menu())
	v.add_child(_build_toolbar())
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.clip_contents = true
	v.add_child(stack)
	plan = PlanView.new()
	plan.main = self
	plan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plan.cursor_moved.connect(_on_cursor)
	stack.add_child(plan)
	sheets = TabContainer.new()
	sheets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheets.tabs_position = TabContainer.POSITION_BOTTOM
	sheets.visible = false
	stack.add_child(sheets)
	var specs := {"trechos": SH_TRECHOS, "nos": SH_NOS, "dimens": SH_DIMENS, "quant": SH_QUANT, "res": SH_RES, "orc": SH_ORC, "obs": SH_OBS}
	for sh in SHEETS:
		var gt := GridTable.new()
		gt.name = str(sh[0])
		gt.setup(specs[sh[0]])
		gt.choices_fn = Callable(self, "_choices")
		var key: String = sh[0]
		gt.cells_changed.connect(func(ch): _on_sheet_cells(key, ch))
		if key in ["res", "obs"]:
			gt.tint_readonly = false
		sheets.add_child(gt)
		sheets.set_tab_title(sheets.get_tab_count() - 1, str(sh[1]))
		tables[key] = gt
	sheets.tab_changed.connect(func(i): _refresh_sheet(i))
	v.add_child(_build_statusbar())

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.size = Vector2i(900, 560)
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.dir_selected.connect(_on_file_selected)
	add_child(file_dialog)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Alterações não salvas"
	confirm_dialog.dialog_text = "O projeto atual tem alterações não salvas.\nDeseja descartá-las?"
	confirm_dialog.ok_button_text = "Descartar"
	confirm_dialog.cancel_button_text = "Cancelar"
	confirm_dialog.confirmed.connect(func(): _do_action(confirm_action))
	add_child(confirm_dialog)


func _menu(mb: MenuBar, titulo: String, itens: Array) -> PopupMenu:
	var pm := PopupMenu.new()
	pm.name = titulo
	_preencher_menu(pm, itens)
	pm.id_pressed.connect(_on_menu)
	mb.add_child(pm)
	menus[titulo] = pm
	return pm


func _preencher_menu(pm: PopupMenu, itens: Array) -> void:
	for it in itens:
		if it.is_empty():
			pm.add_separator()
		elif it[0] == "sub":
			var sub := PopupMenu.new()
			sub.name = str(it[1])
			_preencher_menu(sub, it[2])
			sub.id_pressed.connect(_on_menu)
			pm.add_submenu_node_item(str(it[1]), sub)
			menus[str(it[1])] = sub
		elif it[0] == "chk":
			pm.add_check_item(str(it[1]), int(it[2]))
			menu_of[int(it[2])] = pm
		else:
			pm.add_item(str(it[0]), int(it[1]), int(it[2]) if it.size() > 2 else 0)
			menu_of[int(it[1])] = pm


func _build_menu() -> Control:
	var mb := MenuBar.new()
	mb.flat = true
	_menu(mb, "Arquivos", [
		["Novo…", 0, KEY_MASK_CTRL | KEY_N], ["Novo com imagem…", 1], ["Lê…", 2],
		["Lê DXF de topografia…", 3], ["Lê DXF de ruas…", 4], ["Lê DXF de pontos cotados…", 5], ["Remove a base topográfica", 6],
		["sub", "Cadastro e SIG", [["Importa ligações (CSV)…", 90], ["Exporta relatório de ligações (CSV)…", 91], [],
			["Importa bacias (GeoJSON)…", 92], ["Balanço de contribuições…", 97], [],
			["Importa interferências (GeoJSON)…", 93], ["Exporta interferências (GeoJSON)…", 94], [],
			["Exporta rede (GeoJSON)…", 95], ["Importa rede (GeoJSON)…", 96]]], [],
		["Salva", 7, KEY_F2], ["Salva como…", 8], ["Exporta planta para DXF…", 9], ["Exporta planilha…", 10],
		["Exporta memorial de cálculo (TXT/PDF)…", 11], [],
		["Imprimir", 12], ["Visualizar impressão de planilha", 13], [],
		["sub", "Parâmetros", [["Diretório de dados…", 14], ["Banco de itens de custo…", 15], ["Usar banco padrão", 17]]],
		["Propriedades do projeto…", 16], ["sub", "Arquivos recentes", []], [], ["Fim", 19, KEY_MASK_CTRL | KEY_Q]])
	_menu(mb, "Editar", [["Desfazer", 80, KEY_MASK_CTRL | KEY_Z], ["Refazer", 81, KEY_MASK_CTRL | KEY_Y]])
	_menu(mb, "Opções", [
		["Área de trabalho…", 20], ["Traçado da rede", 21, KEY_MASK_CTRL | KEY_L], ["Exibição de DXF's", 22, KEY_MASK_CTRL | KEY_X],
		["Cálculo automático de cotas", 23, KEY_MASK_CTRL | KEY_S], [],
		["sub", "Resultados", [["chk", "Grava arquivo", 24], ["Prefixo p/ o arquivo…", 25]]], [],
		["Localizar", 26, KEY_F5], ["Localizar próxima", 27, KEY_F3], [], ["chk", "Visual clássico", 28]])
	_menu(mb, "Visualizar", [
		["Zoom in (1,25)", 30, KEY_MASK_CTRL | KEY_I], ["Zoom out (0,80)", 31, KEY_MASK_CTRL | KEY_O], [],
		["Sem zoom", 32, KEY_MASK_CTRL | KEY_0], ["Último zoom", 33, KEY_MASK_CTRL | KEY_U], ["Janela", 34, KEY_MASK_CTRL | KEY_J],
		["Pan", 35, KEY_MASK_CTRL | KEY_P], [], ["Ajuste máximo", 36, KEY_MASK_CTRL | KEY_A], ["Redesenha", 37, KEY_MASK_CTRL | KEY_R]])
	_menu(mb, "Acionar", [
		["Traçado", 40, KEY_MASK_CTRL | KEY_T], ["Planilhas", 41, KEY_MASK_CTRL | KEY_E], ["Dimensionamento", 42, KEY_MASK_CTRL | KEY_D], [],
		["Planilha de observações", 43], [],
		["Fixar coordenadas e cotas", 44, KEY_F6], ["Fixar cota do pto mais próx.", 45, KEY_F7],
		["Interpolação de cotas nas curvas de nível", 46, KEY_F8], [], ["Recalcular cotas", 47], [], ["Carregar rede de exemplo", 48]])
	_menu(mb, "Trechos", [
		["Apaga marcados", 50, KEY_DELETE], ["Desmarca trechos", 51], ["Desloca trecho", 52], ["Divide trecho", 53], [], ["Perfil", 54]])
	_menu(mb, "Banco de dados", [["Itens de custo, materiais e tubos…", 60]])
	_menu(mb, "Ajuda", [["Conteúdo", 70, KEY_F1], ["Como usar?", 71], ["Créditos", 72], [], ["Registro de erros…", 73]])
	var pm: PopupMenu = menus["Opções"]
	var sub: PopupMenu = menus["Resultados"]
	sub.set_item_checked(sub.get_item_index(24), bool(opts.get("grava_res", true)))
	pm.set_item_checked(pm.get_item_index(28), classic)
	_atualizar_recentes()
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 4)
	wrap.add_child(mb)
	return wrap


func _build_toolbar() -> Control:
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 6)
	m.add_theme_constant_override("margin_top", 2)
	m.add_theme_constant_override("margin_bottom", 4)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	m.add_child(h)
	var itens := [
		["novo", 0, "Arquivo novo (Ctrl+N)"], ["abre", 2, "Abre projeto"], ["salva", 7, "Salva (F2)"], [],
		["desfazer", 80, "Desfazer (Ctrl+Z)"], ["refazer", 81, "Refazer (Ctrl+Y ou Ctrl+Shift+Z)"], [],
		["dxf", 9, "Exporta planta para DXF"], ["exp_planilha", 10, "Exporta planilha (CSV/HTML)"], [],
		["imprime", 12, "Imprime (abre a planta ou a planilha para impressão)"], ["visualiza", 13, "Visualiza impressão de planilha"], [],
		["zoom_max", 36, "Ajuste máximo (Ctrl+A)"], ["janela", 34, "Zoom janela (Ctrl+J)"], ["redesenha", 37, "Redesenha (Ctrl+R)"], ["pan", 35, "Pan (Ctrl+P)"], [],
		["tracado", 40, "Traçado (Ctrl+T)"], ["planilhas", 41, "Planilhas (Ctrl+E)"], ["calculo", 42, "Cálculos / dimensionamento (Ctrl+D)"], [],
		["apaga", 50, "Apaga trechos marcados (Del)"], ["desmarca", 51, "Desmarca trechos"], ["desloca", 52, "Desloca trecho"], ["divide", 53, "Divide trecho"], [],
		["perfil", 54, "Perfil dos trechos marcados"], ["obs", 43, "Planilha de observações"],
	]
	for it in itens:
		if it.is_empty():
			var s := VSeparator.new()
			s.custom_minimum_size = Vector2(8, 0)
			h.add_child(s)
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(32, 30)
		b.tooltip_text = it[2]
		b.focus_mode = Control.FOCUS_NONE
		var ic := Control.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 5
		ic.offset_top = 4
		ic.offset_right = -5
		ic.offset_bottom = -4
		var icon_id: String = it[0]
		ic.draw.connect(func(): Icons.desenhar(ic, icon_id, ic.size, pal.get("text", Color.BLACK)))
		b.add_child(ic)
		var id: int = it[1]
		b.pressed.connect(func(): _on_menu(id))
		h.add_child(b)
		tool_btns[id] = b
	return m


func _build_statusbar() -> Control:
	var sbar := PanelContainer.new()
	sbar.name = "BarraStatus"
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	sbar.add_child(sh)
	for m in [["cc", "C+C", "Fixar cotas e coordenadas do ponto cotado mais próximo (F6)"],
			["prx", "PRX", "Fixar a cota do ponto cotado mais próximo (F7)"],
			["int", "INT", "Interpolação de cotas nas curvas de nível (F8)"]]:
		var b := Button.new()
		b.text = m[1]
		b.toggle_mode = true
		b.tooltip_text = m[2]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		b.custom_minimum_size = Vector2(38, 0)
		var modo: String = m[0]
		b.pressed.connect(func(): _set_modo(modo if str(opts["cota_modo"]) != modo else "none"))
		sh.add_child(b)
		modo_btns[modo] = b
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	sh.add_child(status_label)
	erro_btn = Button.new()
	erro_btn.visible = false
	erro_btn.focus_mode = Control.FOCUS_NONE
	erro_btn.tooltip_text = "O programa registrou erros. Clique para ver o rastreio."
	erro_btn.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	erro_btn.add_theme_color_override("font_hover_color", Color(0.8, 0.1, 0.1))
	erro_btn.add_theme_font_size_override("font_size", 12)
	erro_btn.pressed.connect(func(): dlg.abrir_registro())
	sh.add_child(erro_btn)
	stale_label = Label.new()
	stale_label.visible = false
	stale_label.add_theme_color_override("font_color", Color(0.75, 0.35, 0.0))
	sh.add_child(stale_label)
	for k in [["n", "N:", 110], ["e", "E:", 110], ["z", "Z:", 80], ["d", "Dist:", 90]]:
		var l := Label.new()
		l.text = "%s " % k[1]
		l.custom_minimum_size = Vector2(k[2], 0)
		l.add_theme_font_size_override("font_size", 12)
		sh.add_child(l)
		coord_labels[k[0]] = l
	return sbar


func _on_cursor(e: float, n: float, z: float, dist: float) -> void:
	coord_labels["n"].text = "N: %s" % fmt(n, 2)
	coord_labels["e"].text = "E: %s" % fmt(e, 2)
	coord_labels["z"].text = "Z: %s" % ("" if is_nan(z) else fmt(z, 2))
	coord_labels["d"].text = "Dist: %s" % (fmt(dist, 2) if dist > 0.0 else "-")


func _mostrar(v: String) -> void:
	view = "planilhas" if v == "planilhas" else "tracado"
	plan.visible = view == "tracado"
	sheets.visible = view == "planilhas"
	if view == "planilhas":
		_refresh_sheet(sheets.current_tab)
		tables[SHEETS[sheets.current_tab][0]].grab_focus()
	else:
		plan.grab_focus()
		plan.redesenhar()
	_atualizar_menus()


func _set_disabled(id: int, b: bool) -> void:
	if menu_of.has(id):
		var pm: PopupMenu = menu_of[id]
		pm.set_item_disabled(pm.get_item_index(id), b)
	if tool_btns.has(id):
		tool_btns[id].disabled = b
		tool_btns[id].modulate = Color(1, 1, 1, 0.35 if b else 1.0)


func _atualizar_menus() -> void:
	var nm: int = plan.marked.size()
	var tr := view == "tracado"
	for id in [50, 51, 53]:
		_set_disabled(id, nm == 0 or not tr)
	_set_disabled(52, nm != 1 or not tr)
	_set_disabled(54, nm == 0 or not resultados_validos)
	_set_disabled(43, results.get("obs", []).is_empty())
	_set_disabled(9, not resultados_validos)
	_set_disabled(10, tr)
	_set_disabled(13, tr)
	_set_disabled(27, tr)
	for id in [30, 31, 32, 33, 34, 35, 36, 37]:
		_set_disabled(id, not tr)
	_set_disabled(40, tr)
	_set_disabled(41, not tr)
	_set_disabled(80, undo_stack.is_empty())
	_set_disabled(81, redo_stack.is_empty())
	for k in [4, 5]:
		sheets.set_tab_disabled(k, not resultados_validos)
	sheets.set_tab_disabled(6, results.get("obs", []).is_empty())
	atualizar_modos()


func atualizar_modos() -> void:
	var tem_p: bool = topo.tem_pontos()
	var tem_c: bool = topo.tem_curvas()
	var m := str(opts.get("cota_modo", "int"))
	for k in modo_btns.keys():
		var b: Button = modo_btns[k]
		b.disabled = (k == "int" and not tem_c) or (k != "int" and not tem_p)
		b.set_pressed_no_signal(m == k and not b.disabled)
	_set_disabled(44, not tem_p)
	_set_disabled(45, not tem_p)
	_set_disabled(46, not tem_c)


func _set_modo(m: String) -> void:
	if m == "int" and not topo.tem_curvas():
		set_status("Leia antes um DXF de topografia (curvas de nível).")
		m = str(opts["cota_modo"])
	elif (m == "cc" or m == "prx") and not topo.tem_pontos():
		set_status("Leia antes um DXF de pontos cotados.")
		m = str(opts["cota_modo"])
	opts["cota_modo"] = m
	salvar_config()
	atualizar_modos()
	var nomes := {"none": "sem cálculo automático de cotas", "cc": "fixar cotas e coordenadas (ponto cotado mais próximo)",
		"prx": "fixar a cota do ponto cotado mais próximo", "int": "interpolação nas curvas de nível"}
	set_status("Modo do traçado: %s." % nomes.get(m, m))


# ------------------------------------------------------------------ cotas do terreno

func cota_auto(w: Vector2, rapido := false) -> Dictionary:
	var raio := float(opts.get("raio", 100.0))
	var nr := 8 * int(opts.get("precisao", 3))
	if rapido:
		if topo.tem_curvas():
			return topo.cota_curvas(w, raio, 12)
		var pq: Dictionary = topo.ponto_proximo(w, float(opts.get("raio_pontos", 100.0)))
		return {"ok": pq["ok"], "z": pq["pt"].z if pq["ok"] else NAN}
	match str(opts.get("cota_modo", "int")):
		"cc":
			var pp: Dictionary = topo.ponto_proximo(w, float(opts.get("raio_pontos", 100.0)))
			if pp["ok"]:
				return {"ok": true, "z": pp["pt"].z, "w": Vector2(pp["pt"].x, pp["pt"].y)}
		"prx":
			var pp: Dictionary = topo.ponto_proximo(w, float(opts.get("raio_pontos", 100.0)))
			if pp["ok"]:
				return {"ok": true, "z": pp["pt"].z}
		"int":
			if topo.tem_curvas():
				return topo.cota_curvas(w, raio, nr)
	return {"ok": false, "z": NAN}


## criterio: 1 curvas, 2 pontos, 3 ambos
func cota_criterio(w: Vector2, criterio: int) -> Dictionary:
	return topo.cota(w, criterio, float(opts.get("raio", 100.0)), 8 * int(opts.get("precisao", 3)), float(opts.get("raio_pontos", 100.0)))


func _cota_para_calculo(w: Vector2, crit: int) -> float:
	var r := cota_criterio(w, crit)
	return float(r["z"]) if bool(r["ok"]) else NAN


func recalcular_cotas(todos: bool, criterio: int) -> void:
	var ok := 0
	var falha := 0
	for n in proj["nodes"]:
		if not todos and bool(n.get("ct_ok", true)):
			continue
		var r := cota_criterio(Net.pos(n), criterio)
		if bool(r["ok"]):
			n["ct"] = snappedf(float(r["z"]), 0.001)
			n["ct_ok"] = true
			ok += 1
		else:
			n["ct_ok"] = false
			falha += 1
	on_changed("cotas")
	set_status("Cotas recalculadas: %d nó(s); %d sem cota (marcados com X vermelho)." % [ok, falha])


# ------------------------------------------------------------------ cálculo

func executar_calculo(gravar := true) -> Dictionary:
	plan.cancelar()
	if bool(proj["params"]["num_auto"]) and Calc.validar_rede(proj).is_empty():
		Net.renumerar(proj)
	var t0 := Time.get_ticks_msec()
	results = Calc.calcular(proj, db, Callable(self, "_cota_para_calculo"))
	if bool(results["ok"]):
		var tm := Net.trecho_map(proj)
		for tid in results["rows"].keys():
			var t: Dictionary = tm[tid]
			var r: Dictionary = results["rows"][tid]
			if not bool(t["fixa_d"]):
				t["d"] = r["d"]
			if not bool(t["fixa_cotas"]):
				t["cc_m"] = snappedf(float(r["cc_m"]), 0.001)
				t["cc_j"] = snappedf(float(r["cc_j"]), 0.001)
			if bool(proj["params"]["escoramento_auto"]):
				t["escoramento"] = r["esc"]
		results["orc"] = Calc.orcamento(proj, db, results)
		results["identificador"] = identificador()
	results["tempo_ms"] = Time.get_ticks_msec() - t0
	resultados_validos = bool(results["ok"])
	resultados_atuais = resultados_validos
	dirty = true
	# o arquivo .RES só é gravado para resultado aprovado (EVAL-104)
	if gravar and bool(opts.get("grava_res", true)) and bool(results.get("aprovado", false)):
		_gravar_res()
	_registrar("dimensionamento")
	plan.redesenhar()
	if view == "planilhas":
		_refresh_sheet(sheets.current_tab)
	_atualizar_menus()
	_atualizar_stale()
	_update_title()
	if not resultados_validos:
		set_status("O cálculo não pôde ser feito: %s" % " ".join(PackedStringArray(results["erros"])))
		registro.aviso("Dimensionamento bloqueado: %s" % " ".join(PackedStringArray(results["erros"])))
	elif not bool(results["aprovado"]):
		set_status("Resultado NÃO aprovado: há restrições impeditivas (ver Planilha de Observações). %d trechos calculados." % results["rows"].size())
		registro.acao("Dimensionamento com restrições impeditivas (não aprovado)")
	else:
		set_status("Dimensionamento concluído: %d trechos, %d observação(ões). Total orçado: R$ %s." % [
			results["rows"].size(), results["obs"].size(), fmt(results["orc"]["total"], 2)])
	return results


func _gravar_res() -> void:
	opts["res_num"] = int(opts.get("res_num", 0)) + 1
	var nome := "%s%03d.RES" % [str(opts.get("prefixo", "CESG")), int(opts["res_num"])]
	var path := _data_dir().path_join(nome)
	if gravar_texto(path, Report.memorial(proj, results, "%s %s" % [APP_NAME, VERSAO], extra_memorial()), false, false):
		ultimo_res = nome
	salvar_config()


# ------------------------------------------------------------------ rastreabilidade e bloqueio de exportação

## Identificador do conjunto projeto + parâmetros + topografia + banco + versão do motor (T4-03).
func identificador(motor := Calc.MOTOR_VERSAO) -> String:
	var dados := {"info": proj.get("info", {}), "area": proj.get("area", {}), "nodes": proj["nodes"], "trechos": proj["trechos"],
		"params": proj["params"], "referencia": proj.get("referencia", {}), "ligacoes": proj.get("ligacoes", []),
		"bacias": proj.get("bacias", []), "topo": JSON.stringify(topo.to_dict()).sha256_text(),
		"banco": Db.hash_conteudo(db), "motor": motor}
	return JSON.stringify(_sanear(dados)).sha256_text().substr(0, 16)


func extra_memorial() -> Dictionary:
	return {"banco": Db.identificacao(db), "materiais": db.get("materiais", []), "identificador": identificador()}


## "" se os resultados podem ser exportados como finais; senão, o motivo.
func motivo_bloqueio() -> String:
	if results.is_empty() or not resultados_validos:
		var erros: Array = results.get("erros", [])
		return "não há resultado de dimensionamento válido" + (" (%s)" % "; ".join(PackedStringArray(erros)) if not erros.is_empty() else "")
	if not resultados_atuais:
		return "os resultados estão desatualizados (o projeto mudou depois do cálculo) — dimensione novamente com Ctrl+D"
	if not bool(results.get("aprovado", false)):
		return "o resultado não está aprovado: há restrições impeditivas (ver Planilha de Observações)"
	return ""


func _bloqueio(oque: String) -> Dictionary:
	var m := motivo_bloqueio()
	if m == "":
		return {}
	var msg := "Exportação de %s bloqueada: %s." % [oque, m]
	set_status(msg)
	registro.aviso(msg)
	return {"ok": false, "motivo": msg}


func _avisar_bloqueio(oque: String) -> bool:
	var b := _bloqueio(oque)
	if b.is_empty():
		return false
	dlg.mensagem("Exportação bloqueada", str(b["motivo"]))
	return true


func info_rastreio() -> Dictionary:
	var b := Db.identificacao(db)
	return {"Projeto": str(proj.get("info", {}).get("projeto", "")), "Identificador do resultado": identificador(),
		"Aplicativo": "%s %s" % [APP_NAME, VERSAO], "Motor": Calc.MOTOR_VERSAO, "Banco": "%s (versão %s, conteúdo %s)" % [
		b["arquivo"] if b["arquivo"] != "" else "padrão", b["versao"], b["hash"]], "Referência espacial": Net.referencia_texto(proj),
		"Situação": "aprovado" if motivo_bloqueio() == "" else "não aprovado / desatualizado", "Separador decimal": "vírgula (CSV e HTML)"}


func exportar_memorial(path: String) -> Dictionary:
	var b := _bloqueio("memorial final")
	if not b.is_empty():
		return b
	var txt := Report.memorial(proj, results, "%s %s" % [APP_NAME, VERSAO], extra_memorial())
	var ok := false
	if path.get_extension().to_lower() == "pdf":
		ok = gravar_bytes(path, Report.pdf("Memorial de cálculo — %s" % str(proj["info"].get("projeto", "")), Array(txt.split("\n"))))
	else:
		ok = gravar_texto(path, txt)
	if ok:
		set_status("Memorial exportado: " + path)
	return {"ok": ok, "motivo": "" if ok else "falha ao gravar " + path}


func exportar_planta(path: String) -> Dictionary:
	var b := _bloqueio("planta DXF com resultados")
	if not b.is_empty():
		return b
	var ok := gravar_texto(path, Report.dxf_planta(proj, results, topo, opts, db, identificador()))
	if ok:
		set_status("Planta exportada: " + path)
	return {"ok": ok, "motivo": "" if ok else "falha ao gravar " + path}


func exportar_perfil(rows: Array, titulo: String, path: String) -> Dictionary:
	var b := _bloqueio("perfil")
	if not b.is_empty():
		return b
	var ok := gravar_texto(path, Report.dxf_perfil(rows, titulo, float(opts.get("exp_escala", 1000.0)), identificador()))
	return {"ok": ok, "motivo": "" if ok else "falha ao gravar " + path}


## Exporta uma aba de planilha (csv, xlsx, html ou pdf, pela extensão). Resultados e orçamento
## só saem como finais com resultado aprovado e atualizado.
func exportar_planilha_arquivo(key: String, path: String) -> Dictionary:
	if key in ["res", "orc"]:
		var b := _bloqueio("planilha de %s" % ("resultados" if key == "res" else "orçamento"))
		if not b.is_empty():
			return b
	var idx := -1
	for i in SHEETS.size():
		if SHEETS[i][0] == key:
			idx = i
	if idx < 0:
		return {"ok": false, "motivo": "planilha desconhecida"}
	_refresh_sheet(idx)
	var dados: Array = tables[key].dados()
	var titulo: String = SHEETS[idx][1]
	var projeto := str(proj["info"].get("projeto", ""))
	var info := info_rastreio()
	var ok := false
	match path.get_extension().to_lower():
		"xlsx":
			ok = Report.gravar_xlsx(path, titulo, dados, info)
			if not ok:
				registro.aviso("Falha ao gravar %s" % path)
		"html", "htm":
			ok = gravar_texto(path, Report.html(titulo, dados, projeto, "Identificador do resultado: %s • %s" % [info["Identificador do resultado"], info["Banco"]]))
		"pdf":
			var linhas: Array = ["Projeto: %s   •   Identificador do resultado: %s" % [projeto, info["Identificador do resultado"]], ""]
			linhas.append_array(Report.tabela_texto(dados))
			ok = gravar_bytes(path, Report.pdf(titulo, linhas))
		_:
			ok = gravar_texto(path, Report.csv(dados), true)
	if ok:
		set_status("Planilha exportada: " + path)
	return {"ok": ok, "motivo": "" if ok else "falha ao gravar " + path, "linhas": dados.size()}


# ------------------------------------------------------------------ planilhas

func _choices(chave: String) -> Array:
	match chave:
		"tipo":
			return dlg._tipos_no()
		"situacao":
			return Db.nomes(db, "situacoes")
		"crit":
			return Calc.CRITERIOS
		"material":
			return Db.nomes(db, "materiais")
		"superficie":
			return Db.nomes(db, "pavimentos")
		"escoramento":
			return Db.nomes(db, "escoramentos")
	return []


func _refresh_sheet(idx: int) -> void:
	if idx < 0 or idx >= SHEETS.size():
		return
	var key: String = SHEETS[idx][0]
	var gt: GridTable = tables[key]
	match key:
		"trechos", "dimens", "quant":
			gt.set_rows(_rows_trechos(key))
		"nos":
			gt.set_rows(_rows_nos())
		"res":
			gt.set_rows(_rows_res())
		"orc":
			gt.set_rows(_rows_orc())
		"obs":
			gt.set_rows(_rows_obs())


func _rows_trechos(key: String) -> Array:
	var nodes := Net.node_map(proj)
	var tm := Net.trecho_map(proj)
	var rows: Array = []
	for sq in Net.sequencias(proj):
		var first := true
		for tid in sq["trechos"]:
			var t: Dictionary = tm[tid]
			var r := {"_meta": tid, "coletor": str(sq["nome"]) if first else "",
				"ni_nome": str(nodes.get(int(t["ni"]), {}).get("nome", "?")), "nf_nome": str(nodes.get(int(t["nf"]), {}).get("nome", "?")),
				"L": Net.comprimento(nodes, t), "nome": str(t["nome"])}
			first = false
			match key:
				"trechos":
					r.merge({"d": t["d"], "cc_m": t["cc_m"], "cc_j": t["cc_j"], "fixa_d": t["fixa_d"], "fixa_cotas": t["fixa_cotas"],
						"fixa_ext": float(t.get("ext_fix", 0.0)) > 0.0})
				"dimens":
					r.merge({"recob": t["recob"], "pmax": t["pmax"], "situacao": t["situacao"], "crit": t.get("crit", "Global")})
				"quant":
					r.merge({"material": t["material"], "superficie": t["superficie"], "escoramento": t["escoramento"], "aterro": t["aterro"]})
			rows.append(r)
	return rows


func _rows_nos() -> Array:
	var nodes := Net.node_map(proj)
	var tm := Net.trecho_map(proj)
	var rows: Array = []
	var vistos := {}
	var linha := func(nid: int, col: String) -> Dictionary:
		var n: Dictionary = nodes[nid]
		vistos[nid] = true
		return {"_meta": nid, "coletor": col, "nome": str(n["nome"]), "n": n["n"], "e": n["e"], "ct": n["ct"],
			"qp_i": n["qp_i"], "qp_f": n["qp_f"], "tipo": str(n["tipo"]), "ct_ok": bool(n.get("ct_ok", true)),
			"_st": {} if bool(n.get("ct_ok", true)) else {"cores": {"ct": Color(0.85, 0.1, 0.1)}}}
	for sq in Net.sequencias(proj):
		var first := true
		for tid in sq["trechos"]:
			var t: Dictionary = tm[tid]
			if first and nodes.has(int(t["ni"])):
				rows.append(linha.call(int(t["ni"]), str(sq["nome"])))
				first = false
			if nodes.has(int(t["nf"])):
				rows.append(linha.call(int(t["nf"]), ""))
	for n in proj["nodes"]:
		if not vistos.has(int(n["id"])):
			rows.append(linha.call(int(n["id"]), "—"))
	return rows


func _rows_res() -> Array:
	var rows: Array = []
	if not resultados_validos:
		return rows
	var rr: Dictionary = results["rows"]
	var dec_rug := 4 if int(proj["params"]["metodo"]) == 0 else 3
	var verm := Color(0.8, 0.1, 0.1)
	for sq in Net.sequencias(proj):
		var first := true
		for tid in sq["trechos"]:
			if not rr.has(tid):
				continue
			var r: Dictionary = rr[tid]
			var cores := {}
			if float(r["yd_f"]) > float(r["lim"]) + 1e-9:
				cores["yd"] = verm
			if float(r["sigma"]) < float(proj["params"]["tensao_min"]) - 0.005:
				cores["sv"] = verm
			if float(r["v_f"]) > float(proj["params"]["v_max"]):
				cores["v"] = verm
			var st := {"cores": cores}
			if int(r["status"]) >= 2:
				st["color"] = verm
			rows.append({"_meta": tid, "_st": st, "col": str(sq["nome"]) if first else "", "tr": r["nome"], "pv": r["pv_i"], "L": r["L"],
				"tx": r["txi"], "ctr": r["ctr_i"], "qp": r["qp_i"], "qm": r["qm_i"], "qj": r["qj_i"], "d": r["d"], "i": r["i"],
				"ct": r["ct_m"], "cc": r["cc_m"], "rec": r["rec_m"], "pv_": r["pvala_m"], "yd": r["yd_i"], "v": r["v_i"],
				"sv": r["sigma"], "rug": fmt(r["rug_i"], dec_rug), "larg": r["larg"], "esc": r["esc"]})
			rows.append({"_meta": tid, "_st": st, "col": "", "tr": "", "pv": r["pv_f"], "L": "", "tx": r["txf"], "ctr": r["ctr_f"],
				"qp": r["qp_f"], "qm": r["qm_f"], "qj": r["qj_f"], "d": "", "i": "", "ct": r["ct_j"], "cc": r["cc_j"],
				"rec": r["rec_j"], "pv_": r["pvala_j"], "yd": r["yd_f"], "v": r["v_f"], "sv": r["vc"], "rug": fmt(r["rug_f"], dec_rug),
				"larg": "", "esc": ""})
			first = false
	return rows


func _rows_orc() -> Array:
	var rows: Array = []
	if not resultados_validos:
		return rows
	var azul := Color(0.1, 0.25, 0.75)
	if motivo_bloqueio() != "":
		rows.append({"_meta": null, "desc": "ORÇAMENTO PRELIMINAR — não aprovado ou desatualizado", "un": "", "q": "", "c1": "", "c2": "", "total": "",
			"_st": {"color": Color(0.8, 0.1, 0.1)}})
	for l in results["orc"]["linhas"]:
		var r := {"_meta": null, "desc": str(l.get("desc", "")), "un": str(l.get("un", "")), "q": "", "c1": "", "c2": "", "total": ""}
		match str(l["tipo"]):
			"sec":
				r["_st"] = {"color": azul}
				r["c1"] = str(l.get("c1", ""))
				r["c2"] = str(l.get("c2", ""))
			"item":
				r["q"] = fmt(l["q"], int(l.get("dec", 2)))
				if l.has("c1"):
					r["c1"] = l["c1"]
				if l.has("c2"):
					r["c2"] = l["c2"]
				if l.has("total"):
					r["total"] = l["total"]
			"total":
				r["c2"] = "Total:"
				r["total"] = l["total"]
				r["_st"] = {"color": Color(0.05, 0.05, 0.05)}
		rows.append(r)
	return rows


func _rows_obs() -> Array:
	var rows: Array = []
	if results.is_empty():
		return rows
	var ant := ""
	for o in results["obs"]:
		var tr := str(o[0])
		rows.append({"_meta": null, "trecho": tr if tr != ant else "", "obs": str(o[1]), "_st": {"color": Color(0.6, 0.0, 0.0)}})
		ant = tr
	if rows.is_empty():
		rows.append({"_meta": null, "trecho": "", "obs": "Nenhuma restrição encontrada no dimensionamento."})
	return rows


func _on_sheet_cells(key: String, changes: Array) -> void:
	var tm := Net.trecho_map(proj)
	var nodes := Net.node_map(proj)
	for c in changes:
		var meta = c[0]
		var k: String = c[1]
		var v = c[2]
		if meta == null:
			continue
		if key == "nos":
			var n: Dictionary = nodes.get(int(meta), {})
			if n.is_empty():
				continue
			match k:
				"nome":
					if str(v) != "":
						n["nome"] = str(v)
				"ct":
					n["ct"] = float(v)
					n["ct_ok"] = true
				"tipo":
					n["tipo"] = str(v).split("-")[0]
				"qp_i", "qp_f":
					n[k] = maxf(float(v), 0.0)
				_:
					n[k] = v
			continue
		var t: Dictionary = tm.get(int(meta), {})
		if t.is_empty():
			continue
		match k:
			"L":
				t["ext_fix"] = maxf(float(v), 0.0)
			"fixa_ext":
				t["ext_fix"] = Net.comprimento(nodes, t) if bool(v) else 0.0
			"nome":
				if str(v) != "":
					t["nome"] = str(v)
			"d":
				t["d"] = maxf(float(v), 0.0)
				t["fixa_d"] = float(v) > 0.0
			"cc_m", "cc_j":
				t[k] = float(v)
				t["fixa_cotas"] = true
			"recob", "pmax":
				t[k] = maxf(float(v), 0.0)
			_:
				t[k] = v
	on_changed("planilha")


# ------------------------------------------------------------------ comandos

func _on_menu(id: int) -> void:
	if id >= 100 and id < 110:
		var rec: Array = opts.get("recentes", [])
		if id - 100 < rec.size():
			var path := str(rec[id - 100])
			_ask_discard("abrir_recente:" + path)
		return
	var rotulo := str(id)
	if menu_of.has(id):
		var pm: PopupMenu = menu_of[id]
		rotulo = pm.get_item_text(pm.get_item_index(id))
	registro.acao("Comando: " + rotulo)
	match id:
		0:
			_ask_discard("novo")
		1:
			_ask_discard("novo_imagem")
		2:
			_ask_discard("abrir")
		3:
			_ler_dxf("topografia")
		4:
			_ler_dxf("ruas")
		5:
			_ler_dxf("pontos")
		6:
			topo.limpar()
			proj["topo"] = {}
			on_changed("topo")
			set_status("Base topográfica removida.")
		7:
			if current_path == "":
				_salvar_como()
			else:
				_save_to(current_path)
		8:
			_salvar_como()
		9:
			if not _avisar_bloqueio("planta DXF com resultados"):
				dlg.abrir_exibicao_dxf(3, _exportar_planta)
		10:
			_exportar_planilha()
		11:
			if not _avisar_bloqueio("memorial final"):
				pedir_arquivo("salvar", ["*.txt ; Texto", "*.pdf ; PDF"], _safe_name() + "-memorial.txt", _exportar_memorial)
		90:
			pedir_arquivo("abrir", ["*.csv ; Ligações (CSV)"], "", importar_ligacoes)
		91:
			pedir_arquivo("salvar", ["*.csv ; Relatório (CSV)"], _safe_name() + "-ligacoes.csv", exportar_relatorio_ligacoes)
		92:
			pedir_arquivo("abrir", ["*.geojson, *.json ; GeoJSON"], "", importar_bacias)
		93:
			pedir_arquivo("abrir", ["*.geojson, *.json ; GeoJSON"], "", importar_interferencias)
		94:
			pedir_arquivo("salvar", ["*.geojson ; GeoJSON"], _safe_name() + "-interferencias.geojson", exportar_interferencias)
		95:
			pedir_arquivo("salvar", ["*.geojson ; GeoJSON"], _safe_name() + "-rede.geojson", exportar_rede_geojson)
		96:
			_ask_discard("importar_rede")
		97:
			dlg.texto_longo("Balanço de contribuições", texto_balanco(), "balanco.txt")
		12:
			_imprimir()
		13:
			_imprimir()
		14:
			pedir_arquivo("pasta", [], "", _definir_data_dir)
		15:
			pedir_arquivo("abrir", ["*.json ; Banco de itens de custo"], "", _definir_banco)
		17:
			opts["db_path"] = ""
			salvar_config()
			db = Db.carregar(_db_file())
			on_changed("banco")
			set_status("Usando o banco padrão: " + db_path_exibicao())
		16:
			dlg.abrir_propriedades()
		19:
			_ask_discard("fim")
		20:
			dlg.abrir_area()
		21:
			dlg.abrir_tracado()
		22:
			dlg.abrir_exibicao_dxf(0)
		23:
			dlg.abrir_cotas()
		24:
			opts["grava_res"] = not bool(opts.get("grava_res", true))
			menus["Resultados"].set_item_checked(menus["Resultados"].get_item_index(24), bool(opts["grava_res"]))
			salvar_config()
		25:
			dlg.prompt("Prefixo p/ o arquivo", "Prefixo dos arquivos de resultados ([prefixo][número].RES):", str(opts.get("prefixo", "CESG")), _definir_prefixo)
		26:
			dlg.prompt("Localizar", "Forneça o nome do Elemento:", busca, _localizar.bind(false))
		27:
			_localizar(busca, true)
		28:
			classic = not classic
			menus["Opções"].set_item_checked(menus["Opções"].get_item_index(28), classic)
			salvar_config()
			_apply_theme()
			plan.redesenhar()
		80:
			desfazer()
		81:
			refazer()
		30:
			plan.zoom(1.25)
		31:
			plan.zoom(0.8)
		32:
			plan.sem_zoom()
		33:
			plan.ultimo_zoom()
		34:
			plan.mode = "janela"
			plan.mouse_default_cursor_shape = Control.CURSOR_CROSS
			set_status("Janela: clique e arraste para definir a área a ampliar.")
		35:
			plan.mode = "pan"
			plan.mouse_default_cursor_shape = Control.CURSOR_DRAG
			set_status("Pan: arraste com o botão 1 para deslocar a vista; botão 2 ou Esc encerra.")
		36:
			plan.ajuste_maximo()
		37:
			plan.redesenhar()
		40:
			_mostrar("tracado")
		41:
			_mostrar("planilhas")
		42:
			_mostrar(view)
			dlg.abrir_dimensionamento()
		43:
			_mostrar("planilhas")
			sheets.current_tab = 6
		44:
			_set_modo("cc")
		45:
			_set_modo("prx")
		46:
			_set_modo("int")
		47:
			dlg.abrir_recalcular()
		48:
			_ask_discard("exemplo")
		50:
			apagar_marcados()
		51:
			plan.marked.clear()
			plan.redesenhar()
			_atualizar_menus()
		52:
			if plan.marked.size() == 1:
				dlg.abrir_desloca(int(plan.marked.keys()[0]))
		53:
			_dividir()
		54:
			perfil()
		60:
			dlg.abrir_banco()
		70:
			dlg.abrir_ajuda("conteudo")
		71:
			dlg.abrir_ajuda("como")
		73:
			dlg.abrir_registro()
		72:
			dlg.mensagem("Créditos", "%s %s\n\nProjeto de redes de esgoto sanitário: traçado gráfico com topografia DXF,\nplanilhas, dimensionamento (NBR 9649, Manning ou Fórmula Universal),\nquantitativos, orçamento, perfis e exportação DXF.\n\nVersão modernizada inspirada no CEsg (FCTH)." % [APP_NAME, VERSAO])


## Exporta o perfil em PNG (requer renderização; no modo headless devolve ok=false).
func exportar_perfil_png(rows: Array, titulo: String, path: String, grid_modo := 0, escala := {}) -> Dictionary:
	var b := _bloqueio("perfil")
	if not b.is_empty():
		return b
	if DisplayServer.get_name() == "headless":
		return {"ok": false, "motivo": "renderização indisponível no modo headless"}
	var sv := SubViewport.new()
	sv.size = Vector2i(1600, 900)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cp = load("res://profile_view.gd").new()
	cp.size = Vector2(1600, 900)
	cp.grid_modo = grid_modo
	if not escala.is_empty():
		cp.escala = escala.duplicate()
	cp.set_data(rows, titulo)
	sv.add_child(cp)
	add_child(sv)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	if img == null or img.is_empty():
		return {"ok": false, "motivo": "não foi possível renderizar o perfil"}
	var ok := gravar_bytes(path, img.save_png_to_buffer())
	set_status("Imagem do perfil salva em %s" % path if ok else "Falha ao salvar a imagem do perfil.")
	return {"ok": ok, "motivo": "" if ok else "falha ao gravar " + path, "tamanho": img.get_size()}


func _exportar_planta() -> void:
	pedir_arquivo("salvar", ["*.dxf ; Desenho DXF"], _safe_name() + "-planta.dxf", exportar_planta)


func _exportar_memorial(path: String) -> void:
	exportar_memorial(path)


# ------------------------------------------------------------------ cadastro e SIG (Fase 3)

func importar_ligacoes(path: String) -> Dictionary:
	var a: Dictionary = proj["area"]
	var r := Cadastro.importar_ligacoes(path, Rect2(float(a["e0"]), float(a["n0"]), float(a["le"]), float(a["ln"])))
	if not bool(r["ok"]):
		dlg.mensagem("Ligações", str(r["erro"]))
		registro.aviso("Importação de ligações falhou (%s): %s" % [path, r["erro"]])
		return r
	Cadastro.associar(proj, r["registros"])
	proj["ligacoes"] = r["registros"]
	var rs: Dictionary = r["resumo"]
	var pc: Dictionary = rs["por_categoria"]
	var msg := "%d ligações lidas (%d identificadores): %d válidas, %d duplicadas, %d fora da área, %d sem consumo, %d sem coordenada, %d inválidas." % [
		rs["lidos"], rs["ids_unicos"], pc["válida"], pc["duplicada"], pc["fora da área"], pc["sem consumo"], pc["sem coordenada"], pc["inválida"]]
	set_status(msg)
	if int(rs["lidos"]) > int(pc["válida"]):
		registro.aviso("Ligações (%s): %s" % [path.get_file(), msg])
	on_changed("cadastro")
	return r


func exportar_relatorio_ligacoes(path: String) -> Dictionary:
	var ok := gravar_texto(path, Cadastro.relatorio_csv(proj.get("ligacoes", [])), true)
	return {"ok": ok}


func importar_bacias(path: String) -> Dictionary:
	var g := Geo.ler(path)
	if not bool(g["ok"]):
		dlg.mensagem("Bacias", str(g["erro"]))
		registro.aviso("Importação de bacias falhou (%s): %s" % [path, g["erro"]])
		return g
	var bacias: Array = []
	for f in g["features"]:
		var pr: Dictionary = f.get("properties", {})
		var geom: Dictionary = f.get("geometry", {})
		if str(geom.get("type", "")) != "Polygon":
			continue
		var anel: Array = geom["coordinates"][0]
		bacias.append({"id": str(pr.get("id", "B%d" % (bacias.size() + 1))), "nome": str(pr.get("nome", "")),
			"pai": str(pr.get("pai", "")), "trecho_saida": str(pr.get("trecho_saida", "")), "poligono": anel})
	proj["bacias"] = bacias
	var erros := Cadastro.validar_bacias(proj)
	for e in erros:
		registro.aviso("Bacias: " + e)
	if not erros.is_empty():
		dlg.mensagem("Bacias — avisos", "• " + "\n• ".join(PackedStringArray(erros)))
	set_status("%d bacia(s) importada(s)." % bacias.size())
	on_changed("cadastro")
	return {"ok": true, "bacias": bacias, "erros": erros}


func importar_interferencias(path: String) -> Dictionary:
	var r := Geo.importar_interferencias(path)
	if not bool(r["ok"]):
		dlg.mensagem("Interferências", str(r["erro"]))
		registro.aviso("Importação de interferências falhou (%s): %s" % [path, r["erro"]])
		return r
	proj["interferencias"] = {"crs": r["crs"], "camadas": r["camadas"], "feicoes": r["feicoes"], "arquivo": path.get_file()}
	for a in r["avisos"]:
		registro.aviso("Interferências: " + str(a))
	set_status("%d interferência(s) em %d camada(s): %s." % [r["feicoes"].size(), r["camadas"].size(), ", ".join(PackedStringArray(r["camadas"]))])
	on_changed("cadastro")
	return r


func exportar_interferencias(path: String) -> Dictionary:
	return {"ok": gravar_texto(path, Geo.exportar_interferencias(proj.get("interferencias", {})))}


func exportar_rede_geojson(path: String) -> Dictionary:
	var ok := gravar_texto(path, Geo.exportar_rede(proj))
	if ok:
		set_status("Rede exportada em GeoJSON: " + path)
	return {"ok": ok}


func importar_rede_geojson(path: String) -> Dictionary:
	var r := Geo.importar_rede(path, Calc.default_params(), db)
	if not bool(r["ok"]):
		dlg.mensagem("Rede GeoJSON", str(r["erro"]))
		registro.aviso("Importação de rede GeoJSON falhou (%s): %s" % [path, r["erro"]])
		return r
	_set_projeto(r["proj"], "")
	plan.ajuste_maximo()
	set_status("Rede importada de %s: %d nós e %d trechos." % [path.get_file(), proj["nodes"].size(), proj["trechos"].size()])
	return r


func texto_balanco() -> String:
	var b := Cadastro.balanco(proj)
	var s := "BALANÇO DE CONTRIBUIÇÕES (ligações → bacias → trechos)\n\n"
	s += "População válida: %s hab\nConsumo válido: %s l/dia\n" % [fmt(b["populacao_valida"], 0), fmt(b["consumo_valido_l_dia"], 1)]
	s += "Vazão das ligações válidas: %s l/s\nVazão lançada nos trechos: %s l/s\n\n" % [fmt(b["q_validas"], 6), fmt(b["q_lancada"], 6)]
	for bid in b["por_bacia"].keys():
		var x: Dictionary = b["por_bacia"][bid]
		s += "Bacia %s: %d ligações, %s hab, %s l/dia, %s l/s\n" % [bid, x["ligacoes"], fmt(x["populacao"], 0), fmt(x["consumo_l_dia"], 1), fmt(x["q"], 6)]
	if not b["nao_lancadas"].is_empty():
		s += "\nLigações válidas sem destino: %s\n" % ", ".join(PackedStringArray(b["nao_lancadas"]))
	for e in b["erros"]:
		s += "ERRO: %s\n" % e
	return s


func _definir_data_dir(path: String) -> void:
	opts["data_dir"] = path
	salvar_config()
	set_status("Diretório de dados: " + path)


func _definir_banco(path: String) -> void:
	opts["db_path"] = path
	salvar_config()
	db = Db.carregar(path)
	on_changed("banco")
	set_status("Banco de itens de custo: " + path)


func _definir_prefixo(t: String) -> void:
	if t != "":
		opts["prefixo"] = t.substr(0, 200)
		salvar_config()


func _novo_com_imagem(path: String) -> void:
	_novo()
	proj["imagem"] = path
	plan.set_imagem(path)
	plan.sem_zoom()
	set_status("Imagem de fundo: %s. Ajuste a área de trabalho às dimensões reais da imagem." % path.get_file())
	dlg.abrir_area()


func apagar_marcados() -> void:
	if plan.marked.is_empty():
		set_status("Marque os trechos (Ctrl + botão 1 sobre a seta do trecho) antes de apagar.")
		return
	var n := Net.apagar_trechos(proj, plan.marked)
	plan.marked.clear()
	on_changed("apagar")
	set_status("%d trecho(s) apagado(s). Nós sem trechos também foram removidos." % n)


func _dividir() -> void:
	if plan.marked.is_empty():
		return
	var k := 0
	for tid in plan.marked.keys():
		var novo := Net.dividir(proj, db, int(tid))
		if novo.is_empty():
			continue
		k += 1
		if str(opts.get("cota_modo", "int")) != "none":
			var cr := cota_auto(Net.pos(novo))
			if bool(cr["ok"]):
				novo["ct"] = snappedf(float(cr["z"]), 0.001)
				novo["ct_ok"] = true
	plan.marked.clear()
	on_changed("dividir")
	set_status("%d trecho(s) dividido(s) ao meio." % k)


func deslocar_trecho(tid: int, dist: float, esquerda: bool) -> void:
	var movidos := Net.deslocar_trecho(proj, tid, dist, esquerda)
	if movidos.is_empty():
		return
	for n in movidos:
		if str(opts.get("cota_modo", "int")) != "none":
			var cr := cota_auto(Net.pos(n))
			if bool(cr["ok"]):
				n["ct"] = snappedf(float(cr["z"]), 0.001)
	on_changed("deslocar")
	set_status("Trecho %s deslocado %s m para a %s." % [str(Net.trecho_map(proj)[tid]["nome"]), fmt(dist, 2), "esquerda" if esquerda else "direita"])


func perfil() -> void:
	if not resultados_validos:
		dlg.mensagem("Perfil", "O perfil está disponível somente após o dimensionamento (Ctrl+D).")
		return
	if plan.marked.is_empty():
		dlg.mensagem("Perfil", "Marque os trechos: Ctrl + botão 1 sobre a seta de um trecho,\nou Shift + botão 1 para marcar o coletor inteiro.")
		return
	var ordem: Array = Net.ordem(proj)["order"]
	var rows: Array = []
	var nomes: Array = []
	for tid in ordem:
		if plan.marked.has(tid) and results["rows"].has(tid):
			rows.append(results["rows"][tid])
			if not str(results["rows"][tid]["coletor"]) in nomes:
				nomes.append(str(results["rows"][tid]["coletor"]))
	if rows.is_empty():
		return
	var titulo := "Perfil — coletor %s  (%s a %s)%s" % [", ".join(PackedStringArray(nomes)), rows[0]["nome"], rows[-1]["nome"],
		"  [DESATUALIZADO / NÃO APROVADO]" if motivo_bloqueio() != "" else ""]
	dlg.abrir_perfil(rows, titulo)


func _localizar(texto: String, proxima: bool) -> void:
	busca = texto
	if texto == "":
		return
	if view == "planilhas":
		var gt: GridTable = tables[SHEETS[sheets.current_tab][0]]
		if not gt.localizar(texto, proxima):
			set_status("\"%s\" não encontrado nesta planilha." % texto)
		return
	var n := Net.achar_no(proj, texto)
	if not n.is_empty():
		plan.centralizar(Net.pos(n))
		set_status("Nó %s localizado." % str(n["nome"]))
		return
	var t := Net.achar_trecho(proj, texto)
	if not t.is_empty():
		var nodes := Net.node_map(proj)
		plan.centralizar((Net.pos(nodes[int(t["ni"])]) + Net.pos(nodes[int(t["nf"])])) / 2.0)
		set_status("Trecho %s localizado." % str(t["nome"]))
		return
	set_status("Elemento \"%s\" não encontrado." % texto)


func abrir_no(nid: int) -> void:
	dlg.abrir_no(nid)


func abrir_trecho(tid: int) -> void:
	dlg.abrir_trecho(tid)


# ------------------------------------------------------------------ arquivos

func pedir_arquivo(modo: String, filtros: Array, nome: String, cb: Callable) -> void:
	file_cb = cb
	file_dialog.clear_filters()
	for f in filtros:
		file_dialog.add_filter(str(f))
	file_ext = ""
	if filtros.size() > 0:
		file_ext = str(filtros[0]).split(";")[0].strip_edges().replace("*", "")
	match modo:
		"abrir":
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.title = "Abrir"
		"pasta":
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
			file_dialog.title = "Diretório de dados"
		_:
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.title = "Salvar"
	file_dialog.current_dir = _data_dir()
	file_dialog.current_file = nome
	file_dialog.popup_centered(Vector2i(900, 560))


func _on_file_selected(path: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE and path.get_extension() == "" and file_ext != "":
		path += file_ext
	if file_cb.is_valid():
		file_cb.call(path)


## Grava de forma atômica: escreve num temporário e só então substitui o arquivo (T5-06).
## Se algo falhar, o arquivo anterior fica intacto e a falha é registrada.
func gravar_bytes(path: String, dados: PackedByteArray, avisar := true) -> bool:
	var tmp := path + ".tmp~"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	var err := FileAccess.get_open_error() if f == null else OK
	if f != null:
		f.store_buffer(dados)
		err = f.get_error()
		f.close()
		if err == OK:
			err = DirAccess.rename_absolute(tmp, path)
		if err != OK and FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)
	if err != OK:
		if avisar:
			set_status("Não foi possível gravar em %s (%s). Nada foi alterado." % [path, error_string(err)])
		registro.aviso("Falha ao gravar %s (código %d: %s); o arquivo anterior foi preservado." % [path, err, error_string(err)])
		return false
	return true


func gravar_texto(path: String, text: String, bom := false, avisar := true) -> bool:
	var b := PackedByteArray()
	if bom:
		b.append_array(PackedByteArray([0xEF, 0xBB, 0xBF]))
	b.append_array(text.to_utf8_buffer())
	return gravar_bytes(path, b, avisar)


## Troca valores não representáveis em JSON (NaN, infinito) por null.
func _sanear(v):
	if v is float:
		return null if (is_nan(v) or is_inf(v)) else v
	if v is Dictionary:
		var d := {}
		for k in v.keys():
			d[str(k)] = _sanear(v[k])
		return d
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_sanear(x))
		return a
	if v is Vector2:
		return [v.x, v.y]
	return v


func _safe_name() -> String:
	var n := current_path.get_file().get_basename() if current_path != "" else str(proj["info"].get("projeto", "projeto"))
	n = n.strip_edges()
	return (n if n != "" else "projeto").validate_filename()


func _ask_discard(action: String) -> void:
	if dirty:
		confirm_action = action
		confirm_dialog.popup_centered()
	else:
		_do_action(action)


func _do_action(action: String) -> void:
	if action.begins_with("abrir_recente:"):
		_load_from(action.substr(14))
		return
	match action:
		"novo":
			_novo()
			dlg.abrir_area()
		"novo_imagem":
			pedir_arquivo("abrir", ["*.png, *.jpg, *.jpeg, *.bmp, *.webp, *.svg ; Imagens"], "", _novo_com_imagem)
		"abrir":
			pedir_arquivo("abrir", ["*.esg ; Projeto DimEsgoto", "*.json ; JSON"], "", _load_from)
		"importar_rede":
			pedir_arquivo("abrir", ["*.geojson, *.json ; GeoJSON"], "", importar_rede_geojson)
		"exemplo":
			_set_projeto(Net.exemplo(Calc.default_params(), db), "")
			executar_calculo(false)
			_reiniciar_historico()
			dirty = false
			_update_title()
			plan.ajuste_maximo()
			set_status("Rede de exemplo carregada.")
		"fim":
			salvar_config()
			get_tree().quit()


func _novo() -> void:
	_set_projeto(Net.novo_projeto(Calc.default_params()), "")
	plan.sem_zoom()
	_mostrar("tracado")
	set_status("Novo projeto. Leia a topografia (Arquivos › Lê DXF…) ou comece o traçado com o botão 2.")


func _set_projeto(p: Dictionary, path: String) -> void:
	proj = p
	topo.from_dict(proj.get("topo", {}))
	results = {}
	resultados_validos = false
	resultados_atuais = false
	current_path = path
	registro.projeto(path)
	dirty = false
	plan.marked.clear()
	plan.cancelar()
	plan.rastro = {}
	plan.destaque = Vector2(NAN, NAN)
	plan.set_imagem(str(proj.get("imagem", "")))
	if not topo.vazio():
		opts["cota_modo"] = "int" if topo.tem_curvas() else "prx"
	_update_title()
	_atualizar_menus()
	_atualizar_stale()
	plan.redesenhar()
	if view == "planilhas":
		_refresh_sheet(sheets.current_tab)
	_reiniciar_historico()


func _salvar_como() -> void:
	pedir_arquivo("salvar", ["*.esg ; Projeto DimEsgoto"], _safe_name() + ".esg", func(path): _save_to(path))


func _save_to(path: String) -> bool:
	proj["topo"] = topo.to_dict()
	if not _estado.is_empty():
		_estado["topo"] = proj["topo"]
	proj["formato"] = "dimesgoto"
	proj["versao"] = 3
	var dados := proj.duplicate()
	dados["banco"] = Db.identificacao(db)
	dados["resultados"] = {"dados": results, "validos": resultados_validos, "atuais": resultados_atuais}
	if gravar_texto(path, JSON.stringify(_sanear(dados), "  ")):
		current_path = path
		dirty = false
		_lembrar_recente(path)
		_update_title()
		set_status("Projeto salvo: " + path)
		return true
	set_status("Projeto NÃO salvo: falha ao gravar %s. O arquivo anterior foi preservado." % path)
	return false


func _normalizar(data: Dictionary) -> Dictionary:
	var p := Net.novo_projeto(Calc.default_params())
	for k in ["info", "area", "topo", "interferencias"]:
		if data.get(k) is Dictionary:
			p[k] = data[k]
	if data.get("referencia") is Dictionary:
		for k in p["referencia"].keys():
			if data["referencia"].has(k):
				p["referencia"][k] = str(data["referencia"][k])
	if data.get("bacias") is Array:
		p["bacias"] = data["bacias"]
	if data.get("ligacoes") is Array:
		var regs: Array = []
		for r in data["ligacoes"]:
			if r is Dictionary:
				var x: Dictionary = r.duplicate()
				for k in ["e", "n", "dist", "populacao", "consumo"]:
					x[k] = float(x[k]) if (x.get(k) is float or x.get(k) is int) else NAN
				x["trecho"] = int(x.get("trecho", -1)) if x.get("trecho") != null else -1
				x["problemas"] = x.get("problemas", []) if x.get("problemas") is Array else []
				x["valido"] = bool(x.get("valido", false))
				regs.append(x)
		p["ligacoes"] = regs
	p["imagem"] = str(data.get("imagem", ""))
	var lp = data.get("params", {})
	if lp is Dictionary:
		for k in lp.keys():
			if p["params"].has(k):
				var dv = p["params"][k]
				p["params"][k] = bool(lp[k]) if dv is bool else (int(lp[k]) if dv is int else float(lp[k]))
	for k in ["n0", "e0", "ln", "le", "grid"]:
		p["area"][k] = float(p["area"].get(k, 0.0))
	var nds: Array = []
	for n in data.get("nodes", []):
		if not n is Dictionary:
			continue
		nds.append({"id": int(n.get("id", 0)), "nome": str(n.get("nome", "")), "e": float(n.get("e", 0.0)), "n": float(n.get("n", 0.0)),
			"ct": float(n.get("ct", 0.0)), "ct_ok": bool(n.get("ct_ok", true)), "tipo": str(n.get("tipo", "PV")),
			"qp_i": float(n.get("qp_i", 0.0)), "qp_f": float(n.get("qp_f", 0.0))})
	p["nodes"] = nds
	var trs: Array = []
	for t in data.get("trechos", []):
		if not t is Dictionary:
			continue
		var base := Net.trecho_padrao(db)
		for k in base.keys():
			if t.has(k):
				var dv = base[k]
				base[k] = bool(t[k]) if dv is bool else (str(t[k]) if dv is String else float(t[k]))
		base["id"] = int(t.get("id", 0))
		base["nome"] = str(t.get("nome", ""))
		base["ni"] = int(t.get("ni", 0))
		base["nf"] = int(t.get("nf", 0))
		base["coletor"] = str(t.get("coletor", "C1"))
		trs.append(base)
	p["trechos"] = trs
	return p


## Erros de formato e de tipos de um arquivo de projeto (T5-04). Referências entre nós e
## trechos não são verificadas aqui: o motor de cálculo as aponta como erro estrutural.
func _validar_arquivo(data) -> Array:
	if not data is Dictionary:
		return ["o conteúdo não é um projeto (arquivo vazio ou JSON inválido)"]
	if data.has("parametros") and data.has("trechos") and not data.has("nodes"):
		return [] if data["trechos"] is Array else ["lista de trechos inválida no projeto da versão anterior"]
	var e: Array = []
	if not data.has("nodes") and not data.has("trechos"):
		return ["não é um projeto do %s (faltam as listas de nós e de trechos)" % APP_NAME]
	if not data.get("nodes") is Array:
		e.append("projeto sem a lista de nós (\"nodes\")")
	if not data.get("trechos") is Array:
		e.append("projeto sem a lista de trechos (\"trechos\")")
	if not e.is_empty():
		return e
	var num := func(v): return v is float or v is int
	for k in data["nodes"].size():
		var n = data["nodes"][k]
		if not n is Dictionary:
			e.append("nó nº %d: registro inválido" % (k + 1))
			continue
		for c in ["id", "e", "n", "ct"]:
			if not num.call(n.get(c)):
				e.append("nó nº %d (%s): campo \"%s\" ausente ou não numérico (%s)" % [k + 1, str(n.get("nome", "?")), c, str(n.get(c))])
	for k in data["trechos"].size():
		var t = data["trechos"][k]
		if not t is Dictionary:
			e.append("trecho nº %d: registro inválido" % (k + 1))
			continue
		for c in ["id", "ni", "nf"]:
			if not num.call(t.get(c)):
				e.append("trecho nº %d (%s): campo \"%s\" ausente ou não numérico (%s)" % [k + 1, str(t.get("nome", "?")), c, str(t.get(c))])
		for c in ["d", "cc_m", "cc_j", "ext_fix", "recob", "pmax"]:
			if t.has(c) and not num.call(t[c]):
				e.append("trecho nº %d (%s): campo \"%s\" não numérico (%s)" % [k + 1, str(t.get("nome", "?")), c, str(t[c])])
	if data.has("params") and not data["params"] is Dictionary:
		e.append("parâmetros (\"params\") inválidos")
	elif data.get("params") is Dictionary:
		for k in data["params"].keys():
			var v = data["params"][k]
			if Calc.default_params().has(k) and not (num.call(v) or v is bool):
				e.append("parâmetro \"%s\" com tipo inválido (%s)" % [k, str(v)])
	return e


func _load_from(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		set_status("Não foi possível abrir %s." % path)
		registro.aviso("Falha ao abrir %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	var texto := f.get_as_text()
	f.close()
	var j := JSON.new()
	var err_json := j.parse(texto)
	var data = j.data if err_json == OK else null
	var erros: Array
	if texto.strip_edges() == "":
		erros = ["o arquivo está vazio"]
	elif err_json != OK:
		erros = ["JSON inválido na linha %d: %s (arquivo corrompido ou incompleto)" % [j.get_error_line(), j.get_error_message()]]
	else:
		erros = _validar_arquivo(data)
	if not erros.is_empty():
		var lista := erros.slice(0, 8)
		dlg.mensagem("Arquivo corrompido ou inválido", "O arquivo %s não pôde ser aberto:\n• %s%s\n\nO projeto atual foi mantido." % [
			path.get_file(), "\n• ".join(PackedStringArray(lista)), "\n• … (+%d)" % (erros.size() - lista.size()) if erros.size() > lista.size() else ""])
		registro.aviso("Projeto rejeitado (%s): %s" % [path, "; ".join(PackedStringArray(erros))])
		set_status("Projeto não aberto: arquivo inválido. O projeto atual foi mantido.")
		return false
	var p: Dictionary
	var msg := "Projeto aberto: " + path
	if data.has("nodes"):
		p = _normalizar(data)
	else:
		p = Net.migrar_v2(data, Calc.default_params(), db)
		msg = "Projeto da versão anterior convertido. As extensões foram mantidas (Fixa Ext.); a planta é esquemática — ajuste os nós se quiser."
	_set_projeto(p, path)
	set_status(msg)
	if data.get("banco") is Dictionary:
		_restaurar_banco(data["banco"])
	if data.get("resultados") is Dictionary:
		_restaurar_resultados(data["resultados"])
	_lembrar_recente(path)
	plan.ajuste_maximo()
	return true


func _restaurar_banco(b: Dictionary) -> void:
	var arq := str(b.get("arquivo", ""))
	if arq != "" and arq != _db_file() and FileAccess.file_exists(arq):
		opts["db_path"] = "" if arq == DB_PADRAO else arq
		db = Db.carregar(arq)
		salvar_config()
	if Db.hash_conteudo(db) != str(b.get("hash", "")):
		var msg := "O banco de itens de custo atual (%s) difere do usado quando o projeto foi salvo (%s, versão %s)." % [
			db_path_exibicao(), arq if arq != "" else "padrão", str(b.get("versao", "?"))]
		registro.aviso(msg)
		set_status(msg)


func _restaurar_resultados(r: Dictionary) -> void:
	var dados = r.get("dados", {})
	if not dados is Dictionary or dados.is_empty():
		return
	# o JSON devolve todo número como float: restaura chaves e campos inteiros
	for chave in ["rows", "nodes"]:
		var conv := {}
		var orig = dados.get(chave, {})
		if orig is Dictionary:
			for k in orig.keys():
				conv[int(k)] = orig[k]
		dados[chave] = conv
	for row in dados["rows"].values():
		for k in ["id", "ni", "nf", "status"]:
			if row.get(k) is float:
				row[k] = int(row[k])
	for l in dados.get("orc", {}).get("linhas", []):
		if l.get("dec") is float:
			l["dec"] = int(l["dec"])
	results = dados
	resultados_validos = bool(r.get("validos", false))
	resultados_atuais = bool(r.get("atuais", false))
	# segurança: se o projeto/banco não correspondem ao identificador salvo, fica desatualizado
	if resultados_atuais and str(results.get("identificador", "")) != identificador():
		resultados_atuais = false
	_atualizar_menus()
	_atualizar_stale()
	plan.redesenhar()
	if view == "planilhas":
		_refresh_sheet(sheets.current_tab)
	_reiniciar_historico()


func _lembrar_recente(path: String) -> void:
	var rec: Array = opts.get("recentes", [])
	rec.erase(path)
	rec.push_front(path)
	while rec.size() > 4:
		rec.pop_back()
	opts["recentes"] = rec
	salvar_config()
	_atualizar_recentes()


func _atualizar_recentes() -> void:
	var pm: PopupMenu = menus["Arquivos recentes"]
	pm.clear()
	var rec: Array = opts.get("recentes", [])
	for k in rec.size():
		pm.add_item("%d. %s" % [k + 1, str(rec[k])], 100 + k)
	if rec.is_empty():
		pm.add_item("(nenhum)", 109)
		pm.set_item_disabled(0, true)


func _ler_dxf(tipo: String) -> void:
	pedir_arquivo("abrir", ["*.dxf ; Desenho DXF (ASCII)"], "", func(path):
		var info := Dxf.ler(path)
		if not bool(info["ok"]):
			dlg.mensagem("Leitura de DXF", str(info["erro"]))
			registro.aviso("Leitura de DXF falhou (%s): %s" % [path, str(info["erro"])])
			return
		if info["layers"].is_empty():
			dlg.mensagem("Leitura de DXF", "Nenhuma entidade reconhecida (Line, Polyline, Lwpolyline, Arc, Circle, Text ou Point).")
			registro.aviso("Leitura de DXF (%s): nenhuma entidade reconhecida." % path)
			return
		var titulos := {"topografia": "DXF Topografia - Seleção de Layers", "ruas": "DXF Ruas - Seleção de Layers", "pontos": "DXF Pontos Cotados - Seleção de Layers"}
		var prefs := {"topografia": ["CURVA", "NIVEL", "TOPO", "CN"], "ruas": ["QUADRA", "RUA", "LOTE", "VIARIO", "VIA", "MEIO"],
			"pontos": ["PTCT", "PONTO", "COTA", "PT"]}
		dlg.abrir_layers(titulos[tipo], path, info, prefs[tipo], func(sel): importar_dxf(path, tipo, sel)))


## Importa curvas, ruas ou pontos cotados dos layers escolhidos, com diagnóstico (T2-06).
func importar_dxf(path: String, tipo: String, sel: Dictionary) -> Dictionary:
	var papel: String = {"topografia": "curvas", "ruas": "ruas", "pontos": "pontos"}.get(tipo, "curvas")
	var papeis := {}
	for ly in sel.keys():
		papeis[ly] = papel
	var r := Dxf.importar(path, sel, papeis)
	if not bool(r["ok"]):
		dlg.mensagem("Leitura de DXF", str(r["erro"]))
		registro.aviso("Leitura de DXF falhou (%s): %s" % [path, str(r["erro"])])
		set_status("DXF não importado: %s" % str(r["erro"]))
		return r
	var sem_rede: bool = proj["nodes"].is_empty()
	match tipo:
		"topografia":
			topo.set_curvas(r["curvas"])
			topo.textos = Dxf.textos(r["ents"], sel)
			opts["cota_modo"] = "int"
			set_status("%d curvas de nível lidas de %s." % [r["curvas"].size(), path.get_file()])
		"ruas":
			topo.ruas = r["ruas"]
			set_status("%d linhas de ruas lidas de %s." % [topo.ruas.size(), path.get_file()])
		"pontos":
			topo.set_pontos(r["pontos"])
			if not topo.tem_curvas():
				opts["cota_modo"] = "prx"
			set_status("%d pontos cotados lidos de %s." % [topo.pontos.size(), path.get_file()])
	if tipo != "ruas":
		var ref: Dictionary = proj["referencia"]
		ref["origem_topografia"] = path.get_file()
		ref["data_topografia"] = Time.get_date_string_from_system()
	proj["topo"] = topo.to_dict()
	var avisos: Array = r["avisos"]
	for a in avisos:
		registro.aviso("DXF %s: %s" % [path.get_file(), a])
	if not avisos.is_empty():
		dlg.mensagem("Leitura de DXF — avisos", "• " + "\n• ".join(PackedStringArray(avisos)))
		set_status(status_label.text + "  Avisos: " + " ".join(PackedStringArray(avisos)))
	if sem_rede and not topo.vazio():
		var re: Rect2 = topo.extents().grow(20.0)
		var a: Dictionary = proj["area"]
		a["e0"] = floorf(re.position.x)
		a["n0"] = floorf(re.position.y)
		a["le"] = ceilf(re.size.x)
		a["ln"] = ceilf(re.size.y)
		plan.ajuste_maximo()
	on_changed("topo")
	return r


## Compatibilidade com chamadas antigas.
func _aplicar_dxf(tipo: String, _info: Dictionary, sel: Dictionary, path: String) -> void:
	importar_dxf(path, tipo, sel)


func _exportar_planilha() -> void:
	if view != "planilhas":
		set_status("Abra as planilhas (Ctrl+E) e escolha a aba a exportar.")
		return
	var sh: Array = SHEETS[sheets.current_tab]
	if sh[0] in ["res", "orc"] and _avisar_bloqueio("planilha"):
		return
	pedir_arquivo("salvar", ["*.csv ; Planilha CSV (Excel / LibreOffice)", "*.xlsx ; Pasta de trabalho Excel", "*.html ; Arquivo HTML", "*.pdf ; PDF"],
		"%s-%s.csv" % [_safe_name(), str(sh[0])], func(path): exportar_planilha_arquivo(str(sh[0]), path))


func _imprimir() -> void:
	if view == "planilhas":
		var sh: Array = SHEETS[sheets.current_tab]
		var path := ProjectSettings.globalize_path("user://impressao-planilha.html")
		if gravar_texto(path, Report.html(str(sh[1]), tables[sh[0]].dados(), str(proj["info"].get("projeto", "")))):
			OS.shell_open(path)
			set_status("Planilha aberta no navegador para impressão (Ctrl+P lá).")
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var r: Rect2 = plan.get_global_rect()
	var sub := img.get_region(Rect2i(r))
	var path := ProjectSettings.globalize_path("user://impressao-planta.png")
	if sub.save_png(path) == OK:
		OS.shell_open(path)
		set_status("Planta aberta no visualizador de imagens para impressão.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		salvar_config()
		get_tree().quit()


# ------------------------------------------------------------------ aparência

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


func _check_tex(marcado: bool, radio: bool, borda: Color, marca: Color) -> ImageTexture:
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ctr := Vector2(7.5, 7.5)
	for y in n:
		for x in n:
			var p := Vector2(x, y)
			var col := Color(0, 0, 0, 0)
			if radio:
				var d := p.distance_to(ctr)
				if d <= 6.6:
					col = Color.WHITE
				if d > 5.6 and d <= 6.8:
					col = borda
				if marcado and d <= 3.3:
					col = marca
			else:
				if x >= 1 and x <= 14 and y >= 1 and y <= 14:
					col = Color.WHITE
					if x == 1 or x == 14 or y == 1 or y == 14:
						col = borda
				if marcado:
					var d1 := p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(3.5, 7.5), Vector2(6.5, 10.5)))
					var d2 := p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(6.5, 10.5), Vector2(11.5, 4.5)))
					if minf(d1, d2) <= 1.1:
						col = marca
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
	var btn: StyleBoxFlat = _bevel(p["button"], false, 8, 4) if c else _sb(p["button"], p["border"], 1, r, 8, 4)
	var btn_h: StyleBoxFlat = _bevel(p["button_hover"], false, 8, 4) if c else _sb(p["button_hover"], p["accent"], 1, r, 8, 4)
	var btn_p: StyleBoxFlat = _bevel(p["button"], true, 8, 4) if c else _sb(p["select"], p["accent"], 1, r, 8, 4)

	t.set_stylebox("panel", "PanelContainer", _sb(p["panel"], p["border"], 0 if c else 1, r, 10, 8))
	t.set_stylebox("panel", "Panel", _sb(p["panel"]))
	for typ in ["Label", "CheckBox", "CheckButton"]:
		t.set_color("font_color", typ, p["text"])
	for typ in ["CheckBox"]:
		t.set_color("font_hover_color", typ, p["text"])
		t.set_color("font_pressed_color", typ, p["text"])
		t.set_color("font_hover_pressed_color", typ, p["text"])
		t.set_color("font_focus_color", typ, p["text"])
		t.set_color("font_disabled_color", typ, p["muted"])
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
	var borda := Color("404040") if c else Color("7a8796")
	var marca: Color = Color("000000") if c else p["accent"]
	var ck := _check_tex(true, false, borda, marca)
	var uk := _check_tex(false, false, borda, marca)
	var rk := _check_tex(true, true, borda, marca)
	var ru := _check_tex(false, true, borda, marca)
	for typ in ["CheckBox", "PopupMenu"]:
		t.set_icon("checked", typ, ck)
		t.set_icon("unchecked", typ, uk)
		t.set_icon("radio_checked", typ, rk)
		t.set_icon("radio_unchecked", typ, ru)
		t.set_icon("checked_disabled", typ, _check_tex(true, false, Color(borda, 0.4), Color(marca, 0.4)))
		t.set_icon("unchecked_disabled", typ, _check_tex(false, false, Color(borda, 0.4), marca))
		t.set_icon("radio_checked_disabled", typ, _check_tex(true, true, Color(borda, 0.4), Color(marca, 0.4)))
		t.set_icon("radio_unchecked_disabled", typ, _check_tex(false, true, Color(borda, 0.4), marca))
	t.set_icon("checked", "Tree", ck)
	t.set_icon("unchecked", "Tree", uk)
	t.set_icon("checked_disabled", "Tree", _check_tex(true, false, Color(borda, 0.45), Color(marca, 0.45)))
	t.set_icon("unchecked_disabled", "Tree", _check_tex(false, false, Color(borda, 0.45), marca))
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
	t.set_color("font_disabled_color", "PopupMenu", Color(p["muted"], 0.6))
	t.set_color("font_accelerator_color", "PopupMenu", p["muted"])
	t.set_color("font_separator_color", "PopupMenu", p["accent"])
	var sep := StyleBoxLine.new()
	sep.color = p["border"]
	sep.thickness = 1
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_stylebox("labeled_separator_left", "PopupMenu", sep)
	t.set_stylebox("labeled_separator_right", "PopupMenu", sep)
	t.set_stylebox("separator", "HSeparator", sep)
	var vsep := StyleBoxLine.new()
	vsep.color = p["border"]
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)
	for typ in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", typ, field_sb)
		t.set_stylebox("focus", typ, field_focus)
		t.set_stylebox("read_only", typ, field_sb if typ == "TextEdit" else _sb(Color(1.0, 0.98, 0.83) if not c else p["bg"], p["border"], 1, r, 6, 4))
		t.set_color("font_color", typ, p["text"])
		t.set_color("font_readonly_color", typ, p["text"])
		t.set_color("font_uneditable_color", typ, p["text"])
		t.set_color("caret_color", typ, p["text"])
		t.set_color("selection_color", typ, Color(p["accent"], 0.35))
		t.set_color("font_selected_color", typ, p["text"])
		t.set_color("font_placeholder_color", typ, p["muted"])
	t.set_color("background_color", "TextEdit", p["field"])
	t.set_color("default_color", "RichTextLabel", p["text"])
	t.set_stylebox("normal", "RichTextLabel", _sb(p["field"], p["border"], 1, r, 10, 8))
	t.set_stylebox("panel", "ItemList", _bevel(p["field"], true, 4, 4) if c else _sb(p["field"], p["border"], 1, r, 4, 4))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", _sb(p["select"]))
	t.set_stylebox("selected_focus", "ItemList", _sb(p["select"]))
	t.set_stylebox("hovered", "ItemList", _sb(Color(p["select"], 0.4)))
	t.set_color("font_color", "ItemList", p["text"])
	t.set_color("font_selected_color", "ItemList", p["select_text"])
	t.set_color("font_hovered_color", "ItemList", p["text"])
	t.set_constant("v_separation", "ItemList", 6)
	t.set_stylebox("panel", "Tree", _bevel(p["field"], true, 2, 2) if c else _sb(p["field"], p["border"], 1, r, 2, 2))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("selected", "Tree", _sb(Color(0.1, 0.1, 0.1, 0.0), Color(0.05, 0.05, 0.05), 2))
	t.set_stylebox("selected_focus", "Tree", _sb(Color(0.1, 0.1, 0.1, 0.0), Color(0.05, 0.05, 0.05), 2))
	t.set_stylebox("cursor", "Tree", _sb(Color(0, 0, 0, 0), Color(0.05, 0.05, 0.05), 2))
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
	t.set_color("font_selected_color", "Tree", p["text"])
	t.set_color("guide_color", "Tree", Color(0.75, 0.75, 0.75))
	t.set_constant("draw_guides", "Tree", 1)
	t.set_constant("v_separation", "Tree", 4)
	t.set_constant("item_margin", "Tree", 0)
	t.set_font_size("title_button_font_size", "Tree", 12)
	t.set_font_size("font_size", "Tree", 13)
	var tab_sel: StyleBoxFlat = _bevel(p["panel"], false, 12, 5) if c else _sb(p["panel"], p["border"], 1, 0, 12, 5)
	if not c:
		tab_sel.border_width_top = 3
		tab_sel.border_color = p["accent"]
	var tab_un: StyleBoxFlat = _bevel(Color("b0b0b0"), false, 12, 5) if c else _sb(p["bg"], Color(0, 0, 0, 0), 0, 0, 12, 5)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", _sb(p["button_hover"], Color(0, 0, 0, 0), 0, 0, 12, 5))
	t.set_stylebox("tab_disabled", "TabContainer", tab_un)
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TabContainer", _bevel(p["panel"], false, 8, 8) if c else _sb(p["panel"], p["border"], 1, r, 8, 8))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", p["accent"] if not c else p["text"])
	t.set_color("font_unselected_color", "TabContainer", p["muted"])
	t.set_color("font_hovered_color", "TabContainer", p["text"])
	t.set_color("font_disabled_color", "TabContainer", Color(p["muted"], 0.45))
	for typ in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", typ, _sb(Color(p["border"], 0.25), Color(0, 0, 0, 0), 0, 4, 4, 4))
		t.set_stylebox("grabber", typ, _sb(Color(p["muted"], 0.55), Color(0, 0, 0, 0), 0, 4, 4, 4))
		t.set_stylebox("grabber_highlight", typ, _sb(Color(p["muted"], 0.8), Color(0, 0, 0, 0), 0, 4, 4, 4))
		t.set_stylebox("grabber_pressed", typ, _sb(p["accent"], Color(0, 0, 0, 0), 0, 4, 4, 4))
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
	var sbar: PanelContainer = bg_panel.find_child("BarraStatus", true, false)
	if sbar:
		var ss: StyleBoxFlat = _bevel(pal["status"], true, 8, 2) if classic else _sb(pal["status"], pal["border"], 0, 0, 8, 3)
		if not classic:
			ss.border_width_top = 1
		sbar.add_theme_stylebox_override("panel", ss)
	if file_dialog:
		file_dialog.theme = ThemeDB.get_default_theme()
	for b in tool_btns.values():
		for ch in b.get_children():
			ch.queue_redraw()
