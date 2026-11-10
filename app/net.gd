extends RefCounted
## Estrutura da rede: nós (PVs, TLs, ...) e trechos ligando nós, agrupados em coletores.
## Funções auxiliares de grafo, numeração automática, rede de exemplo e migração
## de projetos da versão anterior (tabela).

const Db = preload("res://db.gd")


static func novo_projeto(params: Dictionary) -> Dictionary:
	return {
		"formato": "dimesgoto", "versao": 3,
		"info": {"projeto": "Novo projeto", "responsavel": "", "local": ""},
		"params": params.duplicate(true),
		"area": {"n0": 0.0, "e0": 0.0, "ln": 500.0, "le": 800.0, "grid": 50.0},
		"nodes": [], "trechos": [],
		"topo": {}, "imagem": "",
		"referencia": referencia_padrao(),
		"ligacoes": [], "bacias": [], "interferencias": {},
	}


## Referência espacial do projeto (T2-07 / EVAL-205).
static func referencia_padrao() -> Dictionary:
	return {"crs": "", "unidade_horizontal": "m", "unidade_vertical": "m", "datum_vertical": "não informado",
		"origem_topografia": "", "data_topografia": ""}


static func referencia_texto(proj: Dictionary) -> String:
	var r: Dictionary = proj.get("referencia", {})
	if str(r.get("crs", "")).strip_edges() == "":
		return "referência não informada"
	return "%s • unidades %s / %s • datum vertical: %s" % [r["crs"], r.get("unidade_horizontal", "m"),
		r.get("unidade_vertical", "m"), r.get("datum_vertical", "não informado")]


# ------------------------------------------------------------------ consultas

static func node_map(proj: Dictionary) -> Dictionary:
	var m := {}
	for n in proj["nodes"]:
		m[int(n["id"])] = n
	return m


static func trecho_map(proj: Dictionary) -> Dictionary:
	var m := {}
	for t in proj["trechos"]:
		m[int(t["id"])] = t
	return m


static func pos(n: Dictionary) -> Vector2:
	return Vector2(float(n["e"]), float(n["n"]))


static func comprimento(nodes: Dictionary, t: Dictionary) -> float:
	if float(t.get("ext_fix", 0.0)) > 0.0:
		return float(t["ext_fix"])
	var a = nodes.get(int(t["ni"]))
	var b = nodes.get(int(t["nf"]))
	if a == null or b == null:
		return 0.0
	return pos(a).distance_to(pos(b))


## {"inc": {no: [trechos que chegam]}, "out": {no: [trechos que saem]}}
static func ligacoes(proj: Dictionary) -> Dictionary:
	var inc := {}
	var out := {}
	for n in proj["nodes"]:
		inc[int(n["id"])] = []
		out[int(n["id"])] = []
	for t in proj["trechos"]:
		var ni := int(t["ni"])
		var nf := int(t["nf"])
		if not out.has(ni):
			out[ni] = []
		if not inc.has(nf):
			inc[nf] = []
		out[ni].append(int(t["id"]))
		inc[nf].append(int(t["id"]))
	return {"inc": inc, "out": out}


## Ordem de cálculo (de montante para jusante). "ciclo" indica trechos em laço.
static func ordem(proj: Dictionary) -> Dictionary:
	var lig := ligacoes(proj)
	var inc: Dictionary = lig["inc"]
	var trs := trecho_map(proj)
	var pend := {}
	for tid in trs.keys():
		pend[tid] = inc.get(int(trs[tid]["ni"]), []).size()
	var fila: Array = []
	for t in proj["trechos"]:
		if int(pend[int(t["id"])]) == 0:
			fila.append(int(t["id"]))
	var out_ord: Array = []
	var k := 0
	var out: Dictionary = lig["out"]
	while k < fila.size():
		var tid: int = fila[k]
		k += 1
		out_ord.append(tid)
		var nf := int(trs[tid]["nf"])
		for t2 in out.get(nf, []):
			pend[t2] = int(pend[t2]) - 1
			if int(pend[t2]) == 0:
				fila.append(t2)
	return {"order": out_ord, "ciclo": out_ord.size() < trs.size()}


