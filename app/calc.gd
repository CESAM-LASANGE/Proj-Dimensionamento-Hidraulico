extends RefCounted
## Motor de cálculo: dimensionamento de redes coletoras de esgoto sanitário
## (critérios da NBR 9649), quantitativos e orçamento — conforme o manual do CEsg.

const Db = preload("res://db.gd")
const Net = preload("res://net.gd")
const Cadastro = preload("res://cadastro.gd")

## Versão do motor de cálculo (entra no identificador de rastreabilidade dos resultados).
const MOTOR_VERSAO := "motor-3.1"
## Configuração normativa adotada (aparece no memorial).
const NORMA := "ABNT NBR 9649:1986 (projeto de redes coletoras de esgoto sanitário) — critérios: vazão mínima, tensão trativa, lâmina máxima 75% / 50%, velocidade crítica"

const G := 9.81
const GAMMA := 10000.0 # peso específico do esgoto (N/m3)
const NU := 1.01e-6 # viscosidade cinemática (m2/s)
const THETA_MAX := 5.278 # ângulo central de vazão máxima em seção circular
const BERCO := 0.15 # altura do berço (m): prof. da vala = prof. do coletor + berço
const YD_MAX := 0.75
const CRITERIOS := ["Global", "Cotas de PV's", "Curvas de Nível", "Pontos Cotados"]

# Ajuste de rugosidade pela velocidade (curvas lidas dos gráficos do manual, 4.1.1).
# Índice 0 = inferior (otimista), 1 = superior (pessimista). Pares [v (m/s), valor].
const CURVA_N := [
	[[0.5, 0.0118], [1.0, 0.0104], [1.5, 0.0094], [2.0, 0.0088]],
	[[0.5, 0.0128], [1.0, 0.0112], [1.5, 0.0100], [2.0, 0.0092]],
]
const CURVA_K := [
	[[0.5, 1.00], [0.75, 0.45], [1.0, 0.25], [1.5, 0.10], [2.0, 0.05]],
	[[0.5, 1.40], [0.75, 0.75], [1.0, 0.45], [1.5, 0.18], [2.0, 0.08]],
]


static func default_params() -> Dictionary:
	return {
		# Dados de consumo
		"pop_ini": 1500.0, "qpc_ini": 200.0, "c_ini": 0.8, "k2_ini": 1.5,
		"pop_fin": 2500.0, "qpc_fin": 200.0, "c_fin": 0.8, "k1": 1.2, "k2_fin": 1.5,
		# Dados gerais
		"q_min": 1.5, "d_min": 150.0, "infiltracao": 0.0, "recob_min": 1.35, "prof_max": 4.5,
		"tensao_min": 1.0, "v_max": 5.0, "degrau_min": 0.05, "degrau_max": 0.65, "i_min_constr": 0.0005,
		"dist_max_pv": 100.0, "num_auto": false,
		# Critérios de cálculo
		"metodo": 1, # 0 = Manning, 1 = Fórmula Universal
		"ajuste_rug": 0, # 0 = inferior (otimista), 1 = superior (pessimista), 2 = valor do banco
		"cotas_interm": 0, # 0 = só cotas de PVs, 1 = curvas de nível, 2 = pontos cotados
		"rede_plastica": true, "escoramento_auto": true,
	}


# ------------------------------------------------------------------ hidráulica

