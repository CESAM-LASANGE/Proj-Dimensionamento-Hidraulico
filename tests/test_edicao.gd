extends SceneTree
## Fase 6 — edição da rede, planilhas e intercâmbio (tests/PHASE-6.md).
##   T6-01 ligação só em PV com saída          T6-06 seleção por caixa
##   T6-02 trecho de jusante de PV com ≥2 chegadas  T6-07 exportação das planilhas
##   T6-03 confirmação ao apagar ponto          T6-08 colunas fixas na planilha de resultados
##   T6-04 no máximo 3 entradas por PV          T6-09 importação DXF da rede e exportação GeoPackage
##   T6-05 sem resíduos ao apagar / cancelar
## (T6-10, regressão das fases 0–5, é calculado pelo runner.)

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")
const Report = preload("res://report.gd")

const PY_GPKG := """
import sqlite3, sys, json, struct
con = sqlite3.connect('file:%s?mode=ro' % sys.argv[1], uri=True)
c = con.cursor()
o = {}
o['integrity'] = c.execute('PRAGMA integrity_check').fetchone()[0]
o['app_id'] = c.execute('PRAGMA application_id').fetchone()[0]
o['user_version'] = c.execute('PRAGMA user_version').fetchone()[0]
o['tables'] = sorted(r[0] for r in c.execute("select name from sqlite_master where type='table'"))
o['contents'] = [list(r) for r in c.execute('select table_name, data_type, srs_id, min_x, max_x from gpkg_contents order by table_name')]
o['geomcols'] = [list(r) for r in c.execute('select table_name, column_name, geometry_type_name, srs_id from gpkg_geometry_columns order by table_name')]
o['srs'] = sorted(r[0] for r in c.execute('select srs_id from gpkg_spatial_ref_sys'))
o['n_pvs'] = c.execute('select count(*) from pvs').fetchone()[0]
o['n_trechos'] = c.execute('select count(*) from trechos').fetchone()[0]
o['cols_trechos'] = [r[1] for r in c.execute('pragma table_info(trechos)')]
ok = True
for (g,) in c.execute('select geom from trechos'):
    env = (g[3] >> 1) & 7
    off = 8 + (32 if env == 1 else 0)
    if g[:2] != b'GP' or g[off] != 1 or struct.unpack('<I', g[off + 1:off + 5])[0] != 2:
        ok = False
o['geom_linhas_ok'] = ok
pts = {}
for g, nome in c.execute('select geom, nome from pvs'):
    pts[nome] = list(struct.unpack('<dd', g[13:29]))
o['pvs'] = pts
o['fk'] = len(c.execute('PRAGMA foreign_key_check').fetchall())
if 'diametro_mm' in o['cols_trechos']:
    o['d_min'] = c.execute('select min(diametro_mm) from trechos').fetchone()[0]
print('GPKG=' + json.dumps(o))
"""

var T
var m
var p


func _initialize() -> void:
	T = Lib.new()
	m = await T.novo_main(self)
	T.usar_banco_teste(m)
	m.opts["grava_res"] = false
	p = m.plan
	print("META|" + JSON.stringify(T.meta(m)))
	_t601()
	_t602()
	_t603()
	_t604()
	_t605()
	_t606()
	await _t607()
	await _t608()
	_t609()
	quit(T.fim())


# ------------------------------------------------------------------ utilidades

func _frames(n := 3) -> void:
	for _k in n:
		await process_frame


func _abrir(fixture: String) -> void:
	_fechar_janelas()
	T.carregar(m, fixture)
	m.opts["grava_res"] = false
	m._mostrar("tracado")
	p.limpar_selecao()
	m.ultimo_alerta = ""


func _fechar_janelas() -> void:
	for ch in m.get_children():
		if ch is AcceptDialog and ch.visible:
			ch.hide()


func _alerta_visivel() -> String:
	for ch in m.get_children():
		if ch is AcceptDialog and not ch is ConfirmationDialog and ch.visible:
			return ch.dialog_text
	return ""


func _no(nome: String) -> Dictionary:
	return Net.achar_no(m.proj, nome)


func _tid(nome: String) -> int:
	return int(Net.achar_trecho(m.proj, nome)["id"])


func _s(w: Vector2) -> Vector2:
	return p.w2s(w)