## Coletores na ordem em que aparecem; trechos de cada um em ordem de escoamento.
static func sequencias(proj: Dictionary) -> Array:
	var grupos := {}
	var ordem_col: Array = []
	for t in proj["trechos"]:
		var c := str(t.get("coletor", ""))
		if not grupos.has(c):
			grupos[c] = []
			ordem_col.append(c)
		grupos[c].append(t)
	var res: Array = []
	for c in ordem_col:
		var lst: Array = grupos[c]
		var por_ni := {}
		var nfs := {}
		for t in lst:
			por_ni[int(t["ni"])] = t
			nfs[int(t["nf"])] = true
		var usados := {}
		var seq: Array = []
		for t in lst:
			if nfs.has(int(t["ni"])):
				continue
			var cur = t
			while cur != null and not usados.has(int(cur["id"])):
				usados[int(cur["id"])] = true
				seq.append(int(cur["id"]))
				cur = por_ni.get(int(cur["nf"]))
		for t in lst:
			if not usados.has(int(t["id"])):
				seq.append(int(t["id"]))
		res.append({"nome": c, "trechos": seq})
	return res


static func coletores_do_no(proj: Dictionary, nid: int) -> Array:
	var out: Array = []
	for t in proj["trechos"]:
		if int(t["ni"]) == nid or int(t["nf"]) == nid:
			var c := str(t.get("coletor", ""))
			if not c in out:
				out.append(c)
	return out


static func coletor_de_chegada(proj: Dictionary, nid: int) -> String:
	for t in proj["trechos"]:
		if int(t["nf"]) == nid:
			return str(t.get("coletor", ""))
	return ""


static func tem_saida(proj: Dictionary, nid: int) -> bool:
	for t in proj["trechos"]:
		if int(t["ni"]) == nid:
			return true
	return false


## O nó "ate" fica a jusante de "de"? (ligar ate→de criaria um laço)
static func alcanca(proj: Dictionary, de: int, ate: int) -> bool:
	var out := {}
	for t in proj["trechos"]:
		out[int(t["ni"])] = int(t["nf"])
	var cur := de
	var guard := 0
	while guard < 100000:
		if cur == ate:
			return true
		if not out.has(cur):
			return false
		cur = int(out[cur])
		guard += 1
	return true


static func achar_no(proj: Dictionary, nome: String) -> Dictionary:
	for n in proj["nodes"]:
		if str(n["nome"]).to_lower() == nome.to_lower():
			return n
	return {}


static func achar_trecho(proj: Dictionary, nome: String) -> Dictionary:
	for t in proj["trechos"]:
		if str(t["nome"]).to_lower() == nome.to_lower():
			return t
	return {}


# ------------------------------------------------------------------ edição

static func _novo_id(arr: Array) -> int:
	var m := 0
	for x in arr:
		m = maxi(m, int(x["id"]))
	return m + 1


static func coletor_novo(proj: Dictionary) -> String:
	var m := 0
	for t in proj["trechos"]:
		var c := str(t.get("coletor", ""))
		if c.begins_with("C") and c.substr(1).is_valid_int():
			m = maxi(m, c.substr(1).to_int())
	return "C%d" % (m + 1)


static func novo_no(proj: Dictionary, w: Vector2, ct: float, ct_ok: bool, tipo: String) -> Dictionary:
	var id := _novo_id(proj["nodes"])
	var n := {"id": id, "nome": str(id), "e": w.x, "n": w.y, "ct": ct, "ct_ok": ct_ok,
		"tipo": tipo, "qp_i": 0.0, "qp_f": 0.0}
	proj["nodes"].append(n)
	return n


