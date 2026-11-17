extends SceneTree
## Fase 8 — pedidos do engenheiro de 17/11/2026 (tests/PHASE-8.md, docs/fase-8/).
##   T8-01 lâmina ≤ 75% com as duas vazões        T8-02 TL que recebe rede: pergunta e escolha
##   T8-03 2+ entradas: PV automático             T8-04 TIL de passagem
##   T8-05 exportação da planta                   T8-06 materiais sem marca
##   T8-07 numeração coletor/trecho               T8-08 comprimento ao traçar
##   T8-09 redesenhar                             T8-10 formato do projeto
## (T8-11, regressão das fases 0–7, é calculado pelo runner.)
## Casos ainda não implementados saem como SKIP "a implementar" (docs/fase-8/04-backlog.md).

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")
const Db = preload("res://db.gd")
const Geo = preload("res://geo.gd")
const Report = preload("res://report.gd")
const Calc = preload("res://calc.gd")

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
	_t801()
	_t802()
	_t803()
	_t804()
	_t805()
	_t807()
	_t808()
	for par in [["T8-06", "B1"], ["T8-09", "B3"], ["T8-10", "B4"]]:
		T.skip(par[0], "a implementar (tarefa %s)" % par[1])
	quit(T.fim())


# ------------------------------------------------------------------ utilidades

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
	m.tl_pendente = {}


func _janela_visivel() -> String:
	for ch in m.get_children():
		if ch is AcceptDialog and ch.visible:
			return str(ch.name) + ": " + ch.dialog_text
	return ""


func _no(nome: String) -> Dictionary:
	return Net.achar_no(m.proj, nome)


func _tid(nome: String) -> int:
	return int(Net.achar_trecho(m.proj, nome)["id"])


func _s(w: Vector2) -> Vector2:
	return p.w2s(w)


