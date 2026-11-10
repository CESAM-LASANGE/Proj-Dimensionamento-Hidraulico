extends RefCounted
## Cadastro (Fase 3): ligações domiciliares, bacias / sub-bacias e contribuições.
##
## Ligações: CSV com id;e;n;populacao;consumo_l_hab_dia;situacao (separador ; ou ,).
## Cada linha recebe uma categoria e a lista de problemas — nenhuma linha é descartada em silêncio.
## Vazão de uma ligação válida: consumo (l/dia, valor da coluna de consumo) × C (retorno) / 86400 (l/s).
## Destino da vazão: a sub-bacia mais interna que contém a ligação lança no seu trecho de saída
## (ou no do ancestral mais próximo); sem bacias cadastradas, vai para o trecho mais próximo
## (até DIST_ASSOC m). O balanço confere: soma das ligações válidas = soma lançada nos trechos.

const Net = preload("res://net.gd")

const CATEGORIAS := ["válida", "duplicada", "fora da área", "sem consumo", "sem coordenada", "inválida"]
const DIST_ASSOC := 20.0


# ------------------------------------------------------------------ CSV

static func ler_csv(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "erro": "Arquivo não encontrado: %s" % path}
	var txt := FileAccess.get_file_as_string(path).replace("\r", "")
	if txt.begins_with("﻿"):
		txt = txt.substr(1)
	var linhas := txt.split("\n", false)
	if linhas.is_empty():
		return {"ok": false, "erro": "Arquivo CSV vazio."}
	var sep := ";" if linhas[0].count(";") >= linhas[0].count(",") else ","
	var cab: Array = []
	for c in linhas[0].split(sep):
		cab.append(c.strip_edges().to_lower())
	var out: Array = []
	for k in range(1, linhas.size()):
		var cel := linhas[k].split(sep)
		var r := {"_linha": k + 1}
		for j in cab.size():
			r[cab[j]] = cel[j].strip_edges().trim_prefix("\"").trim_suffix("\"") if j < cel.size() else ""
		out.append(r)
	return {"ok": true, "cabecalho": cab, "linhas": out, "sep": sep}


static func _num(s: String) -> Variant:
	var t := s.strip_edges().replace(",", ".")
	if t == "":
		return null
	if not t.is_valid_float():
		return "x"
	return t.to_float()


## Lê e classifica as ligações. area = área de estudo (Rect2 em E/N); size 0 = sem limite.
static func importar_ligacoes(path: String, area: Rect2) -> Dictionary:
	var csv := ler_csv(path)
	if not bool(csv["ok"]):
		return {"ok": false, "erro": csv["erro"], "registros": [], "resumo": {}}
	var regs: Array = []
	var vistos := {}
	for r in csv["linhas"]:
		var id := str(r.get("id", "")).strip_edges()
		var e = _num(str(r.get("e", r.get("x", ""))))
		var n = _num(str(r.get("n", r.get("y", ""))))
		var pop = _num(str(r.get("populacao", r.get("população", ""))))
		var cons = _num(str(r.get("consumo_l_hab_dia", r.get("consumo", ""))))
		var prob: Array = []
		if id == "":
			prob.append("inválida")
		if e == null or n == null:
			prob.append("sem coordenada")
		elif e is String or n is String:
			prob.append("inválida")
		if pop is String or (pop != null and float(pop) < 0.0):
			prob.append("inválida")
		if cons == null:
			prob.append("sem consumo")
		elif cons is String or float(cons) < 0.0:
			prob.append("inválida")
		if id != "" and vistos.has(id):
			prob.append("duplicada")
		if e is float and n is float and area.size.x > 0.0 and not area.has_point(Vector2(e, n)):
			prob.append("fora da área")
		var unicos: Array = []
		for p in prob:
			if not p in unicos:
				unicos.append(p)
		if id != "" and not vistos.has(id):
			vistos[id] = true
		regs.append({"linha": int(r["_linha"]), "id": id, "e": e if e is float else NAN, "n": n if n is float else NAN,
			"populacao": pop if pop is float else 0.0, "consumo": cons if cons is float else 0.0,
			"situacao": str(r.get("situacao", r.get("situação", ""))), "problemas": unicos,
			"categoria": "válida" if unicos.is_empty() else str(unicos[0]), "valido": unicos.is_empty(),
			"trecho": -1, "trecho_nome": "", "dist": NAN})
	return {"ok": true, "registros": regs, "resumo": resumo(regs)}