static func _interp(tab: Array, v: float) -> float:
	if v <= float(tab[0][0]):
		return float(tab[0][1])
	for k in range(1, tab.size()):
		if v <= float(tab[k][0]):
			var a: Array = tab[k - 1]
			var b: Array = tab[k]
			return lerpf(float(a[1]), float(b[1]), (v - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(tab[-1][1])


static func _vel(rh: float, i: float, metodo: int, val: float) -> float:
	if rh <= 0.0 or i <= 0.0:
		return 0.0
	if metodo == 0:
		return pow(rh, 2.0 / 3.0) * sqrt(i) / val
	var s := sqrt(8.0 * G * rh * i)
	var arg := (val / 1000.0) / (14.8 * rh) + 2.51 * NU / (4.0 * rh * s)
	return -2.0 * s * log(arg) / log(10.0)


static func _q_theta(th: float, d: float, i: float, metodo: int, val: float) -> float:
	var a := d * d / 8.0 * (th - sin(th))
	var rh := a / (d * th / 2.0)
	return a * _vel(rh, i, metodo, val)


static func _resolve(q: float, d: float, i: float, metodo: int, val: float) -> Dictionary:
	var qmax := _q_theta(THETA_MAX, d, i, metodo, val)
	if q > qmax:
		var af := PI * d * d / 4.0
		return {"ok": false, "yd": 1.0, "v": q / af, "rh": d / 4.0}
	var lo := 0.0001
	var hi := THETA_MAX
	for _k in 48:
		var mid := (lo + hi) / 2.0
		if _q_theta(mid, d, i, metodo, val) < q:
			lo = mid
		else:
			hi = mid
	var th := (lo + hi) / 2.0
	var a := d * d / 8.0 * (th - sin(th))
	return {"ok": true, "yd": (1.0 - cos(th / 2.0)) / 2.0, "v": q / a, "rh": a / (d * th / 2.0)}


## Escoamento uniforme em seção circular parcialmente cheia.
## q em m3/s, d em m, i em m/m. rug = {metodo, n, k (mm), ajuste}.
static func escoamento(q: float, d: float, i: float, rug: Dictionary) -> Dictionary:
	if q <= 0.0 or i <= 0.0 or d <= 0.0:
		return {"ok": false, "yd": 0.0, "v": 0.0, "rh": 0.0, "rug": 0.0}
	var metodo := int(rug["metodo"])
	var aj := int(rug["ajuste"])
	var val: float = float(rug["n"]) if metodo == 0 else float(rug["k"])
	var res := _resolve(q, d, i, metodo, val)
	if aj != 2:
		var tab: Array = CURVA_N[aj] if metodo == 0 else CURVA_K[aj]
		for _k in 6:
			var novo := _interp(tab, float(res["v"]))
			var conv := absf(novo - val) <= absf(val) * 0.002
			val = novo
			res = _resolve(q, d, i, metodo, val)
			if conv:
				break
	res["rug"] = val
	return res


static func _ceil4(v: float) -> float:
	return ceil(v * 10000.0 - 1e-6) / 10000.0


static func _floor4(v: float) -> float:
	return floor(v * 10000.0 + 1e-6) / 10000.0


## Declividade que produz a tensão trativa mínima com a vazão inicial.
static func i_tensao(q: float, d: float, rug: Dictionary, smin: float) -> float:
	var i := 0.0055 * pow(maxf(q * 1000.0, 0.1), -0.47)
	if smin <= 0.0:
		return 0.0
	for _k in 30:
		var h := escoamento(q, d, i, rug)
		if not bool(h["ok"]):
			i = minf(i * 1.6, 1.0)
			continue
		var s := GAMMA * float(h["rh"]) * i
		if s <= 0.0:
			i = minf(i * 2.0, 1.0)
			continue
		var r := smin / s
		if absf(r - 1.0) < 0.0005:
			break
		i = clampf(i * pow(r, 1.4), 1e-6, 1.0)
	return i


## Maior declividade para a qual a velocidade não passa de vmax.
static func i_vmax(q: float, d: float, rug: Dictionary, vmax: float) -> float:
	var lo := 1e-6
	var hi := 1.0
	if float(escoamento(q, d, hi, rug)["v"]) <= vmax:
		return hi
	for _k in 40:
		var mid := sqrt(lo * hi)
		if float(escoamento(q, d, mid, rug)["v"]) > vmax:
			hi = mid
		else:
			lo = mid
	return lo


# ------------------------------------------------------------------ grandezas usadas pelas telas
# (as telas não recalculam nada por conta própria: chamam estas funções)

static func declividade(cota_montante: float, cota_jusante: float, extensao: float) -> float:
	return (cota_montante - cota_jusante) / maxf(extensao, 0.01)


static func profundidade(cota_terreno: float, cota_coletor: float) -> float:
	return cota_terreno - cota_coletor


# ------------------------------------------------------------------ validação (EVAL-104 / EVAL-105)

const PARAMS_ROTULOS := {
	"pop_ini": "População inicial", "pop_fin": "População final",
	"qpc_ini": "Consumo efetivo per capita inicial", "qpc_fin": "Consumo efetivo per capita final",
	"c_ini": "Coeficiente de retorno inicial", "c_fin": "Coeficiente de retorno final",
	"k1": "Coeficiente K1", "k2_ini": "Coeficiente K2 inicial", "k2_fin": "Coeficiente K2 final",
	"q_min": "Vazão mínima", "d_min": "Diâmetro mínimo", "infiltracao": "Taxa de infiltração",
	"recob_min": "Recobrimento mínimo", "prof_max": "Profundidade máxima", "tensao_min": "Tensão trativa mínima",
	"v_max": "Velocidade máxima", "degrau_min": "Altura de degrau mínima", "degrau_max": "Altura de degrau máxima",
	"i_min_constr": "Declividade mínima construtiva", "dist_max_pv": "Distância máxima entre PVs",
}


## Lista de erros impeditivos nos parâmetros. Vazia = parâmetros aceitos.
static func validar_params(p: Dictionary) -> Array:
	var erros: Array = []
	var padrao := default_params()
	for k in PARAMS_ROTULOS.keys():
		var v = p.get(k, padrao[k])
		if not (v is float or v is int) or is_nan(float(v)) or is_inf(float(v)):
			erros.append("%s inválido(a): valor não numérico (%s)." % [PARAMS_ROTULOS[k], str(v)])
	if not erros.is_empty():
		return erros
	var f := func(k): return float(p.get(k, padrao[k]))
	for k in ["pop_ini", "pop_fin", "infiltracao", "degrau_min", "degrau_max"]:
		if f.call(k) < 0.0:
			erros.append("%s não pode ser negativo(a) (%s)." % [PARAMS_ROTULOS[k], _br(f.call(k), 2)])
	for k in ["qpc_ini", "qpc_fin", "q_min", "d_min", "recob_min", "prof_max", "tensao_min", "v_max", "i_min_constr", "dist_max_pv"]:
		if f.call(k) <= 0.0:
			erros.append("%s deve ser maior que zero (%s)." % [PARAMS_ROTULOS[k], _br(f.call(k), 4)])
	for k in ["c_ini", "c_fin"]:
		if f.call(k) <= 0.0 or f.call(k) > 1.0:
			erros.append("%s deve estar entre 0 e 1 (%s)." % [PARAMS_ROTULOS[k], _br(f.call(k), 2)])
	for k in ["k1", "k2_ini", "k2_fin"]:
		if f.call(k) < 1.0 or f.call(k) > 3.0:
			erros.append("%s deve estar entre 1,0 e 3,0 (%s)." % [PARAMS_ROTULOS[k], _br(f.call(k), 2)])
	if f.call("degrau_min") > f.call("degrau_max"):
		erros.append("Altura de degrau mínima (%s m) maior que a máxima (%s m)." % [_br(f.call("degrau_min"), 2), _br(f.call("degrau_max"), 2)])
	if f.call("prof_max") <= f.call("recob_min"):
		erros.append("Profundidade máxima (%s m) deve ser maior que o recobrimento mínimo (%s m)." % [_br(f.call("prof_max"), 2), _br(f.call("recob_min"), 2)])
	if f.call("v_max") > 10.0:
		erros.append("Velocidade máxima acima de 10 m/s (%s) não é aceitável." % _br(f.call("v_max"), 2))
	if not int(p.get("metodo", 1)) in [0, 1] or not int(p.get("ajuste_rug", 0)) in [0, 1, 2] or not int(p.get("cotas_interm", 0)) in [0, 1, 2]:
		erros.append("Critérios de cálculo com opção inexistente (método, ajuste de rugosidade ou cotas intermediárias).")
	return erros


## Erros estruturais da rede (impedem o cálculo).
static func validar_rede(proj: Dictionary) -> Array:
	var erros: Array = []
	var nodes := Net.node_map(proj)
	var trs: Array = proj.get("trechos", [])
	if trs.is_empty():
		erros.append("A rede não tem trechos. Use o Traçado para desenhar os coletores.")
		return erros
	for t in trs:
		var ni := int(t.get("ni", -1))
		var nf := int(t.get("nf", -1))
		if not nodes.has(ni):
			erros.append("Trecho %s: nó inicial (id %d) inexistente." % [str(t.get("nome", "?")), ni])
		if not nodes.has(nf):
			erros.append("Trecho %s: nó final (id %d) inexistente." % [str(t.get("nome", "?")), nf])
		if ni == nf:
			erros.append("Trecho %s sem conexão: começa e termina no mesmo nó." % str(t.get("nome", "?")))
	var saidas := {}
	for t in trs:
		saidas[int(t["ni"])] = int(saidas.get(int(t["ni"]), 0)) + 1
	for nid in saidas.keys():
		if int(saidas[nid]) > 1:
			var nome: String = str(nodes[nid]["nome"]) if nodes.has(nid) else str(nid)
			erros.append("O nó %s tem %d trechos saindo dele (múltiplas saídas); cada nó deve ter uma única saída." % [nome, saidas[nid]])
	if bool(Net.ordem(proj)["ciclo"]):
		erros.append("Há trechos formando um laço (ciclo): a água voltaria ao mesmo nó. Confira o sentido dos trechos.")
	return erros


# ------------------------------------------------------------------ dimensionamento

static func taxas(p: Dictionary, ltot: float) -> Array:
	if ltot <= 0.0:
		return [0.0, 0.0]
	var inf := float(p["infiltracao"]) / 1000.0
	var ti := float(p["c_ini"]) * float(p["qpc_ini"]) * float(p["k2_ini"]) * float(p["pop_ini"]) / (86400.0 * ltot) + inf
	var tf := float(p["c_fin"]) * float(p["qpc_fin"]) * float(p["k1"]) * float(p["k2_fin"]) * float(p["pop_fin"]) / (86400.0 * ltot) + inf
	return [ti, tf]


static func _crit(t: Dictionary, p: Dictionary) -> int:
	var c := CRITERIOS.find(str(t.get("crit", "Global")))
	if c <= 0:
		return int(p["cotas_interm"])
	return c - 1


## Dimensiona toda a rede. cota_fn(w: Vector2, criterio: int) -> float (NAN se não houver)
## é usada para as cotas intermediárias do terreno ao longo dos trechos.
static func calcular(proj: Dictionary, db: Dictionary, cota_fn: Callable) -> Dictionary:
	var p: Dictionary = proj["params"]
	var nodes := Net.node_map(proj)
	var trs := Net.trecho_map(proj)
	var res := {"ok": false, "aprovado": false, "rows": {}, "nodes": {}, "obs": [], "erros": [], "luz": "vermelha",
		"tx_i": 0.0, "tx_f": 0.0, "ltot": 0.0, "motor": MOTOR_VERSAO}
	# erros impeditivos: o cálculo não é feito e nenhum resultado é apresentado como válido
	for e in validar_params(p):
		res["erros"].append("Parâmetro: " + e)
	for e in validar_rede(proj):
		res["erros"].append(e)
	for e in Db.validar(db, proj):
		res["erros"].append(e)
	if not res["erros"].is_empty():
		for e in res["erros"]:
			res["obs"].append(["Rede", e])
		return res
	var ord := Net.ordem(proj)
	var lig := Net.ligacoes(proj)
	var inc: Dictionary = lig["inc"]
	var out: Dictionary = lig["out"]
	var extra: Dictionary = Cadastro.vazoes_por_trecho(proj)
	var ltot := 0.0
	var comp := {}
	for tid in trs.keys():
		var l := Net.comprimento(nodes, trs[tid])
		comp[tid] = l
		ltot += l
	var tx := taxas(p, ltot)
	res["tx_i"] = tx[0]
	res["tx_f"] = tx[1]
	res["ltot"] = ltot
	var rows: Dictionary = res["rows"]
	for tid in ord["order"]:
		var t: Dictionary = trs[tid]
		if not nodes.has(int(t["ni"])) or not nodes.has(int(t["nf"])):
			continue
		var up_rows: Array = []
		for u in inc.get(int(t["ni"]), []):
			if rows.has(u):
				up_rows.append(rows[u])
		rows[tid] = _dim(p, db, t, nodes[int(t["ni"])], nodes[int(t["nf"])], float(comp[tid]), up_rows, tx, cota_fn, float(extra.get(tid, 0.0)))
	# nós: tipo calculado, degraus e tubos de queda
	for nid in nodes.keys():
		var nd: Dictionary = nodes[nid]
		var tipo := str(nd["tipo"])
		var cc_min := INF
		var conex: Array = []
		var queda := 0.0
		var r_out = null
		for tid in out.get(nid, []):
			if rows.has(tid):
				r_out = rows[tid]
		for tid in inc.get(nid, []):
			if not rows.has(tid):
				continue
			var r: Dictionary = rows[tid]
			cc_min = minf(cc_min, float(r["cc_j"]))
			conex.append({"trecho": r["nome"], "d": r["d"], "rec": r["rec_j"], "cc": r["cc_j"], "prof": r["pc_j"]})
			if r_out != null:
				queda = maxf(queda, float(r["cc_j"]) - float(r_out["cc_m"]))
		if r_out != null:
			cc_min = minf(cc_min, float(r_out["cc_m"]))
			conex.append({"trecho": r_out["nome"], "d": r_out["d"], "rec": r_out["rec_m"], "cc": r_out["cc_m"], "prof": r_out["pc_m"]})
		var tq := queda > float(p["degrau_max"]) + 1e-6
		var plast := bool(p["rede_plastica"])
		var tipo_calc := tipo
		if tq and tipo in ["PV", "TR", "TQ", "TT"]:
			tipo_calc = "TT" if plast else "TQ"
		elif plast and tipo == "PV":
			tipo_calc = "TR"
		if cc_min == INF:
			cc_min = float(nd["ct"])
		var prof := float(nd["ct"]) - cc_min
		res["nodes"][nid] = {"tipo": tipo_calc, "queda": queda, "tq": tq, "prof": prof, "cc_min": cc_min, "conexoes": conex}
		if tq and r_out != null:
			r_out["obs"].append("Tubo de queda no nó %s (desnível de %s m)." % [str(nd["nome"]), _br(queda, 2)])
			if int(r_out["status"]) == 0:
				r_out["status"] = 1
	# observações na ordem dos coletores
	for sq in Net.sequencias(proj):
		for tid in sq["trechos"]:
			if not rows.has(tid):
				continue
			var r: Dictionary = rows[tid]
			for m in r["obs"]:
				res["obs"].append([str(r["nome"]), m])
	for e in res["erros"]:
		res["obs"].push_front(["Rede", e])
	res["ok"] = rows.size() == trs.size()
	var impeditivo := false
	for r in rows.values():
		if int(r["status"]) >= 2:
			impeditivo = true
	# aprovado = calculado sem erro estrutural e sem restrição impeditiva (advertências são permitidas)
	res["aprovado"] = bool(res["ok"]) and not impeditivo
	if not bool(res["ok"]) or impeditivo:
		res["luz"] = "vermelha"
	elif not res["obs"].is_empty():
		res["luz"] = "amarela"
	else:
		res["luz"] = "verde"
	return res


static func _avaliar(p: Dictionary, t: Dictionary, dd: float, l: float, ct_m: float, ct_j: float, recob: float,
		up_rows: Array, qd_i: float, qd_f: float, rug: Dictionary, amostras: Array) -> Dictionary:
	var d := dd / 1000.0
	var imin := _ceil4(maxf(i_tensao(qd_i / 1000.0, d, rug, float(p["tensao_min"])), float(p["i_min_constr"])))
	var cc_m: float
	var cc_j: float
	var i: float
	var vred := false
	if bool(t.get("fixa_cotas", false)):
		cc_m = float(t["cc_m"])
		cc_j = float(t["cc_j"])
		i = (cc_m - cc_j) / l
	else:
		var cc_m0 := ct_m - recob - d
		for u in up_rows:
			# alinhamento pela geratriz superior
			cc_m0 = minf(cc_m0, float(u["cc_j"]) + float(u["d"]) / 1000.0 - d)
		var cc_jmax := ct_j - recob - d
		i = _ceil4(maxf(imin, (cc_m0 - cc_jmax) / l))
		cc_m = cc_m0
		# velocidade máxima: reduz a declividade e cria um degrau no nó de montante
		if float(escoamento(qd_f / 1000.0, d, i, rug)["v"]) > float(p["v_max"]) and i > imin:
			var iv := _floor4(i_vmax(qd_f / 1000.0, d, rug, float(p["v_max"])))
			if iv >= imin and iv < i:
				var queda := cc_m0 - (cc_jmax + iv * l)
				queda = maxf(queda, float(p["degrau_min"]))
				cc_m = cc_m0 - queda
				i = maxf(imin, _ceil4((cc_m - cc_jmax) / l))
				vred = true
		# cotas intermediárias do terreno ao longo do trecho
		for a in amostras:
			cc_m = minf(cc_m, float(a[1]) - recob - d + i * float(a[0]))
		cc_j = cc_m - i * l
	var hf := escoamento(qd_f / 1000.0, d, i, rug)
	var vc := 6.0 * sqrt(G * float(hf["rh"]))
	var lim := YD_MAX
	if float(hf["v"]) > vc:
		lim = 0.5
	var ok: bool = i > 0.0 and bool(hf["ok"]) and float(hf["yd"]) <= lim + 1e-9
	return {"d": dd, "cc_m": cc_m, "cc_j": cc_j, "i": i, "imin": imin, "hf": hf, "vc": vc, "lim": lim, "ok": ok, "vred": vred}


static func _dim(p: Dictionary, db: Dictionary, t: Dictionary, ni: Dictionary, nf: Dictionary, l: float,
		up_rows: Array, tx: Array, cota_fn: Callable, q_lig := 0.0) -> Dictionary:
	var obs: Array = []
	var status := 0
	if l <= 0.0:
		obs.append("Verifique: extensão nula; adotado 1 m.")
		status = 2
		l = 1.0
	# vazões pontuais do nó + contribuição de ligações/bacias atribuídas a este trecho
	var qp_i := float(ni.get("qp_i", 0.0)) + q_lig
	var qp_f := float(ni.get("qp_f", 0.0)) + q_lig
	var qm_i := 0.0
	var qm_f := 0.0
	var d_up := 0.0
	for u in up_rows:
		qm_i += float(u["qj_i"])
		qm_f += float(u["qj_f"])
		d_up = maxf(d_up, float(u["d"]))
	var ctr_i := float(tx[0]) * l
	var ctr_f := float(tx[1]) * l
	var qj_i := qm_i + qp_i + ctr_i
	var qj_f := qm_f + qp_f + ctr_f
	var qd_i := maxf(qj_i, float(p["q_min"]))
	var qd_f := maxf(qj_f, float(p["q_min"]))
	var mrow := Db.material(db, str(t.get("material", "")))
	var mat := str(mrow["nome"])
	var rug := {"metodo": int(p["metodo"]), "n": float(mrow["n"]), "k": float(mrow["k"]), "ajuste": int(p["ajuste_rug"])}
	var recob := float(t.get("recob", 0.0))
	if recob <= 0.0:
		recob = float(p["recob_min"])
	var pmax := float(t.get("pmax", 0.0))
	if pmax <= 0.0:
		pmax = float(p["prof_max"])
	var ct_m := float(ni["ct"])
	var ct_j := float(nf["ct"])
	var amostras: Array = []
	var crit := _crit(t, p)
	if crit != 0 and l > 15.0 and cota_fn.is_valid():
		var nseg := int(ceil(l / 10.0))
		for s in range(1, nseg):
			var f := float(s) / nseg
			var w := Net.pos(ni).lerp(Net.pos(nf), f)
			var z: float = cota_fn.call(w, crit)
			if not is_nan(z):
				amostras.append([l * f, z])
	var cands: Array = []
	if bool(t.get("fixa_d", false)) and float(t.get("d", 0.0)) > 0.0:
		cands.append(float(t["d"]))
	else:
		var todos := Db.diametros(db, mat)
		for dd in todos:
			if float(dd) >= maxf(float(p["d_min"]), d_up) - 0.5:
				cands.append(float(dd))
		if cands.is_empty():
			cands.append(float(todos[-1]) if todos.size() > 0 else maxf(float(p["d_min"]), d_up))
			obs.append("Verifique: nenhum diâmetro cadastrado para %s atende ao mínimo." % mat)
	var esc: Dictionary = {}
	for dd in cands:
		esc = _avaliar(p, t, float(dd), l, ct_m, ct_j, recob, up_rows, qd_i, qd_f, rug, amostras)
		if bool(esc["ok"]):
			break
	var d: float = esc["d"]
	var i: float = esc["i"]
	var cc_m: float = esc["cc_m"]
	var cc_j: float = esc["cc_j"]
	var hf: Dictionary = esc["hf"]
	var hi := escoamento(qd_i / 1000.0, d / 1000.0, i, rug)
	var sigma := GAMMA * float(hi["rh"]) * i
	var pc_m := ct_m - cc_m
	var pc_j := ct_j - cc_j
	var rec_m := pc_m - d / 1000.0
	var rec_j := pc_j - d / 1000.0
	if i <= 0.0:
		obs.append("Verifique: declividade do trecho nula ou negativa.")
		status = 2
	if bool(t.get("fixa_d", false)) and d < d_up - 0.5:
		obs.append("Verifique: diâmetro fixado menor que o do trecho de montante.")
		status = maxi(status, 1)
	if not bool(esc["ok"]) and i > 0.0:
		obs.append("Verifique: lâmina final y/D = %s maior que o limite de %s." % [_br(float(hf["yd"]), 2), _br(float(esc["lim"]), 2)])
		status = 2
	if sigma < float(p["tensao_min"]) - 0.005:
		obs.append("Verifique: tensão trativa de %s Pa menor que a mínima." % _br(sigma, 2))
		status = maxi(status, 1)
	if float(hf["v"]) > float(p["v_max"]) + 1e-6:
		obs.append("Verifique: velocidade final de %s m/s maior que a máxima." % _br(float(hf["v"]), 2))
		status = maxi(status, 1)
	if float(esc["lim"]) < YD_MAX and bool(esc["ok"]):
		obs.append("Velocidade final maior que a crítica: lâmina limitada a 50%.")
		status = maxi(status, 1)
	if pc_m > pmax + 1e-6:
		obs.append("Verifique: Prof. a montante é maior que prof. máxima")
		status = maxi(status, 1)
	if pc_j > pmax + 1e-6:
		obs.append("Verifique: Prof. de jusante é maior que prof. máxima")
		status = maxi(status, 1)
	if rec_m < recob - 0.005 or rec_j < recob - 0.005:
		obs.append("Verifique: recobrimento menor que o mínimo (%s m)." % _br(recob, 2))
		status = maxi(status, 1)
	if l > float(p["dist_max_pv"]) + 1e-6:
		obs.append("Verifique: Compr. do trecho maior que dist. máx. entre PV's")
		status = maxi(status, 1)
	if not bool(ni.get("ct_ok", true)) or not bool(nf.get("ct_ok", true)):
		obs.append("Verifique: cota de terreno não confirmada em um dos nós.")
		status = maxi(status, 1)
	var pvala_m := pc_m + BERCO
	var pvala_j := pc_j + BERCO
	var esc_nome := str(t.get("escoramento", ""))
	if bool(p["escoramento_auto"]):
		esc_nome = Db.escoramento_por_prof(db, (pvala_m + pvala_j) / 2.0)
	var larg := Db.largura_vala(db, mat, d, maxf(pvala_m, pvala_j), esc_nome)
	return {
		"id": int(t["id"]), "nome": str(t["nome"]), "coletor": str(t.get("coletor", "")),
		"ni": int(ni["id"]), "nf": int(nf["id"]), "pv_i": str(ni["nome"]), "pv_f": str(nf["nome"]),
		"L": l, "material": mat, "txi": float(tx[0]) * 1000.0, "txf": float(tx[1]) * 1000.0,
		"ctr_i": ctr_i, "ctr_f": ctr_f, "qp_i": qp_i, "qp_f": qp_f,
		"q_lig": q_lig, "qm_i": qm_i, "qm_f": qm_f, "qj_i": qj_i, "qj_f": qj_f, "qd_i": qd_i, "qd_f": qd_f,
		"d": d, "i": i, "imin": float(esc["imin"]), "ct_m": ct_m, "ct_j": ct_j, "cc_m": cc_m, "cc_j": cc_j,
		"rec_m": rec_m, "rec_j": rec_j, "pc_m": pc_m, "pc_j": pc_j, "pvala_m": pvala_m, "pvala_j": pvala_j,
		"yd_i": float(hi["yd"]), "yd_f": float(hf["yd"]), "v_i": float(hi["v"]), "v_f": float(hf["v"]),
		"vc": float(esc["vc"]), "sigma": sigma, "rug_i": float(hi["rug"]), "rug_f": float(hf["rug"]),
		"lim": float(esc["lim"]), "larg": larg, "esc": esc_nome, "vred": bool(esc["vred"]),
		"superficie": str(t.get("superficie", "")), "aterro": bool(t.get("aterro", false)),
		"situacao": str(t.get("situacao", "")), "status": status, "obs": obs,
	}


# ------------------------------------------------------------------ quantitativos e orçamento

static func orcamento(proj: Dictionary, db: Dictionary, res: Dictionary) -> Dictionary:
	var p: Dictionary = proj["params"]
	var rows: Dictionary = res.get("rows", {})
	var tubos := {}
	var tubos_ord: Array = []
	var pav := {}
	var escor := {}
	var vol := [0.0, 0.0, 0.0, 0.0]
	var reaterro := 0.0
	var faixas := [0.0, 2.0, 4.0, 6.0, 1e9]
	for r in rows.values():
		var chave := "%s|%d" % [r["material"], int(r["d"])]
		if not tubos.has(chave):
			tubos[chave] = 0.0
			tubos_ord.append(chave)
		tubos[chave] = float(tubos[chave]) + float(r["L"])
		var l := float(r["L"])
		var w := float(r["larg"])
		var h1 := float(r["pvala_m"])
		var h2 := float(r["pvala_j"])
		var sup := str(r["superficie"])
		pav[sup] = float(pav.get(sup, 0.0)) + w * l
		var en := str(r["esc"])
		escor[en] = float(escor.get(en, 0.0)) + 2.0 * (h1 + h2) / 2.0 * l
		var nseg := 20
		var dx := l / nseg
		for s in nseg:
			var h := lerpf(h1, h2, (s + 0.5) / nseg)
			for k in 4:
				vol[k] += w * dx * clampf(h - float(faixas[k]), 0.0, float(faixas[k + 1]) - float(faixas[k]))
		var escav := w * l * (h1 + h2) / 2.0
		var dm := float(r["d"]) / 1000.0
		var reat := maxf(escav - PI * dm * dm / 4.0 * l, 0.0)
		if bool(r["aterro"]):
			reat *= 1.30
		reaterro += reat
	var pvs := {}
	var pvs_ord: Array = []
	var queda_total := 0.0
	var aces := {}
	var reds := {}
	var plast := bool(p["rede_plastica"])
	var lig := Net.ligacoes(proj)
	var nodes := Net.node_map(proj)
	for nid in res.get("nodes", {}).keys():
		var nr: Dictionary = res["nodes"][nid]
		var sig := str(nr["tipo"])
		if not pvs.has(sig):
			pvs[sig] = [0, 0.0]
			pvs_ord.append(sig)
		pvs[sig][0] += 1
		pvs[sig][1] += float(nr["prof"])
		if bool(nr["tq"]):
			queda_total += float(nr["queda"])
		if not plast:
			continue
		var out_r = null
		for tid in lig["out"].get(nid, []):
			if rows.has(tid):
				out_r = rows[tid]
		if out_r == null:
			continue
		if sig == "TL":
			for a in db["acessorios"]:
				if str(a["uso"]) == "Terminal de limpeza" and absf(float(a["d"]) - float(out_r["d"])) < 0.5:
					aces[str(a["nome"])] = int(aces.get(str(a["nome"]), 0)) + 1
		for tid in lig["inc"].get(nid, []):
			if not rows.has(tid):
				continue
			var du := float(rows[tid]["d"])
			var dj := float(out_r["d"])
			if du < dj - 0.5:
				var nome := ""
				for rd in db["reducoes"]:
					if absf(float(rd["d1"]) - dj) < 0.5 and absf(float(rd["d2"]) - du) < 0.5:
						nome = str(rd["nome"])
				if nome == "":
					nome = "Redução %dx%d (não cadastrada)" % [int(dj), int(du)]
				reds[nome] = int(reds.get(nome, 0)) + 1
	var linhas: Array = []
	var total := 0.0
	linhas.append({"tipo": "sec", "desc": "Trechos:", "c1": "Fornecimento", "c2": "Assentamento"})
	for chave in tubos_ord:
		var partes: PackedStringArray = str(chave).split("|")
		var tb := Db.tubo(db, partes[0], float(partes[1]))
		var c1 := float(tb.get("fornecimento", 0.0))
		var c2 := float(tb.get("assentamento", 0.0))
		var q := float(tubos[chave])
		var tot := q * (c1 + c2)
		total += tot
		linhas.append({"tipo": "item", "desc": "%s - ø%s" % [partes[0], partes[1]], "q": q, "un": "m", "c1": c1, "c2": c2, "total": tot})
	linhas.append({"tipo": "vazio"})
	linhas.append({"tipo": "sec", "desc": "Poços de Visita e similares:", "c2": "Custo/m prof."})
	pvs_ord.sort()
	for sig in pvs_ord:
		var pr := Db.pv(db, sig)
		var c2 := float(pr["custo"])
		var tot := c2 * float(pvs[sig][1])
		total += tot
		linhas.append({"tipo": "item", "desc": "%s (%s) — prof. total %s m" % [pr["nome"], pr["sigla_imp"], _br(float(pvs[sig][1]), 2)],
			"q": float(pvs[sig][0]), "un": "un", "c2": c2, "total": tot, "dec": 0})
	if queda_total > 0.0:
		linhas.append({"tipo": "item", "desc": "Comprimento dos trechos de queda", "q": queda_total, "un": "m"})
	linhas.append({"tipo": "vazio"})
	linhas.append({"tipo": "sec", "desc": "Reconstituição de pavimentos:", "c1": "Retirada", "c2": "Colocação"})
	for sup in pav.keys():
		var pr := Db.linha(db, "pavimentos", sup)
		var c1 := float(pr.get("retirada", 0.0))
		var c2 := float(pr.get("colocacao", 0.0))
		var tot := float(pav[sup]) * (c1 + c2)
		total += tot
		linhas.append({"tipo": "item", "desc": sup, "q": float(pav[sup]), "un": "m²", "c1": c1, "c2": c2, "total": tot})
	linhas.append({"tipo": "vazio"})
	linhas.append({"tipo": "sec", "desc": "Escoramento:"})
	for en in escor.keys():
		var c2 := float(Db.linha(db, "escoramentos", en).get("custo", 0.0))
		var tot := float(escor[en]) * c2
		total += tot
		linhas.append({"tipo": "item", "desc": en, "q": float(escor[en]), "un": "m²", "c2": c2, "total": tot})
	if not aces.is_empty() or not reds.is_empty():
		linhas.append({"tipo": "vazio"})
		linhas.append({"tipo": "sec", "desc": "Acessórios:"})
		for an in aces.keys():
			var c2 := float(Db.linha(db, "acessorios", an).get("custo", 0.0))
			var tot := c2 * int(aces[an])
			total += tot
			linhas.append({"tipo": "item", "desc": an, "q": float(aces[an]), "un": "un", "c2": c2, "total": tot, "dec": 0})
		for rn in reds.keys():
			var c2 := float(Db.linha(db, "reducoes", rn).get("custo", 0.0))
			var tot := c2 * int(reds[rn])
			total += tot
			linhas.append({"tipo": "item", "desc": rn, "q": float(reds[rn]), "un": "un", "c2": c2, "total": tot, "dec": 0})
	linhas.append({"tipo": "vazio"})
	linhas.append({"tipo": "total", "desc": "", "c2": "Total:", "total": total})
	linhas.append({"tipo": "vazio"})
	linhas.append({"tipo": "sec", "desc": "Volume de escavação:"})
	var rot := ["0 a 2 m", "2 a 4 m", "4 a 6 m", "Acima de 6 m"]
	var vt := 0.0
	for k in 4:
		vt += vol[k]
		linhas.append({"tipo": "item", "desc": rot[k], "q": vol[k], "un": "m³"})
	linhas.append({"tipo": "item", "desc": "Volume total", "q": vt, "un": "m³"})
	linhas.append({"tipo": "vazio"})
	linhas.append({"tipo": "item", "desc": "Volume de reaterro", "q": reaterro, "un": "m³"})
	return {"linhas": linhas, "total": total, "escavacao": vt, "reaterro": reaterro}


static func _br(v: float, dec: int) -> String:
	return (("%." + str(dec) + "f") % v).replace(".", ",")