func _clique(botao: int, s: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = botao
	ev.position = s
	ev.pressed = true
	p._gui_input(ev)
	var ev2: InputEventMouseButton = ev.duplicate()
	ev2.pressed = false
	p._gui_input(ev2)


## Inicia um coletor em "inicio" (área vazia) e clica no nó "alvo" (botão 1).
func _tracar_para(inicio: Vector2, alvo: Dictionary) -> void:
	m.opts["osnap"] = false
	_clique(MOUSE_BUTTON_RIGHT, _s(inicio))
	_clique(MOUSE_BUTTON_LEFT, _s(Net.pos(alvo)))


func _tipo(nome: String) -> String:
	return str(_no(nome).get("tipo", "?"))


# ------------------------------------------------------------------ T8-01

## Dimensiona rede_unica.esg com vazão pontual na cabeceira (nó 1) e devolve a linha de T1.
func _calc_unica(qi: float, qf: float, fixa_d := 0.0) -> Dictionary:
	_abrir("rede_unica.esg")
	var cab := _no("1")
	cab["qp_i"] = qi
	cab["qp_f"] = qf
	var t := Net.achar_trecho(m.proj, "T1")
	t["fixa_d"] = fixa_d > 0.0
	if fixa_d > 0.0:
		t["d"] = fixa_d
	m.executar_calculo(false)
	return T.linha(m, "T1")


## Limite de lâmina de uma vazão: 0,50 se a velocidade passa da crítica, senão 0,75.
func _lim(yd: float, v: float, d_mm: float) -> float:
	var rh: float = Lib.secao(clampf(yd, 0.001, 0.999), d_mm / 1000.0)["rh"]
	return 0.5 if v > 6.0 * sqrt(9.81 * rh) else 0.75


func _t801() -> void:
	var id := "T8-01"
	T.dado(id, "entrada", "rede_unica.esg (T1, 100 m), vazão pontual no nó 1; caso do print do engenheiro: início 35 l/s, fim 20 l/s")
	var r := _calc_unica(35.0, 20.0)
	T.check(id, float(r["d"]) > 150.0 and float(r["yd_i"]) <= 0.75 + 1e-9 and float(r["yd_f"]) <= 0.75 + 1e-9,
		"início 35 / fim 20 l/s: ø%d, y/D início %.2f e fim %.2f (antes: ø150 com y/D início 1,00, aprovado)" % [int(r["d"]), float(r["yd_i"]), float(r["yd_f"])])
	T.check(id, float(r["yd_i"]) <= _lim(float(r["yd_i"]), float(r["v_i"]), float(r["d"])) + 1e-9,
		"limite da velocidade crítica também vale para a vazão de início (y/D %.2f, v %.2f m/s)" % [float(r["yd_i"]), float(r["v_i"])])
	T.check(id, bool(m.results["aprovado"]), "com o diâmetro maior, o resultado é aprovado")
	# início ≤ fim: resultados idênticos aos do motor 3.1 (gravados em 17/11/2026)
	var r2 := _calc_unica(20.0, 35.0)
	T.check(id, int(r2["d"]) == 350 and is_equal_approx(snappedf(float(r2["i"]), 1e-6), 0.0013) and is_equal_approx(snappedf(float(r2["cc_j"]), 1e-4), 98.17)
		and absf(float(r2["yd_f"]) - 0.6526) < 1e-4 and absf(float(r2["yd_i"]) - 0.4521) < 1e-4,
		"início 20 / fim 35 l/s: igual ao motor anterior (ø%d, I %.4f, CC jus. %.2f, y/D %.4f / %.4f)" % [int(r2["d"]), float(r2["i"]), float(r2["cc_j"]), float(r2["yd_i"]), float(r2["yd_f"])])
	var r3 := _calc_unica(0.0, 0.0)
	T.check(id, int(r3["d"]) == 150 and absf(float(r3["i"]) - 0.0037) < 1e-6 and absf(float(r3["yd_f"]) - 0.5236) < 1e-4,
		"sem vazão pontual: igual ao motor anterior (ø%d, I %.4f, y/D fim %.4f)" % [int(r3["d"]), float(r3["i"]), float(r3["yd_f"])])
	# diâmetro fixado em 150: nenhum diâmetro atende → impeditivo, citando a lâmina inicial
	var r4 := _calc_unica(35.0, 20.0, 150.0)
	var obs: String = " | ".join(PackedStringArray(r4.get("obs", [])))
	T.check(id, int(r4["status"]) == 2 and obs.contains("lâmina inicial") and not bool(m.results["aprovado"]),
		"ø150 fixado com 35 l/s no início: impeditivo e não aprovado (\"%s\")" % obs.left(120))
	T.check(id, Calc.MOTOR_VERSAO == "motor-3.2" and str(m.results.get("motor", "")) == "motor-3.2", "versão do motor: %s" % Calc.MOTOR_VERSAO)


# ------------------------------------------------------------------ T8-02

func _t802() -> void:
	var id := "T8-02"
	T.dado(id, "entrada", "rede_unica.esg: TL 1 → PV 2 (saída); novo coletor traçado até o TL 1")
	for opcao in [["PI", "Poço de inspeção"], ["PV", "Poço de visita"], ["TP", "TIL de passagem"]]:
		_abrir("rede_unica.esg")
		p.ajustar(Rect2(-60, -60, 220, 120), false)
		var n0: int = m.proj["nodes"].size()
		var t0: int = m.proj["trechos"].size()
		var pilha0: int = m.undo_stack.size()
		_tracar_para(Vector2(-40, 30), _no("1"))
		var janela := _janela_visivel()
		if opcao[0] == "PI":
			T.check(id, m.tl_dialog.visible and janela.contains("TL 1") and janela.contains("Transformar"),
				"clicar no TL 1 abre a pergunta: \"%s\"" % janela.replace("\n", " ").left(120))
			var botoes: Array = []
			for ch in m.tl_dialog.find_children("*", "Button", true, false):
				if ch.visible:
					botoes.append(ch.text)
			T.check(id, "Poço de visita (PV)" in botoes and "Poço de inspeção (PI)" in botoes and "TIL de passagem" in botoes and "Cancelar" in botoes,
				"opções da pergunta: %s" % ", ".join(PackedStringArray(botoes)))
			T.check(id, m.proj["trechos"].size() == t0 and _tipo("1") == "TL" and p.tracing,
				"antes da escolha: nenhum trecho novo, o nó continua TL, o traçado segue ativo")
		var ok: bool = m.escolher_tipo_tl(opcao[0])
		T.check(id, ok and m.proj["trechos"].size() == t0 + 1 and _tipo("1") == opcao[0] and not p.tracing and not m.tl_dialog.visible,
			"escolher %s: trecho criado, TL 1 vira %s, traçado finalizado" % [opcao[1], _tipo("1")])
		T.check(id, m.undo_stack.size() == pilha0 + 1, "a ligação e a troca do tipo são um passo só de desfazer (%d passo)" % (m.undo_stack.size() - pilha0))
		m.desfazer()
		T.check(id, m.proj["trechos"].size() == t0 and m.proj["nodes"].size() == n0 and _tipo("1") == "TL",
			"Ctrl+Z (%s): sem o trecho, sem o nó inicial e o nó 1 volta a ser TL" % opcao[0])
	# Cancelar
	_abrir("rede_unica.esg")
	p.ajustar(Rect2(-60, -60, 220, 120), false)
	var n1: int = m.proj["nodes"].size()
	_tracar_para(Vector2(-40, 30), _no("1"))
	m.tl_dialog.canceled.emit()
	T.check(id, m.proj["trechos"].size() == 1 and _tipo("1") == "TL" and p.tracing and not m.tl_dialog.visible,
		"Cancelar: nenhum trecho novo, o TL continua TL e o traçado segue ativo")
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(-40, 30)))
	T.check(id, not p.tracing and m.proj["nodes"].size() == n1, "finalizar depois de cancelar não deixa nó solto")
	# clicar num PV com saída: sem pergunta
	_abrir("rede_ramificada.esg")
	p.ajustar(Rect2(-20, -120, 240, 240), false)
	var tr0: int = m.proj["trechos"].size()
	_tracar_para(Vector2(150, 80), _no("C"))
	T.check(id, not m.tl_dialog.visible and m.proj["trechos"].size() == tr0 + 1, "ligar num PV não abre a pergunta")
	# domínio: Net.ligar sem tipo é recusado com a regra "escolher_tipo"
	_abrir("rede_unica.esg")
	var tl := Net.novo_no(m.proj, Vector2(-40, 30), 100.5, true, "TL")
	var r := Net.ligar(m.proj, m.db, int(tl["id"]), int(_no("1")["id"]), "C9")
	T.check(id, not bool(r["ok"]) and str(r["regra"]) == "escolher_tipo" and m.proj["trechos"].size() == 1,
		"domínio: Net.ligar num TL sem escolher o tipo é recusado (regra \"%s\")" % r["regra"])
	var r2 := Net.ligar(m.proj, m.db, int(tl["id"]), int(_no("1")["id"]), "C9", "TL")
	T.check(id, not bool(r2["ok"]) and str(r2["regra"]) == "tipo_invalido", "domínio: TL não é opção para o TL que recebe rede")
	# DXF: polilinha que termina no início de outra → o nó é PV, sem pergunta
	var polis := [PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(200, 0)]), PackedVector2Array([Vector2(-100, 50), Vector2(0, 0)])]
	var dx := Net.de_polilinhas(polis, m.db)
	var tipo0 := "?"
	for n in dx["nodes"]:
		if Net.pos(n).is_equal_approx(Vector2.ZERO):
			tipo0 = str(n["tipo"])
	T.check(id, tipo0 == "PV", "DXF: o início de coletor que recebe outra polilinha é PV, sem pergunta (%s)" % tipo0)


