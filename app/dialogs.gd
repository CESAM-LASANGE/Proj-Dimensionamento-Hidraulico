extends RefCounted
## Janelas de diálogo do DimEsgoto, seguindo as telas descritas no manual do CEsg.

const Net = preload("res://net.gd")
const Db = preload("res://db.gd")
const Calc = preload("res://calc.gd")
const GridTable = preload("res://grid_table.gd")
const ProfileView = preload("res://profile_view.gd")
const Report = preload("res://report.gd")

var main


func _init(m) -> void:
	main = m


# ------------------------------------------------------------------ utilidades de formulário

func _dlg(titulo: String, tam: Vector2i, ok := "OK", cancel := true) -> AcceptDialog:
	var d := AcceptDialog.new()
	d.title = titulo
	d.ok_button_text = ok
	d.min_size = tam
	d.wrap_controls = true
	if cancel:
		d.add_cancel_button("Cancela")
	d.visibility_changed.connect(func():
		if not d.visible:
			d.queue_free())
	main.add_child(d)
	if main.registro:
		main.registro.acao("Janela: " + titulo)
	return d


func _show(d: AcceptDialog) -> void:
	d.popup_centered()


func _vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _grid(cols := 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 6)
	return g


func _grupo(titulo: String) -> Array:
	var pc := PanelContainer.new()
	var v := _vbox(6)
	pc.add_child(v)
	var l := Label.new()
	l.text = titulo
	l.add_theme_color_override("font_color", main.pal["accent"])
	v.add_child(l)
	v.add_child(HSeparator.new())
	return [pc, v]


func _lbl(t: String, dica := "") -> Label:
	var l := Label.new()
	l.text = t
	l.tooltip_text = dica
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _num(v, dec: int, w := 110) -> LineEdit:
	var le := LineEdit.new()
	le.text = main.fmt(v, dec)
	le.custom_minimum_size = Vector2(w, 0)
	le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	le.select_all_on_focus = true
	return le


func _txt(v: String, w := 220) -> LineEdit:
	var le := LineEdit.new()
	le.text = v
	le.custom_minimum_size = Vector2(w, 0)
	return le


func _ro(v: String, w := 110) -> LineEdit:
	var le := LineEdit.new()
	le.text = v
	le.editable = false
	le.custom_minimum_size = Vector2(w, 0)
	le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return le


func _opt(itens: Array, atual: String, w := 220) -> OptionButton:
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(w, 0)
	for i in itens.size():
		ob.add_item(str(itens[i]), i)
	var k := itens.find(atual)
	if k >= 0:
		ob.select(k)
	elif itens.size() > 0:
		ob.select(0)
	ob.fit_to_longest_item = false
	return ob


func _opt_txt(ob: OptionButton) -> String:
	return ob.get_item_text(ob.selected) if ob.selected >= 0 else ""


