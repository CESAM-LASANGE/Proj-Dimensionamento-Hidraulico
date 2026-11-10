extends RefCounted
## Leitura e gravação de arquivos DXF (ASCII).
## Leitura: LINE, POLYLINE/VERTEX, LWPOLYLINE, ARC, CIRCLE, TEXT, MTEXT e POINT.


const SENTINELA := "AutoCAD Binary DXF"


static func ler(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "erro": "Arquivo não encontrado: %s" % path}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "erro": "Não foi possível abrir o arquivo."}
	var buf := f.get_buffer(f.get_length())
	f.close()
	if buf.size() == 0 or buf.get_string_from_ascii().strip_edges() == "" and buf.size() < 64:
		return {"ok": false, "erro": "Arquivo DXF vazio."}
	var pr: Dictionary
	var binario := buf.size() >= 22 and buf.slice(0, 18).get_string_from_ascii() == SENTINELA
	if binario:
		pr = _pares_binario(buf)
	else:
		pr = _pares_ascii(buf)
	if not pr.get("erro", "") == "":
		return {"ok": false, "erro": pr["erro"]}
	if bool(pr["truncado"]):
		return {"ok": false, "erro": "Arquivo DXF truncado ou incompleto (termina sem EOF). Exporte-o novamente do CAD."}
	var out := _processar(pr["pares"])
	out["binario"] = binario
	return out


static func _pares_ascii(buf: PackedByteArray) -> Dictionary:
	var txt := buf.get_string_from_utf8()
	if txt == "" and buf.size() > 0:
		# arquivos antigos em Windows-1252: descarta acentos
		var limpo := PackedByteArray()
		for b in buf:
			limpo.append(b if b < 128 else 63)
		txt = limpo.get_string_from_ascii()
	var lines := txt.split("\n")
	var pares: Array = []
	var i := 0
	var tem_eof := false
	while i + 1 < lines.size():
		var cs := lines[i].strip_edges()
		if not cs.is_valid_int():
			return {"erro": "Arquivo DXF inválido: código de grupo \"%s\" na linha %d." % [cs.left(20), i + 1], "pares": [], "truncado": false}
		var val := lines[i + 1].strip_edges()
		pares.append([cs.to_int(), val])
		if cs.to_int() == 0 and val == "EOF":
			tem_eof = true
			break
		i += 2
	return {"pares": pares, "truncado": not tem_eof, "erro": ""}


## Tipo do valor de um código de grupo DXF: "s" texto, "d" double, "i2"/"i4"/"i8" inteiros, "b" bool, "h" binário.
static func tipo_codigo(c: int) -> String:
	if c >= 10 and c <= 59 or c >= 110 and c <= 149 or c >= 210 and c <= 239 or c >= 460 and c <= 469 or c >= 1010 and c <= 1059:
		return "d"
	if c >= 60 and c <= 79 or c >= 170 and c <= 179 or c >= 270 and c <= 289 or c >= 370 and c <= 389 or c >= 400 and c <= 409 or c >= 1060 and c <= 1070:
		return "i2"
	if c >= 90 and c <= 99 or c >= 420 and c <= 429 or c >= 440 and c <= 459 or c == 1071:
		return "i4"
	if c >= 160 and c <= 169:
		return "i8"
	if c >= 290 and c <= 299:
		return "b"
	if c >= 310 and c <= 319 or c == 1004:
		return "h"
	return "s"


static func _pares_binario(buf: PackedByteArray) -> Dictionary:
	var p := 22
	var dois_bytes := buf.size() > 24 and buf[22] == 0 and buf[23] == 0
	var pares: Array = []
	var tem_eof := false
	while p < buf.size():
		var c: int
		if dois_bytes:
			if p + 2 > buf.size():
				break
			c = buf.decode_s16(p)
			p += 2
		else:
			c = buf[p]
			p += 1
			if c == 255:
				if p + 2 > buf.size():
					break
				c = buf.decode_s16(p)
				p += 2
		var t := tipo_codigo(c)
		var v
		match t:
			"d":
				if p + 8 > buf.size():
					break
				v = buf.decode_double(p)
				p += 8
			"i2":
				if p + 2 > buf.size():
					break
				v = buf.decode_s16(p)
				p += 2
			"i4":
				if p + 4 > buf.size():
					break
				v = buf.decode_s32(p)
				p += 4
			"i8":
				if p + 8 > buf.size():
					break
				v = buf.decode_s64(p)
				p += 8
			"b":
				v = buf[p]
				p += 1
			"h":
				var n := buf[p]
				p += 1 + n
				v = ""
			_:
				var fim := p
				while fim < buf.size() and buf[fim] != 0:
					fim += 1
				if fim >= buf.size():
					break
				v = buf.slice(p, fim).get_string_from_utf8()
				p = fim + 1
		pares.append([c, v])
		if c == 0 and str(v) == "EOF":
			tem_eof = true
			break
	return {"pares": pares, "truncado": not tem_eof, "erro": ""}


