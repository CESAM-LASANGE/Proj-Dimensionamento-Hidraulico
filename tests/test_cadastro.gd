extends SceneTree
## Fase 3 — T3-01 a T3-08 (ligações, bacias, interferências, GeoJSON e resultados desatualizados).

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")
const Cadastro = preload("res://cadastro.gd")
const Geo = preload("res://geo.gd")

var T
var m


func _initialize() -> void:
	T = Lib.new()
	m = await T.novo_main(self)
	T.usar_banco_teste(m)
	print("META|" + JSON.stringify(T.meta(m)))
	_t301_302()
	_t303()
	_t304()
	_t305()
	_t306()
	_t307()
	_t308()
	quit(T.fim())


## Rede do T3-02: T1 (0,0)→(100,0) e T2 (0,100)→(100,100).
func _rede_dois_trechos(tam := 130.0) -> void:
	m._novo()
	m.proj["area"] = {"e0": -10.0, "n0": -10.0, "le": tam, "ln": tam, "grid": 50.0}
	var p: Dictionary = m.proj
	var a := Net.novo_no(p, Vector2(0, 0), 100.0, true, "TL")
	var b := Net.novo_no(p, Vector2(100, 0), 99.0, true, "PV")
	var c := Net.novo_no(p, Vector2(0, 100), 101.0, true, "TL")
	var d := Net.novo_no(p, Vector2(100, 100), 100.0, true, "PV")
	Net.novo_trecho(p, m.db, int(a["id"]), int(b["id"]), "C1")
	Net.novo_trecho(p, m.db, int(c["id"]), int(d["id"]), "C2")


func _reg(regs: Array, id: String) -> Dictionary:
	for r in regs:
		if str(r["id"]) == id:
			return r
	return {}


func _t301_302() -> void:
	_rede_dois_trechos()
	var r: Dictionary = m.importar_ligacoes(T.fix("ligacoes_phase3.csv"))
	var rs: Dictionary = r["resumo"]
	var pc: Dictionary = rs["por_categoria"]
	T.dado("T3-01", "resumo", rs)
	T.check("T3-01", int(rs["lidos"]) == 5, "%d registros lidos (esperado 5)" % rs["lidos"])
	T.check("T3-01", int(rs["ids_unicos"]) == 4, "%d identificadores únicos (esperado 4)" % rs["ids_unicos"])
	T.check("T3-01", int(pc["duplicada"]) == 1 and int(pc["sem consumo"]) == 1 and int(pc["fora da área"]) == 1,
		"1 duplicado, 1 sem consumo, 1 fora da área (obtido %d, %d, %d)" % [pc["duplicada"], pc["sem consumo"], pc["fora da área"]])
	var arq: String = T.tmp("relatorio_ligacoes.csv")
	m.exportar_relatorio_ligacoes(arq)
	var linhas := FileAccess.get_file_as_string(arq).strip_edges().split("\n")
	T.check("T3-01", r["registros"].size() == 5 and linhas.size() == 6, "todas as 5 linhas aparecem no relatório (nenhuma descartada em silêncio)")
	var regs: Array = m.proj["ligacoes"]
	var l1 := _reg(regs, "L001")
	var l2 := _reg(regs, "L002")
	var l3 := _reg(regs, "L003")
	T.check("T3-02", str(l1["trecho_nome"]) == "T1" and absf(float(l1["dist"]) - 5.0) < 0.001, "(10,5) → %s a %s m" % [l1["trecho_nome"], str(l1["dist"])])
	T.check("T3-02", str(l2["trecho_nome"]) == "T2" and absf(float(l2["dist"]) - 5.0) < 0.001, "(90,95) → %s a %s m" % [l2["trecho_nome"], str(l2["dist"])])
	T.check("T3-02", int(l3["trecho"]) == -1 and float(l3["dist"]) > 20.0, "(50,50) a %s m (> 20 m) fica sem associação" % str(l3["dist"]))
	T.check("T3-02", not is_nan(float(l1["dist"])) and not is_nan(float(l3["dist"])), "a distância calculada é armazenada em cada ligação")


