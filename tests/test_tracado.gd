extends SceneTree
## Fase 7 — traçado assistido e alertas de cálculo (tests/PHASE-7.md).
##   T7-01 raio de busca e interpolação na colocação do PV (sobre a curva: sem interpolar)
##   T7-02 osnap (magnetismo)        T7-03 orto (F9)
##   T7-04 alertas ao calcular: trecho isolado e terreno sem caimento
## (T7-05, regressão das fases 0–6, é calculado pelo runner.)
##
## Terreno de teste: curvas retas y = 10·k com cota 100 + k (cota exata = 100 + y/10),
## um ponto cotado em (200; 33) com 123,45 m (de propósito diferente das curvas) e duas ruas.

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")

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
	_t701()
	_t702()
	_t703()
	_t704()
	quit(T.fim())


# ------------------------------------------------------------------ utilidades

func _fechar_janelas() -> void:
	for ch in m.get_children():
		if ch is AcceptDialog and ch.visible:
			ch.hide()


func _terreno() -> void:
	_fechar_janelas()
	m._novo()
	m.proj["area"] = {"e0": -100.0, "n0": -100.0, "le": 500.0, "ln": 300.0, "grid": 50.0}
	var cs: Array = []
	for k in range(-5, 16):
		var y := 10.0 * k
		cs.append({"z": 100.0 + k, "pts": PackedVector2Array([Vector2(-100, y), Vector2(400, y)])})
	m.topo.set_curvas(cs)
	m.topo.set_pontos([Vector3(200.0, 33.0, 123.45), Vector3(150.0, -33.0, 111.11)])
	m.topo.ruas = [PackedVector2Array([Vector2(250, -50), Vector2(250, 150)]), PackedVector2Array([Vector2(250, 150), Vector2(350, 150)])]
	m.proj["topo"] = m.topo.to_dict()
	m.opts.merge({"cota_modo": "int", "raio": 100.0, "precisao": 3, "osnap": true, "orto": false, "rastro": true,
			"topo_desenho": 0, "pontos_desenho": true, "ruas_desenho": true}, true)
	m.atualizar_modos()
	p.scale_px = 4.0 # 12 px de captura = 3 m
	p.center = Vector2(150, 50)
	p.limpar_selecao()


func _s(w: Vector2) -> Vector2:
	return p.w2s(w)


func _mover(s: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = s
	p._gui_input(mv)


func _botao(botao: int, s: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = botao
	ev.position = s
	ev.pressed = pressed
	p._gui_input(ev)


func _clique(botao: int, s: Vector2) -> void:
	_mover(s)
	_botao(botao, s, true)
	_botao(botao, s, false)


func _arrastar(de: Vector2, para: Vector2) -> void:
	_mover(de)
	_botao(MOUSE_BUTTON_LEFT, de, true)
	for k in 4:
		_mover(de.lerp(para, (k + 1) / 4.0))
	_botao(MOUSE_BUTTON_LEFT, para, false)


func _ultimo_no() -> Dictionary:
	var best: Dictionary = {}
	for n in m.proj["nodes"]:
		if best.is_empty() or int(n["id"]) > int(best["id"]):
			best = n
	return best


func _alerta_visivel() -> String:
	for ch in m.get_children():
		if ch is AcceptDialog and not ch is ConfirmationDialog and ch.visible and ch.dialog_text != "":
			return ch.dialog_text
	return ""


# ------------------------------------------------------------------ T7-01

func _t701() -> void:
	var id := "T7-01"
	_terreno()
	m.opts["osnap"] = false
	T.dado(id, "entrada", "curvas y = 10k com cota 100 + k; raio de busca 100 m; osnap desligado")
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(0, 25)))
	var n0 := _ultimo_no()
	T.check(id, p.tracing and Lib.aprox(float(n0["ct"]), 102.5, 1e-6), "1º PV (fora das curvas) interpolado: %.3f m (esperado 102,500)" % float(n0["ct"]))
	_mover(_s(Vector2(40, 25)))
	var pv: Dictionary = p.previa
	T.check(id, not pv.is_empty() and Lib.aprox(float(pv.get("raio", 0.0)), 100.0, 1e-9), "durante o traçado, o raio de busca acompanha o cursor (%s m)" % str(pv.get("raio", "—")))
	T.check(id, bool(pv.get("ok", false)) and Lib.aprox(float(pv.get("z", 0.0)), 102.5, 1e-6) and not bool(pv.get("sobre_curva", true))
		and pv.get("raios", []).size() > 0 and pv.get("par", []).size() == 2,
		"prévia: Z %.3f m interpolado, %d retas e o par de maior declive" % [float(pv.get("z", NAN)), pv.get("raios", []).size()])
	T.check(id, m.coord_labels["z"].text.contains("102,50"), "barra de status mostra a cota que o PV vai receber (\"%s\")" % m.coord_labels["z"].text)
	var z_previa := float(pv.get("z", NAN))
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(40, 25)))
	T.check(id, Lib.aprox(float(_ultimo_no()["ct"]), z_previa, 1e-6), "o PV colocado recebe exatamente a cota da prévia")
	_mover(_s(Vector2(80, 30)))
	pv = p.previa
	T.check(id, bool(pv.get("sobre_curva", false)) and pv.get("raios", [1]).is_empty() and Lib.aprox(float(pv.get("z", 0.0)), 103.0, 1e-9),
		"sobre a curva de 103 m: cota da curva, sem interpolar (sem retas)")
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(80, 30)))
	T.check(id, Lib.aprox(float(_ultimo_no()["ct"]), 103.0, 1e-9), "PV sobre a curva fica com 103,000 m")
	var r_perto: Dictionary = m.topo.cota_curvas(Vector2(120, 30.03), 100.0, 24)
	var r_longe: Dictionary = m.topo.cota_curvas(Vector2(120, 30.5), 100.0, 24)
	T.check(id, bool(r_perto["sobre_curva"]) and not bool(r_longe["sobre_curva"]) and Lib.aprox(float(r_longe["z"]), 103.05, 1e-6),
		"tolerância de %.2f m: a 3 cm é a curva; a 50 cm interpola (%.3f m)" % [m.topo.TOL_CURVA, float(r_longe["z"])])
	m.opts["raio"] = 3.0
	_mover(_s(Vector2(160, 25)))
	pv = p.previa
	T.check(id, not bool(pv.get("ok", true)) and Lib.aprox(float(pv.get("raio", 0.0)), 3.0, 1e-9), "com raio de 3 m e curvas a 5 m: prévia avisa que não há cota no raio")
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(160, 25)))
	T.check(id, not bool(_ultimo_no()["ct_ok"]), "o PV fica sem cota confirmada (X vermelho)")
	m.opts["raio"] = 100.0
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(200, 80)))
	_mover(_s(Vector2(210, 85)))
	T.check(id, not p.tracing and p.previa.is_empty(), "fora do traçado, o raio não é mostrado")