static func _processar(pares: Array) -> Dictionary:
	var ents: Array = []
	var layers := {}
	var secao := ""
	var cur := {}
	var poly := {}
	var i := 0
	while i < pares.size():
		var code: int = pares[i][0]
		var raw = pares[i][1]
		var val := str(raw)
		var fv: float = float(raw) if (raw is float or raw is int) else val.to_float()
		i += 1
		if code == 0:
			var r = _fechar(cur, poly)
			if r is Dictionary and not r.is_empty():
				ents.append(r)
				layers[r["layer"]] = int(layers.get(r["layer"], 0)) + 1
			cur = {}
			if val == "SECTION":
				if i < pares.size() and int(pares[i][0]) == 2:
					secao = str(pares[i][1])
					i += 1
				continue
			if val == "ENDSEC":
				secao = ""
				continue
			if val == "EOF":
				break
			if secao == "ENTITIES":
				cur = {"tipo": val, "layer": "0", "c": {}, "xs": [], "ys": [], "zs": []}
				if val == "POLYLINE":
					poly = {"layer": "0", "z": 0.0, "fechada": false, "pts": PackedVector2Array(), "zs": [], "aberta": true}
					cur["poly"] = true
			continue
		if cur.is_empty():
			continue
		match code:
			8:
				cur["layer"] = val
				if cur.has("poly"):
					poly["layer"] = val
			10:
				cur["xs"].append(fv)
				cur["c"][10] = fv
			20:
				cur["ys"].append(fv)
				cur["c"][20] = fv
			30:
				cur["zs"].append(fv)
				cur["c"][30] = fv
			1:
				cur["c"][1] = val if not cur["c"].has(1) else str(cur["c"][1]) + val
			3:
				cur["c"][1] = str(cur["c"].get(1, "")) + val
			_:
				cur["c"][code] = fv
	var r = _fechar(cur, poly)
	if r is Dictionary and not r.is_empty():
		ents.append(r)
		layers[r["layer"]] = int(layers.get(r["layer"], 0)) + 1
	var lnames: Array = layers.keys()
	lnames.sort()
	return {"ok": true, "ents": ents, "layers": lnames, "contagem": layers}


## Converte um DXF ASCII em DXF binário (formato R13+, códigos de 2 bytes).
static func ascii_para_binario(entrada: String, saida: String) -> bool:
	var f := FileAccess.open(entrada, FileAccess.READ)
	if f == null:
		return false
	var pr := _pares_ascii(f.get_buffer(f.get_length()))
	f.close()
	var out := PackedByteArray()
	out.append_array(SENTINELA.to_ascii_buffer())
	out.append_array(PackedByteArray([13, 10, 26, 0]))
	for par in pr["pares"]:
		var c: int = par[0]
		var v: String = par[1]
		var b := PackedByteArray()
		b.resize(2)
		b.encode_s16(0, c)
		out.append_array(b)
		match tipo_codigo(c):
			"d":
				b.resize(8)
				b.encode_double(0, v.to_float())
				out.append_array(b)
			"i2":
				b.resize(2)
				b.encode_s16(0, v.to_int())
				out.append_array(b)
			"i4":
				b.resize(4)
				b.encode_s32(0, v.to_int())
				out.append_array(b)
			"i8":
				b.resize(8)
				b.encode_s64(0, v.to_int())
				out.append_array(b)
			"b":
				out.append(v.to_int())
			"h":
				out.append(0)
			_:
				out.append_array(v.to_utf8_buffer())
				out.append(0)
	var g := FileAccess.open(saida, FileAccess.WRITE)
	if g == null:
		return false
	g.store_buffer(out)
	g.close()
	return true


# ------------------------------------------------------------------ importação com diagnóstico