func _bacias_geojson(nome: String, bacias: Array) -> String:
	var feats: Array = []
	for b in bacias:
		feats.append({"type": "Feature", "properties": {"id": b[0], "pai": b[1], "trecho_saida": b[2]},
			"geometry": {"type": "Polygon", "coordinates": [b[3]]}})
	var p: String = T.tmp(nome)
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify({"type": "FeatureCollection", "features": feats}))
	f.close()
	return p


func _ret(x0: float, y0: float, x1: float, y1: float) -> Array:
	return [[x0, y0], [x1, y0], [x1, y1], [x0, y1], [x0, y0]]


func _t303() -> void:
	var id := "T3-03"
	_rede_dois_trechos()
	m.importar_ligacoes(T.fix("ligacoes_phase3.csv"))
	m.importar_bacias(_bacias_geojson("bacia.geojson", [["B", "", "T1", _ret(-5, -5, 105, 105)]]))
	var b := Cadastro.balanco(m.proj)
	T.dado(id, "balanco", {"pop": b["populacao_valida"], "consumo": b["consumo_valido_l_dia"], "q_validas": b["q_validas"], "q_lancada": b["q_lancada"]})
	T.check(id, is_equal_approx(float(b["populacao_valida"]), 9.0), "população válida %s hab (esperado 9)" % str(b["populacao_valida"]))
	T.check(id, is_equal_approx(float(b["consumo_valido_l_dia"]), 400.0), "consumo válido %s l/dia (esperado 400)" % str(b["consumo_valido_l_dia"]))
	var c := float(m.proj["params"]["c_fin"])
	T.check(id, Lib.aprox(b["q_validas"], 400.0 * c / 86400.0, 1e-9), "registros inválidos (duplicado, sem consumo/fora da área) não entram na vazão")
	T.check(id, Lib.aprox(b["q_validas"], b["q_lancada"], 1e-6), "soma das áreas = soma lançada (%.9f = %.9f l/s)" % [b["q_validas"], b["q_lancada"]])
	m.executar_calculo(false)
	var soma := 0.0
	for r in m.results["rows"].values():
		soma += float(r["q_lig"])
	T.check(id, Lib.aprox(soma, b["q_lancada"], 1e-6), "o motor lança nos trechos a mesma vazão (%.9f l/s)" % soma)


func _t304() -> void:
	var id := "T3-04"
	_rede_dois_trechos()
	var csv := "id;e;n;populacao;consumo_l_hab_dia;situacao\nA1;10;5;3;120;ATIVA\nA2;;;2;80;ATIVA\nA3;20;5;abc;80;ATIVA\nA4;30;5;2;;ATIVA\nA1;10;5;3;120;ATIVA\nA6;999;999;1;90;ATIVA\n"
	var p: String = T.tmp("ligacoes_categorias.csv")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(csv)
	f.close()
	var r: Dictionary = m.importar_ligacoes(p)
	var cats: Array = []
	for reg in r["registros"]:
		cats.append(str(reg["categoria"]))
	T.dado(id, "categorias", cats)
	T.check(id, cats == ["válida", "sem coordenada", "inválida", "sem consumo", "duplicada", "fora da área"], "cada linha classificada: %s" % str(cats))
	var arq: String = T.tmp("relatorio_categorias.csv")
	var ok: Dictionary = m.exportar_relatorio_ligacoes(arq)
	var txt := FileAccess.get_file_as_string(arq)
	T.check(id, bool(ok["ok"]) and txt.contains("categoria") and txt.contains("sem coordenada") and txt.contains("fora da área"),
		"relatório de importação exportado em CSV com a categoria de cada linha")


