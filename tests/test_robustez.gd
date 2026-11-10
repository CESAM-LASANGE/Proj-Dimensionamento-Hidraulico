extends SceneTree
## Fase 5 — T5-01 a T5-08 (migração, persistência, desfazer/refazer, arquivos corrompidos,
## banco inconsistente, falha de gravação, projeto grande e isolamento da lógica de domínio).
## T5-09 (regressão completa) é avaliado pelo runner. O redraw do T5-07 é medido em test_grafico.gd.

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")
const Db = preload("res://db.gd")

var T
var m


func _initialize() -> void:
	T = Lib.new()
	m = await T.novo_main(self)
	T.usar_banco_teste(m)
	m.opts["db_path"] = T.BANCO_TESTE
	print("META|" + JSON.stringify(T.meta(m)))
	_t501()
	_t502()
	_t503()
	_t504()
	_t505()
	_t506()
	_t507()
	_t508()
	quit(T.fim())


func _txt(v) -> String:
	return JSON.stringify(m._sanear(v))


# ------------------------------------------------------------------ T5-01

func _t501() -> void:
	var id := "T5-01"
	var ok: bool = m._load_from(T.fix("projeto_v2_phase5.json"))
	T.check(id, ok, "projeto v2 abre sem crash")
	var nomes: Array = []
	for n in m.proj["nodes"]:
		nomes.append(str(n["nome"]))
	nomes.sort()
	T.check(id, nomes == ["PV-01", "PV-02", "PV-03"], "nós criados uma única vez por nome: %s" % str(nomes))
	var t1: Dictionary = Net.achar_trecho(m.proj, "1-2")
	var t2: Dictionary = Net.achar_trecho(m.proj, "2-3")
	T.check(id, is_equal_approx(float(t1["ext_fix"]), 80.0) and is_equal_approx(float(t2["ext_fix"]), 75.0), "extensões preservadas como extensão fixa (80 e 75 m)")
	T.check(id, bool(t1["fixa_d"]) and is_equal_approx(float(t1["d"]), 150.0) and not bool(t2["fixa_d"]), "diâmetro fixado (ø150 em 1-2) permanece fixado")
	var pv1 := Net.achar_no(m.proj, "PV-01")
	var pv2 := Net.achar_no(m.proj, "PV-02")
	T.check(id, is_equal_approx(float(pv1["qp_i"]), 0.4) and is_equal_approx(float(pv1["qp_f"]), 0.8) and is_equal_approx(float(pv2["qp_f"]), 0.5),
		"vazões pontuais preservadas (PV-01: 0,4 / 0,8 l/s; PV-02: 0,5 l/s)")
	T.check(id, str(pv1["tipo"]) == "TL" and str(pv2["tipo"]) == "PV", "nó de cabeceira vira terminal de limpeza")
	var arq: String = T.tmp("migrado.esg")
	var salvo: bool = m._save_to(arq)
	var antes := _txt(m.proj["trechos"])
	m._novo()
	T.check(id, salvo and m._load_from(arq) and _txt(m.proj["trechos"]) == antes, "projeto convertido é salvo e reaberto igual")


# ------------------------------------------------------------------ T5-02