# ------------------------------------------------------------------ T8-03

func _t803() -> void:
	var id := "T8-03"
	for tipo1 in ["TP", "PI", "CP"]:
		_abrir("rede_unica.esg")
		p.ajustar(Rect2(-60, -60, 220, 120), false)
		_tracar_para(Vector2(-40, 30), _no("1"))
		if tipo1 == "CP":
			m.escolher_tipo_tl("PV")
			_no("1")["tipo"] = "CP"
			m.on_changed("no")
		else:
			m.escolher_tipo_tl(tipo1)
		var pilha0: int = m.undo_stack.size()
		_tracar_para(Vector2(-40, -30), _no("1"))
		var janela := _janela_visivel()
		T.check(id, _tipo("1") == "PV" and Net.entradas(m.proj, int(_no("1")["id"])).size() == 2 and janela == "",
			"%s com 1 entrada recebe a 2ª: vira PV, sem mensagem (%s)" % [tipo1, janela if janela != "" else "nenhuma janela"])
		if tipo1 == "TP":
			T.check(id, m.undo_stack.size() == pilha0 + 1, "2ª ligação + conversão: um passo de desfazer")
			m.desfazer()
			T.check(id, _tipo("1") == "TP" and Net.entradas(m.proj, int(_no("1")["id"])).size() == 1, "Ctrl+Z devolve o TIL de passagem com 1 entrada")
			m.refazer()
			T.check(id, _tipo("1") == "PV", "Ctrl+Y refaz a conversão em PV")
			# apagar uma das entradas: continua PV
			var ent := Net.entradas(m.proj, int(_no("1")["id"]))
			var r: Dictionary = m.executar_apagar({int(ent[0]["id"]): true}, {})
			T.check(id, bool(r["ok"]) and _tipo("1") == "PV" and Net.entradas(m.proj, int(_no("1")["id"])).size() == 1,
				"apagar uma das 2 entradas: o nó continua PV (não volta sozinho)")
	# dividir o trecho de chegada não muda o tipo
	_abrir("rede_unica.esg")
	p.ajustar(Rect2(-60, -60, 220, 120), false)
	_tracar_para(Vector2(-40, 30), _no("1"))
	m.escolher_tipo_tl("TP")
	var chegada: Dictionary = Net.entradas(m.proj, int(_no("1")["id"]))[0]
	p.marked = {int(chegada["id"]): true}
	m._dividir()
	T.check(id, _tipo("1") == "TP" and Net.entradas(m.proj, int(_no("1")["id"])).size() == 1, "dividir o trecho de chegada não muda o tipo (continua TIL de passagem)")
	# janela do nó: tentar marcar TL num nó com 2 entradas → PV
	_abrir("rede_ramificada.esg")
	_no("C")["tipo"] = "TL"
	m.on_changed("no")
	T.check(id, _tipo("C") == "PV", "nó com 2 entradas marcado como TL pela janela do nó volta a PV")
	# TQ e TT não mudam
	for tq in ["TQ", "TT", "TR"]:
		_no("C")["tipo"] = tq
		Net.ajustar_tipos(m.proj)
		T.check(id, _tipo("C") == tq, "%s com 2 entradas não muda" % tq)
	# projeto da versão 3 com TL no meio da rede
	_abrir("rede_tl_meio_v3.esg")
	var st: String = m.status_label.text
	T.check(id, _tipo("C") == "PV" and st.contains("passaram a PV") and st.contains("C (era TL)"),
		"ao abrir: o TL C, com 2 entradas, vira PV e o status avisa (\"%s\")" % st.left(160))
	var meio := Net.tls_no_meio(m.proj)
	T.check(id, _tipo("D") == "TL" and meio.size() == 1 and str(meio[0]["nome"]) == "D", "o TL D, com 1 entrada, continua TL e é apontado como TL no meio da rede")
	m.executar_calculo(false)
	var al := ""
	for a in m.results.get("alertas", []):
		if str(a["tipo"]) == "tl_meio":
			al = str(a["texto"])
	T.check(id, al.contains("D") and al.contains("T3") and al.contains("TIL de passagem"), "alerta ao dimensionar: \"%s\"" % al.left(150))
	T.check(id, m.texto_alertas(m.results["alertas"]).contains("TL NO MEIO DA REDE"), "a janela de alertas tem a seção \"TL no meio da rede\"")
	# domínio puro, sem interface
	var pj := {"nodes": [], "trechos": []}
	var a := Net.novo_no(pj, Vector2(0, 10), 101.0, true, "TL")
	var b := Net.novo_no(pj, Vector2(0, -10), 101.0, true, "TL")
	var c := Net.novo_no(pj, Vector2(50, 0), 100.0, true, "TP")
	var d := Net.novo_no(pj, Vector2(100, 0), 99.0, true, "PV")
	Net.novo_trecho(pj, m.db, int(c["id"]), int(d["id"]), "C1")
	Net.novo_trecho(pj, m.db, int(a["id"]), int(c["id"]), "C1")
	var r3 := Net.ligar(pj, m.db, int(b["id"]), int(c["id"]), "C2")
	T.check(id, bool(r3["ok"]) and str(c["tipo"]) == "PV" and r3["convertidos"].size() == 1, "domínio: Net.ligar converte o TIL de passagem em PV na 2ª entrada, sem interface")