## Papel de um layer pelo nome: "curvas", "ruas", "pontos" ou "outros".
static func papel_layer(nome: String) -> String:
	var n := nome.to_upper()
	for k in ["CURVA", "NIVEL", "NÍVEL", "TOPO", "CN_"]:
		if n.contains(k):
			return "curvas"
	for k in ["PTCT", "PT_", "PONTO", "COTADO"]:
		if n.contains(k):
			return "pontos"
	for k in ["RUA", "QUADRA", "LOTE", "VIARIO", "VIÁRIO", "MEIO_FIO", "MEIOFIO"]:
		if n.contains(k):
			return "ruas"
	return "outros"


## Lê o DXF e separa curvas, ruas, pontos e textos por layer, com avisos de qualidade.
## sel: layers a usar ({} = todos). papeis: força o papel de layers ({"X": "curvas"}).
static func importar(path: String, sel := {}, papeis := {}) -> Dictionary:
	var info := ler(path)
	if not bool(info["ok"]):
		return {"ok": false, "erro": info["erro"], "avisos": [], "layers": []}
	var avisos: Array = []
	for ly in sel.keys():
		if not ly in info["layers"]:
			avisos.append("Layer \"%s\" não existe no arquivo." % ly)
	var grupos := {"curvas": [], "ruas": [], "pontos": [], "outros": []}
	for ly in info["layers"]:
		if sel.is_empty() or sel.has(ly):
			grupos[str(papeis.get(ly, papel_layer(ly)))].append(ly)
	var s_curvas := {}
	for ly in grupos["curvas"]:
		s_curvas[ly] = true
	var s_ruas := {}
	for ly in grupos["ruas"]:
		s_ruas[ly] = true
	var s_pontos := {}
	for ly in grupos["pontos"]:
		s_pontos[ly] = true
	var curvas_brutas := curvas(info["ents"], s_curvas) if not s_curvas.is_empty() else []
	var cs: Array = []
	var sem_z := 0
	for e in info["ents"]:
		if str(e["tipo"]) == "POLY" and s_curvas.has(str(e["layer"])) and e["pts"].size() < 2:
			avisos.append("Curva no layer %s com menos de dois vértices: ignorada." % e["layer"])
	for c in curvas_brutas:
		if is_zero_approx(float(c["z"])):
			sem_z += 1
		cs.append(c)
	if sem_z > 0:
		avisos.append("%d curva(s) de nível sem elevação (z = 0): confira o DXF." % sem_z)
	var pts := pontos(info["ents"], s_pontos) if not s_pontos.is_empty() else []
	var pts_sem_z := 0
	for p in pts:
		if is_zero_approx(p.z):
			pts_sem_z += 1
	if pts_sem_z > 0:
		avisos.append("%d ponto(s) cotado(s) sem elevação e sem texto de cota próximo." % pts_sem_z)
	var outros := 0
	for e in info["ents"]:
		if grupos["outros"].has(str(e["layer"])):
			outros += 1
	var rs := ruas(info["ents"], s_ruas) if not s_ruas.is_empty() else []
	var ts := textos(info["ents"], s_pontos) if not s_pontos.is_empty() else []
	if cs.is_empty() and rs.is_empty() and pts.is_empty():
		avisos.append("Nenhuma curva, rua ou ponto cotado nos layers selecionados.")
	return {"ok": true, "binario": bool(info.get("binario", false)), "layers": info["layers"], "grupos": grupos,
		"curvas": cs, "ruas": rs, "pontos": pts, "textos": ts, "outros": outros, "avisos": avisos, "ents": info["ents"],
		"contagem": info["contagem"]}