static func trecho_padrao(db: Dictionary) -> Dictionary:
	return {
		"ext_fix": 0.0, "d": 0.0, "fixa_d": false, "cc_m": 0.0, "cc_j": 0.0, "fixa_cotas": false,
		"material": Db.material_padrao(db), "escoramento": Db.primeiro(db, "escoramentos", "Sem escoramento"),
		"superficie": Db.primeiro(db, "pavimentos", "Sem revestimento"), "aterro": false,
		"recob": 0.0, "pmax": 0.0, "situacao": Db.primeiro(db, "situacoes", "Rede Projetada"), "crit": "Global",
	}


static func novo_trecho(proj: Dictionary, db: Dictionary, ni: int, nf: int, coletor: String, base := {}) -> Dictionary:
	var id := _novo_id(proj["trechos"])
	var t := trecho_padrao(db)
	for k in base.keys():
		if t.has(k) and not k in ["ext_fix", "cc_m", "cc_j", "fixa_cotas", "fixa_d", "d"]:
			t[k] = base[k]
	t["id"] = id
	t["nome"] = "T%d" % id
	t["ni"] = ni
	t["nf"] = nf
	t["coletor"] = coletor
	proj["trechos"].append(t)
	return t


static func apagar_trechos(proj: Dictionary, ids: Dictionary) -> int:
	var antes: int = proj["trechos"].size()
	var novos: Array = []
	for t in proj["trechos"]:
		if not ids.has(int(t["id"])):
			novos.append(t)
	proj["trechos"] = novos
	var usados := {}
	for t in novos:
		usados[int(t["ni"])] = true
		usados[int(t["nf"])] = true
	var nn: Array = []
	for n in proj["nodes"]:
		if usados.has(int(n["id"])):
			nn.append(n)
	proj["nodes"] = nn
	return antes - novos.size()


## Translação paralela de um trecho (os dois nós andam "dist" metros para a esquerda ou
## direita de quem olha no sentido do escoamento). Retorna os nós movidos.
static func deslocar_trecho(proj: Dictionary, tid: int, dist: float, esquerda: bool) -> Array:
	var t: Dictionary = trecho_map(proj).get(tid, {})
	if t.is_empty():
		return []
	var nodes := node_map(proj)
	var a: Dictionary = nodes[int(t["ni"])]
	var b: Dictionary = nodes[int(t["nf"])]
	var dir := (pos(b) - pos(a)).normalized()
	var nrm := Vector2(-dir.y, dir.x) * (1.0 if esquerda else -1.0)
	for n in [a, b]:
		n["e"] = float(n["e"]) + nrm.x * dist
		n["n"] = float(n["n"]) + nrm.y * dist
	return [a, b]


## Divide o trecho ao meio: novo nó no centro, dois trechos.
static func dividir(proj: Dictionary, db: Dictionary, tid: int) -> Dictionary:
	var nodes := node_map(proj)
	var t: Dictionary = trecho_map(proj).get(tid, {})
	if t.is_empty():
		return {}
	var a: Dictionary = nodes[int(t["ni"])]
	var b: Dictionary = nodes[int(t["nf"])]
	var meio := (pos(a) + pos(b)) / 2.0
	var ct := (float(a["ct"]) + float(b["ct"])) / 2.0
	var novo := novo_no(proj, meio, ct, bool(a.get("ct_ok", true)) and bool(b.get("ct_ok", true)), "PV")
	var nf_antigo := int(t["nf"])
	t["nf"] = int(novo["id"])
	if float(t.get("ext_fix", 0.0)) > 0.0:
		t["ext_fix"] = float(t["ext_fix"]) / 2.0
	t["fixa_cotas"] = false
	var t2 := novo_trecho(proj, db, int(novo["id"]), nf_antigo, str(t["coletor"]), t)
	t2["ext_fix"] = t["ext_fix"]
	# mantém a ordem: o novo trecho logo depois do original
	var arr: Array = proj["trechos"]
	arr.erase(t2)
	arr.insert(arr.find(t) + 1, t2)
	return novo


