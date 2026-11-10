extends SceneTree
## Fase 1 — EVAL-101, 103, 105, 106 e 107 (motor hidráulico, restrições, parâmetros, métodos e orçamento).
##
## Premissa de severidade usada no EVAL-103 (o EVALS.md não define; validar com o responsável técnico):
##   impeditivo (status 2): lâmina acima do limite, declividade nula ou negativa;
##   advertência (status 1): velocidade acima da máxima, tensão trativa abaixo da mínima,
##                           recobrimento insuficiente, profundidade acima da máxima, trecho acima da distância máxima.

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")
const Db = preload("res://db.gd")
const Report = preload("res://report.gd")

var T
var m


func _initialize() -> void:
	T = Lib.new()
	m = await T.novo_main(self)
	T.usar_banco_teste(m)
	print("META|" + JSON.stringify(T.meta(m)))
	_eval_101()
	_eval_103()
	_eval_105()
	_eval_106()
	_eval_107()
	quit(T.fim())


func _abrir(fixture: String) -> void:
	T.carregar(m, fixture)
	m.opts["grava_res"] = false


# ------------------------------------------------------------------ EVAL-101

func _eval_101() -> void:
	var id := "EVAL-101"
	_abrir("rede_unica.esg")
	var exp = JSON.parse_string(FileAccess.get_file_as_string(Lib.DIR.path_join("expected/rede_unica.json")))
	var res: Dictionary = m.executar_calculo(false)
	var r = T.linha(m, "T1")
	T.dado(id, "entrada", "fixtures/rede_unica.esg (1 trecho de 100 m, terreno plano, Manning n=0,013 do banco teste-1)")
	T.dado(id, "params", m.proj["params"])
	T.dado(id, "meta", T.meta(m))
	if not T.check(id, not r.is_empty(), "trecho calculado"):
		return
	T.dado(id, "saida", {"txi": r["txi"], "txf": r["txf"], "qj_i": r["qj_i"], "qj_f": r["qj_f"], "d": r["d"], "i": r["i"],
		"v_i": r["v_i"], "v_f": r["v_f"], "yd_i": r["yd_i"], "yd_f": r["yd_f"], "sigma": r["sigma"], "rec_m": r["rec_m"], "rec_j": r["rec_j"]})
	var n := 0.013
	var d := float(r["d"]) / 1000.0
	var i := float(r["i"])
	T.check(id, Lib.aprox(r["txi"], exp["txi_ls_km"], 1e-6) and Lib.aprox(r["txf"], exp["txf_ls_km"], 1e-6),
		"contribuição linear inicial/final = %.6f / %.6f l/s·km (analítico %.6f / %.6f; tol 1e-6)" % [r["txi"], r["txf"], exp["txi_ls_km"], exp["txf_ls_km"]])
	T.check(id, Lib.aprox(r["qj_i"], exp["qj_i"], 1e-6) and Lib.aprox(r["qj_f"], exp["qj_f"], 1e-6),
		"vazão inicial/final = %.6f / %.6f l/s (analítico %.6f / %.6f)" % [r["qj_i"], r["qj_f"], exp["qj_i"], exp["qj_f"]])
	T.check(id, int(r["d"]) == int(exp["d"]), "diâmetro comercial selecionado = %d mm (esperado %d, o mínimo)" % [int(r["d"]), int(exp["d"])])
	var qi := maxf(float(r["qj_i"]), 1.5) / 1000.0
	var qf := maxf(float(r["qj_f"]), 1.5) / 1000.0
	var s_i := Lib.tensao(qi, d, i, n)
	var s_menos := Lib.tensao(qi, d, i - 0.0001, n)
	T.check(id, s_i >= 1.0 - 1e-6 and s_menos < 1.0,
		"declividade %.4f é a mínima por tensão trativa: σ(I)=%.4f Pa ≥ 1 e σ(I−0,0001)=%.4f Pa < 1 (conferência independente)" % [i, s_i, s_menos])
	T.dado(id, "i_nbr_formula", exp["i_nbr_referencia"])
	T.check(id, absf(i - float(exp["i_nbr_referencia"])) / float(exp["i_nbr_referencia"]) < 0.15,
		"declividade dentro de 15%% da fórmula da NBR 9649 (I=0,0055·Qi^-0,47 = %.4f)" % float(exp["i_nbr_referencia"]))
	T.check(id, Lib.aprox(r["sigma"], s_i, 1e-6), "tensão trativa do motor %.6f Pa = conferência %.6f Pa (tol 1e-6)" % [r["sigma"], s_i])
	var yi := Lib.manning_yd(qi, d, i, n)
	var yf := Lib.manning_yd(qf, d, i, n)
	var vi := qi / float(Lib.secao(yi, d)["a"])
	var vf := qf / float(Lib.secao(yf, d)["a"])
	T.check(id, Lib.aprox(r["yd_i"], yi, 1e-6) and Lib.aprox(r["yd_f"], yf, 1e-6),
		"lâmina relativa inicial/final = %.6f / %.6f (conferência %.6f / %.6f)" % [r["yd_i"], r["yd_f"], yi, yf])
	T.check(id, Lib.aprox(r["v_i"], vi, 1e-6) and Lib.aprox(r["v_f"], vf, 1e-6),
		"velocidade inicial/final = %.6f / %.6f m/s (conferência %.6f / %.6f)" % [r["v_i"], r["v_f"], vi, vf])
	T.check(id, float(r["yd_f"]) <= 0.75, "lâmina final ≤ 0,75")
	T.check(id, Lib.aprox(r["rec_m"], exp["rec_m"], 0.001) and float(r["rec_j"]) >= 1.35 - 0.001,
		"recobrimento montante %.3f m (= 1,35 ± 0,001) e jusante %.3f m (≥ 1,35)" % [r["rec_m"], r["rec_j"]])
	T.check(id, bool(res["ok"]) and str(res["luz"]) == "verde", "sem observações (luz %s)" % res["luz"])