static func _fechar(cur: Dictionary, poly: Dictionary):
	if cur.is_empty():
		return null
	var c: Dictionary = cur["c"]
	var tipo: String = cur["tipo"]
	var layer: String = cur["layer"]
	match tipo:
		"LINE":
			var pts := PackedVector2Array([Vector2(float(c.get(10, 0.0)), float(c.get(20, 0.0))),
				Vector2(float(c.get(11, 0.0)), float(c.get(21, 0.0)))])
			return {"tipo": "POLY", "layer": layer, "pts": pts, "z": float(c.get(30, 0.0))}
		"LWPOLYLINE":
			var pts := PackedVector2Array()
			var xs: Array = cur["xs"]
			var ys: Array = cur["ys"]
			for k in mini(xs.size(), ys.size()):
				pts.append(Vector2(float(xs[k]), float(ys[k])))
			if int(c.get(70, 0.0)) & 1 and pts.size() > 2:
				pts.append(pts[0])
			return {"tipo": "POLY", "layer": layer, "pts": pts, "z": float(c.get(38, 0.0))}
		"POLYLINE":
			poly["layer"] = layer
			poly["z"] = float(c.get(30, 0.0))
			poly["fechada"] = int(c.get(70, 0.0)) & 1
			return null
		"VERTEX":
			if not poly.is_empty():
				poly["pts"].append(Vector2(float(c.get(10, 0.0)), float(c.get(20, 0.0))))
				poly["zs"].append(float(c.get(30, 0.0)))
			return null
		"SEQEND":
			if poly.is_empty():
				return null
			var pts: PackedVector2Array = poly["pts"]
			if bool(poly["fechada"]) and pts.size() > 2:
				pts.append(pts[0])
			var z := float(poly["z"])
			if is_zero_approx(z) and poly["zs"].size() > 0:
				z = float(poly["zs"][0])
			var out := {"tipo": "POLY", "layer": str(poly["layer"]), "pts": pts, "z": z}
			poly.clear()
			return out
		"ARC", "CIRCLE":
			var ctr := Vector2(float(c.get(10, 0.0)), float(c.get(20, 0.0)))
			var r := float(c.get(40, 0.0))
			var a1 := 0.0
			var a2 := 360.0
			if tipo == "ARC":
				a1 = float(c.get(50, 0.0))
				a2 = float(c.get(51, 360.0))
				if a2 < a1:
					a2 += 360.0
			var nseg := maxi(6, int((a2 - a1) / 7.5))
			var pts := PackedVector2Array()
			for k in nseg + 1:
				var a := deg_to_rad(lerpf(a1, a2, float(k) / nseg))
				pts.append(ctr + Vector2(cos(a), sin(a)) * r)
			return {"tipo": "POLY", "layer": layer, "pts": pts, "z": float(c.get(30, 0.0))}
		"TEXT", "MTEXT":
			var s := str(c.get(1, ""))
			if tipo == "MTEXT":
				s = s.replace("\\P", " ")
				var re := RegEx.create_from_string("\\\\[A-Za-z][^;]*;|[{}]")
				s = re.sub(s, "", true)
			return {"tipo": "TEXT", "layer": layer, "p": Vector2(float(c.get(10, 0.0)), float(c.get(20, 0.0))),
				"s": s.strip_edges(), "z": float(c.get(30, 0.0))}
		"POINT":
			return {"tipo": "POINT", "layer": layer, "p": Vector2(float(c.get(10, 0.0)), float(c.get(20, 0.0))),
				"z": float(c.get(30, 0.0))}
	return null


static func _sel(e: Dictionary, sel: Dictionary) -> bool:
	return sel.is_empty() or sel.has(str(e["layer"]))


static func curvas(ents: Array, sel: Dictionary) -> Array:
	var out: Array = []
	for e in ents:
		if str(e["tipo"]) == "POLY" and _sel(e, sel) and e["pts"].size() >= 2:
			out.append({"z": float(e["z"]), "pts": e["pts"]})
	return out


static func ruas(ents: Array, sel: Dictionary) -> Array:
	var out: Array = []
	for e in ents:
		if str(e["tipo"]) == "POLY" and _sel(e, sel) and e["pts"].size() >= 2:
			out.append(e["pts"])
	return out


static func textos(ents: Array, sel: Dictionary) -> Array:
	var out: Array = []
	for e in ents:
		if str(e["tipo"]) == "TEXT" and _sel(e, sel) and str(e["s"]) != "":
			out.append({"p": e["p"], "s": e["s"]})
	return out


## Pontos cotados: entidades POINT com z; se não tiverem z, usa o valor
## numérico do texto mais próximo; textos numéricos sozinhos também viram pontos.
static func pontos(ents: Array, sel: Dictionary) -> Array:
	var pts: Array = []
	var nums: Array = []
	for e in ents:
		if not _sel(e, sel):
			continue
		if str(e["tipo"]) == "POINT":
			pts.append(e)
		elif str(e["tipo"]) == "TEXT":
			var s := str(e["s"]).replace(",", ".")
			if s.is_valid_float():
				nums.append([e["p"], s.to_float()])
	var out: Array = []
	for e in pts:
		var z := float(e["z"])
		var p: Vector2 = e["p"]
		if is_zero_approx(z) and not nums.is_empty():
			var best := INF
			for t in nums:
				var d: float = p.distance_to(t[0])
				if d < best:
					best = d
					z = float(t[1])
		out.append(Vector3(p.x, p.y, z))
	if pts.is_empty():
		for t in nums:
			out.append(Vector3(t[0].x, t[0].y, float(t[1])))
	return out


