extends SceneTree
## Fase 2 — T2-03, T2-04, T2-05 e T2-07 (cotas e referência espacial).

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")
const Report = preload("res://report.gd")

var T
var m


func _initialize() -> void:
	T = Lib.new()
	m = await T.novo_main(self)
	print("META|" + JSON.stringify(T.meta(m)))
	m._novo()
	var fx: String = T.fix("topografia_phase2.dxf")
	m.importar_dxf(fx, "topografia", {"TOPO_CURVAS": true})
	m.importar_dxf(fx, "pontos", {"PT_COTADOS": true})
	m.opts["raio"] = 100.0
	m.opts["precisao"] = 3
	m.opts["raio_pontos"] = 10.0
	_t203()
	_t204()
	_t205()
	_t207()
	quit(T.fim())


func _t203() -> void:
	var id := "T2-03"
	T.dado(id, "entrada", "curvas horizontais 100 m (y=0) e 110 m (y=100) da fixture; raio 100 m, precisão 3")
	for c in [[Vector2(50, 50), 105.0], [Vector2(25, 25), 102.5], [Vector2(75, 75), 107.5]]:
		var r: Dictionary = m.cota_criterio(c[0], 1)
		T.check(id, bool(r["ok"]) and absf(float(r["z"]) - float(c[1])) <= 0.001,
			"(%d, %d) → %.4f m (esperado %.3f; tolerância 0,001)" % [int(c[0].x), int(c[0].y), float(r["z"]), c[1]])


func _t204() -> void:
	var id := "T2-04"
	var t = m.topo
	var a: Dictionary = t.cota(Vector2(21, 20), 2, 100.0, 24, 10.0)
	var b: Dictionary = t.cota(Vector2(79, 80), 2, 100.0, 24, 10.0)
	var fora: Dictionary = t.cota(Vector2(50, 50), 2, 100.0, 24, 10.0)
	T.check(id, bool(a["ok"]) and is_equal_approx(float(a["z"]), 101.5), "(21,20) → %s" % str(a["z"]))
	T.check(id, bool(b["ok"]) and is_equal_approx(float(b["z"]), 108.5), "(79,80) → %s" % str(b["z"]))
	T.check(id, not bool(fora["ok"]) and is_nan(float(fora["z"])), "fora do raio (10 m) → ok=false, sem cota")
	T.check(id, absf(float(a["dist"]) - 1.0) < 1e-6 and absf(float(b["dist"]) - 1.0) < 1e-6,
		"resultado informa a distância do ponto usado (%s m e %s m)" % [str(a["dist"]), str(b["dist"])])


func _t205() -> void:
	var id := "T2-05"
	var t = m.topo
	var perto: Dictionary = t.cota(Vector2(21, 20), 3, 100.0, 24, 100.0)
	T.check(id, str(perto["metodo"]) == "ponto" and is_equal_approx(float(perto["z"]), 101.5),
		"ponto a 1 m (dentro de 10%% do raio de 100 m) usa o ponto cotado: %s / %s" % [perto["metodo"], str(perto["z"])])
	var longe: Dictionary = t.cota(Vector2(50, 50), 3, 100.0, 24, 100.0)
	T.check(id, str(longe["metodo"]) == "curvas" and absf(float(longe["z"]) - 105.0) < 0.001,
		"sem ponto próximo usa as curvas: %s / %s" % [longe["metodo"], str(longe["z"])])
	var nada: Dictionary = t.cota(Vector2(900, 900), 3, 100.0, 24, 100.0)
	T.check(id, not bool(nada["ok"]) and is_nan(float(nada["z"])), "nenhum método funciona → cota inválida (NaN), nunca 0,000")
	# no traçado, o nó criado sem cota fica marcado como não confirmado
	m.opts["cota_modo"] = "int"
	var cr: Dictionary = m.cota_auto(Vector2(900, 900))
	T.check(id, not bool(cr["ok"]), "cota automática fora da base também falha explicitamente")


func _t207() -> void:
	var id := "T2-07"
	var ref := {"crs": "EPSG:31983", "unidade_horizontal": "m", "unidade_vertical": "m", "datum_vertical": "não informado",
		"origem_topografia": "topografia_phase2.dxf"}
	for k in ref.keys():
		m.proj["referencia"][k] = ref[k]
	var arq: String = T.tmp("ref.esg")
	m._save_to(arq)
	m._novo()
	m._load_from(arq)
	var lido: Dictionary = m.proj["referencia"]
	var dif: Array = []
	for k in ref.keys():
		if str(lido.get(k, "")) != str(ref[k]):
			dif.append("%s: %s" % [k, str(lido.get(k))])
	T.dado(id, "referencia_lida", lido)
	T.check(id, dif.is_empty(), "CRS, unidades, datum e origem preservados ao salvar e reabrir" + ("" if dif.is_empty() else " — diferenças: %s" % str(dif)))
	T.check(id, Net.referencia_texto(m.proj).begins_with("EPSG:31983"), "texto de referência: %s" % Net.referencia_texto(m.proj))
	m._novo()
	T.check(id, Net.referencia_texto(m.proj) == "referência não informada", "projeto sem CRS marcado como \"referência não informada\"")
	m._do_action("exemplo")
	var mem := Report.memorial(m.proj, m.results, "teste", m.extra_memorial())
	T.check(id, mem.contains("referência não informada"), "o memorial mostra a situação da referência espacial")