func _t502() -> void:
	var id := "T5-02"
	T.carregar(m, "rede_ramificada.esg")
	T.usar_banco_teste(m)
	m.proj["params"]["pop_fin"] = 2600.0
	m.marcar_alterado("dados")
	Net.achar_no(m.proj, "C")["ct"] = 100.2
	m.on_changed("no")
	Net.achar_trecho(m.proj, "T3")["recob"] = 1.5
	m.on_changed("trecho")
	m.importar_dxf(T.fix("topografia_phase2.dxf"), "pontos", {"PT_COTADOS": true})
	m.executar_calculo(false)
	var arq: String = T.tmp("ciclo.esg")
	T.check(id, m._save_to(arq), "projeto salvo")
	var esperado := {"projeto": _txt({"nodes": m.proj["nodes"], "trechos": m.proj["trechos"], "info": m.proj["info"], "area": m.proj["area"],
		"referencia": m.proj["referencia"]}), "parametros": _txt(m.proj["params"]), "topografia": _txt(m.topo.to_dict()),
		"banco": str(Db.identificacao(m.db)), "resultados": _txt(m.results.get("rows", {})), "orcamento": _txt(m.results.get("orc", {})),
		"flags": "%s/%s" % [m.resultados_validos, m.resultados_atuais]}
	# "fecha": outro projeto e outro banco
	m._do_action("exemplo")
	m.opts["db_path"] = ""
	m.db = Db.carregar("")
	m._load_from(arq)
	var obtido := {"projeto": _txt({"nodes": m.proj["nodes"], "trechos": m.proj["trechos"], "info": m.proj["info"], "area": m.proj["area"],
		"referencia": m.proj["referencia"]}), "parametros": _txt(m.proj["params"]), "topografia": _txt(m.topo.to_dict()),
		"banco": str(Db.identificacao(m.db)), "resultados": _txt(m.results.get("rows", {})), "orcamento": _txt(m.results.get("orc", {})),
		"flags": "%s/%s" % [m.resultados_validos, m.resultados_atuais]}
	for k in esperado.keys():
		T.check(id, esperado[k] == obtido[k], "%s igual após fechar e reabrir%s" % [k, "" if esperado[k] == obtido[k] else
			" — antes %s / depois %s" % [str(esperado[k]).left(70), str(obtido[k]).left(70)]])
	T.check(id, obtido["flags"] == "true/true", "resultados reabertos como válidos e atualizados")


# ------------------------------------------------------------------ T5-03

func _snap() -> String:
	return JSON.stringify(m._foto()["p"]) + "|" + JSON.stringify(m.topo.to_dict())


func _op(nome: String, f: Callable) -> void:
	var id := "T5-03"
	var antes := _snap()
	f.call()
	var depois := _snap()
	if antes == depois:
		T.check(id, false, "%s: a operação não alterou o projeto" % nome)
		return
	m.desfazer()
	var u := _snap() == antes
	m.refazer()
	var r := _snap() == depois
	T.check(id, u and r, "%s: desfazer volta ao estado anterior%s e refazer ao posterior%s" % [nome, "" if u else " (FALHOU)", "" if r else " (FALHOU)"])


func _t503() -> void:
	T.carregar(m, "rede_ramificada.esg")
	T.usar_banco_teste(m)
	var p = m.plan
	p.ajustar(Rect2(-50, -150, 400, 300), false)
	_op("traçado", func(): p._right_press(p.w2s(Vector2(300, 100)), false))
	p.cancelar()
	_op("mover nó", func():
		var n := Net.achar_no(m.proj, "D")
		n["e"] = float(n["e"]) + 10.0
		m.on_changed("mover"))
	_op("edição de nó", func():
		Net.achar_no(m.proj, "C")["qp_f"] = 1.25
		m.on_changed("no"))
	_op("edição de trecho", func():
		Net.achar_trecho(m.proj, "T1")["recob"] = 1.8
		m.on_changed("trecho"))
	_op("dividir trecho", func():
		p.marked = {int(Net.achar_trecho(m.proj, "T3")["id"]): true}
		m._dividir())
	_op("deslocar trecho", func(): m.deslocar_trecho(int(Net.achar_trecho(m.proj, "T2")["id"]), 5.0, true))
	_op("remoção", func():
		p.marked = {int(Net.achar_trecho(m.proj, "T1")["id"]): true}
		m.apagar_marcados())
	_op("alteração de parâmetros", func():
		m.proj["params"]["pop_fin"] = 3333.0
		m.marcar_alterado("dados"))
	_op("alteração de topografia", func(): m.importar_dxf(T.fix("topografia_phase2.dxf"), "topografia", {"TOPO_CURVAS": true}))


# ------------------------------------------------------------------ T5-04

func _arquivo(nome: String, conteudo: String) -> String:
	var p: String = T.tmp(nome)
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(conteudo)
	f.close()
	return p