func _clique(botao: int, s: Vector2, ctrl := false, shift := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = botao
	ev.position = s
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	p._gui_input(ev)
	var ev2: InputEventMouseButton = ev.duplicate()
	ev2.pressed = false
	p._gui_input(ev2)


func _arrastar(a: Vector2, b: Vector2, ctrl := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = a
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	p._gui_input(ev)
	for k in 4:
		var mv := InputEventMouseMotion.new()
		mv.position = a.lerp(b, (k + 1) / 4.0)
		mv.relative = (b - a) / 4.0
		p._gui_input(mv)
	var ev2: InputEventMouseButton = ev.duplicate()
	ev2.position = b
	ev2.pressed = false
	p._gui_input(ev2)


func _tecla(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	p._gui_input(ev)


## Invariantes da rede: todo nó tem trecho; nenhum nó com 2+ chegadas sem saída (salvo os que já
## eram assim, como o lançamento final da rede de exemplo); ≤ 3 entradas; uma saída; sem laço.
func _invariantes(ja_eram := {}) -> String:
	var lig := Net.ligacoes(m.proj)
	for n in m.proj["nodes"]:
		var i := int(n["id"])
		var ni: int = lig["inc"].get(i, []).size()
		var no: int = lig["out"].get(i, []).size()
		if ni + no == 0:
			return "nó %s sem trechos (resíduo)" % n["nome"]
		if ni >= 2 and no == 0 and not ja_eram.has(i):
			return "nó %s com %d chegadas e sem saída" % [n["nome"], ni]
		if ni > Net.MAX_ENTRADAS:
			return "nó %s com %d entradas" % [n["nome"], ni]
		if no > 1:
			return "nó %s com %d saídas" % [n["nome"], no]
	if bool(Net.ordem(m.proj)["ciclo"]):
		return "laço na rede"
	return ""


# ------------------------------------------------------------------ T6-01

func _t601() -> void:
	var id := "T6-01"
	_abrir("rede_ramificada.esg")
	T.dado(id, "entrada", "rede_ramificada.esg (T1 A→C, T2 B→C, T3 C→D; D é a saída da rede)")
	p.ajustar(Rect2(-20, -120, 240, 240), false)
	var t0: int = m.proj["trechos"].size()
	var d := _no("D")
	var c := _no("C")
	var r := Net.pode_ligar(m.proj, int(_no("A")["id"]), int(d["id"]))
	T.check(id, not bool(r["ok"]) and str(r["regra"]) == "sem_saida", "regra: ligar em D (sem saída) é recusado (regra \"%s\")" % r["regra"])
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(150, 80)))
	T.check(id, p.tracing, "botão 2 na área vazia inicia um coletor")
	_clique(MOUSE_BUTTON_LEFT, _s(Net.pos(d)))
	var alerta := _alerta_visivel()
	T.check(id, m.proj["trechos"].size() == t0, "clique em D durante o traçado não cria trecho (%d trechos)" % m.proj["trechos"].size())
	T.check(id, alerta.contains("não tem saída") and m.ultimo_alerta == alerta, "janela de alerta ao usuário: \"%s\"" % alerta.get_slice("\n", 0))
	T.check(id, p.tracing, "o traçado continua ativo para o usuário escolher outro PV")
	_fechar_janelas()
	_clique(MOUSE_BUTTON_LEFT, _s(Net.pos(c)))
	var novo: Dictionary = m.proj["trechos"][-1] if m.proj["trechos"].size() > t0 else {}
	T.check(id, not novo.is_empty() and int(novo["nf"]) == int(c["id"]) and not p.tracing,
		"ligação em C (que tem saída) é aceita e encerra o traçado")
	T.check(id, _invariantes() == "", "rede continua consistente (%s)" % (_invariantes() if _invariantes() != "" else "ok"))


# ------------------------------------------------------------------ T6-02

func _t602() -> void:
	var id := "T6-02"
	_abrir("rede_ramificada.esg")
	T.dado(id, "entrada", "rede_ramificada.esg: C recebe T1 e T2; T3 é o trecho de jusante de C")
	var r: Dictionary = m.executar_apagar({_tid("T3"): true}, {})
	T.check(id, not bool(r["ok"]) and m.proj["trechos"].size() == 3 and m.proj["nodes"].size() == 4,
		"apagar T3 é recusado e a rede fica intacta (%d trechos, %d nós)" % [m.proj["trechos"].size(), m.proj["nodes"].size()])
	var al: String = m.ultimo_alerta
	T.check(id, al.contains("T3") and al.contains("PV C") and al.contains("sem saída"), "alerta cita o trecho, o PV e o motivo: \"%s\"" % al.get_slice("\n", 0).left(140))
	_fechar_janelas()
	p.limpar_selecao()
	p.marked[_tid("T3")] = true
	m.apagar_selecao()
	T.check(id, _alerta_visivel() != "" and not m.apagar_dialog.visible, "pelo Del: aparece o alerta e não a confirmação")
	_fechar_janelas()
	var rn: Dictionary = m.executar_apagar({}, {int(_no("C")["id"]): true})
	T.check(id, not bool(rn["ok"]) and str(m.ultimo_alerta).contains("recebe 2 trechos"), "apagar o próprio PV C (2 chegadas) também é recusado")
	_fechar_janelas()
	var r1: Dictionary = m.executar_apagar({_tid("T1"): true}, {})
	T.check(id, bool(r1["ok"]) and m.proj["trechos"].size() == 2 and _no("A").is_empty(),
		"apagar T1 (C fica com 1 chegada) é permitido e o nó A sai junto")
	_abrir("rede_ramificada.esg")
	var r3: Dictionary = m.executar_apagar({_tid("T1"): true, _tid("T2"): true, _tid("T3"): true}, {})
	T.check(id, bool(r3["ok"]) and m.proj["trechos"].is_empty() and m.proj["nodes"].is_empty(),
		"apagar T1, T2 e T3 juntos é permitido (ninguém fica sem saída) e não sobra nó")


# ------------------------------------------------------------------ T6-03

func _t603() -> void:
	var id := "T6-03"
	_abrir("rede_ramificada.esg")
	p.marked = {_tid("T3"): true}
	m._dividir()
	var meio := -1
	for n in m.proj["nodes"]:
		if not str(n["nome"]) in ["A", "B", "C", "D"]:
			meio = int(n["id"])
	var nm := Net.nome_no(m.proj, meio)
	T.dado(id, "entrada", "rede_ramificada.esg com T3 dividido (ponto intermediário %s)" % nm)
	p.limpar_selecao()
	p.sel_nos[meio] = true
	m.apagar_selecao()
	T.check(id, m.apagar_dialog.visible and m.apagar_dialog.dialog_text.contains("Deseja mesmo apagar o ponto"),
		"Del num ponto abre a confirmação: \"%s\"" % m.apagar_dialog.dialog_text.get_slice("\n", 0))
	T.check(id, m.proj["nodes"].size() == 5, "nada é apagado antes de confirmar")
	m.apagar_dialog.canceled.emit()
	m.apagar_dialog.hide()
	T.check(id, m.proj["nodes"].size() == 5 and m.proj["trechos"].size() == 4, "Cancelar mantém o ponto e os trechos")
	p.sel_nos[meio] = true
	m.apagar_selecao()
	m.apagar_dialog.confirmed.emit()
	m.apagar_dialog.hide()
	var lig := Net.ligacoes(m.proj)
	var c := int(_no("C")["id"])
	var t_cd: Dictionary = Net.trecho_map(m.proj).get(int(lig["out"][c][0]), {}) if not lig["out"].get(c, []).is_empty() else {}
	T.check(id, m.proj["nodes"].size() == 4 and m.proj["trechos"].size() == 3 and not t_cd.is_empty() and int(t_cd["nf"]) == int(_no("D")["id"]),
		"Confirmar apaga o ponto e une os dois trechos num só (C→D)")
	T.check(id, not t_cd.is_empty() and Lib.aprox(Net.comprimento(Net.node_map(m.proj), t_cd), 100.0, 1e-6),
		"extensão do trecho unido = 100,00 m")
	_fechar_janelas()
	m.desfazer()
	T.check(id, m.proj["nodes"].size() == 5 and m.proj["trechos"].size() == 4, "Ctrl+Z devolve o ponto")


# ------------------------------------------------------------------ T6-04

func _t604() -> void:
	var id := "T6-04"
	_fechar_janelas()
	m._novo()
	var pr: Dictionary = m.proj
	var x := Net.novo_no(pr, Vector2(0, 0), 100.0, true, "PV")
	var y := Net.novo_no(pr, Vector2(60, 0), 99.0, true, "PV")
	Net.novo_trecho(pr, m.db, int(x["id"]), int(y["id"]), "C1")
	var afl := [Vector2(-60, 0), Vector2(0, 60), Vector2(0, -60)]
	for k in afl.size():
		var a := Net.novo_no(pr, afl[k], 101.0, true, "TL")
		Net.novo_trecho(pr, m.db, int(a["id"]), int(x["id"]), "C%d" % (k + 2))
	m.on_changed("traçado")
	T.dado(id, "entrada", "PV X com saída e 3 trechos chegando")
	p.ajustar(Rect2(-100, -100, 200, 200), false)
	var t0: int = pr["trechos"].size()
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(-50, 50)))
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(0, 0)))
	var al := _alerta_visivel()
	T.check(id, m.proj["trechos"].size() == t0, "a 4ª entrada no PV X é recusada (%d trechos)" % m.proj["trechos"].size())
	T.check(id, al.contains("no máximo 3"), "alerta ao usuário: \"%s\"" % al.get_slice("\n", 1).left(100))
	_fechar_janelas()
	_tecla(KEY_ESCAPE)
	T.check(id, m.proj["nodes"].size() == 5, "Esc encerra o traçado sem deixar o nó inicial")
	var w := Net.novo_no(m.proj, Vector2(-40, 40), 101.0, true, "TL")
	var r := Net.pode_ligar(m.proj, int(w["id"]), int(x["id"]))
	T.check(id, str(r["regra"]) == "max_entradas", "regra no domínio (Net.pode_ligar → \"%s\")" % r["regra"])
	Net.remover_orfaos(m.proj)
	# 3ª entrada ainda é permitida
	var trs: Array = pr["trechos"]
	m.executar_apagar({int(trs[-1]["id"]): true}, {})
	var z := Net.novo_no(m.proj, Vector2(-40, -40), 101.0, true, "TL")
	var r3 := Net.pode_ligar(m.proj, int(z["id"]), int(x["id"]))
	T.check(id, bool(r3["ok"]), "com 2 entradas, a 3ª ligação é aceita")
	Net.remover_orfaos(m.proj)
	# importação: quatro polilinhas chegando no mesmo PV → a quarta é recusada
	var polis: Array = [PackedVector2Array([Vector2(0, 0), Vector2(50, 0)])]
	for v in [Vector2(-50, 0), Vector2(0, 50), Vector2(0, -50), Vector2(-40, -40)]:
		polis.append(PackedVector2Array([v, Vector2(0, 0)]))
	var imp := Net.de_polilinhas(polis, m.db)
	var ent := 0
	var mapa := {}
	for n in imp["nodes"]:
		mapa[int(n["id"])] = n
	for t in imp["trechos"]:
		if Net.pos(mapa[int(t["nf"])]) == Vector2.ZERO:
			ent += 1
	T.check(id, ent == 3 and int(imp["recusados"]) == 1, "importação de DXF respeita o limite (%d entradas, %d recusada)" % [ent, int(imp["recusados"])])


