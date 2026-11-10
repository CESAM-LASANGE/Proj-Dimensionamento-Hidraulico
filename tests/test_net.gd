extends SceneTree
## Fase 1 — EVAL-102 (rede ramificada) e EVAL-104 (erro estrutural bloqueia resultado).

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")

var T
var m


func _initialize() -> void:
	T = Lib.new()
	m = await T.novo_main(self)
	T.usar_banco_teste(m)
	print("META|" + JSON.stringify(T.meta(m)))
	_eval_102()
	_eval_104()
	quit(T.fim())


func _abrir(fixture: String) -> void:
	T.carregar(m, fixture)
	m.opts["grava_res"] = false


# ------------------------------------------------------------------ EVAL-102

func _eval_102() -> void:
	var id := "EVAL-102"
	_abrir("rede_ramificada.esg")
	T.dado(id, "entrada", "rede_ramificada.esg: T1 (A→C) e T2 (B→C) chegam em C; T3 (C→D)")
	T.dado(id, "params", m.proj["params"])
	m.executar_calculo(false)
	var r1: Dictionary = T.linha(m, "T1")
	var r2: Dictionary = T.linha(m, "T2")
	var r3: Dictionary = T.linha(m, "T3")
	T.check(id, Lib.aprox(r3["qm_i"], float(r1["qj_i"]) + float(r2["qj_i"]), 1e-9),
		"vazão de montante inicial de T3 = soma dos afluentes (%.6f = %.6f + %.6f)" % [r3["qm_i"], r1["qj_i"], r2["qj_i"]])
	T.check(id, Lib.aprox(r3["qm_f"], float(r1["qj_f"]) + float(r2["qj_f"]), 1e-9),
		"vazão de montante final de T3 = soma dos afluentes (%.6f)" % r3["qm_f"])
	var ok_prop := true
	for r in [r1, r2, r3]:
		ok_prop = ok_prop and Lib.aprox(r["qj_i"], float(r["qm_i"]) + float(r["qp_i"]) + float(r["ctr_i"]), 1e-9)
		ok_prop = ok_prop and Lib.aprox(r["qj_f"], float(r["qm_f"]) + float(r["qp_f"]) + float(r["ctr_f"]), 1e-9)
		ok_prop = ok_prop and Lib.aprox(r["ctr_i"], float(r["txi"]) / 1000.0 * float(r["L"]), 1e-9)
	T.check(id, ok_prop, "Q jusante = Q montante + pontual + contribuição do trecho, em início e fim de plano")
	T.check(id, float(r3["d"]) >= maxf(float(r1["d"]), float(r2["d"])), "diâmetro de T3 (%d) ≥ maior de montante (%d)" % [int(r3["d"]), int(maxf(float(r1["d"]), float(r2["d"])))])
	# diâmetro de montante maior forçado
	_abrir("rede_ramificada.esg")
	var t2: Dictionary = T.trecho(m, "T2")
	t2["fixa_d"] = true
	t2["d"] = 200.0
	m.executar_calculo(false)
	T.check(id, float(T.linha(m, "T3")["d"]) >= 200.0, "com T2 fixado em ø200, T3 adota %d mm (≥ 200)" % int(T.linha(m, "T3")["d"]))
	# degrau sem tubo de queda (desnível < degrau máximo)
	_abrir("rede_ramificada.esg")
	var t1: Dictionary = T.trecho(m, "T1")
	t1["fixa_cotas"] = true
	t1["cc_m"] = 99.3
	t1["cc_j"] = 98.8
	m.executar_calculo(false)
	_verifica_queda(id, "degrau", false)
	# tubo de queda (desnível > 0,65 m)
	_abrir("rede_ramificada.esg")
	t1 = T.trecho(m, "T1")
	t1["fixa_cotas"] = true
	t1["cc_m"] = 99.6
	t1["cc_j"] = 99.3
	m.executar_calculo(false)
	_verifica_queda(id, "tubo de queda", true)


func _verifica_queda(id: String, caso: String, espera_tq: bool) -> void:
	var c: Dictionary = Net.achar_no(m.proj, "C")
	var nr: Dictionary = m.results["nodes"][int(c["id"])]
	var r1: Dictionary = T.linha(m, "T1")
	var r2: Dictionary = T.linha(m, "T2")
	var r3: Dictionary = T.linha(m, "T3")
	var esperado := maxf(float(r1["cc_j"]), float(r2["cc_j"])) - float(r3["cc_m"])
	T.check(id, Lib.aprox(nr["queda"], esperado, 1e-9), "%s: desnível no nó C = %.3f m (maior chegada − saída = %.3f)" % [caso, nr["queda"], esperado])
	T.check(id, bool(nr["tq"]) == espera_tq and (str(nr["tipo"]) == "TQ") == espera_tq,
		"%s: tubo de queda %s (tipo adotado %s; degrau máximo 0,65 m)" % [caso, "sim" if bool(nr["tq"]) else "não", nr["tipo"]])
	if espera_tq:
		T.check(id, T.obs_de(m, "T3").contains("Tubo de queda"), "%s: observação registrada no trecho de saída" % caso)


# ------------------------------------------------------------------ EVAL-104

func _eval_104() -> void:
	var id := "EVAL-104"
	var pasta := ProjectSettings.globalize_path("user://res_eval104")
	DirAccess.make_dir_recursive_absolute(pasta)
	var casos := [["rede_invalida.esg", "ciclo", ["laço"]], ["rede_invalida_no_inexistente.esg", "nó inexistente", ["inexistente", "não existe"]],
		["rede_invalida_autoligacao.esg", "trecho sem conexão (nó inicial = final)", ["laço", "conexão", "mesmo nó"]],
		["rede_invalida_multiplas_saidas.esg", "nó com múltiplas saídas", ["saída"]]]
	T.dado(id, "entrada", "fixtures rede_invalida*.esg")
	for c in casos:
		_abrir(c[0])
		m.opts["grava_res"] = true
		m.opts["data_dir"] = pasta
		var antes := DirAccess.get_files_at(pasta).size()
		var res: Dictionary = m.executar_calculo(true)
		var depois := DirAccess.get_files_at(pasta).size()
		var nome: String = c[1]
		T.check(id, res.has("aprovado") and res["aprovado"] == false,
			"%s: resultado.aprovado == false" % nome + ("" if res.has("aprovado") else " (campo 'aprovado' não existe; ok=%s)" % str(res.get("ok"))))
		T.check(id, not m.resultados_validos, "%s: resultados_validos == false (obtido %s)" % [nome, str(m.resultados_validos)])
		T.check(id, depois == antes, "%s: nenhum .RES gravado (%d novo(s))" % [nome, depois - antes])
		T.check(id, not res.has("orc"), "%s: nenhum orçamento apresentado como final" % nome)
		var obs_txt := ""
		for o in m._rows_obs():
			obs_txt += " " + str(o.get("obs", "")).to_lower()
		var achou := false
		for k in c[2]:
			if obs_txt.contains(str(k)):
				achou = true
		T.check(id, achou, "%s: planilha de observações mostra o erro estrutural" % nome + ("" if achou else " (planilha: [%s])" % obs_txt.strip_edges().left(120)))
		T.check(id, not m.status_label.text.to_lower().contains("concluído"), "%s: interface não informa \"dimensionamento concluído\"" % nome +
			("" if not m.status_label.text.to_lower().contains("concluído") else " (barra: \"%s\")" % m.status_label.text.left(80)))
	m.opts["data_dir"] = ""