# ------------------------------------------------------------------ EVAL-103

func _caso_103(nome: String, preparar: Callable, chave_obs: String, status_esperado: int, campos_fixos: Array) -> void:
	var id := "EVAL-103"
	_abrir("rede_unica.esg")
	var t: Dictionary = T.trecho(m, "T1")
	preparar.call(t)
	var antes := {}
	for k in campos_fixos:
		antes[k] = t[k]
	m.executar_calculo(false)
	t = T.trecho(m, "T1")
	var r = T.linha(m, "T1")
	var obs = T.obs_de(m, "T1")
	var achou: bool = obs.to_lower().contains(chave_obs.to_lower())
	T.check(id, achou, "%s: aviso gerado (\"%s\")" % [nome, chave_obs] + ("" if achou else " — obtido: [%s]" % obs))
	T.check(id, int(r.get("status", -1)) == status_esperado, "%s: severidade %s (esperado %s)" % [
		nome, ["ok", "advertência", "impeditivo"][clampi(int(r.get("status", 0)), 0, 2)], ["ok", "advertência", "impeditivo"][status_esperado]])
	var mudou: Array = []
	for k in campos_fixos:
		if str(t[k]) != str(antes[k]):
			mudou.append("%s %s→%s" % [k, str(antes[k]), str(t[k])])
	if not campos_fixos.is_empty():
		T.check(id, mudou.is_empty(), "%s: entrada fixada preservada" % nome + ("" if mudou.is_empty() else " — alterado: %s" % str(mudou)))


func _eval_103() -> void:
	T.dado("EVAL-103", "entrada", "rede_unica.esg com uma restrição forçada por caso")
	_caso_103("velocidade acima do máximo", _p_vel, "velocidade final", 1, ["cc_m", "cc_j"])
	_caso_103("tensão trativa abaixo do mínimo", _p_tensao, "tensão trativa", 1, ["cc_m", "cc_j"])
	_caso_103("lâmina acima do limite", _p_lamina, "lâmina final", 2, ["d", "fixa_d"])
	_caso_103("declividade negativa", _p_decl, "declividade", 2, ["cc_m", "cc_j"])
	_caso_103("recobrimento insuficiente", _p_recob, "recobrimento", 1, ["cc_m", "cc_j"])
	_caso_103("profundidade acima do máximo", _p_prof, "prof.", 1, ["pmax"])
	_caso_103("trecho acima da distância máxima", _p_dist, "dist. máx", 1, ["ext_fix"])