# ------------------------------------------------------------------ T6-05

func _t605() -> void:
	var id := "T6-05"
	_abrir("rede_ramificada.esg")
	p.ajustar(Rect2(-20, -120, 240, 240), false)
	var n0: int = m.proj["nodes"].size()
	var u0: int = m.undo_stack.size()
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(150, 80)))
	var durante: int = m.proj["nodes"].size()
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(160, 80)))
	T.check(id, durante == n0 + 1 and m.proj["nodes"].size() == n0, "iniciar e finalizar sem trecho: o nó inicial é descartado (%d → %d → %d nós)" % [n0, durante, m.proj["nodes"].size()])
	T.check(id, m.status_label.text.contains("descartado"), "barra de status informa: \"%s\"" % m.status_label.text.left(90))
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(150, 80)))
	_tecla(KEY_ESCAPE)
	T.check(id, m.proj["nodes"].size() == n0 and not p.tracing, "iniciar e cancelar com Esc: sem resíduo")
	T.check(id, m.undo_stack.size() == u0, "começos de traçado abandonados não entram no histórico (%d → %d)" % [u0, m.undo_stack.size()])
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(150, 80)))
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(150, 30)))
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(170, 90)))
	var novo: Dictionary = m.proj["trechos"][-1]
	T.check(id, m.proj["nodes"].size() == n0 + 2, "um trecho traçado cria 2 nós")
	m.executar_apagar({int(novo["id"]): true}, {})
	T.check(id, m.proj["nodes"].size() == n0 and _invariantes() == "", "criar e apagar o trecho: nenhum nó residual (%d nós)" % m.proj["nodes"].size())
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(150, 80)))
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(150, 30)))
	m.desfazer()
	T.check(id, m.proj["nodes"].size() == n0 and m.proj["trechos"].size() == 3, "Ctrl+Z do 1º trecho remove também o nó inicial (um passo só)")
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(150, 80)))
	p.marked = {_tid("T1"): true}
	m.executar_apagar(p.marked.duplicate(), {})
	T.check(id, _invariantes() == "" and not p.tracing, "apagar com traçado em andamento encerra o traçado sem resíduo (%s)" % (_invariantes() if _invariantes() != "" else "ok"))


