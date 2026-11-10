extends RefCounted
## Base topográfica: curvas de nível, ruas, pontos cotados e textos.
## Cálculo automático de cotas (manual 1.3.4): interpolação nas curvas de nível
## pelas linhas de maior declive, ou ponto cotado mais próximo.

var curvas: Array = [] # [{"z": float, "pts": PackedVector2Array, "bb": Rect2}]
var ruas: Array = [] # [PackedVector2Array]
var pontos: Array = [] # [Vector3] (e, n, z)
var textos: Array = [] # [{"p": Vector2, "s": String}]

const CELULA := 20.0
var _grid := {}
var _pgrid := {}


func limpar() -> void:
	curvas = []
	ruas = []
	pontos = []
	textos = []
	_grid = {}
	_pgrid = {}


func tem_curvas() -> bool:
	return not curvas.is_empty()


func tem_pontos() -> bool:
	return not pontos.is_empty()


func vazio() -> bool:
	return curvas.is_empty() and ruas.is_empty() and pontos.is_empty()


static func _flat_to_pts(flat: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var k := 0
	while k + 1 < flat.size():
		pts.append(Vector2(float(flat[k]), float(flat[k + 1])))
		k += 2
	return pts


static func _pts_to_flat(pts: PackedVector2Array) -> Array:
	var out: Array = []
	for p in pts:
		out.append(snappedf(p.x, 0.001))
		out.append(snappedf(p.y, 0.001))
	return out


func from_dict(d: Dictionary) -> void:
	limpar()
	var cs: Array = []
	for c in d.get("curvas", []):
		cs.append({"z": float(c.get("z", 0.0)), "pts": _flat_to_pts(c.get("p", []))})
	set_curvas(cs)
	for r in d.get("ruas", []):
		ruas.append(_flat_to_pts(r))
	var ps: Array = []
	for p in d.get("pontos", []):
		if p is Array and p.size() >= 3:
			ps.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	set_pontos(ps)
	for t in d.get("textos", []):
		if t is Array and t.size() >= 3:
			textos.append({"p": Vector2(float(t[0]), float(t[1])), "s": str(t[2])})


func to_dict() -> Dictionary:
	var cs: Array = []
	for c in curvas:
		cs.append({"z": c["z"], "p": _pts_to_flat(c["pts"])})
	var rs: Array = []
	for r in ruas:
		rs.append(_pts_to_flat(r))
	var ps: Array = []
	for p in pontos:
		ps.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
	var ts: Array = []
	for t in textos:
		ts.append([snappedf(t["p"].x, 0.01), snappedf(t["p"].y, 0.01), t["s"]])
	return {"curvas": cs, "ruas": rs, "pontos": ps, "textos": ts}


func set_curvas(cs: Array) -> void:
	curvas = []
	for c in cs:
		var pts: PackedVector2Array = c["pts"]
		if pts.size() < 2:
			continue
		var bb := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			bb = bb.expand(p)
		curvas.append({"z": float(c["z"]), "pts": pts, "bb": bb})
	_indexar()


func set_pontos(ps: Array) -> void:
	pontos = ps
	_pgrid = {}
	for k in pontos.size():
		var c := Vector2i(floori(pontos[k].x / CELULA), floori(pontos[k].y / CELULA))
		if not _pgrid.has(c):
			_pgrid[c] = []
		_pgrid[c].append(k)


func _indexar() -> void:
	_grid = {}
	for ci in curvas.size():
		var pts: PackedVector2Array = curvas[ci]["pts"]
		for si in pts.size() - 1:
			var a := pts[si]
			var b := pts[si + 1]
			var x0 := floori(minf(a.x, b.x) / CELULA)
			var x1 := floori(maxf(a.x, b.x) / CELULA)
			var y0 := floori(minf(a.y, b.y) / CELULA)
			var y1 := floori(maxf(a.y, b.y) / CELULA)
			if (x1 - x0 + 1) * (y1 - y0 + 1) > 400:
				x1 = x0 + 19
				y1 = y0 + 19
			for cx in range(x0, x1 + 1):
				for cy in range(y0, y1 + 1):
					var key := Vector2i(cx, cy)
					if not _grid.has(key):
						_grid[key] = []
					_grid[key].append(Vector2i(ci, si))


func extents() -> Rect2:
	var r := Rect2()
	var first := true
	for c in curvas:
		r = c["bb"] if first else r.merge(c["bb"])
		first = false
	for rua in ruas:
		for p in rua:
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
	for p in pontos:
		var v := Vector2(p.x, p.y)
		if first:
			r = Rect2(v, Vector2.ZERO)
			first = false
		else:
			r = r.expand(v)
	return r


## Interpolação nas curvas de nível pela linha de maior declive:
## lança "nraios" semirretas; para cada par de direções opostas que encontra
## curvas de cotas diferentes, interpola linearmente; usa o par mais curto
## (maior declividade). Retorna também o rastro para desenho.
func cota_curvas(p: Vector2, raio: float, nraios: int) -> Dictionary:
	var res := {"ok": false, "z": NAN, "raios": [], "par": []}
	if curvas.is_empty():
		return res
	var segs := {}
	var x0 := floori((p.x - raio) / CELULA)
	var x1 := floori((p.x + raio) / CELULA)
	var y0 := floori((p.y - raio) / CELULA)
	var y1 := floori((p.y + raio) / CELULA)
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			for s in _grid.get(Vector2i(cx, cy), []):
				segs[s] = true
	if segs.is_empty():
		return res
	nraios = maxi(4, nraios + nraios % 2)
	var hits: Array = []
	hits.resize(nraios)
	for k in nraios:
		var ang := TAU * k / nraios
		var dir := Vector2(cos(ang), sin(ang))
		var best_t := INF
		var best_z := 0.0
		for s in segs.keys():
			var pts: PackedVector2Array = curvas[s.x]["pts"]
			var a := pts[s.y]
			var b := pts[s.y + 1]
			var sv := b - a
			var den := dir.cross(sv)
			if absf(den) < 1e-12:
				continue
			var ap := a - p
			var t := ap.cross(sv) / den
			var u := ap.cross(dir) / den
			if t >= 0.0 and t <= raio and u >= 0.0 and u <= 1.0 and t < best_t:
				best_t = t
				best_z = float(curvas[s.x]["z"])
		if best_t < INF:
			hits[k] = [best_t, best_z, dir]
			res["raios"].append([p, p + dir * best_t])
	var half := nraios / 2
	var melhor := INF
	var mais_perto = null
	for k in nraios:
		var h = hits[k]
		if h != null and (mais_perto == null or float(h[0]) < float(mais_perto[0])):
			mais_perto = h
	if mais_perto != null and float(mais_perto[0]) < 0.01:
		res["ok"] = true
		res["z"] = float(mais_perto[1])
		return res
	for k in half:
		var a = hits[k]
		var b = hits[k + half]
		if a == null or b == null or is_equal_approx(float(a[1]), float(b[1])):
			continue
		var tot := float(a[0]) + float(b[0])
		if tot < melhor:
			melhor = tot
			res["z"] = float(a[1]) + (float(b[1]) - float(a[1])) * float(a[0]) / tot
			res["par"] = [p + a[2] * float(a[0]), p + b[2] * float(b[0])]
			res["ok"] = true
	if not bool(res["ok"]) and mais_perto != null:
		# cume ou ponto baixo: todas as curvas ao redor têm a mesma cota
		res["ok"] = true
		res["z"] = float(mais_perto[1])
		res["aprox"] = true
	return res


func ponto_proximo(p: Vector2, raio: float) -> Dictionary:
	var res := {"ok": false, "pt": Vector3.ZERO, "dist": INF}
	if pontos.is_empty():
		return res
	var r := ceili(raio / CELULA)
	var c0 := Vector2i(floori(p.x / CELULA), floori(p.y / CELULA))
	for cx in range(c0.x - r, c0.x + r + 1):
		for cy in range(c0.y - r, c0.y + r + 1):
			for k in _pgrid.get(Vector2i(cx, cy), []):
				var q: Vector3 = pontos[k]
				var d := p.distance_to(Vector2(q.x, q.y))
				if d <= raio and d < float(res["dist"]):
					res = {"ok": true, "pt": q, "dist": d}
	return res


## criterio: 1 = curvas de nível, 2 = pontos cotados, 3 = curvas + pontos.
## Resultado: {ok, z, metodo ("curvas" | "ponto" | ""), dist (m, para ponto), aprox, raios, par}.
## Sem resultado: ok=false e z=NAN (nunca 0 silencioso).
func cota(p: Vector2, criterio: int, raio: float, nraios: int, raio_pontos: float) -> Dictionary:
	var falha := {"ok": false, "z": NAN, "metodo": "", "dist": NAN, "aprox": false, "raios": [], "par": []}
	var de_ponto := func(pp: Dictionary) -> Dictionary:
		return {"ok": true, "z": pp["pt"].z, "metodo": "ponto", "dist": pp["dist"], "aprox": false,
			"ponto": Vector2(pp["pt"].x, pp["pt"].y), "raios": [], "par": []}
	if criterio == 2 or (criterio == 3 and not tem_curvas()):
		var pp := ponto_proximo(p, raio_pontos)
		return de_ponto.call(pp) if bool(pp["ok"]) else falha
	if criterio == 3 and tem_pontos():
		# ponto cotado dentro de 10% do raio de busca tem prioridade
		var pp := ponto_proximo(p, raio_pontos * 0.1)
		if pp["ok"]:
			return de_ponto.call(pp)
	var rc := cota_curvas(p, raio, nraios)
	if bool(rc["ok"]):
		rc["metodo"] = "curvas"
		rc["dist"] = NAN
		rc["aprox"] = bool(rc.get("aprox", false))
		return rc
	if criterio == 3:
		var pp := ponto_proximo(p, raio_pontos)
		if pp["ok"]:
			return de_ponto.call(pp)
	falha["raios"] = rc.get("raios", [])
	return falha