func _chk(t: String, v: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = t
	c.button_pressed = v
	return c


func _radios(itens: Array, atual: int, vertical := true) -> Array:
	var box: BoxContainer = _vbox(2) if vertical else _hbox(14)
	var grp := ButtonGroup.new()
	var btns: Array = []
	for i in itens.size():
		var c := CheckBox.new()
		c.text = str(itens[i])
		c.button_group = grp
		c.button_pressed = i == atual
		box.add_child(c)
		btns.append(c)
	return [box, btns]


func _radio_val(btns: Array) -> int:
	for i in btns.size():
		if btns[i].button_pressed:
			return i
	return 0


func _n(le: LineEdit) -> float:
	return main.num(le.text)


func _linha(g: GridContainer, rot: String, w: Control, dica := "") -> void:
	g.add_child(_lbl(rot, dica))
	w.tooltip_text = dica
	g.add_child(w)


func _tipos_no() -> Array:
	var out: Array = []
	for r in main.db["pvs"]:
		out.append("%s-%s" % [r["sigla"], r["nome"]])
	return out


# ------------------------------------------------------------------ mensagens

func mensagem(titulo: String, texto: String) -> void:
	var d := _dlg(titulo, Vector2i(420, 120), "OK", false)
	# mensagens podem surgir de dentro de outra janela (ex.: avisos de importação): não exclusivas
	d.exclusive = false
	d.dialog_text = texto
	_show(d)


func texto_longo(titulo: String, texto: String, nome_arquivo := "listagem.txt") -> void:
	var d := _dlg(titulo, Vector2i(900, 560), "Fecha", false)
	d.exclusive = false
	var v := _vbox()
	d.add_child(v)
	var h := _hbox()
	v.add_child(h)
	var te := TextEdit.new()
	var b1 := Button.new()
	b1.text = "Copiar"
	b1.pressed.connect(func():
		DisplayServer.clipboard_set(texto)
		main.set_status("Texto copiado."))
	h.add_child(b1)
	var b2 := Button.new()
	b2.text = "Salvar como texto…"
	b2.pressed.connect(func(): main.pedir_arquivo("salvar", ["*.txt ; Texto"], nome_arquivo,
		func(p): main.gravar_texto(p, texto)))
	h.add_child(b2)
	te.text = texto
	te.editable = false
	te.custom_minimum_size = Vector2(860, 480)
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	te.add_theme_font_override("font", main.fonte_mono())
	te.add_theme_font_size_override("font_size", 13)
	v.add_child(te)
	_show(d)


func prompt(titulo: String, rotulo: String, valor: String, cb: Callable) -> void:
	var d := _dlg(titulo, Vector2i(420, 110))
	var v := _vbox()
	d.add_child(v)
	v.add_child(_lbl(rotulo))
	var le := _txt(valor, 380)
	v.add_child(le)
	d.register_text_enter(le)
	d.confirmed.connect(func(): cb.call(le.text.strip_edges()))
	_show(d)
	le.grab_focus.call_deferred()
	le.select_all.call_deferred()


# ------------------------------------------------------------------ nó (manual 2.1)

func abrir_no(nid: int) -> void:
	var n: Dictionary = Net.node_map(main.proj).get(nid, {})
	if n.is_empty():
		return
	var d := _dlg("Definição do Nó", Vector2i(560, 400))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(540, 360)
	d.add_child(tabs)
	var pg := _vbox(10)
	pg.name = "Dados do Nó"
	tabs.add_child(pg)
	var g := _grid()
	pg.add_child(g)
	var nome := _txt(str(n["nome"]), 260)
	_linha(g, "Nome:", nome, "Nome exibido na área de trabalho (até 40 caracteres).")
	nome.max_length = 40
	var qf := _num(n["qp_f"], 4)
	_linha(g, "Vazão pontual - Fim de plano (l/s):", qf, "Vazão concentrada de rede existente, elevatória ou grande contribuinte.")
	var qi := _num(n["qp_i"], 4)
	_linha(g, "Vazão pontual - Início de plano (l/s):", qi)
	var tipos := _tipos_no()
	var atual := ""
	for t in tipos:
		if str(t).begins_with(str(n["tipo"]) + "-"):
			atual = t
	var tipo := _opt(tipos, atual, 260)
	_linha(g, "Tipo do nó:", tipo)
	var h := _hbox(14)
	pg.add_child(h)
	var gs := _grupo("Situação")
	h.add_child(gs[0])
	var mini := Control.new()
	mini.custom_minimum_size = Vector2(170, 130)
	mini.draw.connect(func(): _mini_situacao(mini, nid))
	gs[1].add_child(mini)
	var gt := _grupo("Dados Topográficos")
	gt[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gt[0])
	var g2 := _grid()
	gt[1].add_child(g2)
	var nn := _num(n["n"], 2, 130)
	_linha(g2, "Norte (m):", nn, "Coordenadas planas (arbitrárias ou UTM). As extensões dos trechos vêm delas.")
	var ee := _num(n["e"], 2, 130)
	_linha(g2, "Este (m):", ee)
	var ct := _num(n["ct"], 3, 130)
	_linha(g2, "Cota do terreno (m):", ct)
	var ct_ok := {"v": bool(n.get("ct_ok", true)), "mudou": false}
	ct.text_changed.connect(func(_t): ct_ok["mudou"] = true)
	var calc := OptionButton.new()
	calc.add_item("Calcular…", 0)
	calc.add_item("Interpola nas Curvas de Nível", 1)
	calc.add_item("Interpola nos Pontos Cotados", 2)
	calc.add_item("Interp. nas C. Nível + P. Cotados", 3)
	calc.disabled = main.topo.vazio()
	calc.set_item_disabled(1, not main.topo.tem_curvas())
	calc.set_item_disabled(2, not main.topo.tem_pontos())
	calc.set_item_disabled(3, not (main.topo.tem_curvas() and main.topo.tem_pontos()))
	calc.tooltip_text = "Habilitado após a leitura de uma base topográfica (curvas de nível ou pontos cotados)."
	calc.item_selected.connect(func(ix):
		if ix == 0:
			return
		var w := Vector2(_n(ee), _n(nn))
		var r: Dictionary = main.cota_criterio(w, ix)
		if bool(r["ok"]):
			ct.text = main.fmt(r["z"], 3)
			ct_ok["mudou"] = true
			main.set_status("Cota calculada: %s m." % main.fmt(r["z"], 3))
		else:
			main.set_status("Não foi possível calcular a cota neste ponto (aumente o raio de busca).")
		calc.select(0))
	gt[1].add_child(calc)
	# resultados
	var pr := _vbox()
	pr.name = "Resultados"
	tabs.add_child(pr)
	var rt := Label.new()
	rt.add_theme_font_override("font", main.fonte_mono())
	pr.add_child(rt)
	var nr = main.results.get("nodes", {}).get(nid) if main.resultados_validos else null
	if nr == null:
		rt.text = "Resultados disponíveis após o dimensionamento (Ctrl+D)."
	else:
		var s := "Tipo adotado no cálculo: %s\nProfundidade do poço: %s m\n" % [str(Db.pv(main.db, str(nr["tipo"]))["nome"]), main.fmt(nr["prof"], 3)]
		if float(nr["queda"]) > 0.001:
			s += "Desnível (degrau) no nó: %s m%s\n" % [main.fmt(nr["queda"], 3), "  → tubo de queda" if bool(nr["tq"]) else ""]
		for c in nr["conexoes"]:
			s += "\nTrecho: %s\n  Diâmetro (mm) ............ %d\n  Recobrimento (m) ......... %s\n  Cota do coletor (m) ...... %s\n  Profundidade do coletor .. %s\n" % [
				str(c["trecho"]), int(c["d"]), main.fmt(c["rec"], 3), main.fmt(c["cc"], 3), main.fmt(c["prof"], 3)]
		rt.text = s
		if not main.resultados_atuais:
			rt.text += "\n(Resultados desatualizados: dimensione novamente.)"
	d.confirmed.connect(func():
		n["nome"] = nome.text.strip_edges() if nome.text.strip_edges() != "" else str(n["nome"])
		n["qp_f"] = maxf(_n(qf), 0.0)
		n["qp_i"] = maxf(_n(qi), 0.0)
		n["tipo"] = _opt_txt(tipo).split("-")[0]
		n["n"] = _n(nn)
		n["e"] = _n(ee)
		if ct_ok["mudou"]:
			n["ct"] = _n(ct)
			n["ct_ok"] = true
		main.on_changed("no"))
	_show(d)


func _mini_situacao(c: Control, nid: int) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color.WHITE)
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.6, 0.6, 0.6), false, 1.0)
	var nodes := Net.node_map(main.proj)
	var n0: Dictionary = nodes[nid]
	var p0 := Net.pos(n0)
	var raio := 10.0
	for t in main.proj["trechos"]:
		if int(t["ni"]) == nid or int(t["nf"]) == nid:
			var o: Dictionary = nodes[int(t["nf"]) if int(t["ni"]) == nid else int(t["ni"])]
			raio = maxf(raio, p0.distance_to(Net.pos(o)))
	var esc := (minf(c.size.x, c.size.y) / 2.0 - 8.0) / raio
	var ctr := c.size / 2.0
	var f := c.get_theme_default_font()
	for t in main.proj["trechos"]:
		if int(t["ni"]) == nid or int(t["nf"]) == nid:
			var o: Dictionary = nodes[int(t["nf"]) if int(t["ni"]) == nid else int(t["ni"])]
			var dv := (Net.pos(o) - p0) * esc
			var q := ctr + Vector2(dv.x, -dv.y)
			c.draw_line(ctr, q, Color(0.15, 0.3, 0.8), 1.5)
			c.draw_string(f, (ctr + q) / 2.0 + Vector2(3, -3), str(t["nome"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)
	c.draw_circle(ctr, 5, Color.WHITE)
	c.draw_arc(ctr, 5, 0, TAU, 16, Color(0.15, 0.3, 0.8), 1.5)
	c.draw_string(f, ctr + Vector2(6, -6), str(n0["nome"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.1, 0.1))


# ------------------------------------------------------------------ trecho (manual 2.2)

func abrir_trecho(tid: int) -> void:
	var t: Dictionary = Net.trecho_map(main.proj).get(tid, {})
	if t.is_empty():
		return
	var nodes := Net.node_map(main.proj)
	var a: Dictionary = nodes[int(t["ni"])]
	var b: Dictionary = nodes[int(t["nf"])]
	var r = main.results.get("rows", {}).get(tid) if main.resultados_validos else null
	var d := _dlg("Dados do Trecho %s" % str(t["nome"]), Vector2i(600, 470))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(580, 430)
	d.add_child(tabs)
	# --- Dados geométricos
	var pg := _vbox(8)
	pg.name = "Dados Geométricos"
	tabs.add_child(pg)
	var g0 := _grid()
	pg.add_child(g0)
	var nome := _txt(str(t["nome"]), 260)
	_linha(g0, "Nome do trecho:", nome)
	g0.add_child(_lbl("Nó inicial / final:"))
	g0.add_child(_lbl("%s  →  %s" % [str(a["nome"]), str(b["nome"])]))
	pg.add_child(HSeparator.new())
	var g1 := _grid(3)
	pg.add_child(g1)
	var l_geo := Net.pos(a).distance_to(Net.pos(b))
	var ext := _num(Net.comprimento(nodes, t), 2)
	ext.editable = float(t.get("ext_fix", 0.0)) > 0.0
	var fx_ext := _chk("Fixa extensão", float(t.get("ext_fix", 0.0)) > 0.0)
	fx_ext.tooltip_text = "Desmarcado: a extensão vem das coordenadas dos nós. Marcado: usa o valor digitado (traçado esquemático)."
	fx_ext.toggled.connect(func(on):
		ext.editable = on
		if not on:
			ext.text = main.fmt(l_geo, 2))
	g1.add_child(_lbl("Extensão (m):"))
	g1.add_child(ext)
	g1.add_child(fx_ext)
	g1.add_child(_lbl("Cota do terreno - jusante (m):"))
	g1.add_child(_ro(main.fmt(b["ct"], 3)))
	g1.add_child(Control.new())
	g1.add_child(_lbl("Cota do terreno - montante (m):"))
	g1.add_child(_ro(main.fmt(a["ct"], 3)))
	g1.add_child(Control.new())
	g1.add_child(_lbl("Declividade do terreno (m/m):"))
	var lt := maxf(Net.comprimento(nodes, t), 0.01)
	g1.add_child(_ro(main.fmt(Calc.declividade(float(a["ct"]), float(b["ct"]), lt), 4)))
	g1.add_child(Control.new())
	pg.add_child(HSeparator.new())
	var g2 := _grid(3)
	pg.add_child(g2)
	var dd := _num(t["d"], 0)
	var fx_d := _chk("Fixa Diâmetro", bool(t["fixa_d"]))
	fx_d.tooltip_text = "Para verificação: o dimensionamento não altera o diâmetro informado."
	g2.add_child(_lbl("Diâmetro (mm):"))
	g2.add_child(dd)
	g2.add_child(fx_d)
	var ccm := _num(t["cc_m"], 3)
	var ccj := _num(t["cc_j"], 3)
	var fx_c := _chk("Fixa Cotas", bool(t["fixa_cotas"]))
	fx_c.tooltip_text = "O dimensionamento não altera as cotas do coletor informadas."
	var pm := _ro(main.fmt(Calc.profundidade(float(a["ct"]), float(t["cc_m"])), 3))
	var pj := _ro(main.fmt(Calc.profundidade(float(b["ct"]), float(t["cc_j"])), 3))
	var decl := _ro(main.fmt(Calc.declividade(float(t["cc_m"]), float(t["cc_j"]), lt), 4))
	var atualiza := func(_x):
		pm.text = main.fmt(Calc.profundidade(float(a["ct"]), _n(ccm)), 3)
		pj.text = main.fmt(Calc.profundidade(float(b["ct"]), _n(ccj)), 3)
		decl.text = main.fmt(Calc.declividade(_n(ccm), _n(ccj), _n(ext)), 4)
	ccm.text_changed.connect(atualiza)
	ccj.text_changed.connect(atualiza)
	g2.add_child(_lbl("Cota do coletor - montante (m):"))
	g2.add_child(ccm)
	g2.add_child(fx_c)
	g2.add_child(_lbl("Profundidade - montante (m):"))
	g2.add_child(pm)
	g2.add_child(Control.new())
	g2.add_child(_lbl("Cota do coletor - jusante (m):"))
	g2.add_child(ccj)
	g2.add_child(Control.new())
	g2.add_child(_lbl("Profundidade - jusante (m):"))
	g2.add_child(pj)
	g2.add_child(Control.new())
	g2.add_child(_lbl("Declividade do trecho (m/m):"))
	g2.add_child(decl)
	# --- Especificações
	var pe := _vbox(8)
	pe.name = "Especificações"
	tabs.add_child(pe)
	var gq := _grupo("Quantitativo")
	pe.add_child(gq[0])
	var g3 := _grid()
	gq[1].add_child(g3)
	var mat := _opt(Db.nomes(main.db, "materiais"), str(t["material"]), 280)
	_linha(g3, "Material do tubo:", mat)
	var esc := _opt(Db.nomes(main.db, "escoramentos"), str(t["escoramento"]), 280)
	_linha(g3, "Tipo de escoramento:", esc, "Definido automaticamente se 'Definição automática do escoramento' estiver marcada no dimensionamento.")
	var sup := _opt(Db.nomes(main.db, "pavimentos"), str(t["superficie"]), 280)
	_linha(g3, "Tipo de superfície do terreno:", sup)
	var at := _radios(["Sim", "Não"], 0 if bool(t["aterro"]) else 1, false)
	_linha(g3, "Aterro compactado:", at[0], "Sim: o reaterro é calculado com empolamento de 30%.")
	var gdp := _grupo("Dados de Projeto")
	pe.add_child(gdp[0])
	var g4 := _grid()
	gdp[1].add_child(g4)
	var rec := _num(t["recob"], 3)
	_linha(g4, "Recobrimento mínimo (m):", rec, "0 = usa o recobrimento geral da tela de dimensionamento.")
	var pmx := _num(t["pmax"], 3)
	_linha(g4, "Profundidade máxima (m):", pmx, "0 = usa a profundidade máxima geral.")
	var sit := _opt(Db.nomes(main.db, "situacoes"), str(t["situacao"]), 280)
	_linha(g4, "Situação:", sit, "Define o layer do trecho na planta exportada em DXF.")
	var crit := _opt(Calc.CRITERIOS, str(t.get("crit", "Global")), 280)
	_linha(g4, "Critério de interpolação de cotas:", crit, "Global = critério escolhido na janela de dimensionamento.")
	# --- Resultados
	var prs := _vbox()
	prs.name = "Resultados"
	tabs.add_child(prs)
	var lr := Label.new()
	lr.add_theme_font_override("font", main.fonte_mono())
	prs.add_child(lr)
	if r == null:
		lr.text = "Resultados disponíveis após o dimensionamento (Ctrl+D)."
	else:
		var f := Callable(main, "fmt")
		var s := ""
		s += "Extensão (m): %28s\nDiâmetro (mm): %27d\nDeclividade (m/m): %23s\nMaterial: %s\n\n" % [f.call(r["L"], 2), int(r["d"]), f.call(r["i"], 4), str(r["material"])]
		s += "%-26s %12s %12s\n" % ["", "Montante", "Jusante"]
		s += "%-26s %12s %12s\n" % ["Cota do terreno (m)", f.call(r["ct_m"], 3), f.call(r["ct_j"], 3)]
		s += "%-26s %12s %12s\n" % ["Cota do coletor (m)", f.call(r["cc_m"], 3), f.call(r["cc_j"], 3)]
		s += "%-26s %12s %12s\n" % ["Prof. do coletor (m)", f.call(r["pc_m"], 3), f.call(r["pc_j"], 3)]
		s += "%-26s %12s %12s\n" % ["Recobrimento (m)", f.call(r["rec_m"], 3), f.call(r["rec_j"], 3)]
		s += "%-26s %12s %12s\n\n" % ["Prof. da vala (m)", f.call(r["pvala_m"], 3), f.call(r["pvala_j"], 3)]
		s += "%-26s %12s %12s\n" % ["", "In. Plano", "Fim Plano"]
		s += "%-26s %12s %12s\n" % ["Contribuição linear (l/s.km)", f.call(r["txi"], 3), f.call(r["txf"], 3)]
		s += "%-26s %12s %12s\n" % ["Contribuição no trecho (l/s)", f.call(r["ctr_i"], 3), f.call(r["ctr_f"], 3)]
		s += "%-26s %12s %12s\n" % ["Vazão pontual (l/s)", f.call(r["qp_i"], 3), f.call(r["qp_f"], 3)]
		s += "%-26s %12s %12s\n" % ["Vazão a montante (l/s)", f.call(r["qm_i"], 3), f.call(r["qm_f"], 3)]
		s += "%-26s %12s %12s\n" % ["Vazão a jusante (l/s)", f.call(r["qj_i"], 3), f.call(r["qj_f"], 3)]
		s += "%-26s %12s %12s\n" % ["Relação y/D", f.call(r["yd_i"], 2), f.call(r["yd_f"], 2)]
		s += "%-26s %12s %12s\n" % ["Velocidade (m/s)", f.call(r["v_i"], 2), f.call(r["v_f"], 2)]
		s += "%-26s %12s\n" % ["Arraste (Pa)", f.call(r["sigma"], 2)]
		s += "%-26s %12s %12s\n" % ["Vel. crít. aeração (m/s)", "", f.call(r["vc"], 2)]
		s += "%-26s %12s %12s\n" % ["Rugosidade (n ou k mm)", f.call(r["rug_i"], 4), f.call(r["rug_f"], 4)]
		s += "\nEscoramento: %s   •   Largura da vala: %s m" % [str(r["esc"]), f.call(r["larg"], 2)]
		if not r["obs"].is_empty():
			s += "\n\n• " + "\n• ".join(PackedStringArray(r["obs"]))
		if not main.resultados_atuais:
			s += "\n\n(Resultados desatualizados: dimensione novamente.)"
		lr.text = s
	d.confirmed.connect(func():
		t["nome"] = nome.text.strip_edges() if nome.text.strip_edges() != "" else str(t["nome"])
		t["ext_fix"] = maxf(_n(ext), 0.01) if fx_ext.button_pressed else 0.0
		t["d"] = maxf(_n(dd), 0.0)
		t["fixa_d"] = fx_d.button_pressed and t["d"] > 0.0
		t["cc_m"] = _n(ccm)
		t["cc_j"] = _n(ccj)
		t["fixa_cotas"] = fx_c.button_pressed
		t["material"] = _opt_txt(mat)
		t["escoramento"] = _opt_txt(esc)
		t["superficie"] = _opt_txt(sup)
		t["aterro"] = _radio_val(at[1]) == 0
		t["recob"] = maxf(_n(rec), 0.0)
		t["pmax"] = maxf(_n(pmx), 0.0)
		t["situacao"] = _opt_txt(sit)
		t["crit"] = _opt_txt(crit)
		main.on_changed("trecho"))
	_show(d)


# ------------------------------------------------------------------ dimensionamento (manual cap. 4)

func abrir_dimensionamento() -> void:
	var p: Dictionary = main.proj["params"]
	var d := _dlg("Dados Gerais para o Cálculo", Vector2i(760, 420), "OK")
	var v := _vbox(8)
	d.add_child(v)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(740, 300)
	v.add_child(tabs)
	var ajuda := Label.new()
	ajuda.add_theme_font_size_override("font_size", 12)
	var campos := {}
	var reg := func(chave: String, w: Control, texto: String):
		campos[chave] = w
		w.tooltip_text = texto
		w.focus_entered.connect(func(): ajuda.text = texto)
	# Dados de consumo
	var pc := _hbox(16)
	pc.name = "Dados de consumo"
	tabs.add_child(pc)
	var gi := _grupo("Início de Plano")
	gi[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_child(gi[0])
	var gfi := _grid()
	gi[1].add_child(gfi)
	var gf := _grupo("Fim de Plano")
	gf[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_child(gf[0])
	var gff := _grid()
	gf[1].add_child(gff)
	var defs_i := [["pop_ini", "População (hab):", 0, "População a ser servida no início do plano."],
		["qpc_ini", "Consumo efetivo per capta (l/hab/dia):", 1, "Consumo de água efetivo por habitante (descontadas as perdas) no início do plano."],
		["c_ini", "Coeficiente de retorno:", 2, "Relação entre a vazão de esgoto coletada e a de água abastecida."],
		["k2_ini", "K2:", 2, "Coeficiente da hora de maior consumo do dia de maior consumo."]]
	var defs_f := [["pop_fin", "População (hab):", 0, "População a ser servida no fim do plano."],
		["qpc_fin", "Consumo efetivo per capta (l/hab/dia):", 1, "Consumo per capta para o final do plano."],
		["c_fin", "Coeficiente de retorno:", 2, "Coeficiente de retorno no fim do plano."],
		["k1", "K1:", 2, "Coeficiente do dia de maior consumo."],
		["k2_fin", "K2:", 2, "Coeficiente da hora de maior consumo do dia de maior consumo."]]
	for df in defs_i:
		var le := _num(p[df[0]], df[2])
		gfi.add_child(_lbl(df[1]))
		gfi.add_child(le)
		reg.call(df[0], le, df[3])
	for df in defs_f:
		var le := _num(p[df[0]], df[2])
		gff.add_child(_lbl(df[1]))
		gff.add_child(le)
		reg.call(df[0], le, df[3])
	# Dados gerais
	var pgx := _vbox(8)
	pgx.name = "Dados Gerais"
	tabs.add_child(pgx)
	var gg := _grupo("Condições de Cálculo")
	pgx.add_child(gg[0])
	var g := _grid(4)
	gg[1].add_child(g)
	var defs_g := [
		["q_min", "Vazão Mínima (l/s):", 2, 1.0, "Descarga mínima de dimensionamento do condutor (NBR 9649: 1,5 l/s)."],
		["tensao_min", "Tensão Trativa Mínima (Pa):", 1, 1.0, "Mínimo para garantir a autolimpeza da rede, com a vazão inicial."],
		["d_min", "Diâmetro Mínimo (mm):", 0, 1.0, "Menor diâmetro a adotar, conforme a disponibilidade de materiais."],
		["v_max", "Velocidade Máxima (m/s):", 2, 1.0, "Admitida em função da resistência do material do coletor."],
		["infiltracao", "Taxa de Infiltração (l/s/km):", 2, 1.0, "Contribuição compulsória do lençol freático."],
		["degrau_min", "Alt. de Degrau Mínima (cm):", 0, 100.0, "Altura mínima de degrau adotada para reduzir a declividade do coletor."],
		["recob_min", "Recobrimento Mínimo (m):", 2, 1.0, "Recobrimento mínimo sobre a geratriz superior do tubo."],
		["degrau_max", "Alt. de Degrau Máxima (cm):", 0, 100.0, "Acima deste desnível no PV é necessário tubo de queda."],
		["prof_max", "Profundidade Máxima (m):", 2, 1.0, "Acima dela é gerada uma observação na planilha de observações."],
		["i_min_constr", "Declividade Mínima Construtiva (m/m):", 4, 1.0, "Menor declividade executável em obra; imposta só se a calculada for menor."],
		["dist_max_pv", "Distância Máx. entre PVs (m):", 1, 1.0, "Trechos mais longos geram aviso no traçado e observação no cálculo."]]
	var fatores := {}
	for df in defs_g:
		var le := _num(float(p[df[0]]) * float(df[3]), df[2], 100)
		g.add_child(_lbl(df[1]))
		g.add_child(le)
		reg.call(df[0], le, df[4])
		fatores[df[0]] = df[3]
	var numauto := _chk("Numeração automática de nós e trechos", bool(p["num_auto"]))
	reg.call("num_auto", numauto, "Renumera nós, trechos e coletores no padrão de redes de esgoto (coletor 1 = maior conjunto contíguo).")
	gg[1].add_child(numauto)
	# Critérios
	var pcr := _vbox(8)
	pcr.name = "Critérios de Cálculo"
	tabs.add_child(pcr)
	var hc := _hbox(16)
	pcr.add_child(hc)
	var gm := _grupo("Método de Cálculo")
	hc.add_child(gm[0])
	var rm := _radios(["Manning", "Fórmula Universal"], int(p["metodo"]), false)
	gm[1].add_child(rm[0])
	var ga := _grupo("Ajuste de rugosidade pela velocidade")
	ga[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_child(ga[0])
	var ra := _radios(["Inferior (otimista)", "Superior (pessimista)", "Utiliza o valor do banco de dados"], int(p["ajuste_rug"]))
	ga[1].add_child(ra[0])
	var gc := _grupo("Ajuste de Cotas Intermediárias")
	pcr.add_child(gc[0])
	var rc := _radios(["Utiliza somente as cotas de PV's", "Interpola nas curvas de nível", "Interpola nos pontos cotados"], int(p["cotas_interm"]))
	gc[1].add_child(rc[0])
	rc[1][1].disabled = not main.topo.tem_curvas()
	rc[1][2].disabled = not main.topo.tem_pontos()
	var hk := _hbox(24)
	gc[1].add_child(hk)
	var plast := _chk("Rede 100% Plástico", bool(p["rede_plastica"]))
	plast.tooltip_text = "Atribui automaticamente TIL radial de PVC aos PVs e calcula curvas, tampões e reduções."
	hk.add_child(plast)
	var escauto := _chk("Definição automática do escoramento", bool(p["escoramento_auto"]))
	escauto.tooltip_text = "Escolhe o escoramento pela profundidade da vala (faixas do banco de dados)."
	hk.add_child(escauto)
	# rodapé: arquivo de resultados, luzes e Inicia
	var rod := _hbox(10)
	v.add_child(rod)
	var arq := Label.new()
	arq.text = "Arquivo de Resultados: %s" % main.ultimo_res
	arq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arq.add_theme_color_override("font_color", main.pal["accent"])
	rod.add_child(arq)
	var luzes := Control.new()
	luzes.custom_minimum_size = Vector2(76, 24)
	var estado := {"luz": main.results.get("luz", "") if main.resultados_atuais else ""}
	luzes.draw.connect(func():
		var cores := {"vermelha": Color(0.9, 0.1, 0.1), "amarela": Color(0.98, 0.85, 0.1), "verde": Color(0.1, 0.75, 0.2)}
		var k := 0
		for nome in ["vermelha", "amarela", "verde"]:
			var on: bool = estado["luz"] == nome
			var ctr := Vector2(12 + k * 26, 12)
			luzes.draw_circle(ctr, 10, Color(0.75, 0.75, 0.75))
			luzes.draw_circle(ctr, 8, cores[nome] if on else cores[nome].darkened(0.65).lerp(Color(0.85, 0.85, 0.85), 0.5))
			k += 1)
	rod.add_child(luzes)
	v.add_child(ajuda)
	ajuda.text = "Preencha os dados e clique em Inicia para dimensionar a rede."
	var aplica := func():
		for k in campos.keys():
			var w = campos[k]
			if w is LineEdit:
				p[k] = main.num(w.text) / float(fatores.get(k, 1.0))
			elif w is CheckBox:
				p[k] = w.button_pressed
		for k in ["pop_ini", "pop_fin", "qpc_ini", "qpc_fin", "c_ini", "c_fin", "q_min", "d_min", "infiltracao", "recob_min",
				"prof_max", "tensao_min", "v_max", "degrau_min", "degrau_max", "i_min_constr", "dist_max_pv"]:
			p[k] = maxf(float(p[k]), 0.0)
		for k in ["k1", "k2_ini", "k2_fin"]:
			p[k] = maxf(float(p[k]), 1.0)
		p["metodo"] = _radio_val(rm[1])
		p["ajuste_rug"] = _radio_val(ra[1])
		p["cotas_interm"] = _radio_val(rc[1])
		p["rede_plastica"] = plast.button_pressed
		p["escoramento_auto"] = escauto.button_pressed
		main.marcar_alterado()
	d.add_button("Inicia", false, "inicia")
	d.custom_action.connect(func(acao):
		if acao != "inicia":
			return
		aplica.call()
		var res: Dictionary = main.executar_calculo()
		estado["luz"] = res.get("luz", "vermelha")
		luzes.queue_redraw()
		arq.text = "Arquivo de Resultados: %s" % main.ultimo_res
		var n_obs: int = res.get("obs", []).size()
		if str(estado["luz"]) == "verde":
			ajuda.text = "Dimensionamento concluído sem problemas."
		elif str(estado["luz"]) == "amarela":
			ajuda.text = "Dimensionamento concluído com %d observação(ões). Veja a Planilha de Observações (botão OBS)." % n_obs
		else:
			ajuda.text = "O cálculo não pôde ser concluído: %s" % " ".join(PackedStringArray(res.get("erros", ["verifique a rede."])))
		d.ok_button_text = "OK")
	d.confirmed.connect(func(): aplica.call())
	_show(d)


# ------------------------------------------------------------------ opções

func abrir_area() -> void:
	var a: Dictionary = main.proj["area"]
	var d := _dlg("Área de Trabalho", Vector2i(440, 240))
	var v := _vbox()
	d.add_child(v)
	var g := _grid()
	v.add_child(g)
	var ln := _num(a["ln"], 2, 140)
	_linha(g, "Compr. direção N (m):", ln, "Dimensão da área de trabalho na direção norte-sul.")
	var le := _num(a["le"], 2, 140)
	_linha(g, "Compr. direção E (m):", le, "Dimensão da área de trabalho na direção este-oeste.")
	var n0 := _num(a["n0"], 2, 140)
	_linha(g, "Coordenada da origem N (m):", n0, "Ponto de referência (canto inferior esquerdo); arbitrário ou UTM.")
	var e0 := _num(a["e0"], 2, 140)
	_linha(g, "Coordenada da origem E (m):", e0)
	var gr := _num(a["grid"], 2, 140)
	_linha(g, "Grid (m):", gr, "Espaçamento do grid de coordenadas.")
	var nota := _lbl("Medidas em metros")
	nota.add_theme_font_size_override("font_size", 12)
	v.add_child(nota)
	d.confirmed.connect(func():
		a["ln"] = maxf(_n(ln), 1.0)
		a["le"] = maxf(_n(le), 1.0)
		a["n0"] = _n(n0)
		a["e0"] = _n(e0)
		a["grid"] = maxf(_n(gr), 0.0)
		main.marcar_alterado()
		main.plan.sem_zoom())
	_show(d)


func abrir_tracado() -> void:
	var o: Dictionary = main.opts
	var d := _dlg("Traçado da Rede", Vector2i(380, 280))
	var v := _vbox()
	d.add_child(v)
	var c1 := _chk("Mostrar grid de coordenadas", bool(o.get("mostra_grid", true)))
	var c2 := _chk("Mostrar imagem de fundo", bool(o.get("mostra_imagem", true)))
	var c3 := _chk("Rótulos dos nós (nome e cota)", bool(o.get("rotulo_no", true)))
	var c4 := _chk("Rótulos dos trechos", bool(o.get("rotulo_trecho", true)))
	var c5 := _chk("Resultados na planta (ø, extensão, declividade)", bool(o.get("rotulo_resultado", true)))
	for c in [c1, c2, c3, c4, c5]:
		v.add_child(c)
	var g := _grid()
	v.add_child(g)
	var esp := _opt(["1", "2", "3", "4"], str(int(o.get("espessura", 2))), 80)
	_linha(g, "Espessura do traço:", esp)
	d.confirmed.connect(func():
		o["mostra_grid"] = c1.button_pressed
		o["mostra_imagem"] = c2.button_pressed
		o["rotulo_no"] = c3.button_pressed
		o["rotulo_trecho"] = c4.button_pressed
		o["rotulo_resultado"] = c5.button_pressed
		o["espessura"] = int(_opt_txt(esp))
		main.salvar_config()
		main.plan.redesenhar())
	_show(d)


func abrir_exibicao_dxf(aba := 0, ao_exportar := Callable()) -> void:
	var o: Dictionary = main.opts
	var d := _dlg("Exibição de DXF's", Vector2i(520, 300))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(500, 260)
	d.add_child(tabs)
	# topografia
	var pt := _vbox()
	pt.name = "Topografia"
	tabs.add_child(pt)
	var h1 := _hbox(16)
	pt.add_child(h1)
	var gd := _grupo("Desenho")
	h1.add_child(gd[0])
	var rd := _radios(["Desenho Normal", "Desenho Rápido", "Não desenha"], int(o.get("topo_desenho", 0)))
	gd[1].add_child(rd[0])
	var gt := _grupo("Texto")
	h1.add_child(gt[0])
	var ctx := _chk("Desenha", bool(o.get("topo_texto", false)))
	gt[1].add_child(ctx)
	var h2 := _hbox(16)
	pt.add_child(h2)
	var gl := _grupo("Legendas")
	h2.add_child(gl[0])
	var cleg := _chk("Desenha Legenda", bool(o.get("topo_legenda", true)))
	gl[1].add_child(cleg)
	var ints := [10.0, 5.0, 1.0]
	var rl := _radios(["10 em 10m", "5 em 5m", "1 em 1m"], maxi(ints.find(float(o.get("topo_leg_int", 5.0))), 0), false)
	gl[1].add_child(rl[0])
	var gco := _grupo("Cor")
	h2.add_child(gco[0])
	var gcc := _grid()
	gco[1].add_child(gcc)
	var cp := ColorPickerButton.new()
	cp.color = Color(str(o.get("cor_principal", "ee7340")))
	cp.custom_minimum_size = Vector2(50, 22)
	var cs := ColorPickerButton.new()
	cs.color = Color(str(o.get("cor_secundaria", "fad85a")))
	cs.custom_minimum_size = Vector2(50, 22)
	_linha(gcc, "Principal:", cp)
	_linha(gcc, "Secundária:", cs)
	# ruas
	var pr := _vbox()
	pr.name = "Ruas"
	tabs.add_child(pr)
	var crua := _chk("Desenha ruas", bool(o.get("ruas_desenho", true)))
	pr.add_child(crua)
	var gr := _grid()
	pr.add_child(gr)
	var corr := ColorPickerButton.new()
	corr.color = Color(str(o.get("cor_ruas", "339eb8")))
	corr.custom_minimum_size = Vector2(50, 22)
	_linha(gr, "Cor:", corr)
	# pontos
	var pp := _vbox()
	pp.name = "Ptos. Cotados"
	tabs.add_child(pp)
	var cpd := _chk("Desenha pontos cotados", bool(o.get("pontos_desenho", true)))
	var cpv := _chk("Mostra o valor das cotas", bool(o.get("pontos_valor", true)))
	pp.add_child(cpd)
	pp.add_child(cpv)
	var gp := _grid()
	pp.add_child(gp)
	var corp := ColorPickerButton.new()
	corp.color = Color(str(o.get("cor_pontos", "2673bf")))
	corp.custom_minimum_size = Vector2(50, 22)
	_linha(gp, "Cor:", corp)
	# exporta
	var pe := _hbox(20)
	pe.name = "Exporta"
	tabs.add_child(pe)
	var ge := _grupo("Exportar")
	pe.add_child(ge[0])
	var exps := [["exp_rede", "Rede"], ["exp_ruas", "Ruas"], ["exp_topo", "Topografia"], ["exp_malha", "Malha"],
		["exp_margem", "Margem"], ["exp_pontos", "Pontos Cotados"]]
	var cex := {}
	for e in exps:
		var c := _chk(e[1], bool(o.get(e[0], true)))
		ge[1].add_child(c)
		cex[e[0]] = c
	var ges := _grupo("Escala")
	pe.add_child(ges[0])
	var hs := _hbox(4)
	ges[1].add_child(hs)
	hs.add_child(_lbl("1:"))
	var escala := _num(o.get("exp_escala", 1000.0), 0, 100)
	hs.add_child(escala)
	tabs.current_tab = aba
	if ao_exportar.is_valid():
		for k in 3:
			tabs.set_tab_disabled(k, true)
		d.ok_button_text = "OK"
	d.confirmed.connect(func():
		o["topo_desenho"] = _radio_val(rd[1])
		o["topo_texto"] = ctx.button_pressed
		o["topo_legenda"] = cleg.button_pressed
		o["topo_leg_int"] = ints[_radio_val(rl[1])]
		o["cor_principal"] = cp.color.to_html(false)
		o["cor_secundaria"] = cs.color.to_html(false)
		o["ruas_desenho"] = crua.button_pressed
		o["cor_ruas"] = corr.color.to_html(false)
		o["pontos_desenho"] = cpd.button_pressed
		o["pontos_valor"] = cpv.button_pressed
		o["cor_pontos"] = corp.color.to_html(false)
		for k in cex.keys():
			o[k] = cex[k].button_pressed
		o["exp_escala"] = maxf(_n(escala), 1.0)
		main.salvar_config()
		main.plan.redesenhar()
		if ao_exportar.is_valid():
			ao_exportar.call())
	_show(d)


func abrir_cotas() -> void:
	var o: Dictionary = main.opts
	var d := _dlg("Cálculo Automático de Cotas", Vector2i(470, 330))
	var v := _vbox()
	d.add_child(v)
	var gm := _grupo("Modo do Traçado")
	v.add_child(gm[0])
	var modos := ["none", "cc", "prx", "int"]
	var rm := _radios(["Sem cálculo automático de cotas", "Fixar cotas e coordenadas", "Fixar cota do ponto mais próximo",
		"Interpolação de cotas nas curvas de nível"], maxi(modos.find(str(o.get("cota_modo", "int"))), 0))
	gm[1].add_child(rm[0])
	rm[1][1].disabled = not main.topo.tem_pontos()
	rm[1][2].disabled = not main.topo.tem_pontos()
	rm[1][3].disabled = not main.topo.tem_curvas()
	var gp := _grupo("Parâmetros para interpolação nas curvas de nível")
	v.add_child(gp[0])
	var g := _grid()
	gp[1].add_child(g)
	var raio := _num(o.get("raio", 100.0), 2)
	_linha(g, "Raio de Busca (m):", raio, "Área de influência considerada no cálculo da cota.")
	var prec := HSlider.new()
	prec.min_value = 1
	prec.max_value = 10
	prec.step = 1
	prec.value = int(o.get("precisao", 3))
	prec.custom_minimum_size = Vector2(200, 0)
	_linha(g, "Precisão de Busca (mín. → máx.):", prec, "Quantidade de retas de maior declive pesquisadas (mais precisa = mais lenta).")
	var rastro := _chk("Rastro", bool(o.get("rastro", true)))
	rastro.tooltip_text = "Mostra a área de influência e as retas usadas no cálculo da cota."
	gp[1].add_child(rastro)
	d.confirmed.connect(func():
		o["cota_modo"] = modos[_radio_val(rm[1])]
		o["raio"] = maxf(_n(raio), 1.0)
		o["precisao"] = int(prec.value)
		o["rastro"] = rastro.button_pressed
		main.salvar_config()
		main.atualizar_modos())
	_show(d)


func abrir_recalcular() -> void:
	var o: Dictionary = main.opts
	var d := _dlg("Recalcular Cotas", Vector2i(560, 330))
	var v := _vbox()
	d.add_child(v)
	var h := _hbox(16)
	v.add_child(h)
	var gr := _grupo("Recalcular")
	h.add_child(gr[0])
	var rr := _radios(["Todos os pontos", "Somente pontos sem cotas confirmadas"], 1)
	gr[1].add_child(rr[0])
	var gc := _grupo("Critérios")
	gc[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gc[0])
	var tc: bool = main.topo.tem_curvas()
	var tp: bool = main.topo.tem_pontos()
	var rc := _radios(["Curvas de Nível", "Pontos Cotados", "Curvas de Nível e Pontos Cotados"], 0 if tc else 1)
	gc[1].add_child(rc[0])
	rc[1][0].disabled = not tc
	rc[1][1].disabled = not tp
	rc[1][2].disabled = not (tc and tp)
	var g := _grid()
	v.add_child(g)
	var raio := _num(o.get("raio", 100.0), 2)
	_linha(g, "Raio de Busca - curvas (m):", raio)
	var prec := HSlider.new()
	prec.min_value = 1
	prec.max_value = 10
	prec.step = 1
	prec.value = int(o.get("precisao", 3))
	prec.custom_minimum_size = Vector2(200, 0)
	_linha(g, "Precisão de Busca:", prec)
	var rp := _num(o.get("raio_pontos", 100.0), 2)
	_linha(g, "Precisão para cálculo de cota - pontos cotados (m):", rp, "Raio máximo para aceitar o ponto cotado mais próximo.")
	var nota := _lbl("Nós cujas cotas não puderem ser calculadas ficam marcados com um X vermelho.")
	nota.add_theme_font_size_override("font_size", 12)
	v.add_child(nota)
	d.confirmed.connect(func():
		o["raio"] = maxf(_n(raio), 1.0)
		o["precisao"] = int(prec.value)
		o["raio_pontos"] = maxf(_n(rp), 0.1)
		main.salvar_config()
		main.recalcular_cotas(_radio_val(rr[1]) == 0, _radio_val(rc[1]) + 1))
	if not tc and not tp:
		d.get_ok_button().disabled = true
		nota.text = "Leia antes uma base topográfica (DXF de topografia ou de pontos cotados)."
	_show(d)


func abrir_propriedades() -> void:
	var info: Dictionary = main.proj["info"]
	var ref: Dictionary = main.proj["referencia"]
	var d := _dlg("Propriedades do Projeto", Vector2i(520, 380))
	var v := _vbox()
	d.add_child(v)
	var g := _grid()
	v.add_child(g)
	var p := _txt(str(info.get("projeto", "")), 300)
	_linha(g, "Nome do projeto:", p)
	var r := _txt(str(info.get("responsavel", "")), 300)
	_linha(g, "Responsável técnico:", r)
	var l := _txt(str(info.get("local", "")), 300)
	_linha(g, "Município / bairro:", l)
	var gr := _grupo("Referência espacial")
	v.add_child(gr[0])
	var g2 := _grid()
	gr[1].add_child(g2)
	var crs := _txt(str(ref.get("crs", "")), 300)
	crs.placeholder_text = "ex.: EPSG:31983 (SIRGAS 2000 / UTM 23S)"
	_linha(g2, "Sistema de referência (CRS):", crs, "Deixe vazio se as coordenadas forem arbitrárias: o projeto fica como “referência não informada”.")
	var uh := _txt(str(ref.get("unidade_horizontal", "m")), 80)
	_linha(g2, "Unidade horizontal:", uh)
	var uv := _txt(str(ref.get("unidade_vertical", "m")), 80)
	_linha(g2, "Unidade vertical:", uv)
	var dv := _txt(str(ref.get("datum_vertical", "não informado")), 300)
	_linha(g2, "Datum vertical:", dv)
	var ot := _txt(str(ref.get("origem_topografia", "")), 300)
	_linha(g2, "Origem da base topográfica:", ot)
	var dt := _txt(str(ref.get("data_topografia", "")), 160)
	_linha(g2, "Data da base topográfica:", dt)
	var est := _lbl("Situação: " + Net.referencia_texto(main.proj))
	est.add_theme_font_size_override("font_size", 12)
	gr[1].add_child(est)
	d.confirmed.connect(func():
		info["projeto"] = p.text.strip_edges()
		info["responsavel"] = r.text.strip_edges()
		info["local"] = l.text.strip_edges()
		ref["crs"] = crs.text.strip_edges()
		ref["unidade_horizontal"] = uh.text.strip_edges()
		ref["unidade_vertical"] = uv.text.strip_edges()
		ref["datum_vertical"] = dv.text.strip_edges()
		ref["origem_topografia"] = ot.text.strip_edges()
		ref["data_topografia"] = dt.text.strip_edges()
		main.marcar_alterado())
	_show(d)


func abrir_desloca(tid: int) -> void:
	var t: Dictionary = Net.trecho_map(main.proj).get(tid, {})
	if t.is_empty():
		return
	var d := _dlg("Desloca Trecho %s" % str(t["nome"]), Vector2i(420, 160))
	var v := _vbox()
	d.add_child(v)
	v.add_child(_lbl("Translação paralela, mantendo a direção do trecho."))
	var g := _grid()
	v.add_child(g)
	var lado := _radios(["Esquerda", "Direita"], 0, false)
	_linha(g, "Lado (olhando no sentido do escoamento):", lado[0])
	var dist := _num(5.0, 2)
	_linha(g, "Deslocamento (m):", dist)
	d.confirmed.connect(func(): main.deslocar_trecho(tid, _n(dist), _radio_val(lado[1]) == 0))
	_show(d)


# ------------------------------------------------------------------ seleção de layers DXF

func abrir_layers(titulo: String, arquivo: String, info: Dictionary, preferidos: Array, cb: Callable) -> void:
	var d := _dlg(titulo, Vector2i(520, 420))
	var v := _vbox()
	d.add_child(v)
	v.add_child(_lbl("Arquivo: %s" % arquivo))
	var h := _hbox()
	v.add_child(h)
	var tree := Tree.new()
	tree.custom_minimum_size = Vector2(330, 300)
	tree.hide_root = true
	tree.columns = 2
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 70)
	var root := tree.create_item()
	var itens: Array = []
	var lays: Array = info["layers"]
	var algum := false
	for ly in lays:
		for pref in preferidos:
			if str(ly).to_upper().contains(pref):
				algum = true
	for ly in lays:
		var it := tree.create_item(root)
		it.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		it.set_editable(0, true)
		it.set_text(0, str(ly))
		var marcar := not algum
		for pref in preferidos:
			if str(ly).to_upper().contains(pref):
				marcar = true
		it.set_checked(0, marcar)
		it.set_text(1, "%d ent." % int(info["contagem"].get(ly, 0)))
		itens.append(it)
	h.add_child(tree)
	var bv := _vbox()
	h.add_child(bv)
	var estado_ini: Array = []
	for it in itens:
		estado_ini.append(it.is_checked(0))
	for b in [["Marca Todos", 1], ["Desmarca Todos", 0], ["Reset", 2]]:
		var bt := Button.new()
		bt.text = b[0]
		var modo: int = b[1]
		bt.pressed.connect(func():
			for k in itens.size():
				itens[k].set_checked(0, estado_ini[k] if modo == 2 else modo == 1))
		bv.add_child(bt)
	d.confirmed.connect(func():
		var sel := {}
		for it in itens:
			if it.is_checked(0):
				sel[it.get_text(0)] = true
		cb.call(sel))
	_show(d)


# ------------------------------------------------------------------ banco de dados (manual cap. 6)

func abrir_banco() -> void:
	var copia: Dictionary = main.db.duplicate(true)
	var d := _dlg("Banco: %s" % main.db_path_exibicao(), Vector2i(900, 520), "OK")
	var v := _vbox()
	d.add_child(v)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(880, 430)
	v.add_child(tabs)
	var tabelas := {}
	for k in Db.ORDEM:
		var spec: Dictionary = Db.SPECS[k]
		var pv := _vbox(6)
		pv.name = str(spec["titulo"])
		tabs.add_child(pv)
		var barra := _hbox(6)
		pv.add_child(barra)
		var gt := GridTable.new()
		gt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gt.setup(spec["cols"])
		gt.choices_fn = func(chave):
			if chave == "material":
				return Db.nomes(copia, "materiais")
			if chave == "uso":
				return Db.USOS
			return []
		var tabela: String = k
		var recarregar := func():
			var rows: Array = []
			for i in copia[tabela].size():
				var r: Dictionary = copia[tabela][i].duplicate()
				r["_meta"] = i
				rows.append(r)
			gt.set_rows(rows)
		gt.cells_changed.connect(func(ch):
			for c in ch:
				var i := int(c[0])
				if c[1] == "padrao" and bool(c[2]):
					for m in copia["materiais"]:
						m["padrao"] = false
				copia[tabela][i][c[1]] = c[2]
			if tabela == "materiais":
				recarregar.call())
		var b_ins := Button.new()
		b_ins.text = "+ Insere registro"
		b_ins.pressed.connect(func():
			var novo := {}
			for c in spec["cols"]:
				var f: String = c["f"]
				novo[c["k"]] = false if f == "chk" else ("" if f == "s" else 0.0)
			if tabela == "tubos":
				novo["material"] = Db.material_padrao(copia)
			elif tabela == "acessorios":
				novo["uso"] = "Manual"
			elif novo.has("nome"):
				novo["nome"] = "Novo item"
			copia[tabela].append(novo)
			recarregar.call())
		var b_del := Button.new()
		b_del.text = "− Elimina registro"
		b_del.pressed.connect(func():
			var sel: Array = []
			var it := gt.get_next_selected(null)
			while it != null:
				sel.append(int(it.get_metadata(0)))
				it = gt.get_next_selected(it)
			sel.sort()
			sel.reverse()
			var apagados := {}
			for i in sel:
				if not apagados.has(i):
					apagados[i] = true
					var removido: Dictionary = copia[tabela][i]
					copia[tabela].remove_at(i)
					if tabela == "materiais":
						# apagar um material apaga também os seus tubos
						var restantes: Array = []
						for tb in copia["tubos"]:
							if str(tb["material"]) != str(removido["nome"]):
								restantes.append(tb)
						copia["tubos"] = restantes
			recarregar.call())
		barra.add_child(b_ins)
		barra.add_child(b_del)
		var dica := _lbl("Clique numa célula selecionada para editar • botão direito nas colunas de lista • Ctrl+C / Ctrl+V")
		dica.add_theme_font_size_override("font_size", 12)
		dica.add_theme_color_override("font_color", main.pal["muted"])
		barra.add_child(dica)
		pv.add_child(gt)
		tabelas[k] = recarregar
		recarregar.call()
	tabs.tab_changed.connect(func(_i):
		for k in tabelas.keys():
			tabelas[k].call())
	var rod := _hbox()
	v.add_child(rod)
	var nota := _lbl("Os preços são apenas referências de mercado: atualize-os para valores reais.")
	nota.add_theme_font_size_override("font_size", 12)
	nota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rod.add_child(nota)
	d.add_button("Imprimir", false, "imprimir")
	d.add_button("Salvar cópia…", false, "salvar")
	d.custom_action.connect(func(a):
		if a == "imprimir":
			texto_longo("Listagem do banco de dados", Db.listagem(copia), "banco-de-dados.txt")
		elif a == "salvar":
			main.pedir_arquivo("salvar", ["*.json ; Banco de itens de custo"], "cesgcust.json", func(path):
				if Db.salvar(path, copia):
					main.set_status("Cópia do banco salva em " + path)))
	d.confirmed.connect(func(): main.aplicar_banco(copia))
	_show(d)


# ------------------------------------------------------------------ perfil (manual 5.1.3)

func abrir_perfil(rows: Array, titulo: String) -> void:
	var w := Window.new()
	w.title = "Perfil"
	w.size = Vector2i(1060, 620)
	w.min_size = Vector2i(600, 400)
	w.wrap_controls = false
	w.transient = true
	w.close_requested.connect(w.queue_free)
	main.add_child(w)
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.add_child(bg)
	var v := _vbox(0)
	bg.add_child(v)
	var mb := MenuBar.new()
	mb.flat = true
	v.add_child(mb)
	var pv := ProfileView.new()
	pv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.set_data(rows, titulo)
	v.add_child(pv)
	var sai := PopupMenu.new()
	sai.name = "Saídas"
	sai.add_item("Salvar imagem (PNG)…", 0)
	sai.add_item("Listagem", 1)
	sai.add_item("Exporta .TXT…", 2)
	sai.add_item("Exporta .DXF…", 3)
	sai.add_separator()
	sai.add_item("Fecha", 4, KEY_MASK_CTRL | KEY_F4)
	sai.id_pressed.connect(_perfil_menu.bind(w, pv, rows, titulo))
	mb.add_child(sai)
	var gr := PopupMenu.new()
	gr.name = "Grid"
	for i in 4:
		gr.add_radio_check_item(["Nenhum", "Horizontal", "Vertical", "Ambos"][i], i)
	gr.set_item_checked(0, true)
	gr.id_pressed.connect(func(id):
		pv.grid_modo = id
		for i in 4:
			gr.set_item_checked(i, i == id)
		pv.queue_redraw())
	mb.add_child(gr)
	var es := PopupMenu.new()
	es.name = "Escala"
	es.add_item("Definição da escala…", 0)
	es.id_pressed.connect(func(_id): abrir_escala_perfil(pv))
	mb.add_child(es)
	w.popup_centered()


func _perfil_menu(id: int, w: Window, pv, rows: Array, titulo: String) -> void:
	if id == 0:
		if not main._avisar_bloqueio("perfil"):
			main.pedir_arquivo("salvar", ["*.png ; Imagem PNG"], "perfil.png", func(path): main.exportar_perfil_png(rows, titulo, path, pv.grid_modo, pv.escala))
	elif id == 1:
		texto_longo("Listagem do perfil", pv.listagem(), "perfil.txt")
	elif id == 2:
		main.pedir_arquivo("salvar", ["*.txt ; Texto"], "perfil.txt", func(path): main.gravar_texto(path, pv.listagem()))
	elif id == 3:
		if not main._avisar_bloqueio("perfil"):
			main.pedir_arquivo("salvar", ["*.dxf ; DXF"], "perfil.dxf", func(path): main.exportar_perfil(rows, titulo, path))
	elif id == 4:
		w.queue_free()


func abrir_escala_perfil(pv) -> void:
	var lim: Dictionary = pv.limites_auto()
	var e: Dictionary = pv.escala
	var d := _dlg("Escala em perfil", Vector2i(560, 150))
	var g := _grid(5)
	d.add_child(g)
	for t in ["", "Mínimo:", "Máximo:", "Passo da Escala:", "Ajuste Automático:"]:
		g.add_child(_lbl(t))
	var campos := {}
	for eixo in ["x", "y"]:
		g.add_child(_lbl("Escala %s:" % eixo.to_upper()))
		var auto := bool(e["auto_" + eixo])
		for k in ["min", "max", "passo"]:
			var val: float = float(lim[eixo + k]) if auto else float(e[eixo + k])
			var le := _num(val, 2, 100)
			g.add_child(le)
			campos[eixo + k] = le
		var ca := _chk("", auto)
		g.add_child(ca)
		campos["auto_" + eixo] = ca
	d.confirmed.connect(func():
		for eixo in ["x", "y"]:
			e["auto_" + eixo] = campos["auto_" + eixo].button_pressed
			for k in ["min", "max", "passo"]:
				e[eixo + k] = _n(campos[eixo + k])
		pv.queue_redraw())
	_show(d)


# ------------------------------------------------------------------ registro de erros

func abrir_registro() -> void:
	var r = main.registro
	r.verificar_godot_log()
	var d := _dlg("Registro de erros", Vector2i(1060, 620), "Fecha", false)
	var v := _vbox()
	d.add_child(v)
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", main.pal["muted"])
	v.add_child(info)
	var filtro := _chk("Mostrar também avisos (falhas ao abrir/gravar arquivos, cálculo não concluído…)", true)
	v.add_child(filtro)
	var hs := HSplitContainer.new()
	hs.custom_minimum_size = Vector2(1040, 440)
	hs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(hs)
	var lista := ItemList.new()
	lista.custom_minimum_size = Vector2(400, 0)
	hs.add_child(lista)
	var det := TextEdit.new()
	det.editable = false
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_theme_font_override("font", main.fonte_mono())
	det.add_theme_font_size_override("font_size", 12)
	det.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	hs.add_child(det)
	var entradas: Array = []
	var preencher := func():
		lista.clear()
		entradas.clear()
		var hist: Array = r.historico()
		hist.reverse()
		for e in hist:
			var nivel := str(e["nivel"])
			if nivel == "AVISO" and not filtro.button_pressed:
				continue
			var texto := str(e["texto"])
			for m in r.erros:
				if str(m["quando"]) == str(e["quando"]) and str(m["msg"]) == str(e["msg"]):
					texto = r.formatar(m)
			entradas.append(texto)
			var idx := lista.add_item("%s  %s  %s" % [str(e["quando"]), nivel, str(e["msg"]).left(90)])
			lista.set_item_custom_fg_color(idx, Color(0.8, 0.1, 0.1) if nivel in ["ERRO", "FALHA"] else Color(0.75, 0.4, 0.0))
			lista.set_item_tooltip(idx, str(e["msg"]))
		var kb: float = r.uso_em_disco() / 1024.0
		info.text = "Pasta: %s   •   ocupando %s KB (limite %d MB)   •   %d erro(s) nesta sessão" % [
			r.pasta_global(), main.fmt(kb, 0), r.LIMITE_PASTA / (1024 * 1024), r.total_erros()]
		if entradas.is_empty():
			det.text = "Nenhum erro registrado.\n\nQuando algo der errado, cada ocorrência aparece aqui com:\n  • a mensagem e o local no código (arquivo:linha);\n  • o rastreio das chamadas, quando disponível;\n  • as últimas ações feitas antes do erro;\n  • o projeto que estava aberto.\n\nErros iguais são agrupados e contados, para o registro não crescer."
		else:
			lista.select(0)
			det.text = entradas[0]
	lista.item_selected.connect(func(i): det.text = entradas[i])
	filtro.toggled.connect(func(_b): preencher.call())
	preencher.call()
	d.add_button("Limpar registros", false, "limpar")
	d.add_button("Registro completo", false, "completo")
	d.add_button("Abrir pasta", false, "pasta")
	d.add_button("Salvar relatório…", false, "salvar")
	d.add_button("Copiar", false, "copiar")
	d.custom_action.connect(func(acao):
		if acao == "copiar":
			DisplayServer.clipboard_set(det.text)
			main.set_status("Detalhe do erro copiado.")
		elif acao == "pasta":
			OS.shell_open(r.pasta_global())
		elif acao == "completo":
			texto_longo("Registro completo (dimesgoto.log)", r.texto_completo(), "dimesgoto-registro.txt")
		elif acao == "salvar":
			var rel := "RELATÓRIO DE ERROS — %s %s\nGodot %s • %s %s\nProjeto: %s\n\n" % [main.APP_NAME, main.VERSAO,
				Engine.get_version_info().get("string", "?"), OS.get_name(), OS.get_version(), main.current_path]
			rel += "\n\n".join(PackedStringArray(entradas)) if not entradas.is_empty() else "Nenhum erro registrado."
			main.pedir_arquivo("salvar", ["*.txt ; Texto"], "relatorio-de-erros.txt", func(path): main.gravar_texto(path, rel))
		elif acao == "limpar":
			var c := ConfirmationDialog.new()
			c.title = "Limpar registros"
			c.dialog_text = "Apagar todos os registros de erros e de sessões anteriores?"
			c.ok_button_text = "Apagar"
			c.cancel_button_text = "Cancelar"
			c.confirmed.connect(func():
				r.limpar_tudo()
				preencher.call())
			c.visibility_changed.connect(func():
				if not c.visible:
					c.queue_free())
			main.add_child(c)
			c.popup_centered())
	_show(d)


# ------------------------------------------------------------------ ajuda

const AJUDA := """[b]DimEsgoto — comandos do traçado[/b]

[table=4]
[cell][b]Comando[/b][/cell][cell][b]Na área vazia[/b][/cell][cell][b]Sobre o nó[/b][/cell][cell][b]Sobre o trecho (caixa da seta)[/b][/cell]
[cell]Botão 1[/cell][cell]Cria nós intermediários (durante o traçado)[/cell][cell]Clicar e arrastar: move o nó[/cell][cell]—[/cell]
[cell]Botão 2[/cell][cell]Inicia o traçado / finaliza o traçado[/cell][cell]Propriedades do nó[/cell][cell]Propriedades do trecho[/cell]
[cell]Shift + botão 1[/cell][cell]—[/cell][cell]Continua o traçado a partir deste nó (só do último nó de um coletor)[/cell][cell]Marca o coletor inteiro[/cell]
[cell]Ctrl + botão 1[/cell][cell]—[/cell][cell]—[/cell][cell]Marca / desmarca o trecho[/cell]
[cell]Ctrl + botão 2[/cell][cell]—[/cell][cell]Mostra o nome do coletor[/cell][cell]—[/cell]
[/table]

• O traçado de cada coletor é feito sempre de [b]montante para jusante[/b]. Para criar um afluente, termine o traçado clicando (botão 1) sobre um nó existente.
• Roda do mouse: zoom no cursor. Botão do meio: desloca a vista. Esc: cancela o comando. Del: apaga os trechos marcados.
• Um nó não é apagado diretamente: apague os trechos ligados a ele. Para inserir um nó no meio de um trecho, use Trechos › Divide trecho.
• Cotas do terreno: com base topográfica carregada (Arquivos › Lê DXF…), o modo do traçado (C+C, PRX, INT na barra inferior) calcula a cota de cada nó criado. Nós sem cota confirmada ficam com um X vermelho.

[b]Teclas de atalho[/b]
Ctrl+N novo • F2 salva • Ctrl+T traçado • Ctrl+E planilhas • Ctrl+D dimensionamento • F5 localizar • F3 localizar próxima
Ctrl+Z desfazer • Ctrl+Y ou Ctrl+Shift+Z refazer
Ctrl+I / Ctrl+O zoom • Ctrl+0 sem zoom • Ctrl+U último zoom • Ctrl+J janela • Ctrl+P pan • Ctrl+A ajuste máximo • Ctrl+R redesenha
Ctrl+L traçado da rede • Ctrl+X exibição de DXF's • Ctrl+S cálculo automático de cotas • F6 / F7 / F8 modos de cota

[b]Registro de erros[/b]
Ajuda › Registro de erros… (ou o aviso vermelho na barra de status) mostra cada erro com o local no código, o rastreio e as últimas ações feitas antes dele. Os arquivos ficam na pasta de dados do usuário (Linux: ~/.local/share/godot/app_userdata/DimEsgoto/logs) e ocupam no máximo cerca de 10 MB: o registro é rotacionado, erros repetidos são contados em vez de gravados de novo e os arquivos mais antigos são apagados automaticamente.

[b]Planilhas[/b]
Colunas brancas são editáveis; amarelas, só leitura. Clique numa célula já selecionada para editar. Botão 2 nas colunas de lista (tipo do nó, material, superfície, escoramento, situação, critério) abre as opções do banco de dados e aplica a todas as células selecionadas da coluna. Ctrl+C / Ctrl+V copiam e colam blocos de células (também com Excel/LibreOffice).
"""

const COMO_USAR := """[b]Meu primeiro projeto (resumo do capítulo 7 do manual)[/b]

1. [b]Arquivos › Novo[/b] e defina a [b]Área de trabalho[/b] (comprimentos N e E, origem e grid).
2. [b]Arquivos › Lê DXF de topografia[/b]: escolha só os layers das curvas de nível. Depois [b]Lê DXF de ruas[/b] (layer das quadras). Também é possível usar [b]Novo com imagem[/b] ou um traçado esquemático.
3. [b]Traçado[/b] (Ctrl+T): botão 2 inicia um coletor na ponta seca; botão 1 em cada PV; botão 2 finaliza. Siga o caimento do terreno e coloque PVs nos cruzamentos.
4. Botão 2 sobre um nó ou trecho mostra e edita os dados (tipo do nó, vazões pontuais, material, pavimento, escoramento, recobrimento…).
5. [b]Planilhas[/b] (Ctrl+E): confira e edite tudo em forma de tabela (Plan. Trechos, Nós, Dimens., Quant.).
6. [b]Dimensionamento[/b] (Ctrl+D): informe população, consumo, coeficientes e critérios; clique [b]Inicia[/b]. Luz verde = sem problemas; amarela = veja as observações.
7. [b]Observações[/b] (botão OBS): corrija o que for possível e dimensione de novo.
8. Marque um coletor (Shift + botão 1 na seta) e use [b]Perfil[/b]. Exporte planta e perfil em DXF.
9. [b]Planilhas › Resultados / Orçamento[/b]: hidráulica completa, quantitativos e custos (preços do Banco de dados).

Para começar rapidamente: [b]Acionar › Carregar rede de exemplo[/b].
"""


func abrir_ajuda(qual: String) -> void:
	var d := _dlg("Ajuda" if qual != "como" else "Como usar?", Vector2i(860, 560), "Fecha", false)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.custom_minimum_size = Vector2(840, 500)
	rt.text = AJUDA if qual != "como" else COMO_USAR
	d.add_child(rt)
	_show(d)