# ------------------------------------------------------------------ T8-04

func _t804() -> void:
	var id := "T8-04"
	var padrao := Db.defaults()
	var tp := Db.pv(padrao, "TP")
	T.check(id, str(tp["nome"]) == "TIL de passagem" and str(tp["sigla_imp"]) == "TIL-P", "banco padrão: \"%s\" (sigla %s)" % [tp["nome"], tp["sigla_imp"]])
	T.check(id, "TP-TIL de passagem" in m.dlg._tipos_no(), "aparece em \"Tipo do nó\" na janela do nó")
	# banco antigo (banco_teste.json, sem o item): ganha o item, o resto fica igual
	var bruto = JSON.parse_string(FileAccess.get_file_as_string(Lib.BANCO_TESTE))
	var pv_arquivo := 0.0
	for r in bruto["pvs"]:
		if str(r["sigla"]) == "PV":
			pv_arquivo = float(r["custo"])
	T.check(id, not "TP" in bruto["pvs"].map(func(r): return str(r["sigla"])) and Db.pv(m.db, "TP")["nome"] == "TIL de passagem" and is_equal_approx(float(Db.pv(m.db, "PV")["custo"]), pv_arquivo),
		"banco antigo sem o item: acrescentado ao carregar; o custo do PV do arquivo (%s) ficou igual" % pv_arquivo)
	# planta: símbolo próprio (círculo extra) e legenda
	_abrir("rede_tl_meio_v3.esg")
	var dxf_tl := Report.dxf_planta(m.proj, {}, m.topo, m.opts, m.db)
	_no("D")["tipo"] = "TP"
	m.on_changed("no")
	var dxf_tp := Report.dxf_planta(m.proj, {}, m.topo, m.opts, m.db)
	var circ_tl := dxf_tl.count("\nCIRCLE\n")
	var circ_tp := dxf_tp.count("\nCIRCLE\n")
	# TL (1 círculo pequeno) → TP (círculo + anel) = +1; item da legenda (círculo + anel) = +2
	T.check(id, circ_tp == circ_tl + 3 and dxf_tp.contains("TIL de passagem") and not dxf_tl.contains("TIL de passagem"),
		"DXF da planta: TIL de passagem com anel interno e item na legenda (%d → %d círculos)" % [circ_tl, circ_tp])
	T.check(id, dxf_tp.contains("TIL-P"), "DXF: sigla TIL-P junto ao nó")
	# orçamento e aviso de DN > 300
	m.executar_calculo(false)
	var no_orc := false
	for l in m.results.get("orc", {}).get("linhas", []):
		if str(l.get("desc", "")).contains("TIL de passagem (TIL-P)"):
			no_orc = true
	T.check(id, no_orc, "orçamento conta o TIL de passagem")
	var t4 := Net.achar_trecho(m.proj, "T4")
	t4["fixa_d"] = true
	t4["d"] = 350.0
	m.on_changed("trecho")
	m.executar_calculo(false)
	var obs: String = T.obs_de(m, "T4")
	T.check(id, obs.contains("TIL de passagem D aceita até DN 300") and int(T.linha(m, "T4")["status"]) == 1 and bool(m.results["aprovado"]),
		"trecho ø350 saindo do TIL de passagem: advertência, não impeditivo (\"%s\")" % obs.left(120))
	# persistência: salvar/abrir e GeoJSON
	var arq: String = T.tmp("fase8_tp.esg")
	m._save_to(arq)
	T.carregar(m, "rede_unica.esg")
	m._load_from(arq)
	T.check(id, _tipo("D") == "TP", "salvar e abrir mantém o TIL de passagem")
	var gj: String = T.tmp("fase8_tp.geojson")
	var f := FileAccess.open(gj, FileAccess.WRITE)
	f.store_string(Geo.exportar_rede(m.proj))
	f.close()
	var gi := Geo.importar_rede(gj, m.proj["params"], m.db)
	var tipo_gj := "?"
	for n in gi.get("proj", {}).get("nodes", []):
		if str(n["nome"]) == "D":
			tipo_gj = str(n["tipo"])
	T.check(id, tipo_gj == "TP", "GeoJSON: exporta e importa o tipo TP")