func _t305() -> void:
	var id := "T3-05"
	_rede_dois_trechos()
	var r: Dictionary = m.importar_interferencias(T.fix("interferencias_phase3.geojson"))
	var fe: Array = m.proj["interferencias"].get("feicoes", [])
	T.check(id, m.proj["interferencias"]["camadas"] == ["AGUA_EXISTENTE", "DRENAGEM"], "camadas reconhecidas: %s" % str(m.proj["interferencias"]["camadas"]))
	var ag: Dictionary = fe[0] if fe.size() > 0 else {}
	T.check(id, str(ag.get("tipo")) == "LineString" and ag.get("coords") == [[10.0, 20.0], [90.0, 20.0]], "geometria preservada (AG-001: %s)" % str(ag.get("coords")))
	T.check(id, str(ag.get("id")) == "AG-001" and str(ag.get("origem")) == "cadastro_teste" and str(ag.get("data")) == "2026-01-15" and str(ag.get("crs")) == "EPSG:31983",
		"propriedades id, origem, data e crs preservadas")
	var arq: String = T.tmp("interf_export.geojson")
	m.exportar_interferencias(arq)
	var de_volta := Geo.importar_interferencias(arq)
	var ids: Array = []
	for f in de_volta["feicoes"]:
		ids.append(f["id"])
	T.check(id, ids == ["AG-001", "DR-001"] and str(de_volta["crs"]) == "EPSG:31983", "exportação mantém os identificadores %s e o CRS" % str(ids))
	m.plan.redesenhar()
	T.check(id, m.plan.has_method("_draw_cadastro"), "planta desenha a camada de interferências (verificação visual no teste gráfico)")


func _t306() -> void:
	var id := "T3-06"
	_rede_dois_trechos(300.0)
	var csv := "id;e;n;populacao;consumo_l_hab_dia;situacao\nL1;10;5;3;120;ATIVA\nL2;90;95;2;80;ATIVA\nL3;50;50;4;200;ATIVA\nL4;150;50;1;60;ATIVA\n"
	var p: String = T.tmp("ligacoes_bacias.csv")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(csv)
	f.close()
	m.importar_ligacoes(p)
	var bacias := [["B", "", "T1", _ret(-5, -5, 105, 105)], ["S1", "B", "", _ret(-5, -5, 48, 105)], ["S2", "B", "", _ret(48, -5, 105, 105)]]
	var rb: Dictionary = m.importar_bacias(_bacias_geojson("subbacias.geojson", bacias))
	T.check(id, rb["erros"].is_empty(), "bacia principal com duas sub-bacias sem sobreposição (%s)" % str(rb["erros"]))
	var uma := true
	var onde: Array = []
	for lid in ["L1", "L2", "L3"]:
		var reg := _reg(m.proj["ligacoes"], lid)
		var bd := Cadastro.bacia_de(Vector2(float(reg["e"]), float(reg["n"])), m.proj["bacias"])
		onde.append("%s→%s" % [lid, bd["id"]])
		uma = uma and str(bd["id"]) in ["S1", "S2"] and not bool(bd["ambigua"])
	T.check(id, uma, "cada ligação pertence a uma única sub-bacia: %s" % str(onde))
	var b := Cadastro.balanco(m.proj)
	var t1 := int(Net.achar_trecho(m.proj, "T1")["id"])
	var q_sub := 0.0
	for k in ["S1", "S2"]:
		q_sub += float(b["por_bacia"].get(k, {}).get("q", 0.0))
	T.check(id, Lib.aprox(float(b["por_trecho"].get(t1, 0.0)), q_sub, 1e-9) and q_sub > 0.0, "contribuição das sub-bacias chega ao trecho de saída T1 (%.9f l/s)" % q_sub)
	var fora := false
	for e in b["erros"]:
		if str(e).contains("L4") and str(e).contains("fora de qualquer bacia"):
			fora = true
	T.check(id, fora, "ligação L4 fora de qualquer bacia aparece como erro")
	var rb2: Dictionary = m.importar_bacias(_bacias_geojson("sobrepostas.geojson", bacias + [["S3", "B", "", _ret(20, 20, 70, 70)]]))
	var sob := false
	for e in rb2["erros"]:
		if str(e).contains("se sobrepõem"):
			sob = true
	T.check(id, sob, "áreas sobrepostas são sinalizadas: %s" % str(rb2["erros"]).left(140))