func _t504() -> void:
	var id := "T5-04"
	m._do_action("exemplo")
	var casos := [
		["JSON vazio", ""],
		["JSON inválido", "{\"formato\": \"dimesgoto\", \"nodes\": [ {"],
		["projeto sem nós", JSON.stringify({"formato": "dimesgoto", "versao": 3, "params": {}, "trechos": []})],
		["projeto sem trechos", JSON.stringify({"formato": "dimesgoto", "versao": 3, "params": {}, "nodes": [{"id": 1, "nome": "1", "e": 0, "n": 0, "ct": 100}]})],
		["projeto com tipos errados", JSON.stringify({"formato": "dimesgoto", "versao": 3, "params": {"pop_ini": "muita"},
			"nodes": [{"id": 1, "nome": "1", "e": "abc", "n": 0, "ct": 100}], "trechos": [{"id": 1, "nome": "T1", "ni": "x", "nf": 1}]})],
	]
	for c in casos:
		var antes = m.proj
		var n0: int = m.registro.erros.size()
		var janelas := 0
		for ch in m.get_children():
			if ch is AcceptDialog and ch.visible:
				janelas += 1
		var ok: bool = m._load_from(_arquivo("corrompido.esg", c[1]))
		var janelas2 := 0
		var texto := ""
		for ch in m.get_children():
			if ch is AcceptDialog and ch.visible:
				janelas2 += 1
				texto = ch.dialog_text
		T.check(id, not ok and is_same(antes, m.proj), "%s: rejeitado e projeto atual mantido" % c[0])
		T.check(id, janelas2 > janelas and texto.contains("não pôde ser aberto") and m.registro.erros.size() > n0,
			"%s: mensagem compreensível e erro no registro (\"%s\")" % [c[0], texto.get_slice("\n", 1).strip_edges().left(90)])
	T.check(id, m.is_inside_tree(), "processo permanece aberto")


# ------------------------------------------------------------------ T5-05

func _erros_banco(db: Dictionary) -> String:
	T.carregar(m, "rede_unica.esg")
	m.db = db
	var r: Dictionary = m.executar_calculo(false)
	return " | ".join(PackedStringArray(r.get("erros", [])))


func _t505() -> void:
	var id := "T5-05"
	var e := _erros_banco(Db.carregar("/caminho/que/nao/existe/banco.json"))
	T.check(id, e.contains("não encontrado") and not m.resultados_validos, "banco inexistente: cálculo bloqueado — %s" % e.left(110))
	var b := Db.carregar(T.BANCO_TESTE)
	var mat := Db.material_padrao(b)
	var sem_tubo: Array = []
	for t in b["tubos"]:
		if str(t["material"]) != mat:
			sem_tubo.append(t)
	b["tubos"] = sem_tubo
	e = _erros_banco(b)
	T.check(id, e.contains("Banco › materiais") and e.contains(mat) and e.contains("não tem nenhum tubo"), "material sem tubo: tabela e registro indicados — %s" % e.left(120))
	b = Db.carregar(T.BANCO_TESTE)
	b["tubos"][2]["d"] = 0.0
	e = _erros_banco(b)
	T.check(id, e.contains("Banco › tubos: registro 3") and e.contains("diâmetro inválido"), "tubo com diâmetro inválido: %s" % e.left(120))
	var bruto = JSON.parse_string(FileAccess.get_file_as_string(T.BANCO_TESTE))
	bruto["pvs"][2].erase("custo")
	var arq := _arquivo("banco_sem_custo.json", JSON.stringify(bruto))
	e = _erros_banco(Db.carregar(arq))
	T.check(id, e.contains("Banco › pvs: registro \"PV\" sem custo"), "PV sem custo: %s" % e.left(120))
	T.usar_banco_teste(m)


# ------------------------------------------------------------------ T5-06

func _t506() -> void:
	var id := "T5-06"
	m._do_action("exemplo")
	var pasta: String = T.tmp("somente_leitura")
	DirAccess.make_dir_recursive_absolute(pasta)
	var arq := pasta.path_join("projeto.esg")
	var f := FileAccess.open(arq, FileAccess.WRITE)
	f.store_string("ORIGINAL")
	f.close()
	OS.execute("chmod", ["555", pasta])
	m.on_changed("dados")
	var n0: int = m.registro.erros.size()
	var ok: bool = m._save_to(arq)
	OS.execute("chmod", ["755", pasta])
	T.check(id, not ok and FileAccess.get_file_as_string(arq) == "ORIGINAL", "diretório sem permissão: gravação falha e o arquivo anterior fica intacto")
	T.check(id, m.dirty and m.current_path != arq, "projeto NÃO é marcado como salvo")
	T.check(id, m.registro.erros.size() > n0 and m.status_label.text.contains("NÃO salvo"), "usuário recebe mensagem e a falha é registrada")
	var ok2: bool = m._save_to(T.tmp("nao/existe/projeto.esg"))
	T.check(id, not ok2 and not FileAccess.file_exists(T.tmp("nao/existe/projeto.esg.tmp~")), "falha de escrita em caminho inexistente não deixa lixo temporário")