# ------------------------------------------------------------------ T8-05

func _t805() -> void:
	var id := "T8-05"
	var arq: String = T.tmp("fase8_planta.dxf")
	# caso do print depois da correção da lâmina: aprovado, a planta sai
	_calc_unica(35.0, 20.0)
	var e1: Dictionary = m.exportar_planta(arq)
	T.check(id, bool(m.results["aprovado"]) and bool(e1["ok"]) and FileAccess.file_exists(arq),
		"rede do print (35 / 20 l/s) dimensionada: aprovada e a planta DXF com resultados é gravada")
	# trecho impeditivo: o aviso cita o trecho e o motivo, e aponta a exportação do traçado
	_calc_unica(35.0, 20.0, 150.0)
	var e2: Dictionary = m.exportar_planta(T.tmp("fase8_bloq.dxf"))
	var mot := str(e2.get("motivo", ""))
	T.check(id, not bool(e2.get("ok", true)) and mot.contains("bloqueada") and mot.contains("T1: lâmina inicial y/D = 1,00"),
		"resultado não aprovado: o aviso cita o trecho e o motivo (\"%s\")" % mot.get_slice("\n", 0).left(170))
	T.check(id, mot.contains("Exporta traçado para DXF"), "o aviso indica a exportação do traçado sem resultados")
	T.check(id, not FileAccess.file_exists(T.tmp("fase8_bloq.dxf")), "EVAL-104 intacto: nada é gravado como planta final")
	# traçado sem resultados: sempre disponível (sem cálculo, desatualizado ou não aprovado)
	var tr: String = T.tmp("fase8_tracado.dxf")
	var e3: Dictionary = m.exportar_tracado(tr)
	var txt := FileAccess.get_file_as_string(tr)
	T.check(id, bool(e3["ok"]) and txt.contains("TRAÇADO SEM RESULTADOS") and txt.contains("T1-100,00") and not txt.contains("ø"),
		"traçado com resultado não aprovado: DXF gravado com nomes e extensões, sem diâmetros e com a nota \"sem resultados\"")
	_abrir("rede_ramificada.esg")
	var e4: Dictionary = m.exportar_tracado(T.tmp("fase8_tracado2.dxf"))
	T.check(id, bool(e4["ok"]) and not m.resultados_validos, "traçado sem nenhum cálculo: também exporta")
	var ids: Array = []
	for pm in m.menus.values():
		for k in pm.item_count:
			ids.append(pm.get_item_text(k))
	T.check(id, "Exporta traçado para DXF (sem resultados)…" in ids, "comando no menu Arquivos")