func _t307() -> void:
	var id := "T3-07"
	m._do_action("exemplo")
	T.usar_banco_teste(m)
	m.executar_calculo(false)
	var nos_antes: Array = m.proj["nodes"].duplicate(true)
	var trs_antes: Array = m.proj["trechos"].duplicate(true)
	var arq: String = T.tmp("rede.geojson")
	m.exportar_rede_geojson(arq)
	m._novo()
	var r: Dictionary = m.importar_rede_geojson(arq)
	T.check(id, bool(r["ok"]), "GeoJSON reimportado num projeto novo")
	var nm := Net.node_map(m.proj)
	var tm := Net.trecho_map(m.proj)
	var dif: Array = []
	for n in nos_antes:
		var x = nm.get(int(n["id"]))
		if x == null:
			dif.append("nó %s sumiu" % n["nome"])
			continue
		if str(x["nome"]) != str(n["nome"]) or absf(float(x["e"]) - float(n["e"])) > 0.001 or absf(float(x["n"]) - float(n["n"])) > 0.001 \
				or absf(float(x["ct"]) - float(n["ct"])) > 0.001 or str(x["tipo"]) != str(n["tipo"]):
			dif.append("nó %s" % n["nome"])
	for t in trs_antes:
		var x = tm.get(int(t["id"]))
		if x == null:
			dif.append("trecho %s sumiu" % t["nome"])
			continue
		if str(x["nome"]) != str(t["nome"]) or int(x["ni"]) != int(t["ni"]) or int(x["nf"]) != int(t["nf"]) \
				or absf(float(x["d"]) - float(t["d"])) > 0.001 or str(x["situacao"]) != str(t["situacao"]) \
				or absf(float(x["cc_m"]) - float(t["cc_m"])) > 0.001 or absf(float(x["cc_j"]) - float(t["cc_j"])) > 0.001:
			dif.append("trecho %s" % t["nome"])
	T.check(id, dif.is_empty() and m.proj["nodes"].size() == nos_antes.size() and m.proj["trechos"].size() == trs_antes.size(),
		"%d nós e %d trechos iguais: identificadores, coordenadas, cotas, diâmetros, situação e sentido" % [nos_antes.size(), trs_antes.size()] +
		("" if dif.is_empty() else " — diferenças: %s" % str(dif.slice(0, 5))))


func _t308() -> void:
	var id := "T3-08"
	m._do_action("exemplo")
	T.usar_banco_teste(m)
	m.executar_calculo(false)
	T.check(id, m.resultados_atuais and m.motivo_bloqueio() == "", "rede dimensionada e aprovada")
	var n: Dictionary = m.proj["nodes"][4]
	n["ct"] = float(n["ct"]) + 0.5
	m.on_changed("no")
	m._mostrar("planilhas")
	m.sheets.current_tab = 4
	m._refresh_sheet(4)
	T.check(id, not m.resultados_atuais and m.stale_label.visible, "após alterar uma cota, resultados marcados como desatualizados (\"%s\")" % m.stale_label.text.strip_edges())
	var e1: Dictionary = m.exportar_memorial(T.tmp("memorial_stale.txt"))
	var e2: Dictionary = m.exportar_planilha_arquivo("orc", T.tmp("orc_stale.csv"))
	T.check(id, not bool(e1["ok"]) and not bool(e2["ok"]) and str(e1["motivo"]).contains("desatualizad"),
		"exportação final bloqueada com motivo: %s" % str(e1.get("motivo", "")).left(120))
	m.executar_calculo(false)
	var e3: Dictionary = m.exportar_memorial(T.tmp("memorial_ok.txt"))
	T.check(id, m.resultados_atuais and not m.stale_label.visible and bool(e3["ok"]), "novo dimensionamento limpa o estado desatualizado e libera a exportação")
	m._mostrar("tracado")