# ------------------------------------------------------------------ T5-07

func _t507() -> void:
	var id := "T5-07"
	T.gerar_rede_grande(m)
	var n_nos: int = m.proj["nodes"].size()
	var n_tr: int = m.proj["trechos"].size()
	T.check(id, n_nos >= 1000 and n_tr >= 1500, "rede de teste com %d nós e %d trechos" % [n_nos, n_tr])
	var t0 := Time.get_ticks_msec()
	m.executar_calculo(false)
	var t_calc := Time.get_ticks_msec() - t0
	var arq: String = T.tmp("grande.esg")
	m._save_to(arq)
	t0 = Time.get_ticks_msec()
	m._load_from(arq)
	var t_abrir := Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	m.exportar_memorial(T.tmp("grande_memorial.txt"))
	m.exportar_planta(T.tmp("grande_planta.dxf"))
	m.exportar_planilha_arquivo("res", T.tmp("grande_res.csv"))
	var t_exp := Time.get_ticks_msec() - t0
	var mem_mb := OS.get_static_memory_usage() / 1048576.0
	var tempos := {"calculo_ms": t_calc, "abertura_ms": t_abrir, "exportacao_ms": t_exp, "memoria_mb": snappedf(mem_mb, 0.1)}
	T.dado(id, "tempos", tempos)
	T.check(id, m.resultados_validos and m.results["rows"].size() == n_tr, "rede grande dimensionada (%d trechos)" % m.results["rows"].size())
	for k in ["calculo_ms", "abertura_ms", "exportacao_ms"]:
		T.check(id, int(tempos[k]) <= 3000, "%s: %d ms (limite 3000 ms sem progresso)" % [k.trim_suffix("_ms"), tempos[k]])
	T.check(id, mem_mb > 0.0, "memória aproximada: %.1f MB" % mem_mb)


# ------------------------------------------------------------------ T5-08

func _t508() -> void:
	var id := "T5-08"
	var hidraulica := ["86400", "0\\.0055", "\\bGAMMA\\b", "2\\.0 / 3\\.0", "\\bacos\\(", "\\* 1\\.3\\b", "\\* 1\\.30\\b",
		"\\[\"(fornecimento|assentamento|retirada|colocacao)\"\\]\\)?\\s*[\\*\\+]", "\\(float\\(a\\[\"ct\"\\]\\)\\s*-", "_n\\(ccm\\)\\s*-", "\\)\\s*/\\s*lt\\b"]
	var geometria := ["Vector2\\(-dir\\.y, dir\\.x\\)"]
	var arquivos := {"main.gd": hidraulica + geometria, "dialogs.gd": hidraulica + geometria, "plan_view.gd": hidraulica,
		"profile_view.gd": hidraulica, "grid_table.gd": hidraulica}
	var achados: Array = []
	for nome in arquivos.keys():
		var txt := FileAccess.get_file_as_string("res://" + nome)
		var n := 0
		for linha in txt.split("\n"):
			n += 1
			var l := linha.strip_edges()
			if l.begins_with("#"):
				continue
			for pad in arquivos[nome]:
				var re := RegEx.create_from_string(pad)
				if re.search(l) != null:
					achados.append("%s:%d (%s)" % [nome, n, l.left(60)])
	T.dado(id, "achados", achados)
	T.check(id, achados.is_empty(), "nenhuma fórmula hidráulica, de orçamento ou de geometria duplicada nas telas" +
		("" if achados.is_empty() else " — %d ocorrência(s): %s" % [achados.size(), str(achados.slice(0, 4))]))
	var dialogs := FileAccess.get_file_as_string("res://dialogs.gd")
	T.check(id, dialogs.contains("Calc.declividade(") and dialogs.contains("Calc.profundidade("), "a janela do trecho usa os serviços do domínio (Calc.declividade / Calc.profundidade)")