# ------------------------------------------------------------------ T8-07 (parcial)

func _t807() -> void:
	var id := "T8-07"
	var achou := ""
	m.dlg.abrir_dimensionamento()
	for ch in m.find_children("*", "CheckBox", true, false):
		if str(ch.text).begins_with("Numeração automática"):
			achou = str(ch.text)
	_fechar_janelas()
	if achou == "Numeração automática de PVs e trechos":
		T.skip(id, "rótulo \"%s\" OK (A5); numeração 1/1 a implementar (B2, aguarda Q7)" % achou)
	else:
		T.check(id, false, "rótulo da opção: \"%s\" (esperado \"Numeração automática de PVs e trechos\")" % achou)


# ------------------------------------------------------------------ T8-08

func _t808() -> void:
	var id := "T8-08"
	m._novo()
	var a := Net.novo_no(m.proj, Vector2(0, 0), 100.0, true, "TL")
	var b := Net.novo_no(m.proj, Vector2(45.32, 0), 99.0, true, "PV")
	var t := Net.novo_trecho(m.proj, m.db, int(a["id"]), int(b["id"]), "C1")
	m.on_changed("traçado")
	T.check(id, p.rotulo_trecho(t, null, Net.node_map(m.proj)) == "45,32 m", "sem cálculo, o rótulo do trecho é a extensão: \"%s\"" % p.rotulo_trecho(t, null, Net.node_map(m.proj)))
	b["e"] = 60.0
	m.on_changed("mover")
	T.check(id, p.rotulo_trecho(t, null, Net.node_map(m.proj)) == "60,00 m", "arrastar o nó atualiza: \"%s\"" % p.rotulo_trecho(t, null, Net.node_map(m.proj)))
	m.executar_calculo(false)
	var r = m.results.get("rows", {}).get(int(t["id"]))
	var txt: String = p.rotulo_trecho(t, r, Net.node_map(m.proj)) if r != null else ""
	T.check(id, txt.begins_with("ø") and txt.contains("I="), "depois de dimensionar: rótulo completo (\"%s\")" % txt)