# ------------------------------------------------------------------ T6-06

func _t606() -> void:
	var id := "T6-06"
	_fechar_janelas()
	m._do_action("exemplo")
	m._mostrar("tracado")
	p.ajustar(Rect2(0, 0, 600, 450), false)
	T.dado(id, "entrada", "rede de exemplo (30 nós); caixa de E 100–300 × N 100–250")
	var a := Vector2(100, 250)
	var b := Vector2(300, 100)
	var r := Rect2(Vector2(100, 100), Vector2(200, 150))
	var esp_n := {}
	for n in m.proj["nodes"]:
		if r.has_point(Net.pos(n)):
			esp_n[int(n["id"])] = true
	var esp_t := {}
	for t in m.proj["trechos"]:
		if esp_n.has(int(t["ni"])) and esp_n.has(int(t["nf"])):
			esp_t[int(t["id"])] = true
	_arrastar(_s(a), _s(b))
	T.check(id, p.sel_nos.size() == esp_n.size() and esp_n.keys().all(func(k): return p.sel_nos.has(k)),
		"arrastar na área vazia seleciona os %d nós dentro da caixa (obtido %d)" % [esp_n.size(), p.sel_nos.size()])
	T.check(id, p.marked.size() == esp_t.size() and esp_t.keys().all(func(k): return p.marked.has(k)),
		"seleciona os %d trechos inteiramente dentro (obtido %d); trechos que cruzam a borda ficam de fora" % [esp_t.size(), p.marked.size()])
	T.check(id, m.status_label.text.contains("selecionado"), "barra de status: \"%s\"" % m.status_label.text.left(80))
	var antes: int = p.sel_nos.size()
	_arrastar(_s(Vector2(400, 440)), _s(Vector2(500, 380)), true)
	T.check(id, p.sel_nos.size() > antes, "Ctrl + caixa soma à seleção (%d → %d nós)" % [antes, p.sel_nos.size()])
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(20, 440)))
	T.check(id, not p.tem_selecao(), "clique na área vazia desfaz a seleção")
	var n1: Dictionary = m.proj["nodes"][0]
	_clique(MOUSE_BUTTON_LEFT, _s(Net.pos(n1)))
	T.check(id, p.sel_nos.size() == 1 and p.sel_nos.has(int(n1["id"])) and p.marked.is_empty(), "clique num nó seleciona só ele")
	# apagar a seleção da caixa
	_arrastar(_s(a), _s(b))
	var nn0: int = m.proj["nodes"].size()
	var lig0 := Net.ligacoes(m.proj)
	var saidas_finais := {}
	for k in lig0["inc"].keys():
		if lig0["inc"][k].size() >= 2 and lig0["out"].get(k, []).is_empty():
			saidas_finais[k] = true
	_tecla(KEY_DELETE)
	var conf: bool = m.apagar_dialog.visible
	T.check(id, conf and m.apagar_dialog.dialog_text.contains("Deseja mesmo apagar a seleção"), "Del pede confirmação para a seleção")
	if conf:
		m.apagar_dialog.confirmed.emit()
		m.apagar_dialog.hide()
	var sobrou := 0
	for k in esp_n.keys():
		if Net.node_map(m.proj).has(k):
			sobrou += 1
	var inv := _invariantes(saidas_finais)
	T.check(id, sobrou == 0 and m.proj["nodes"].size() < nn0 and inv == "",
		"confirmado: os nós da caixa saem e a rede fica consistente (%s)" % (inv if inv != "" else "%d → %d nós" % [nn0, m.proj["nodes"].size()]))


