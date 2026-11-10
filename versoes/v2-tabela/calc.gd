extends RefCounted
## Motor de cálculo: dimensionamento de redes coletoras de esgoto sanitário
## Critérios usuais da NBR 9649 (Projeto de redes coletoras de esgoto sanitário).

const G := 9.81
const GAMMA := 10000.0 # peso específico do esgoto (N/m3)
const DIAMETROS := [100, 150, 200, 250, 300, 350, 375, 400, 450, 500, 600, 700, 800, 900, 1000, 1200, 1500]
const THETA_MAX := 5.278 # ângulo central de vazão máxima em seção circular


static func default_params() -> Dictionary:
	return {
		"projeto": "Rede coletora - Exemplo",
		"responsavel": "",
		"local": "",
		"modo_taxa": 0, # 0 = pela população, 1 = taxas lineares informadas
		"pop_ini": 2400.0,
		"pop_fin": 4000.0,
		"per_capita": 160.0,
		"coef_retorno": 0.8,
		"k1": 1.2,
		"k2": 1.5,
		"infiltracao": 0.1, # L/s.km
		"tx_ini": 0.0020, # L/s.m
		"tx_fin": 0.0040, # L/s.m
		"q_min": 1.5, # L/s
		"manning": 0.013,
		"d_min": 150.0, # mm
		"prof_min": 1.05, # m (até a geratriz inferior)
		"prof_max": 4.5, # m
		"yd_max": 0.75,
		"tensao_min": 1.0, # Pa
		"v_max": 5.0, # m/s
		"degrau_max": 0.5, # m
	}


static func novo_trecho(coletor: String, trecho: String, pv_m: String, pv_j: String, l: float, ct_m: float, ct_j: float) -> Dictionary:
	return {
		"coletor": coletor, "trecho": trecho, "pv_m": pv_m, "pv_j": pv_j,
		"L": l, "ct_m": ct_m, "ct_j": ct_j, "qc_i": 0.0, "qc_f": 0.0, "d_fix": 0.0,
	}


static func example_trechos() -> Array:
	var rows := [
		["1", "1-1", "PV-01", "PV-02", 80.0, 105.20, 104.60],
		["1", "1-2", "PV-02", "PV-03", 75.0, 104.60, 103.90],
		["1", "1-3", "PV-03", "PV-04", 90.0, 103.90, 103.50],
		["1", "1-4", "PV-04", "PV-05", 85.0, 103.50, 102.20],
		["2", "2-1", "PV-06", "PV-07", 70.0, 106.10, 105.30],
		["2", "2-2", "PV-07", "PV-03", 65.0, 105.30, 103.90],
		["3", "3-1", "PV-08", "PV-09", 60.0, 104.80, 104.40],
		["3", "3-2", "PV-09", "PV-04", 70.0, 104.40, 103.50],
	]
	var out := []
	for r in rows:
		out.append(novo_trecho(r[0], r[1], r[2], r[3], r[4], r[5], r[6]))
	return out


## Taxas lineares de contribuição [inicial, final] em L/s.m
static func taxas(p: Dictionary, ltot: float) -> Array:
	if int(p["modo_taxa"]) == 1:
		return [float(p["tx_ini"]), float(p["tx_fin"])]
	if ltot <= 0.0:
		return [0.0, 0.0]
	var inf: float = float(p["infiltracao"]) / 1000.0
	var base: float = float(p["coef_retorno"]) * float(p["per_capita"]) / (86400.0 * ltot)
	var ti: float = base * float(p["k2"]) * float(p["pop_ini"]) + inf
	var tf: float = base * float(p["k1"]) * float(p["k2"]) * float(p["pop_fin"]) + inf
	return [ti, tf]


static func _area(th: float, d: float) -> float:
	return d * d / 8.0 * (th - sin(th))


static func _flow(th: float, d: float, i: float, n: float) -> float:
	var a := _area(th, d)
	var rh := a / (d * th / 2.0)
	return a * pow(rh, 2.0 / 3.0) * sqrt(i) / n


## Escoamento uniforme (Manning) em seção circular parcialmente cheia.
## q em m3/s, d em m, i em m/m.
static func hidraulica(q: float, d: float, i: float, n: float) -> Dictionary:
	if q <= 0.0 or i <= 0.0 or d <= 0.0:
		return {"ok": false, "yd": 0.0, "v": 0.0, "rh": 0.0}
	var qmax := _flow(THETA_MAX, d, i, n)
	if q > qmax:
		return {"ok": false, "yd": 1.0, "v": q / (PI * d * d / 4.0), "rh": d / 4.0}
	var lo := 0.0001
	var hi := THETA_MAX
	for _k in 80:
		var mid := (lo + hi) / 2.0
		if _flow(mid, d, i, n) < q:
			lo = mid
		else:
			hi = mid
	var th := (lo + hi) / 2.0
	var a := _area(th, d)
	return {"ok": true, "yd": (1.0 - cos(th / 2.0)) / 2.0, "v": q / a, "rh": a / (d * th / 2.0)}