func _fixa(t: Dictionary, a: float, b: float) -> void:
	t["fixa_cotas"] = true
	t["cc_m"] = a
	t["cc_j"] = b


func _p_vel(t: Dictionary) -> void:
	m.proj["params"]["v_max"] = 0.5
	Net.achar_no(m.proj, "2")["ct"] = 95.0
	_fixa(t, 98.5, 93.5)


func _p_tensao(t: Dictionary) -> void:
	_fixa(t, 98.5, 98.45)


func _p_lamina(t: Dictionary) -> void:
	t["fixa_d"] = true
	t["d"] = 150.0
	Net.achar_no(m.proj, "1")["qp_f"] = 40.0
	Net.achar_no(m.proj, "1")["qp_i"] = 20.0


func _p_decl(t: Dictionary) -> void:
	_fixa(t, 98.0, 98.3)


func _p_recob(t: Dictionary) -> void:
	_fixa(t, 99.5, 99.0)


func _p_prof(t: Dictionary) -> void:
	t["pmax"] = 1.0


func _p_dist(t: Dictionary) -> void:
	t["ext_fix"] = 150.0


# ------------------------------------------------------------------ EVAL-105

func _eval_105() -> void:
	var id := "EVAL-105"
	var casos := [
		["pop_ini", -100.0, ["popula"], "população inicial negativa"],
		["pop_fin", NAN, ["popula"], "população final NaN"],
		["qpc_ini", 0.0, ["consumo", "per capita"], "consumo per capita nulo"],
		["c_ini", 1.5, ["retorno"], "coeficiente de retorno > 1"],
		["k1", 0.5, ["k1"], "K1 < 1"],
		["q_min", -1.0, ["vazão mínima"], "vazão mínima negativa"],
		["d_min", 0.0, ["diâmetro mínimo"], "diâmetro mínimo nulo"],
		["tensao_min", NAN, ["tensão"], "tensão trativa mínima NaN"],
		["recob_min", -1.0, ["recobrimento"], "recobrimento mínimo negativo"],
		["v_max", 0.0, ["velocidade"], "velocidade máxima nula"],
		["degrau_min", 0.8, ["degrau"], "degrau mínimo (0,80) maior que o máximo (0,65)"],
	]
	T.dado(id, "entrada", "rede_unica.esg com um parâmetro inválido por caso")
	for c in casos:
		_abrir("rede_unica.esg")
		var p: Dictionary = m.proj["params"]
		p[c[0]] = c[1]
		var res: Dictionary = m.executar_calculo(false)
		var textos := " ".join(PackedStringArray(res.get("erros", []))).to_lower()
		for o in res.get("obs", []):
			textos += " " + str(o[1]).to_lower()
		textos += " " + m.status_label.text.to_lower()
		var explicou := false
		for chave in c[2]:
			if textos.contains(str(chave).to_lower()):
				explicou = true
		var v_final = p[c[0]]
		var corrigido: bool = not (str(v_final) == str(c[1]))
		var rejeitou: bool = not bool(res.get("ok", true)) or not m.resultados_validos
		var nan_vazou := false
		for r in res.get("rows", {}).values():
			for k in ["qj_f", "i", "cc_j", "v_f", "sigma"]:
				if is_nan(float(r[k])) or is_inf(float(r[k])):
					nan_vazou = true
		T.check(id, (rejeitou or corrigido) and explicou and not nan_vazou,
			"%s: %s" % [c[3], ("rejeitado/corrigido com explicação" if (rejeitou or corrigido) and explicou else
			"aceito sem aviso (resultado %s, valor final %s%s)" % ["aprovado" if not rejeitou else "rejeitado", str(v_final),
			", NaN/inf nos resultados" if nan_vazou else ""])])


# ------------------------------------------------------------------ EVAL-106