# ------------------------------------------------------------------ T7-02

func _t702() -> void:
	var id := "T7-02"
	_terreno()
	T.dado(id, "entrada", "osnap ligado, captura de %d px (3 m na escala do teste)" % int(p.OSNAP_PX))
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(0, 25)))
	var a := _ultimo_no()
	_mover(_s(Vector2(40, 28)))
	T.check(id, str(p.snap.get("tipo", "")) == "curva" and p.cursor_w.is_equal_approx(Vector2(40, 30)),
		"a 2 m da curva, o cursor gruda nela (%s em %s)" % [p.snap.get("rotulo", "sem alvo"), str(p.cursor_w)])
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(40, 28)))
	var b := _ultimo_no()
	T.check(id, Net.pos(b).is_equal_approx(Vector2(40, 30)) and Lib.aprox(float(b["ct"]), 103.0, 1e-9), "PV colocado exatamente sobre a curva, com a cota dela (103 m)")
	_mover(_s(Vector2(201.5, 33.5)))
	T.check(id, str(p.snap.get("tipo", "")) == "pc" and str(p.snap.get("rotulo", "")).contains("123,45"), "perto do ponto cotado: marcador e rótulo \"%s\"" % p.snap.get("rotulo", ""))
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(201.5, 33.5)))
	var c := _ultimo_no()
	T.check(id, Net.pos(c).is_equal_approx(Vector2(200, 33)) and Lib.aprox(float(c["ct"]), 123.45, 1e-9),
		"PV no ponto cotado: coordenadas e cota do ponto (%.2f m, não interpolada)" % float(c["ct"]))
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(210, 60)))
	# prioridade: PV antes da curva (B está sobre a curva de 103 m)
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(60, -20)))
	_mover(_s(Vector2(41.5, 30.5)))
	T.check(id, str(p.snap.get("tipo", "")) == "no" and int(p.snap.get("nid", -1)) == int(b["id"]), "PV tem prioridade sobre a curva sob o cursor")
	T.check(id, p.previa.is_empty(), "sobre um PV existente não há prévia de cota (o clique liga o trecho, não cria PV)")
	var t0: int = m.proj["trechos"].size()
	var s_b := _s(Net.pos(b)) + Vector2(10.5, 0)
	T.check(id, p.hit_no(s_b) < 0, "pré-condição: a 10,5 px o clique comum não acharia o PV (limite 9 px)")
	_clique(MOUSE_BUTTON_LEFT, s_b)
	var novo: Dictionary = m.proj["trechos"][-1] if m.proj["trechos"].size() > t0 else {}
	T.check(id, not novo.is_empty() and int(novo["nf"]) == int(b["id"]), "o osnap liga o afluente ao PV capturado")
	# ruas
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(300, 100)))
	_mover(_s(Vector2(251.5, 148.5)))
	T.check(id, str(p.snap.get("tipo", "")) == "vertice" and p.cursor_w.is_equal_approx(Vector2(250, 150)), "vértice de rua tem prioridade sobre a curva no mesmo lugar")
	_mover(_s(Vector2(251, 75)))
	T.check(id, str(p.snap.get("tipo", "")) == "rua" and p.cursor_w.is_equal_approx(Vector2(250, 75)), "sobre a linha da rua: ponto mais próximo")
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(330, 60)))
	# desligar / ligar (F10)
	m._on_menu(39)
	_mover(_s(Vector2(201.5, 33.5)))
	var btn: Button = m.modo_btns["osnap"]
	T.check(id, not bool(m.opts["osnap"]) and p.snap.is_empty() and not btn.button_pressed, "F10 desliga o osnap (botão OSNAP solto, cursor livre)")
	m._on_menu(39)
	T.check(id, bool(m.opts["osnap"]) and btn.button_pressed, "F10 liga de novo")
	# arrastar um PV até o ponto cotado; ele não gruda em outro PV
	var alvo: Dictionary = Net.node_map(m.proj)[int(b["id"])]
	var outro: Dictionary = Net.node_map(m.proj)[int(a["id"])]
	var z_antes := float(outro["ct"])
	_arrastar(_s(Net.pos(outro)), _s(Net.pos(alvo)) + Vector2(4, 4))
	T.check(id, not Net.pos(outro).is_equal_approx(Net.pos(alvo)), "arrastando um PV, ele não gruda em outro PV")
	_arrastar(_s(Net.pos(outro)), _s(Vector2(151, -32)))
	T.check(id, Net.pos(outro).is_equal_approx(Vector2(150, -33)) and Lib.aprox(float(outro["ct"]), 111.11, 1e-9) and not is_equal_approx(z_antes, 111.11),
		"PV arrastado até o ponto cotado assume posição e cota dele")