## Numeração automática (manual 4.1): o maior conjunto contíguo vira o coletor 1,
## numerado de montante para jusante; os demais são numerados à medida que
## encontram o coletor principal.
static func renumerar(proj: Dictionary) -> void:
	var nodes := node_map(proj)
	var trs := trecho_map(proj)
	var ord := ordem(proj)
	var up_len := {}
	var best_inc := {}
	for tid in ord["order"]:
		var t: Dictionary = trs[tid]
		var l := comprimento(nodes, t) + float(up_len.get(int(t["ni"]), 0.0))
		var nf := int(t["nf"])
		if not up_len.has(nf) or l > float(up_len[nf]):
			up_len[nf] = l
			best_inc[nf] = tid
	var lig := ligacoes(proj)
	var inc: Dictionary = lig["inc"]
	var out: Dictionary = lig["out"]
	var saidas: Array = []
	for nid in nodes.keys():
		if out.get(nid, []).is_empty() and not inc.get(nid, []).is_empty():
			saidas.append(nid)
	saidas.sort_custom(func(a, b): return float(up_len.get(a, 0.0)) > float(up_len.get(b, 0.0)))
	var num_no := {}
	var num_tr := {}
	var ctx := {"nn": 0, "tn": 0, "cn": 0}
	for s in saidas:
		if best_inc.has(s):
			_numerar_ramo(trs, inc, up_len, best_inc, int(best_inc[s]), num_no, num_tr, ctx)
	# o que sobrou (laços ou nós soltos)
	for t in proj["trechos"]:
		if not num_tr.has(int(t["id"])):
			ctx["tn"] = int(ctx["tn"]) + 1
			num_tr[int(t["id"])] = ctx["tn"]
	for n in proj["nodes"]:
		if not num_no.has(int(n["id"])):
			ctx["nn"] = int(ctx["nn"]) + 1
			num_no[int(n["id"])] = ctx["nn"]
	for n in proj["nodes"]:
		n["nome"] = str(num_no[int(n["id"])])
	for t in proj["trechos"]:
		t["nome"] = "T%d" % int(num_tr[int(t["id"])])
	proj["nodes"].sort_custom(func(a, b): return int(num_no[int(a["id"])]) < int(num_no[int(b["id"])]))
	proj["trechos"].sort_custom(func(a, b): return int(num_tr[int(a["id"])]) < int(num_tr[int(b["id"])]))


static func _numerar_ramo(trs: Dictionary, inc: Dictionary, up_len: Dictionary, best_inc: Dictionary,
		tid_final: int, num_no: Dictionary, num_tr: Dictionary, ctx: Dictionary) -> void:
	var cadeia: Array = [tid_final]
	var n := int(trs[tid_final]["ni"])
	while best_inc.has(n) and not num_tr.has(int(best_inc[n])):
		cadeia.push_front(int(best_inc[n]))
		n = int(trs[int(best_inc[n])]["ni"])
	ctx["cn"] = int(ctx["cn"]) + 1
	var nome_col := "C%d" % int(ctx["cn"])
	var nos_cadeia: Array = []
	for tid in cadeia:
		var t: Dictionary = trs[tid]
		t["coletor"] = nome_col
		for nid in [int(t["ni"]), int(t["nf"])]:
			if not num_no.has(nid):
				ctx["nn"] = int(ctx["nn"]) + 1
				num_no[nid] = ctx["nn"]
			if not nid in nos_cadeia:
				nos_cadeia.append(nid)
		ctx["tn"] = int(ctx["tn"]) + 1
		num_tr[tid] = ctx["tn"]
	for nid in nos_cadeia:
		var ramos: Array = []
		for t2 in inc.get(nid, []):
			if not num_tr.has(int(t2)):
				ramos.append(int(t2))
		ramos.sort_custom(func(a, b):
			var la := float(up_len.get(int(trs[a]["ni"]), 0.0))
			var lb := float(up_len.get(int(trs[b]["ni"]), 0.0))
			return la > lb)
		for r in ramos:
			if not num_tr.has(r):
				_numerar_ramo(trs, inc, up_len, best_inc, r, num_no, num_tr, ctx)