func _eval_106() -> void:
	var id := "EVAL-106"
	var cfgs := [["Manning / banco", 0, 2], ["Manning / otimista", 0, 0], ["Manning / pessimista", 0, 1],
		["Universal / banco", 1, 2], ["Universal / otimista", 1, 0], ["Universal / pessimista", 1, 1]]
	var nomes_met := ["Manning", "Fórmula Universal"]
	var nomes_aj := ["inferior (otimista)", "superior (pessimista)", "valor do banco de dados"]
	var fixos := {}
	T.dado(id, "entrada", "rede_unica.esg com geometria fixada (ø150, I=0,005) e rede_ramificada.esg livre")
	for c in cfgs:
		_abrir("rede_unica.esg")
		var t: Dictionary = T.trecho(m, "T1")
		t["fixa_d"] = true
		t["d"] = 150.0
		t["fixa_cotas"] = true
		t["cc_m"] = 98.5
		t["cc_j"] = 98.0
		m.proj["params"]["metodo"] = c[1]
		m.proj["params"]["ajuste_rug"] = c[2]
		m.executar_calculo(false)
		var r = T.linha(m, "T1")
		fixos[c[0]] = {"yd_f": r["yd_f"], "v_f": r["v_f"], "rug_f": r["rug_f"], "sigma": r["sigma"]}
		var mem := Report.memorial(m.proj, m.results, "teste")
		T.check(id, mem.contains("Método de cálculo: %s" % nomes_met[c[1]]) and mem.contains("Ajuste de rugosidade: %s" % nomes_aj[c[2]]),
			"%s: método e ajuste aparecem no memorial" % c[0])
		T.check(id, float(r["yd_f"]) > 0.0 and float(r["yd_f"]) < 1.0 and not is_nan(float(r["v_f"])), "%s: y/D=%.4f, V=%.3f m/s, rug=%.4f" % [c[0], r["yd_f"], r["v_f"], r["rug_f"]])
	T.dado(id, "geometria_fixa", fixos)
	for met in ["Manning", "Universal"]:
		var o: Dictionary = fixos[met + " / otimista"]
		var p: Dictionary = fixos[met + " / pessimista"]
		T.check(id, float(p["rug_f"]) >= float(o["rug_f"]) and float(p["yd_f"]) >= float(o["yd_f"]) - 1e-9 and float(p["v_f"]) <= float(o["v_f"]) + 1e-9,
			"%s: pessimista é mais rugoso que o otimista → lâmina maior e velocidade menor (coerente)" % met)
	T.check(id, absf(float(fixos["Manning / banco"]["yd_f"]) - float(fixos["Universal / banco"]["yd_f"])) > 1e-6,
		"Manning e Universal produzem resultados diferentes para a mesma geometria")
	for c in cfgs:
		_abrir("rede_ramificada.esg")
		m.proj["params"]["metodo"] = c[1]
		m.proj["params"]["ajuste_rug"] = c[2]
		var res: Dictionary = m.executar_calculo(false)
		T.check(id, bool(res["ok"]) and str(res["luz"]) != "vermelha", "%s: rede ramificada dimensionada (luz %s)" % [c[0], res["luz"]])


# ------------------------------------------------------------------ EVAL-107