# ------------------------------------------------------------------ T7-03

func _t703() -> void:
	var id := "T7-03"
	_terreno()
	m.opts["osnap"] = false
	m._on_menu(38)
	var btn: Button = m.modo_btns["orto"]
	T.check(id, bool(m.opts["orto"]) and btn.button_pressed and m.status_label.text.contains("ORTO ligado"), "F9 liga o ORTO (botão e barra de status)")
	var po: PopupMenu = m.menus["Opções"]
	T.check(id, po.get_item_accelerator(po.get_item_index(38)) == KEY_F9 and po.get_item_accelerator(po.get_item_index(39)) == KEY_F10,
		"atalhos no menu Opções: F9 orto, F10 osnap")
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(0, 0)))
	_mover(_s(Vector2(40, 7)))
	T.check(id, p.cursor_w.is_equal_approx(Vector2(40, 0)) and p.cursor_orto, "cursor alinhado na horizontal (%s)" % str(p.cursor_w))
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(40, 7)))
	var n1 := _ultimo_no()
	T.check(id, Net.pos(n1).is_equal_approx(Vector2(40, 0)), "PV criado na horizontal: (40; 0)")
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(45, 37)))
	var n2 := _ultimo_no()
	T.check(id, Net.pos(n2).is_equal_approx(Vector2(40, 37)), "PV seguinte na vertical: (40; 37)")
	m.opts["osnap"] = true
	_mover(_s(Vector2(201.5, 34)))
	T.check(id, str(p.snap.get("tipo", "")) == "pc" and p.cursor_w.is_equal_approx(Vector2(200, 33)), "o osnap tem prioridade sobre o orto")
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(300, 120)))
	m.opts["osnap"] = false
	_arrastar(_s(Net.pos(n2)), _s(Vector2(62, 41)))
	T.check(id, Net.pos(Net.node_map(m.proj)[int(n2["id"])]).is_equal_approx(Vector2(62, 37)), "arrasto com orto: o PV anda só na horizontal")
	m._on_menu(38)
	T.check(id, not bool(m.opts["orto"]) and not btn.button_pressed, "F9 desliga o ORTO")
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(0, 100)))
	_clique(MOUSE_BUTTON_LEFT, _s(Vector2(33, 113)))
	T.check(id, Net.pos(_ultimo_no()).is_equal_approx(Vector2(33, 113)), "sem orto, traçado livre")
	_clique(MOUSE_BUTTON_RIGHT, _s(Vector2(300, 120)))
	m.opts["osnap"] = true