static func _arred_cima(v: float, casas: float = 10000.0) -> float:
	return ceil(v * casas - 1e-7) / casas


## Dimensiona toda a rede. Retorna "rows" na mesma ordem dos trechos de entrada
## (null para trechos que não puderam ser calculados), a ordem de cálculo e avisos gerais.
static func calcular(p: Dictionary, trechos: Array) -> Dictionary:
	var n_tr := trechos.size()
	var ltot := 0.0
	for t in trechos:
		ltot += max(float(t["L"]), 0.0)
	var tx := taxas(p, ltot)
	var avisos: Array = []

	# Trechos de montante: os que chegam no PV de montante deste trecho
	var ups: Array = []
	var saidas := {}
	for i in n_tr:
		var pm := str(trechos[i]["pv_m"]).strip_edges()
		saidas[pm] = int(saidas.get(pm, 0)) + 1
		var lst: Array = []
		if pm != "":
			for k in n_tr:
				if k != i and str(trechos[k]["pv_j"]).strip_edges() == pm:
					lst.append(k)
		ups.append(lst)
	for pv in saidas.keys():
		if pv != "" and int(saidas[pv]) > 1:
			avisos.append("O %s tem %d trechos saindo dele; normalmente cada PV tem uma única saída." % [pv, saidas[pv]])

	var rows: Array = []
	rows.resize(n_tr)
	var order: Array = []
	var feito := {}
	var progresso := true
	while progresso:
		progresso = false
		for i in n_tr:
			if feito.has(i):
				continue
			var pronto := true
			for k in ups[i]:
				if not feito.has(k):
					pronto = false
					break
			if not pronto:
				continue
			var up_rows: Array = []
			for k in ups[i]:
				if rows[k] != null:
					up_rows.append(rows[k])
			rows[i] = _dimensionar(p, trechos[i], i, up_rows, tx)
			feito[i] = true
			order.append(i)
			progresso = true
	if feito.size() < n_tr:
		avisos.append("Há trechos formando um ciclo (a água voltaria ao mesmo PV). Confira os PVs de montante e jusante.")

	var n_ok := 0
	var n_warn := 0
	var n_err := 0
	for r in rows:
		if r == null:
			n_err += 1
		elif int(r["status"]) == 0:
			n_ok += 1
		elif int(r["status"]) == 1:
			n_warn += 1
		else:
			n_err += 1
	return {
		"rows": rows, "order": order, "tx_i": tx[0], "tx_f": tx[1], "ltot": ltot,
		"avisos": avisos, "n_ok": n_ok, "n_warn": n_warn, "n_err": n_err,
	}


static func _avaliar(p: Dictionary, t: Dictionary, l: float, dd: float, up_rows: Array, qf_d: float, imin: float) -> Dictionary:
	var d := dd / 1000.0
	var pmin := float(p["prof_min"])
	var cc_m := float(t["ct_m"]) - pmin
	for u in up_rows:
		# alinhamento pela geratriz superior quando o diâmetro aumenta
		cc_m = min(cc_m, float(u["cc_j"]) - (d - float(u["d"]) / 1000.0))
	var i_nec := (cc_m - (float(t["ct_j"]) - pmin)) / l
	var i_adot := _arred_cima(max(imin, i_nec))
	var hf := hidraulica(qf_d / 1000.0, d, i_adot, float(p["manning"]))
	var vc := 6.0 * sqrt(G * float(hf["rh"]))
	var lim := float(p["yd_max"])
	if float(hf["v"]) > vc:
		lim = min(lim, 0.5)
	var ok: bool = bool(hf["ok"]) and float(hf["yd"]) <= lim + 1e-9
	return {"d": dd, "cc_m": cc_m, "i": i_adot, "hf": hf, "vc": vc, "lim": lim, "ok": ok}