# ------------------------------------------------------------------ T6-07

func _t607() -> void:
	var id := "T6-07"
	_fechar_janelas()
	m._do_action("exemplo")
	T.dado(id, "entrada", "rede de exemplo dimensionada")
	var barra: Node = m.sheets_box.find_child("BarraPlanilhas", true, false)
	var botoes := 0
	if barra != null:
		for nome in ["Exp_csv", "Exp_xlsx", "Exp_html", "Exp_pdf", "Exp_todas"]:
			if barra.find_child(nome, true, false) != null:
				botoes += 1
	T.check(id, botoes == 5, "barra das planilhas com CSV, XLSX, HTML, PDF e \"Todas as planilhas\" (%d de 5 botões)" % botoes)
	T.check(id, m.motivo_bloqueio() == "", "pré-condição: resultado aprovado e atualizado (%s)" % (m.motivo_bloqueio() if m.motivo_bloqueio() != "" else "ok"))
	var arq: String = T.tmp("todas.xlsx")
	var r: Dictionary = m.exportar_todas_planilhas(arq)
	var x := Report.ler_xlsx(arq)
	var wb: String = x.get("xl/workbook.xml", "")
	var faltam: Array = []
	for nome in ["Plan. Trechos", "Plan. Nós", "Plan. Dimens.", "Plan. Quant.", "Resultados", "Orçamento", "Info"]:
		if not wb.contains("name=\"%s\"" % nome):
			faltam.append(nome)
	T.check(id, bool(r["ok"]) and faltam.is_empty(), "pasta de trabalho com uma aba por planilha (faltando: %s)" % (", ".join(PackedStringArray(faltam)) if not faltam.is_empty() else "nenhuma"))
	var abas: Array = r.get("abas", [])
	var linhas_ok := true
	for i in abas.size():
		var key := ""
		for sh in m.SHEETS:
			if sh[1] == abas[i]:
				key = sh[0]
		m._refresh_sheet(m.SHEETS.map(func(s): return s[0]).find(key))
		var esperadas: int = m.tables[key].dados().size()
		var xml: String = x.get("xl/worksheets/sheet%d.xml" % (i + 1), "")
		if xml.count("<row ") != esperadas:
			linhas_ok = false
			T.dado(id, "divergencia_" + key, [xml.count("<row "), esperadas])
	T.check(id, linhas_ok, "cada aba tem as mesmas linhas da planilha na tela (%d abas)" % abas.size())
	# resultados desatualizados → resultados e orçamento ficam de fora, com aviso na aba Info
	var n: Dictionary = m.proj["nodes"][3]
	n["ct"] = float(n["ct"]) + 0.5
	m.on_changed("no")
	var arq2: String = T.tmp("todas_desatualizadas.xlsx")
	var r2: Dictionary = m.exportar_todas_planilhas(arq2)
	var x2 := Report.ler_xlsx(arq2)
	var wb2: String = x2.get("xl/workbook.xml", "")
	var info2 := ""
	for f in x2.keys():
		if str(x2[f]).contains("Planilhas não incluídas"):
			info2 = f
	T.check(id, bool(r2["ok"]) and not wb2.contains("name=\"Resultados\"") and not wb2.contains("name=\"Orçamento\"") and info2 != "",
		"com resultado desatualizado, Resultados e Orçamento ficam de fora e a aba Info diz por quê")
	m.executar_calculo(false)
	await _frames(1)


