extends RefCounted
## GeoJSON (Fase 3): camadas de interferência e exportação / reimportação da rede.
## Coordenadas em metros no sistema do projeto ([E, N] ou [E, N, cota]).

const Net = preload("res://net.gd")
const Db = preload("res://db.gd")


static func ler(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "erro": "Arquivo não encontrado: %s" % path}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or str(data.get("type", "")) != "FeatureCollection" or not data.get("features") is Array:
		return {"ok": false, "erro": "Não é um GeoJSON FeatureCollection válido."}
	var crs := ""
	if data.get("crs") is Dictionary:
		crs = str(data["crs"].get("properties", {}).get("name", ""))
	return {"ok": true, "crs": crs, "nome": str(data.get("name", "")), "features": data["features"]}


# ------------------------------------------------------------------ interferências

## Retorna {ok, erro, crs, camadas: [nomes], feicoes: [{id, camada, origem, data, crs, tipo, coords, props}]}
static func importar_interferencias(path: String) -> Dictionary:
	var g := ler(path)
	if not bool(g["ok"]):
		return g
	var feicoes: Array = []
	var camadas: Array = []
	var avisos: Array = []
	var k := 0
	for f in g["features"]:
		k += 1
		if not f is Dictionary or not f.get("geometry") is Dictionary:
			avisos.append("Feição %d sem geometria: ignorada." % k)
			continue
		var props: Dictionary = f.get("properties", {}) if f.get("properties") is Dictionary else {}
		var tipo := str(f["geometry"].get("type", ""))
		if not tipo in ["Point", "LineString", "MultiLineString", "Polygon", "MultiPoint"]:
			avisos.append("Feição %d: geometria %s não suportada." % [k, tipo])
			continue
		var camada := str(props.get("camada", props.get("layer", g.get("nome", "INTERFERENCIA"))))
		if not camada in camadas:
			camadas.append(camada)
		feicoes.append({"id": str(props.get("id", "F%d" % k)), "camada": camada, "origem": str(props.get("origem", "")),
			"data": str(props.get("data", "")), "crs": str(props.get("crs", g["crs"])), "tipo": tipo,
			"coords": f["geometry"].get("coordinates", []), "props": props})
	return {"ok": true, "crs": g["crs"], "camadas": camadas, "feicoes": feicoes, "avisos": avisos}


static func exportar_interferencias(interf: Dictionary) -> String:
	var feats: Array = []
	for f in interf.get("feicoes", []):
		var props: Dictionary = f.get("props", {}).duplicate()
		props["id"] = f["id"]
		props["camada"] = f["camada"]
		props["origem"] = f["origem"]
		props["data"] = f["data"]
		props["crs"] = f["crs"]
		feats.append({"type": "Feature", "properties": props, "geometry": {"type": f["tipo"], "coordinates": f["coords"]}})
	return JSON.stringify({"type": "FeatureCollection", "name": "interferencias",
		"crs": {"type": "name", "properties": {"name": str(interf.get("crs", ""))}}, "features": feats}, " ")


## Polilinhas de uma feição para desenho (lista de PackedVector2Array).
static func linhas(f: Dictionary) -> Array:
	var c = f.get("coords", [])
	var out: Array = []
	match str(f.get("tipo", "")):
		"LineString":
			out.append(_pts(c))
		"MultiLineString", "Polygon":
			for parte in c:
				out.append(_pts(parte))
		"Point":
			out.append(_pts([c]))
		"MultiPoint":
			out.append(_pts(c))
	return out


static func _pts(lista) -> PackedVector2Array:
	var p := PackedVector2Array()
	if lista is Array:
		for v in lista:
			if v is Array and v.size() >= 2:
				p.append(Vector2(float(v[0]), float(v[1])))
	return p


# ------------------------------------------------------------------ rede

static func exportar_rede(proj: Dictionary) -> String:
	var feats: Array = []
	var nodes := Net.node_map(proj)
	for n in proj["nodes"]:
		feats.append({"type": "Feature", "geometry": {"type": "Point", "coordinates": [float(n["e"]), float(n["n"]), float(n["ct"])]},
			"properties": {"feicao": "no", "id": int(n["id"]), "nome": n["nome"], "tipo": n["tipo"], "ct": float(n["ct"]),
				"ct_ok": bool(n.get("ct_ok", true)), "qp_i": float(n.get("qp_i", 0.0)), "qp_f": float(n.get("qp_f", 0.0))}})
	for t in proj["trechos"]:
		var a = nodes.get(int(t["ni"]))
		var b = nodes.get(int(t["nf"]))
		if a == null or b == null:
			continue
		var props := {"feicao": "trecho"}
		for k in t.keys():
			props[k] = t[k]
		props["sentido"] = "%s→%s" % [a["nome"], b["nome"]]
		feats.append({"type": "Feature", "properties": props,
			"geometry": {"type": "LineString", "coordinates": [[float(a["e"]), float(a["n"])], [float(b["e"]), float(b["n"])]]}})
	var ref: Dictionary = proj.get("referencia", {})
	return JSON.stringify({"type": "FeatureCollection", "name": str(proj.get("info", {}).get("projeto", "rede")),
		"crs": {"type": "name", "properties": {"name": str(ref.get("crs", ""))}}, "features": feats}, " ")


## Reconstrói a rede (nós e trechos) a partir de um GeoJSON exportado por exportar_rede.
static func importar_rede(path: String, params: Dictionary, db: Dictionary) -> Dictionary:
	var g := ler(path)
	if not bool(g["ok"]):
		return g
	var proj := Net.novo_projeto(params)
	proj["info"]["projeto"] = str(g.get("nome", "Rede importada"))
	proj["referencia"]["crs"] = str(g["crs"])
	for f in g["features"]:
		var pr: Dictionary = f.get("properties", {})
		if str(pr.get("feicao", "")) != "no":
			continue
		var c: Array = f["geometry"]["coordinates"]
		proj["nodes"].append({"id": int(pr["id"]), "nome": str(pr.get("nome", pr["id"])), "e": float(c[0]), "n": float(c[1]),
			"ct": float(pr.get("ct", c[2] if c.size() > 2 else 0.0)), "ct_ok": bool(pr.get("ct_ok", true)),
			"tipo": str(pr.get("tipo", "PV")), "qp_i": float(pr.get("qp_i", 0.0)), "qp_f": float(pr.get("qp_f", 0.0))})
	var base := Net.trecho_padrao(db)
	for f in g["features"]:
		var pr: Dictionary = f.get("properties", {})
		if str(pr.get("feicao", "")) != "trecho":
			continue
		var t := base.duplicate()
		for k in base.keys():
			if pr.has(k):
				var dv = base[k]
				t[k] = bool(pr[k]) if dv is bool else (str(pr[k]) if dv is String else float(pr[k]))
		t["id"] = int(pr["id"])
		t["nome"] = str(pr.get("nome", "T%d" % int(pr["id"])))
		t["ni"] = int(pr["ni"])
		t["nf"] = int(pr["nf"])
		t["coletor"] = str(pr.get("coletor", "C1"))
		proj["trechos"].append(t)
	return {"ok": true, "proj": proj}
