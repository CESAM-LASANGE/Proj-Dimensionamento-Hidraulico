extends SceneTree
## Fase 0 — EVAL-000 (parte interna) e EVAL-002 (snapshot de baseline).

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")

const TOL := 1e-6


func _initialize() -> void:
	var T := Lib.new()
	var m = await T.novo_main(self)
	print("META|" + JSON.stringify(T.meta(m)))

	# ---------------- EVAL-000: a rede de exemplo carrega com nós, trechos e resultados
	T.check("EVAL-000", m.proj["nodes"].size() > 0, "rede de exemplo tem %d nós" % m.proj["nodes"].size())
	T.check("EVAL-000", m.proj["trechos"].size() > 0, "rede de exemplo tem %d trechos" % m.proj["trechos"].size())
	T.check("EVAL-000", m.resultados_validos and m.results["rows"].size() == m.proj["trechos"].size(),
		"exemplo dimensionado na abertura (%d linhas de resultado)" % m.results.get("rows", {}).size())

	# ---------------- EVAL-002: snapshot
	var snap := _snapshot(m)
	T.dado("EVAL-002", "entrada", "rede de exemplo (Net.exemplo) + banco padrão do app")
	T.dado("EVAL-002", "params", m.proj["params"])
	T.dado("EVAL-002", "meta", T.meta(m))
	var campos := ["qm_i", "qm_f", "qj_i", "qj_f", "d", "i", "cc_m", "cc_j", "rec_m", "rec_j", "v_i", "v_f", "sigma"]
	var r0: Dictionary = snap["trechos"].values()[0]
	var falta: Array = []
	for c in campos:
		if not r0.has(c):
			falta.append(c)
	T.check("EVAL-002", falta.is_empty(), "snapshot contém vazões, diâmetro, declividade, cotas, recobrimento, velocidade e tensão" +
		("" if falta.is_empty() else " (faltam %s)" % str(falta)))
	T.check("EVAL-002", not snap["nos"].is_empty() and not snap["orcamento"]["linhas"].is_empty(),
		"snapshot contém tipos dos nós (%d) e quantitativos/custo (total R$ %.2f)" % [snap["nos"].size(), float(snap["orcamento"]["total"])])
	var caminho := Lib.DIR.path_join("expected/baseline_exemplo.json")
	var atualizar := OS.get_environment("ATUALIZAR_BASELINE") == "1"
	if atualizar or not FileAccess.file_exists(caminho):
		var f := FileAccess.open(caminho, FileAccess.WRITE)
		f.store_string(JSON.stringify(snap, " ", false))
		f.close()
		T.check("EVAL-002", true, "baseline gravada em tests/expected/baseline_exemplo.json (%s)" % ("atualizada" if atualizar else "criada agora"))
	else:
		var antigo = JSON.parse_string(FileAccess.get_file_as_string(caminho))
		var difs := _comparar(antigo.get("trechos", {}), snap["trechos"], "trecho") + _comparar(antigo.get("nos", {}), snap["nos"], "nó")
		var ta := float(antigo.get("orcamento", {}).get("total", -1))
		var tb := float(snap["orcamento"]["total"])
		if absf(ta - tb) > 0.005:
			difs.append("total do orçamento %.2f → %.2f" % [ta, tb])
		T.dado("EVAL-002", "diferencas", difs)
		T.check("EVAL-002", difs.is_empty(), "resultados iguais à baseline gravada" +
			("" if difs.is_empty() else ": %d diferença(s), ex.: %s" % [difs.size(), str(difs[0])]))
	quit(T.fim())


func _snapshot(m) -> Dictionary:
	var trs := {}
	for r in m.results["rows"].values():
		trs[str(r["nome"])] = {"coletor": r["coletor"], "pv_i": r["pv_i"], "pv_f": r["pv_f"], "L": r["L"],
			"qm_i": r["qm_i"], "qm_f": r["qm_f"], "qj_i": r["qj_i"], "qj_f": r["qj_f"], "d": r["d"], "i": r["i"],
			"cc_m": r["cc_m"], "cc_j": r["cc_j"], "rec_m": r["rec_m"], "rec_j": r["rec_j"], "v_i": r["v_i"], "v_f": r["v_f"],
			"yd_i": r["yd_i"], "yd_f": r["yd_f"], "sigma": r["sigma"], "status": r["status"]}
	var nos := {}
	var nm := Net.node_map(m.proj)
	for nid in m.results["nodes"].keys():
		var nr: Dictionary = m.results["nodes"][nid]
		nos[str(nm[nid]["nome"])] = {"tipo": nr["tipo"], "prof": nr["prof"], "queda": nr["queda"]}
	var linhas: Array = []
	for l in m.results["orc"]["linhas"]:
		if str(l["tipo"]) in ["item", "total"]:
			linhas.append({"desc": l.get("desc", ""), "q": l.get("q", 0.0), "total": l.get("total", 0.0)})
	return {"_aviso": "Baseline de regressão: resultados atuais do app, NÃO validados normativamente.",
		"versao_app": m.VERSAO, "trechos": trs, "nos": nos,
		"orcamento": {"total": m.results["orc"]["total"], "linhas": linhas}}


func _comparar(a: Dictionary, b: Dictionary, rot: String) -> Array:
	var out: Array = []
	for k in a.keys():
		if not b.has(k):
			out.append("%s %s sumiu" % [rot, k])
			continue
		for c in a[k].keys():
			var va = a[k][c]
			var vb = b[k].get(c)
			if (va is float or va is int) and (vb is float or vb is int):
				if absf(float(va) - float(vb)) > TOL * maxf(1.0, absf(float(va))):
					out.append("%s %s.%s: %s → %s" % [rot, k, c, str(va), str(vb)])
			elif str(va) != str(vb):
				out.append("%s %s.%s: %s → %s" % [rot, k, c, str(va), str(vb)])
	for k in b.keys():
		if not a.has(k):
			out.append("%s %s novo" % [rot, k])
	return out