# ------------------------------------------------------------------ T6-08

func _t608() -> void:
	var id := "T6-08"
	_fechar_janelas()
	m._do_action("exemplo")
	root.size = Vector2i(1000, 700)
	m._mostrar("planilhas")
	m.sheets.current_tab = 4
	await _frames(4)
	var gt = m.tables["res"]
	var titulos: Array = []
	for c in gt.congeladas:
		titulos.append(gt.get_column_title(c).replace("\n", " "))
	T.dado(id, "colunas_fixas", titulos)
	T.check(id, gt.congeladas == 4 and titulos[0] == "Col." and titulos[1] == "Trecho" and str(titulos[2]).begins_with("PV") and str(titulos[3]).begins_with("Ext."),
		"Resultados: 4 colunas fixas (%s)" % ", ".join(PackedStringArray(titulos)))
	var hs = gt._scrollbars()[1]
	T.check(id, hs != null and hs.visible and hs.max_value > hs.page, "planilha mais larga que a tela (rolagem horizontal ativa)")
	T.check(id, not gt.fixas_info()["visivel"], "sem rolagem, a faixa fixa não aparece (as colunas já estão no lugar)")
	hs.value = 400.0
	await _frames(3)
	var info: Dictionary = gt.fixas_info()
	var larg := 0.0
	for c in 4:
		larg += gt.get_column_width(c)
	T.check(id, bool(info["visivel"]) and Lib.aprox(float(info["largura"]), larg, 0.5) and float(info["rect"].size.x) >= larg,
		"rolando %d px para a direita, as 4 colunas ficam fixas à esquerda (faixa de %.0f px)" % [int(hs.value), float(info["rect"].size.x)])
	# clique na faixa seleciona a célula sem voltar a rolagem
	var primeiro: TreeItem = gt.get_root().get_first_child()
	var ry: float = gt.get_item_area_rect(primeiro, 0).position.y + 4.0
	if ry < gt._fixas.position.y + 30.0:
		ry = gt._fixas.position.y + 60.0
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(10, ry - gt._fixas.position.y)
	var item: TreeItem = gt.get_item_at_position(ev.position + gt._fixas.position)
	gt._fixas_input(ev)
	await _frames(2)
	T.check(id, item != null and item.is_selected(0) and Lib.aprox(hs.value, 400.0, 0.5), "clique na coluna fixa seleciona a célula e mantém a rolagem (h = %d)" % int(hs.value))
	hs.value = 0.0
	await _frames(2)
	T.check(id, not gt.fixas_info()["visivel"], "voltando ao início, a faixa some")
	T.check(id, m.tables["trechos"].congeladas == 5 and m.tables["quant"].congeladas == 5, "Plan. Trechos/Dimens./Quant.: coletor, nós, extensão e nome fixos")
	# arquivo exportado também traz as colunas congeladas
	var arq: String = T.tmp("resultados.xlsx")
	m.exportar_planilha_arquivo("res", arq)
	var x := Report.ler_xlsx(arq)
	T.check(id, str(x.get("xl/worksheets/sheet1.xml", "")).contains("xSplit=\"4\"") and str(x.get("xl/worksheets/sheet1.xml", "")).contains("state=\"frozen\""),
		"XLSX de resultados abre com as 4 colunas e o título congelados")
	root.size = Vector2i(1366, 820)
	m._mostrar("tracado")
	await _frames(1)