func _eval_107() -> void:
	var id := "EVAL-107"
	_abrir("rede_ramificada.esg")
	m.proj["params"]["rede_plastica"] = true
	var res: Dictionary = m.executar_calculo(false)
	var orc: Dictionary = res["orc"]
	T.dado(id, "entrada", "rede_ramificada.esg, rede 100% plástico, banco teste-1")
	T.dado(id, "meta", T.meta(m))
	var db: Dictionary = m.db
	var rows: Array = res["rows"].values()
	var l_tot := 0.0
	var custo := 0.0
	var reat := 0.0
	var escav := 0.0
	var area_pav := 0.0
	var area_esc := 0.0
	for r in rows:
		var l := float(r["L"])
		var tb := Db.tubo(db, str(r["material"]), float(r["d"]))
		l_tot += l
		custo += l * (float(tb["fornecimento"]) + float(tb["assentamento"]))
		var w := float(r["larg"])
		var h1 := float(r["pvala_m"])
		var h2 := float(r["pvala_j"])
		var pav := Db.linha(db, "pavimentos", str(r["superficie"]))
		area_pav += w * l
		custo += w * l * (float(pav["retirada"]) + float(pav["colocacao"]))
		area_esc += (h1 + h2) * l
		custo += (h1 + h2) * l * float(Db.linha(db, "escoramentos", str(r["esc"]))["custo"])
		var ev := w * l * (h1 + h2) / 2.0
		escav += ev
		var dm := float(r["d"]) / 1000.0
		reat += maxf(ev - PI * dm * dm / 4.0 * l, 0.0) * (1.3 if bool(r["aterro"]) else 1.0)
	var n_pv := 0
	var prof_pv := 0.0
	var n_aces := 0
	var lig := Net.ligacoes(m.proj)
	for nid in res["nodes"].keys():
		var nr: Dictionary = res["nodes"][nid]
		n_pv += 1
		prof_pv += float(nr["prof"])
		custo += float(Db.pv(db, str(nr["tipo"]))["custo"]) * float(nr["prof"])
		var outs: Array = lig["out"].get(nid, [])
		if str(nr["tipo"]) == "TL" and not outs.is_empty():
			var dout := float(res["rows"][outs[0]]["d"])
			for a in db["acessorios"]:
				if str(a["uso"]) == "Terminal de limpeza" and absf(float(a["d"]) - dout) < 0.5:
					custo += float(a["custo"])
					n_aces += 1
		if not outs.is_empty():
			for u in lig["inc"].get(nid, []):
				var du := float(res["rows"][u]["d"])
				var dj := float(res["rows"][outs[0]]["d"])
				if du < dj - 0.5:
					for rd in db["reducoes"]:
						if absf(float(rd["d1"]) - dj) < 0.5 and absf(float(rd["d2"]) - du) < 0.5:
							custo += float(rd["custo"])
	var q := func(desc: String) -> float:
		for l in orc["linhas"]:
			if str(l.get("desc", "")).begins_with(desc):
				return float(l.get("q", 0.0))
		return NAN
	var soma := func(prefixo: String) -> float:
		var s := 0.0
		for l in orc["linhas"]:
			if str(l.get("tipo", "")) == "item" and str(l.get("desc", "")).begins_with(prefixo):
				s += float(l.get("q", 0.0))
		return s
	T.dado(id, "independente", {"l_tubos": l_tot, "n_pv": n_pv, "prof_pv": prof_pv, "area_pav": area_pav, "area_esc": area_esc,
		"escavacao": escav, "reaterro": reat, "acessorios": n_aces, "total": custo})
	T.dado(id, "app", {"total": orc["total"], "escavacao": orc["escavacao"], "reaterro": orc["reaterro"]})
	T.check(id, Lib.aprox(soma.call("PVC"), l_tot, 1e-6), "comprimento de tubos %.3f m (independente %.3f)" % [soma.call("PVC"), l_tot])
	var n_pv_app := 0.0
	for l in orc["linhas"]:
		if str(l.get("un", "")) == "un" and str(l.get("desc", "")).contains("prof. total"):
			n_pv_app += float(l["q"])
	T.check(id, int(n_pv_app) == n_pv, "quantidade de PVs e similares %d (independente %d)" % [int(n_pv_app), n_pv])
	T.check(id, Lib.aprox(orc["escavacao"], escav, 1e-6) and Lib.aprox(orc["reaterro"], reat, 1e-6),
		"escavação %.4f m³ e reaterro %.4f m³ (independente %.4f / %.4f)" % [orc["escavacao"], orc["reaterro"], escav, reat])
	T.check(id, Lib.aprox(soma.call("Asfáltico") + soma.call("Sem revestimento") + soma.call("Paralelep"), area_pav, 1e-6),
		"área de pavimento %.3f m² (independente %.3f)" % [soma.call("Asfáltico"), area_pav])
	T.check(id, n_aces > 0 and int(soma.call("Curva") + soma.call("Tampão")) == n_aces, "acessórios dos terminais de limpeza: %d" % n_aces)
	T.check(id, Lib.aprox(orc["total"], custo, 0.01), "total R$ %.2f (independente R$ %.2f)" % [orc["total"], custo])
	# determinismo
	var j1 := JSON.stringify(orc)
	m.executar_calculo(false)
	var j2 := JSON.stringify(m.results["orc"])
	var arq := ProjectSettings.globalize_path("user://eval107.esg")
	m._save_to(arq)
	m._load_from(arq)
	T.usar_banco_teste(m)
	m.executar_calculo(false)
	var j3 := JSON.stringify(m.results["orc"])
	T.check(id, j1 == j2 and j2 == j3, "mesmo projeto + mesmo banco → orçamento idêntico (recalculado e após salvar/reabrir)")