# ------------------------------------------------------------------ T7-04

func _t704() -> void:
	var id := "T7-04"
	_fechar_janelas()
	T.carregar(m, "rede_ramificada.esg")
	m.opts["grava_res"] = false
	var r0: Dictionary = m.executar_calculo(false)
	var iso0 := 0
	for a in r0.get("alertas", []):
		if str(a["tipo"]) == "isolado":
			iso0 += 1
	T.check(id, iso0 == 0, "rede conectada: nenhum alerta de trecho isolado")
	var status0 := {}
	for r in r0["rows"].values():
		status0[str(r["nome"])] = int(r["status"])
	# trecho isolado E→F, com terreno subindo
	var e := Net.novo_no(m.proj, Vector2(300, 100), 99.0, true, "TL")
	var f := Net.novo_no(m.proj, Vector2(350, 100), 99.5, true, "PV")
	var t := Net.novo_trecho(m.proj, m.db, int(e["id"]), int(f["id"]), "C9")
	m.proj["params"]["num_auto"] = false
	m.on_changed("traçado")
	var r: Dictionary = m.executar_calculo(false)
	T.dado(id, "entrada", "rede_ramificada.esg + trecho %s solto (CT 99,0 → 99,5)" % t["nome"])
	var iso: Array = []
	var sc: Array = []
	for a in r.get("alertas", []):
		if str(a["tipo"]) == "isolado":
			iso.append(a)
		else:
			sc.append_array(a["trechos"])
	T.check(id, bool(r["ok"]) and iso.size() == 1 and iso[0]["trechos"] == [str(t["nome"])] and str(iso[0]["texto"]).contains("sem deságue"),
		"alerta de trecho isolado, sem deságue na rede principal (%s)" % (iso[0]["texto"].left(90) if not iso.is_empty() else "nenhum"))
	T.check(id, sc.has(str(t["nome"])), "alerta de terreno sem caimento no trecho %s (jusante 99,5 > montante 99,0)" % t["nome"])
	var sc_esperado: Array = []
	var nm := Net.node_map(m.proj)
	for tr in m.proj["trechos"]:
		if float(nm[int(tr["nf"])]["ct"]) >= float(nm[int(tr["ni"])]["ct"]):
			sc_esperado.append(str(tr["nome"]))
	sc.sort()
	sc_esperado.sort()
	T.check(id, sc == sc_esperado, "sem caimento: exatamente os trechos com CT jusante ≥ CT montante (%s)" % ", ".join(PackedStringArray(sc)))
	var mudou := false
	for rr in r["rows"].values():
		if status0.has(str(rr["nome"])) and int(rr["status"]) != int(status0[str(rr["nome"])]):
			mudou = true
	var imped := false
	for rr in r["rows"].values():
		imped = imped or int(rr["status"]) >= 2
	T.check(id, not mudou and bool(r["aprovado"]) == (bool(r["ok"]) and not imped),
		"os alertas são advertências: não mudam o status dos trechos nem bloqueiam o cálculo")
	var obs_hidr := 0
	for o in r["obs"]:
		if not str(o[1]).begins_with("Alerta:"):
			obs_hidr += 1
	var luz_esperada := "vermelha" if (not bool(r["ok"]) or imped) else ("amarela" if obs_hidr > 0 else "verde")
	T.check(id, str(r["luz"]) == luz_esperada, "a luz reflete só a hidráulica (%s); os alertas ficam à parte" % r["luz"])
	var obs := ""
	for o in m._rows_obs():
		obs += str(o.get("obs", "")) + " | "
	T.check(id, obs.contains("Alerta: Trecho(s) isolado(s)") and obs.contains("terreno sem caimento"), "alertas registrados na Planilha de Observações")
	# pelo diálogo de dimensionamento (Ctrl+D › Inicia): janela de alerta
	m.ultimo_alerta = ""
	m.dlg.abrir_dimensionamento()
	var dd: AcceptDialog = null
	for ch in m.get_children():
		if ch is AcceptDialog and ch.visible and ch.title == "Dados Gerais para o Cálculo":
			dd = ch
	if dd != null:
		dd.custom_action.emit("inicia")
	var al := _alerta_visivel()
	T.check(id, dd != null and al.contains("TRECHOS ISOLADOS") and al.contains("SEM CAIMENTO") and m.ultimo_alerta == al,
		"ao calcular (Ctrl+D › Inicia), aparece a janela de alerta com os dois casos")
	_fechar_janelas()
	m._do_action("exemplo")
	var iso_ex := 0
	for a in m.results.get("alertas", []):
		if str(a["tipo"]) == "isolado":
			iso_ex += 1
	T.check(id, iso_ex == 0, "rede de exemplo (uma só saída): sem alerta de isolado")