# ------------------------------------------------------------------ gravação

class Escritor:
	var corpo := PackedStringArray()
	var layers := {}
	var comentarios: Array = []

	func comentario(t: String) -> void:
		comentarios.append(t)

	func _p(code: int, val) -> void:
		corpo.append(str(code))
		if val is float:
			corpo.append("%.4f" % val)
		else:
			corpo.append(str(val))

	func _txt(s: String) -> String:
		return s.replace("ø", "%%c").replace("Ø", "%%c")

	func layer(nome: String, cor: int) -> void:
		layers[nome] = cor

	func _ent(tipo: String, ly: String) -> void:
		if not layers.has(ly):
			layers[ly] = 7
		_p(0, tipo)
		_p(8, ly)

	func linha(ly: String, a: Vector2, b: Vector2) -> void:
		_ent("LINE", ly)
		_p(10, a.x)
		_p(20, a.y)
		_p(30, 0.0)
		_p(11, b.x)
		_p(21, b.y)
		_p(31, 0.0)

	func poli(ly: String, pts: PackedVector2Array, z := 0.0, fechada := false) -> void:
		if pts.size() < 2:
			return
		_ent("POLYLINE", ly)
		_p(66, 1)
		_p(10, 0.0)
		_p(20, 0.0)
		_p(30, z)
		_p(70, 1 if fechada else 0)
		for p in pts:
			_p(0, "VERTEX")
			_p(8, ly)
			_p(10, p.x)
			_p(20, p.y)
			_p(30, z)
		_p(0, "SEQEND")
		_p(8, ly)

	func circulo(ly: String, c: Vector2, r: float) -> void:
		_ent("CIRCLE", ly)
		_p(10, c.x)
		_p(20, c.y)
		_p(30, 0.0)
		_p(40, r)

	func ponto(ly: String, p: Vector3) -> void:
		_ent("POINT", ly)
		_p(10, p.x)
		_p(20, p.y)
		_p(30, p.z)

	## alinh: 0 esquerda, 1 centro, 2 direita
	func texto(ly: String, p: Vector2, h: float, s: String, ang := 0.0, alinh := 0) -> void:
		_ent("TEXT", ly)
		_p(10, p.x)
		_p(20, p.y)
		_p(30, 0.0)
		_p(40, h)
		_p(1, _txt(s))
		if absf(ang) > 1e-6:
			_p(50, ang)
		if alinh != 0:
			_p(72, alinh)
			_p(11, p.x)
			_p(21, p.y)
			_p(31, 0.0)

	var _s: Array = []

	func _add(c, v) -> void:
		_s.append(str(c))
		_s.append(str(v))

	func gerar() -> String:
		_s = []
		var add := Callable(self, "_add")
		for c in comentarios:
			add.call(999, c)
		add.call(0, "SECTION")
		add.call(2, "HEADER")
		add.call(9, "$ACADVER")
		add.call(1, "AC1009")
		add.call(0, "ENDSEC")
		add.call(0, "SECTION")
		add.call(2, "TABLES")
		add.call(0, "TABLE")
		add.call(2, "LTYPE")
		add.call(70, 1)
		add.call(0, "LTYPE")
		add.call(2, "CONTINUOUS")
		add.call(70, 0)
		add.call(3, "Solid line")
		add.call(72, 65)
		add.call(73, 0)
		add.call(40, "0.0")
		add.call(0, "ENDTAB")
		add.call(0, "TABLE")
		add.call(2, "LAYER")
		add.call(70, layers.size())
		for nome in layers.keys():
			add.call(0, "LAYER")
			add.call(2, nome)
			add.call(70, 0)
			add.call(62, layers[nome])
			add.call(6, "CONTINUOUS")
		add.call(0, "ENDTAB")
		add.call(0, "ENDSEC")
		add.call(0, "SECTION")
		add.call(2, "ENTITIES")
		_s.append_array(Array(corpo))
		add.call(0, "ENDSEC")
		add.call(0, "EOF")
		return "\n".join(PackedStringArray(_s)) + "\n"


static func nome_layer(s: String) -> String:
	var out := ""
	var mapa := {"á": "A", "à": "A", "ã": "A", "â": "A", "é": "E", "ê": "E", "í": "I", "ó": "O", "õ": "O", "ô": "O", "ú": "U", "ç": "C"}
	for ch in s.to_lower():
		if mapa.has(ch):
			out += mapa[ch]
		elif (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch.to_upper()
		else:
			out += "_"
	return out