# ------------------------------------------------------------------ exemplo

static func _z_exemplo(e: float, n: float) -> float:
	var bump := 2.2 * exp(-(pow(e - 330.0, 2) + pow(n - 260.0, 2)) / (2.0 * 110.0 * 110.0))
	return 100.0 + 0.028 * n - 0.0125 * e + bump + 0.6 * sin(e / 70.0) * cos(n / 90.0)


static func exemplo(params: Dictionary, db: Dictionary) -> Dictionary:
	var proj := novo_projeto(params)
	proj["info"]["projeto"] = "Rede coletora - Exemplo"
	proj["area"] = {"n0": -40.0, "e0": -40.0, "ln": 530.0, "le": 680.0, "grid": 50.0}
	var es := [50.0, 150.0, 250.0, 350.0, 450.0, 550.0]
	var ns := [45.0, 135.0, 225.0, 315.0, 405.0]
	var ids := {}
	var tipos_head := {}
	for i in es.size():
		for j in ns.size():
			var e: float = es[i]
			var n: float = ns[j]
			var head := j == ns.size() - 1
			var nd := novo_no(proj, Vector2(e, n), snappedf(_z_exemplo(e, n), 0.001), true, "TL" if head else "PV")
			ids[Vector2i(i, j)] = int(nd["id"])
			tipos_head[int(nd["id"])] = head
	# ramais nas ruas verticais (de norte para sul) e coletor na rua de baixo (para leste)
	for i in es.size():
		var col := "C%d" % (i + 1)
		for j in range(ns.size() - 1, 0, -1):
			novo_trecho(proj, db, ids[Vector2i(i, j)], ids[Vector2i(i, j - 1)], col)
		if i < es.size() - 1:
			novo_trecho(proj, db, ids[Vector2i(i, 0)], ids[Vector2i(i + 1, 0)], col)
	# pavimentação variada para o orçamento
	var k := 0
	for t in proj["trechos"]:
		t["superficie"] = "Asfáltico" if k % 3 != 2 else "Paralelepípedo"
		k += 1
	renumerar(proj)
	proj["topo"] = _topo_exemplo(es, ns)
	return proj