static func resumo(regs: Array) -> Dictionary:
	var ids := {}
	var por := {}
	for c in CATEGORIAS:
		por[c] = 0
	var pop := 0.0
	var cons := 0.0
	for r in regs:
		if str(r["id"]) != "":
			ids[str(r["id"])] = true
		if bool(r["valido"]):
			por["válida"] += 1
			pop += float(r["populacao"])
			cons += float(r["consumo"])
		for p in r["problemas"]:
			por[p] = int(por.get(p, 0)) + 1
	return {"lidos": regs.size(), "ids_unicos": ids.size(), "por_categoria": por,
		"populacao_valida": pop, "consumo_valido_l_dia": cons}


static func relatorio_csv(regs: Array) -> String:
	var linhas: Array = ["linha;id;e;n;populacao;consumo;situacao;categoria;problemas;trecho;distancia_m"]
	for r in regs:
		linhas.append("%d;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s" % [int(r["linha"]), r["id"], _f(r["e"]), _f(r["n"]), _f(r["populacao"]),
			_f(r["consumo"]), r["situacao"], r["categoria"], ", ".join(PackedStringArray(r["problemas"])), r.get("trecho_nome", ""), _f(r.get("dist", NAN))])
	return "\n".join(PackedStringArray(linhas)) + "\n"


static func _f(v) -> String:
	if v == null or (v is float and is_nan(v)):
		return ""
	return ("%.3f" % float(v)).replace(".", ",")


# ------------------------------------------------------------------ associação a trechos

static func associar(proj: Dictionary, regs: Array, dmax := DIST_ASSOC) -> void:
	var nodes := Net.node_map(proj)
	var segs: Array = []
	for t in proj["trechos"]:
		var a = nodes.get(int(t["ni"]))
		var b = nodes.get(int(t["nf"]))
		if a != null and b != null:
			segs.append([int(t["id"]), str(t["nome"]), Net.pos(a), Net.pos(b)])
	for r in regs:
		r["trecho"] = -1
		r["trecho_nome"] = ""
		r["dist"] = NAN
		if is_nan(float(r["e"])) or is_nan(float(r["n"])):
			continue
		var p := Vector2(float(r["e"]), float(r["n"]))
		var best := INF
		var bt = null
		for s in segs:
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, s[2], s[3]))
			if d < best:
				best = d
				bt = s
		if bt != null:
			r["dist"] = best
			if best <= dmax:
				r["trecho"] = bt[0]
				r["trecho_nome"] = bt[1]


# ------------------------------------------------------------------ bacias