# ------------------------------------------------------------------ T6-09

func _gpkg(path: String) -> Dictionary:
	var out: Array = []
	var script: String = T.tmp("valida_gpkg.py")
	var f := FileAccess.open(script, FileAccess.WRITE)
	f.store_string(PY_GPKG)
	f.close()
	var rc := OS.execute("python3", ["-I", script, path], out, true)
	var txt := "".join(PackedStringArray(out))
	for l in txt.split("\n"):
		if l.begins_with("GPKG="):
			return JSON.parse_string(l.substr(5))
	return {"_erro": "python3 rc=%d: %s" % [rc, txt.left(300)]}


func _t609() -> void:
	var id := "T6-09"
	_fechar_janelas()
	m._novo()
	var r: Dictionary = m.importar_rede_dxf(T.fix("rede_phase6.dxf"), {"REDE_ESGOTO": true})
	_fechar_janelas()
	T.dado(id, "entrada", "rede_phase6.dxf: layer REDE_ESGOTO (2 LWPOLYLINE + 1 LINE válidas, 1 bifurcação, 1 contorno fechado) e layer TEXTOS")
	T.check(id, bool(r.get("ok", false)) and int(r.get("nos", 0)) == 8 and int(r.get("trechos", 0)) == 7,
		"DXF: 8 nós e 7 trechos importados (obtido %d / %d)" % [int(r.get("nos", 0)), int(r.get("trechos", 0))])
	var av := " ".join(PackedStringArray(r.get("avisos", [])))
	T.check(id, int(r.get("recusados", 0)) == 2 and av.contains("bifurcação") and av.contains("fechada"),
		"bifurcação e contorno fechado recusados com aviso (%d)" % int(r.get("recusados", 0)))
	var lig := Net.ligacoes(m.proj)
	var por_pos := {}
	for n in m.proj["nodes"]:
		por_pos[Vector2i(roundi(float(n["e"])), roundi(float(n["n"])))] = n
	var cab: Dictionary = por_pos.get(Vector2i(0, 100), {})
	var sai: Dictionary = por_pos.get(Vector2i(170, 0), {})
	var jun: Dictionary = por_pos.get(Vector2i(60, 0), {})
	T.check(id, not cab.is_empty() and str(cab["tipo"]) == "TL" and lig["inc"][int(cab["id"])].is_empty()
		and not sai.is_empty() and lig["out"][int(sai["id"])].is_empty(),
		"sentido do desenho = sentido do escoamento (cabeceira TL em (0;100), saída em (170;0))")
	T.check(id, not jun.is_empty() and lig["inc"][int(jun["id"])].size() == 2 and lig["out"][int(jun["id"])].size() == 1,
		"vértices a menos de 5 cm viram o mesmo PV (afluente ligado em (60;0))")
	T.check(id, not por_pos.has(Vector2i(500, 500)) and not por_pos.has(Vector2i(-50, 50)) and _invariantes() == "",
		"layer não selecionado ignorado e nenhum vértice solto (%s)" % (_invariantes() if _invariantes() != "" else "ok"))
	for n in m.proj["nodes"]:
		n["ct"] = 100.0 + 0.02 * float(n["n"]) - 0.012 * float(n["e"])
		n["ct_ok"] = true
	m.on_changed("no")
	var calc: Dictionary = m.executar_calculo(false)
	T.check(id, bool(calc.get("ok", false)), "rede importada é dimensionada sem erro estrutural")
	# GeoPackage
	m.proj["referencia"]["crs"] = "SIRGAS 2000 / UTM zone 22S (EPSG:31982)"
	var arq: String = T.tmp("rede.gpkg")
	var g: Dictionary = m.exportar_rede_gpkg(arq)
	var bytes := FileAccess.get_file_as_bytes(arq)
	T.check(id, bool(g["ok"]) and bytes.size() > 100 and bytes.slice(0, 15).get_string_from_ascii() == "SQLite format 3",
		"GeoPackage gravado (%d bytes, cabeçalho SQLite 3)" % bytes.size())
	var v := _gpkg(arq)
	if v.has("_erro"):
		T.check(id, false, "validação com o sqlite3 do Python: %s" % v["_erro"])
		return
	T.dado(id, "gpkg", {"tables": v["tables"], "srs": v["srs"], "geomcols": v["geomcols"]})
	T.check(id, str(v["integrity"]) == "ok" and int(v["fk"]) == 0, "PRAGMA integrity_check = %s; foreign_key_check sem erros" % v["integrity"])
	T.check(id, int(v["app_id"]) == 0x47504B47 and int(v["user_version"]) == 10300, "application_id \"GPKG\" e user_version 10300 (GeoPackage 1.3)")
	var tabs: Array = v["tables"]
	T.check(id, tabs.has("gpkg_spatial_ref_sys") and tabs.has("gpkg_contents") and tabs.has("gpkg_geometry_columns") and tabs.has("pvs") and tabs.has("trechos"),
		"tabelas obrigatórias + camadas pvs e trechos")
	T.check(id, int(v["n_pvs"]) == 8 and int(v["n_trechos"]) == 7 and bool(v["geom_linhas_ok"]), "8 PVs e 7 trechos com geometria GeoPackage (LineString)")
	T.check(id, (v["srs"] as Array).has(31982.0) and str(v["geomcols"]).contains("31982"), "SRC do projeto gravado (EPSG:31982)")
	var pv_ok := true
	for n in m.proj["nodes"]:
		var pt = v["pvs"].get(str(n["nome"]))
		if pt == null or not Lib.aprox(float(pt[0]), float(n["e"]), 1e-9) or not Lib.aprox(float(pt[1]), float(n["n"]), 1e-9):
			pv_ok = false
	T.check(id, pv_ok, "coordenadas dos PVs idênticas às do projeto")
	T.check(id, (v["cols_trechos"] as Array).has("diametro_mm") == bool(g["com_resultados"]),
		"resultados entram só com dimensionamento aprovado e atualizado (com resultados: %s)" % str(g["com_resultados"]))
	# rede de exemplo aprovada → resultados no GeoPackage
	m._do_action("exemplo")
	var arq2: String = T.tmp("exemplo.gpkg")
	var g2: Dictionary = m.exportar_rede_gpkg(arq2)
	var v2 := _gpkg(arq2)
	T.check(id, bool(g2["com_resultados"]) and str(v2.get("integrity", "")) == "ok" and float(v2.get("d_min", 0.0)) >= 150.0,
		"exemplo dimensionado: trechos levam diâmetro e demais resultados (ø mínimo %s mm)" % str(v2.get("d_min", "?")))
	# rede grande: árvores B com várias páginas e páginas internas
	T.gerar_rede_grande(m)
	var arq3: String = T.tmp("grande.gpkg")
	var g3: Dictionary = m.exportar_rede_gpkg(arq3)
	var v3 := _gpkg(arq3)
	T.check(id, bool(g3["ok"]) and str(v3.get("integrity", "")) == "ok" and int(v3.get("n_pvs", 0)) == 1600 and int(v3.get("n_trechos", 0)) == 1500,
		"rede grande (1.600 PVs, 1.500 trechos, %d KB): integridade %s" % [int(g3.get("bytes", 0)) / 1024, str(v3.get("integrity", "?"))])