static func _topo_exemplo(es: Array, ns: Array) -> Dictionary:
	# curvas de nível por "marching squares" sobre a superfície analítica
	var x0 := -40.0
	var y0 := -40.0
	var passo := 5.0
	var nx := 137
	var ny := 107
	var zs: Array = []
	for j in ny:
		var row := PackedFloat32Array()
		row.resize(nx)
		for i in nx:
			row[i] = _z_exemplo(x0 + i * passo, y0 + j * passo)
		zs.append(row)
	var segs := {}
	for j in ny - 1:
		for i in nx - 1:
			var z00: float = zs[j][i]
			var z10: float = zs[j][i + 1]
			var z01: float = zs[j + 1][i]
			var z11: float = zs[j + 1][i + 1]
			var lo := floori(minf(minf(z00, z10), minf(z01, z11)))
			var hi := floori(maxf(maxf(z00, z10), maxf(z01, z11)))
			for lv in range(lo, hi + 1):
				var z := float(lv)
				var pts: Array = []
				var cs := [[z00, z10, Vector2(i, j), Vector2(i + 1, j)], [z10, z11, Vector2(i + 1, j), Vector2(i + 1, j + 1)],
					[z11, z01, Vector2(i + 1, j + 1), Vector2(i, j + 1)], [z01, z00, Vector2(i, j + 1), Vector2(i, j)]]
				for c in cs:
					var a: float = c[0]
					var b: float = c[1]
					if (a < z) != (b < z):
						var tt := (z - a) / (b - a)
						var p: Vector2 = c[2].lerp(c[3], tt)
						pts.append(Vector2(x0 + p.x * passo, y0 + p.y * passo))
				if pts.size() >= 2:
					if not segs.has(lv):
						segs[lv] = []
					segs[lv].append([pts[0], pts[1]])
					if pts.size() == 4:
						segs[lv].append([pts[2], pts[3]])
	var curvas: Array = []
	for lv in segs.keys():
		for poly in _juntar(segs[lv]):
			var flat: Array = []
			for p in poly:
				flat.append(snappedf(p.x, 0.01))
				flat.append(snappedf(p.y, 0.01))
			curvas.append({"z": float(lv), "p": flat})
	# quadras (ruas com 12 m de largura)
	var ruas: Array = []
	var ex := [-40.0] + es + [640.0]
	var nyy := [-40.0] + ns + [490.0]
	for i in ex.size() - 1:
		for j in nyy.size() - 1:
			var a := Vector2(float(ex[i]) + 6.0, float(nyy[j]) + 6.0)
			var b := Vector2(float(ex[i + 1]) - 6.0, float(nyy[j + 1]) - 6.0)
			if i == 0:
				a.x = -40.0
			if j == 0:
				a.y = -40.0
			if i == ex.size() - 2:
				b.x = 640.0
			if j == nyy.size() - 2:
				b.y = 490.0
			ruas.append([a.x, a.y, b.x, a.y, b.x, b.y, a.x, b.y, a.x, a.y])
	return {"curvas": curvas, "ruas": ruas, "pontos": [], "textos": []}


static func _juntar(segs: Array) -> Array:
	var chave := func(p: Vector2) -> String: return "%d_%d" % [roundi(p.x * 100.0), roundi(p.y * 100.0)]
	var ends := {}
	for i in segs.size():
		for e in 2:
			var k: String = chave.call(segs[i][e])
			if not ends.has(k):
				ends[k] = []
			ends[k].append(i)
	var usado := {}
	var res: Array = []
	for i in segs.size():
		if usado.has(i):
			continue
		usado[i] = true
		var poly: Array = [segs[i][0], segs[i][1]]
		for lado in 2:
			while true:
				var ponta: Vector2 = poly[-1] if lado == 0 else poly[0]
				var prox := -1
				for c in ends.get(chave.call(ponta), []):
					if not usado.has(c):
						prox = c
						break
				if prox < 0:
					break
				usado[prox] = true
				var s: Array = segs[prox]
				var outro: Vector2 = s[1] if chave.call(s[0]) == chave.call(ponta) else s[0]
				if lado == 0:
					poly.append(outro)
				else:
					poly.push_front(outro)
		res.append(poly)
	return res


# ------------------------------------------------------------------ migração