static func _poly(b: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c in b.get("poligono", []):
		pts.append(Vector2(float(c[0]), float(c[1])))
	return pts


static func _nivel(b: Dictionary, por_id: Dictionary) -> int:
	var n := 0
	var cur := str(b.get("pai", ""))
	while cur != "" and por_id.has(cur) and n < 50:
		n += 1
		cur = str(por_id[cur].get("pai", ""))
	return n


## Bacia mais interna que contém o ponto ("" se nenhuma). "ambigua" se duas do mesmo nível contêm.
static func bacia_de(p: Vector2, bacias: Array) -> Dictionary:
	var por_id := {}
	for b in bacias:
		por_id[str(b["id"])] = b
	var melhor := ""
	var nivel := -1
	var ambigua := false
	for b in bacias:
		if Geometry2D.is_point_in_polygon(p, _poly(b)):
			var nv := _nivel(b, por_id)
			if nv > nivel:
				nivel = nv
				melhor = str(b["id"])
				ambigua = false
			elif nv == nivel:
				ambigua = true
	return {"id": melhor, "ambigua": ambigua}


static func validar_bacias(proj: Dictionary) -> Array:
	var erros: Array = []
	var bacias: Array = proj.get("bacias", [])
	var por_id := {}
	for b in bacias:
		por_id[str(b["id"])] = b
	var trechos := {}
	for t in proj["trechos"]:
		trechos[str(t["nome"])] = true
	for i in bacias.size():
		var a: Dictionary = bacias[i]
		if _poly(a).size() < 3:
			erros.append("Bacia %s: polígono com menos de 3 vértices." % a["id"])
		if str(a.get("pai", "")) != "" and not por_id.has(str(a["pai"])):
			erros.append("Bacia %s: bacia principal \"%s\" não existe." % [a["id"], a["pai"]])
		if str(a.get("trecho_saida", "")) != "" and not trechos.has(str(a["trecho_saida"])):
			erros.append("Bacia %s: trecho de saída \"%s\" não existe na rede." % [a["id"], a["trecho_saida"]])
		for j in range(i + 1, bacias.size()):
			var b: Dictionary = bacias[j]
			if str(a.get("pai", "")) != str(b.get("pai", "")):
				continue
			var area := 0.0
			for poly in Geometry2D.intersect_polygons(_poly(a), _poly(b)):
				area += absf(_area(poly))
			if area > 1e-6:
				erros.append("Bacias %s e %s se sobrepõem (%s m²)." % [a["id"], b["id"], _f(area)])
	return erros


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for k in p.size():
		s += p[k].cross(p[(k + 1) % p.size()])
	return s / 2.0


## Trecho de saída efetivo de uma bacia (sobe pelos ancestrais se não tiver).
static func _saida(bid: String, por_id: Dictionary) -> String:
	var cur := bid
	var guard := 0
	while cur != "" and por_id.has(cur) and guard < 50:
		var s := str(por_id[cur].get("trecho_saida", ""))
		if s != "":
			return s
		cur = str(por_id[cur].get("pai", ""))
		guard += 1
	return ""


# ------------------------------------------------------------------ contribuições e balanço

static func q_ligacao(r: Dictionary, c_retorno: float) -> float:
	return float(r["consumo"]) * c_retorno / 86400.0


## Destino de cada ligação válida e balanço de massa.
static func balanco(proj: Dictionary) -> Dictionary:
	var regs: Array = proj.get("ligacoes", [])
	var bacias: Array = proj.get("bacias", [])
	var c := float(proj["params"].get("c_fin", 0.8))
	var por_id := {}
	for b in bacias:
		por_id[str(b["id"])] = b
	var por_nome := {}
	for t in proj["trechos"]:
		por_nome[str(t["nome"])] = int(t["id"])
	if bacias.is_empty():
		associar(proj, regs)
	var por_trecho := {}
	var por_bacia := {}
	var erros: Array = validar_bacias(proj)
	var q_validas := 0.0
	var q_lancada := 0.0
	var pop := 0.0
	var cons := 0.0
	var nao_lancadas: Array = []
	for r in regs:
		if not bool(r["valido"]):
			continue
		var q := q_ligacao(r, c)
		q_validas += q
		pop += float(r["populacao"])
		cons += float(r["consumo"])
		var destino := -1
		var p := Vector2(float(r["e"]), float(r["n"]))
		if not bacias.is_empty():
			var bd := bacia_de(p, bacias)
			r["bacia"] = bd["id"]
			if str(bd["id"]) == "":
				erros.append("Ligação %s (%s, %s) está fora de qualquer bacia." % [r["id"], _f(r["e"]), _f(r["n"])])
			else:
				if bool(bd["ambigua"]):
					erros.append("Ligação %s pertence a mais de uma sub-bacia (áreas sobrepostas)." % r["id"])
				var s := _saida(str(bd["id"]), por_id)
				destino = int(por_nome.get(s, -1))
				if not por_bacia.has(bd["id"]):
					por_bacia[bd["id"]] = {"populacao": 0.0, "consumo_l_dia": 0.0, "q": 0.0, "ligacoes": 0}
				por_bacia[bd["id"]]["populacao"] += float(r["populacao"])
				por_bacia[bd["id"]]["consumo_l_dia"] += float(r["consumo"])
				por_bacia[bd["id"]]["q"] += q
				por_bacia[bd["id"]]["ligacoes"] += 1
		else:
			destino = int(r.get("trecho", -1))
		if destino >= 0:
			por_trecho[destino] = float(por_trecho.get(destino, 0.0)) + q
			q_lancada += q
		else:
			nao_lancadas.append(str(r["id"]))
	return {"por_trecho": por_trecho, "por_bacia": por_bacia, "q_validas": q_validas, "q_lancada": q_lancada,
		"populacao_valida": pop, "consumo_valido_l_dia": cons, "nao_lancadas": nao_lancadas, "erros": erros}


## Vazão (l/s) a somar em cada trecho, usada pelo motor de cálculo.
static func vazoes_por_trecho(proj: Dictionary) -> Dictionary:
	if proj.get("ligacoes", []).is_empty():
		return {}
	return balanco(proj)["por_trecho"]