static func _dimensionar(p: Dictionary, t: Dictionary, idx: int, up_rows: Array, tx: Array) -> Dictionary:
	var msgs: Array = []
	var bad: Array = []
	var warn: Array = []
	var status := 0
	var l: float = float(t["L"])
	if l <= 0.0:
		msgs.append("Extensão inválida (precisa ser maior que zero); usado 1 m.")
		bad.append("L")
		status = 2
		l = 1.0
	var qi_m := 0.0
	var qf_m := 0.0
	var d_up := 0.0
	for u in up_rows:
		qi_m += float(u["qi_j"])
		qf_m += float(u["qf_j"])
		d_up = max(d_up, float(u["d"]))
	var qi_j: float = qi_m + float(tx[0]) * l + float(t.get("qc_i", 0.0))
	var qf_j: float = qf_m + float(tx[1]) * l + float(t.get("qc_f", 0.0))
	var qmin := float(p["q_min"])
	var qi_d: float = max(qi_j, qmin)
	var qf_d: float = max(qf_j, qmin)
	if qf_j < qmin:
		msgs.append("Vazão menor que a mínima: adotada %s L/s no cálculo." % _br(qmin, 2))
	var imin := _arred_cima(0.0055 * pow(qi_d, -0.47))

	var cands: Array = []
	var d_fix := float(t.get("d_fix", 0.0))
	if d_fix > 0.0:
		cands.append(d_fix)
	else:
		for dd in DIAMETROS:
			if float(dd) >= max(float(p["d_min"]), d_up):
				cands.append(float(dd))
		if cands.is_empty():
			cands.append(float(DIAMETROS[-1]))
	var esc: Dictionary = {}
	for dd in cands:
		esc = _avaliar(p, t, l, dd, up_rows, qf_d, imin)
		if bool(esc["ok"]):
			break

	var d: float = esc["d"]
	var i_adot: float = esc["i"]
	var cc_m: float = esc["cc_m"]
	var hf: Dictionary = esc["hf"]
	var hi := hidraulica(qi_d / 1000.0, d / 1000.0, i_adot, float(p["manning"]))
	var sigma: float = GAMMA * float(hi["rh"]) * i_adot
	var cc_j: float = cc_m - i_adot * l
	var prof_m: float = float(t["ct_m"]) - cc_m
	var prof_j: float = float(t["ct_j"]) - cc_j

	if d_fix > 0.0 and d_fix < d_up:
		msgs.append("Diâmetro fixado (%d mm) menor que o do trecho de montante (%d mm)." % [int(d_fix), int(d_up)])
		bad.append("d")
		status = 2
	if not bool(esc["ok"]):
		msgs.append("Lâmina final y/D = %s acima do limite de %s." % [_br(float(hf["yd"]), 2), _br(float(esc["lim"]), 2)])
		bad.append("yd_f")
		status = 2
	elif float(esc["lim"]) < float(p["yd_max"]):
		msgs.append("Velocidade final acima da crítica: lâmina limitada a 50%.")
	if sigma < float(p["tensao_min"]) - 1e-9:
		msgs.append("Tensão trativa %s Pa abaixo do mínimo de %s Pa." % [_br(sigma, 2), _br(float(p["tensao_min"]), 2)])
		bad.append("sigma")
		status = 2
	if float(hf["v"]) > float(p["v_max"]):
		msgs.append("Velocidade final %s m/s acima do máximo de %s m/s: prever degraus ou tubos de queda." % [_br(float(hf["v"]), 2), _br(float(p["v_max"]), 2)])
		bad.append("v_f")
		status = 2
	var pmax := float(p["prof_max"])
	if prof_m > pmax:
		msgs.append("Profundidade a montante %s m acima de %s m." % [_br(prof_m, 2), _br(pmax, 2)])
		warn.append("prof_m")
		status = max(status, 1)
	if prof_j > pmax:
		msgs.append("Profundidade a jusante %s m acima de %s m." % [_br(prof_j, 2), _br(pmax, 2)])
		warn.append("prof_j")
		status = max(status, 1)
	var degrau := 0.0
	for u in up_rows:
		degrau = max(degrau, float(u["cc_j"]) - cc_m)
	if degrau > float(p["degrau_max"]):
		msgs.append("Desnível de %s m no %s: prever tubo de queda." % [_br(degrau, 2), str(t["pv_m"])])
		warn.append("cc_m")
		status = max(status, 1)
	if i_adot > imin + 1e-6 and float(t["ct_m"]) - float(t["ct_j"]) > 0.0:
		msgs.append("Declividade acompanha o terreno.")

	return {
		"idx": idx, "coletor": str(t["coletor"]), "trecho": str(t["trecho"]),
		"pv_m": str(t["pv_m"]), "pv_j": str(t["pv_j"]), "L": l,
		"ct_m": float(t["ct_m"]), "ct_j": float(t["ct_j"]),
		"qi_m": qi_m, "qf_m": qf_m, "qi_j": qi_j, "qf_j": qf_j, "qi_d": qi_d, "qf_d": qf_d,
		"d": d, "i": i_adot, "imin": imin, "cc_m": cc_m, "cc_j": cc_j,
		"prof_m": prof_m, "prof_j": prof_j,
		"yd_i": float(hi["yd"]), "yd_f": float(hf["yd"]), "v_i": float(hi["v"]), "v_f": float(hf["v"]),
		"vc": float(esc["vc"]), "sigma": sigma, "yd_lim": float(esc["lim"]), "degrau": degrau,
		"status": status, "msgs": msgs, "bad": bad, "warn": warn,
	}


static func _br(v: float, dec: int) -> String:
	return (("%." + str(dec) + "f") % v).replace(".", ",")