## Converte projeto da versão 2 (tabela de trechos com PVs por nome) para a rede gráfica.
## As extensões originais são mantidas como "extensão fixa"; a planta fica esquemática.
static func migrar_v2(data: Dictionary, params_default: Dictionary, db: Dictionary) -> Dictionary:
	var proj := novo_projeto(params_default)
	var lp: Dictionary = data.get("parametros", {})
	var p: Dictionary = proj["params"]
	proj["info"] = {"projeto": str(lp.get("projeto", "Projeto importado")), "responsavel": str(lp.get("responsavel", "")),
		"local": str(lp.get("local", ""))}
	var mapa := {"pop_ini": "pop_ini", "pop_fin": "pop_fin", "k1": "k1", "infiltracao": "infiltracao", "q_min": "q_min",
		"d_min": "d_min", "prof_max": "prof_max", "tensao_min": "tensao_min", "v_max": "v_max", "degrau_max": "degrau_max"}
	for k in mapa.keys():
		if lp.has(k):
			p[mapa[k]] = float(lp[k])
	if lp.has("per_capita"):
		p["qpc_ini"] = float(lp["per_capita"])
		p["qpc_fin"] = float(lp["per_capita"])
	if lp.has("coef_retorno"):
		p["c_ini"] = float(lp["coef_retorno"])
		p["c_fin"] = float(lp["coef_retorno"])
	if lp.has("k2"):
		p["k2_ini"] = float(lp["k2"])
		p["k2_fin"] = float(lp["k2"])
	if lp.has("prof_min"):
		p["recob_min"] = maxf(float(lp["prof_min"]) - 0.15, 0.6)
	p["metodo"] = 0
	p["ajuste_rug"] = 2
	var por_nome := {}
	var linhas: Array = data.get("trechos", [])
	for r in linhas:
		if not r is Dictionary:
			continue
		for par in [["pv_m", "ct_m"], ["pv_j", "ct_j"]]:
			var nome := str(r.get(par[0], "")).strip_edges()
			if nome == "" or por_nome.has(nome):
				continue
			var nd := novo_no(proj, Vector2.ZERO, float(r.get(par[1], 0.0)), true, "PV")
			nd["nome"] = nome
			por_nome[nome] = nd
	for r in linhas:
		if not r is Dictionary:
			continue
		var a = por_nome.get(str(r.get("pv_m", "")).strip_edges())
		var b = por_nome.get(str(r.get("pv_j", "")).strip_edges())
		if a == null or b == null or a == b:
			continue
		var t := novo_trecho(proj, db, int(a["id"]), int(b["id"]), "C" + str(r.get("coletor", "1")))
		t["nome"] = str(r.get("trecho", t["nome"]))
		t["ext_fix"] = maxf(float(r.get("L", 0.0)), 0.01)
		if float(r.get("d_fix", 0.0)) > 0.0:
			t["d"] = float(r["d_fix"])
			t["fixa_d"] = true
		a["qp_i"] = float(a["qp_i"]) + float(r.get("qc_i", 0.0))
		a["qp_f"] = float(a["qp_f"]) + float(r.get("qc_f", 0.0))
	# nós de cabeceira viram terminais de limpeza
	var lig := ligacoes(proj)
	for n in proj["nodes"]:
		if lig["inc"].get(int(n["id"]), []).is_empty():
			n["tipo"] = "TL"
	_layout_esquematico(proj)
	return proj


static func _layout_esquematico(proj: Dictionary) -> void:
	var nodes := node_map(proj)
	var lig := ligacoes(proj)
	var inc: Dictionary = lig["inc"]
	var trs := trecho_map(proj)
	var posicionado := {}
	var y_saida := 0.0
	for n in proj["nodes"]:
		if not lig["out"].get(int(n["id"]), []).is_empty():
			continue
		var fila: Array = [[int(n["id"]), Vector2(0.0, y_saida), Vector2(-1, 0)]]
		y_saida -= 300.0
		while not fila.is_empty():
			var item: Array = fila.pop_front()
			var nid: int = item[0]
			if posicionado.has(nid):
				continue
			posicionado[nid] = true
			nodes[nid]["e"] = item[1].x
			nodes[nid]["n"] = item[1].y
			var dir: Vector2 = item[2]
			var k := 0
			for tid in inc.get(nid, []):
				var t: Dictionary = trs[tid]
				var d2 := dir if k == 0 else dir.rotated(PI / 2.0 * (1 if k % 2 == 1 else -1))
				fila.append([int(t["ni"]), item[1] + d2 * float(t.get("ext_fix", 50.0)), d2])
				k += 1
	var a: Dictionary = proj["area"]
	var r := Rect2()
	var first := true
	for n in proj["nodes"]:
		var p := pos(n)
		if first:
			r = Rect2(p, Vector2.ZERO)
			first = false
		else:
			r = r.expand(p)
	r = r.grow(60.0)
	a["e0"] = floorf(r.position.x)
	a["n0"] = floorf(r.position.y)
	a["le"] = ceilf(r.size.x)
	a["ln"] = ceilf(r.size.y)
