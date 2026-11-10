extends SceneTree
## Fase 2 — T2-01, T2-02, T2-06 e T2-08 (leitura de DXF).

const Lib = preload("lib.gd")
const Dxf = preload("res://dxf.gd")

var T
var m
var FIXTURE := ""


func _initialize() -> void:
	T = Lib.new()
	m = await T.novo_main(self)
	FIXTURE = T.fix("topografia_phase2.dxf")
	print("META|" + JSON.stringify(T.meta(m)))
	_t201()
	_t202()
	_t206()
	_t208()
	quit(T.fim())


func _resumo(r: Dictionary) -> Dictionary:
	return {"ok": r.get("ok"), "layers": r.get("layers", []), "curvas": r.get("curvas", []).size(), "ruas": r.get("ruas", []).size(),
		"pontos": r.get("pontos", []).size(), "textos": r.get("textos", []).size(), "outros": r.get("outros", 0)}


func _t201() -> void:
	var id := "T2-01"
	var r := Dxf.importar(FIXTURE)
	var s := _resumo(r)
	T.dado(id, "entrada", "fixtures/topografia_phase2.dxf (todos os layers)")
	T.dado(id, "saida", s)
	T.check(id, bool(r["ok"]), "arquivo lido sem crash")
	T.check(id, s["layers"] == ["INTERF_AGUA", "PT_COTADOS", "RUAS", "TOPO_CURVAS"], "layers %s" % str(s["layers"]))
	T.check(id, s["curvas"] == 2 and s["ruas"] == 1 and s["pontos"] == 2 and s["textos"] == 2,
		"curvas %d, ruas %d, pontos %d, textos %d (esperado 2, 1, 2, 2)" % [s["curvas"], s["ruas"], s["pontos"], s["textos"]])
	var zs: Array = []
	for c in r["curvas"]:
		zs.append(float(c["z"]))
	zs.sort()
	T.check(id, zs == [100.0, 110.0], "cotas Z das curvas preservadas: %s" % str(zs))
	var pz: Array = []
	for p in r["pontos"]:
		pz.append(p.z)
	pz.sort()
	T.check(id, pz == [101.5, 108.5], "cotas Z dos pontos preservadas: %s" % str(pz))
	T.check(id, r["grupos"]["curvas"] == ["TOPO_CURVAS"] and r["grupos"]["ruas"] == ["RUAS"] and r["grupos"]["pontos"] == ["PT_COTADOS"]
		and r["grupos"]["outros"] == ["INTERF_AGUA"], "cada entidade no layer certo; INTERF_AGUA não vira curva nem rua (%s)" % str(r["grupos"]))


func _t202() -> void:
	var id := "T2-02"
	var casos := [["TOPO_CURVAS", 2, 0, 0], ["PT_COTADOS", 0, 0, 2], ["RUAS", 0, 1, 0]]
	for c in casos:
		var r := Dxf.importar(FIXTURE, {c[0]: true})
		var s := _resumo(r)
		T.check(id, s["curvas"] == c[1] and s["ruas"] == c[2] and s["pontos"] == c[3] and s["outros"] == 0,
			"só %s: curvas %d, ruas %d, pontos %d, INTERF_AGUA %d" % [c[0], s["curvas"], s["ruas"], s["pontos"], s["outros"]])


func _dxf(nome: String, corpo: String) -> String:
	var p: String = T.tmp(nome)
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(corpo)
	f.close()
	return p


func _caso_206(nome: String, path: String, sel: Dictionary, espera: String) -> void:
	var id := "T2-06"
	var n_antes: int = m.registro.erros.size()
	var r: Dictionary = m.importar_dxf(path, "topografia", sel)
	var textos := str(r.get("erro", "")) + " " + " ".join(PackedStringArray(r.get("avisos", [])))
	m.registro.verificar_godot_log()
	var logou: bool = m.registro.erros.size() > n_antes
	T.check(id, textos.to_lower().contains(espera.to_lower()) and logou,
		"%s: diagnóstico \"%s\" e registro no log%s" % [nome, espera, "" if textos.to_lower().contains(espera.to_lower()) and logou else
		" — obtido: [%s], log %s" % [textos.strip_edges(), "sim" if logou else "não"]])


func _t206() -> void:
	var original := FileAccess.get_file_as_string(FIXTURE)
	_caso_206("DXF truncado", _dxf("truncado.dxf", original.substr(0, original.length() / 2)), {}, "truncado")
	var cab := "0\nSECTION\n2\nENTITIES\n"
	var fim := "0\nENDSEC\n0\nEOF\n"
	_caso_206("curva com menos de dois vértices", _dxf("um_vertice.dxf", cab +
		"0\nPOLYLINE\n8\nTOPO_CURVAS\n66\n1\n30\n100.0\n0\nVERTEX\n8\nTOPO_CURVAS\n10\n0.0\n20\n0.0\n30\n100.0\n0\nSEQEND\n8\nTOPO_CURVAS\n" + fim),
		{"TOPO_CURVAS": true}, "menos de dois vértices")
	_caso_206("curva sem elevação", _dxf("sem_z.dxf", cab +
		"0\nLWPOLYLINE\n8\nTOPO_CURVAS\n90\n2\n10\n0.0\n20\n0.0\n10\n100.0\n20\n0.0\n" + fim), {"TOPO_CURVAS": true}, "sem elevação")
	var n0: int = m.registro.erros.size()
	var r: Dictionary = m.importar_dxf(_dxf("ponto_sem_z.dxf", cab + "0\nPOINT\n8\nPT_COTADOS\n10\n5.0\n20\n5.0\n" + fim), "pontos", {"PT_COTADOS": true})
	T.check("T2-06", " ".join(PackedStringArray(r.get("avisos", []))).contains("sem elevação") and m.registro.erros.size() > n0,
		"ponto sem elevação: diagnóstico e registro no log")
	_caso_206("layer inexistente", FIXTURE, {"NAO_EXISTE": true}, "não existe")
	_caso_206("arquivo vazio", _dxf("vazio.dxf", ""), {}, "vazio")
	T.check("T2-06", m.is_inside_tree(), "processo continua aberto depois de todos os casos")


func _t208() -> void:
	var id := "T2-08"
	var bin: String = T.tmp("topografia_phase2_bin.dxf")
	T.check(id, Dxf.ascii_para_binario(FIXTURE, bin), "fixture convertida para DXF binário")
	var head := FileAccess.get_file_as_bytes(bin).slice(0, 18).get_string_from_ascii()
	var rb := Dxf.importar(bin)
	var ra := Dxf.importar(FIXTURE)
	T.dado(id, "binario", _resumo(rb))
	T.check(id, head == "AutoCAD Binary DXF" and bool(rb.get("binario", false)), "arquivo é DXF binário de verdade (sentinela) e foi lido como binário")
	T.check(id, _resumo(rb) == _resumo(ra), "binário produz as mesmas curvas, ruas, pontos, textos e layers do ASCII: %s" % str(_resumo(rb)))
	var zs: Array = []
	for c in rb.get("curvas", []):
		zs.append(float(c["z"]))
	zs.sort()
	T.check(id, zs == [100.0, 110.0], "cotas preservadas no binário")
