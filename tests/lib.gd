extends RefCounted
## Utilitários comuns dos evals (EVALS.md).
## Cada verificação é agregada por ID de eval; no fim, imprime uma linha por eval:
##   RESULT|<ID>|<PASS|FAIL|SKIP>|<mensagens>|<json com dados>
## que o tests/run_tests.py lê para montar o relatório.

const Net = preload("res://net.gd")
const Calc = preload("res://calc.gd")
const Db = preload("res://db.gd")

const GAMMA := 10000.0 # N/m3 — mesmo valor adotado pelo motor (NBR 9649)
# pasta tests/ (os testes rodam fora do res:// do app)
static var DIR: String = ""
static var FIX: String = ""
static var BANCO_TESTE: String = ""


func _init() -> void:
	DIR = (get_script() as Resource).resource_path.get_base_dir()
	FIX = DIR.path_join("fixtures")
	BANCO_TESTE = FIX.path_join("banco_teste.json")

var evals := {}
var ordem: Array = []


func _ev(id: String) -> Dictionary:
	if not evals.has(id):
		evals[id] = {"checks": [], "dados": {}, "estado": ""}
		ordem.append(id)
	return evals[id]


func fix(nome: String) -> String:
	return FIX.path_join(nome)


func tmp(nome: String) -> String:
	var d := ProjectSettings.globalize_path("user://tmp_testes")
	DirAccess.make_dir_recursive_absolute(d)
	return d.path_join(nome)


func check(id: String, cond: bool, msg: String) -> bool:
	_ev(id)["checks"].append([cond, msg])
	print("  %s %-9s %s" % ["✓" if cond else "✗", id, msg])
	return cond


func dado(id: String, chave: String, valor) -> void:
	_ev(id)["dados"][chave] = valor


func skip(id: String, msg: String) -> void:
	var e := _ev(id)
	e["estado"] = "SKIP"
	e["checks"].append([true, msg])
	print("  … %-9s %s" % [id, msg])


func fim() -> int:
	var falhou := false
	for id in ordem:
		var e: Dictionary = evals[id]
		var est: String = e["estado"]
		var msgs: Array = []
		var ok := true
		for c in e["checks"]:
			if not bool(c[0]):
				ok = false
				msgs.append("FALHA: " + str(c[1]))
		if est == "":
			est = "PASS" if ok else "FAIL"
		if est == "FAIL":
			falhou = true
		if msgs.is_empty():
			for c in e["checks"]:
				msgs.append(str(c[1]))
		print("RESULT|%s|%s|%s|%s" % [id, est, " • ".join(PackedStringArray(msgs)).replace("|", "/").replace("\n", " "),
			JSON.stringify(e["dados"])])
	return 1 if falhou else 0


# ------------------------------------------------------------------ app

func novo_main(tree: SceneTree):
	var m = load("res://main.tscn").instantiate()
	tree.root.add_child(m)
	await tree.process_frame
	await tree.process_frame
	m.plan.size = Vector2(1200, 700)
	return m


func meta(m) -> Dictionary:
	return {"app": "%s %s" % [m.APP_NAME, m.VERSAO], "banco": str(m.db.get("versao", "?")),
		"godot": str(Engine.get_version_info().get("string", "?")), "data": Time.get_datetime_string_from_system()}


func usar_banco_teste(m) -> void:
	m.db = Db.carregar(BANCO_TESTE)
	# Db.carregar não preserva o campo "versao" do arquivo; registramos o da fixture
	var bruto = JSON.parse_string(FileAccess.get_file_as_string(BANCO_TESTE))
	m.db["versao"] = str(bruto.get("versao", "?")) if bruto is Dictionary else "?"


func carregar(m, fixture: String) -> bool:
	var antes = m.proj
	m._load_from(FIX.path_join(fixture))
	return not is_same(antes, m.proj)


func params_resumo(m) -> Dictionary:
	return m.proj["params"].duplicate()


func linha(m, nome: String) -> Dictionary:
	for r in m.results.get("rows", {}).values():
		if str(r["nome"]) == nome:
			return r
	return {}


func trecho(m, nome: String) -> Dictionary:
	return Net.achar_trecho(m.proj, nome)


func no(m, nome: String) -> Dictionary:
	return Net.achar_no(m.proj, nome)


func obs_de(m, nome: String) -> String:
	var r := linha(m, nome)
	return " | ".join(PackedStringArray(r.get("obs", [])))


# ------------------------------------------------------------------ hidráulica independente (só Manning)
# Implementação separada da do motor, para conferência.

static func secao(yd: float, d: float) -> Dictionary:
	var th := 2.0 * acos(1.0 - 2.0 * yd)
	var a := d * d / 8.0 * (th - sin(th))
	var p := d * th / 2.0
	return {"a": a, "rh": a / p}


static func manning_q(yd: float, d: float, i: float, n: float) -> float:
	var s := secao(yd, d)
	return float(s["a"]) * pow(float(s["rh"]), 2.0 / 3.0) * sqrt(i) / n


## Lâmina relativa por bisseção em y/D (o motor faz bisseção no ângulo central).
static func manning_yd(q: float, d: float, i: float, n: float) -> float:
	var lo := 1e-6
	var hi := 0.938
	for _k in 200:
		var mid := (lo + hi) / 2.0
		if manning_q(mid, d, i, n) < q:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0


static func tensao(q: float, d: float, i: float, n: float) -> float:
	var yd := manning_yd(q, d, i, n)
	return GAMMA * float(secao(yd, d)["rh"]) * i


static func aprox(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


## Rede grande para o T5-07: n_col coletores paralelos de n_tr trechos (n_col × (n_tr + 1) nós).
func gerar_rede_grande(m, n_col := 100, n_tr := 15) -> void:
	m._novo()
	var p: Dictionary = m.proj
	var nodes: Array = []
	var trechos: Array = []
	var nid := 0
	var tid := 0
	for c in n_col:
		var x := float(c) * 120.0
		var ant := -1
		for k in n_tr + 1:
			nid += 1
			var y := float(n_tr - k) * 80.0
			nodes.append({"id": nid, "nome": str(nid), "e": x, "n": y, "ct": 100.0 + y * 0.012 + 0.3 * sin(x / 300.0),
				"ct_ok": true, "tipo": "TL" if k == 0 else "PV", "qp_i": 0.0, "qp_f": 0.0})
			if ant > 0:
				tid += 1
				var t := Net.trecho_padrao(m.db)
				t["id"] = tid
				t["nome"] = "T%d" % tid
				t["ni"] = ant
				t["nf"] = nid
				t["coletor"] = "C%d" % (c + 1)
				trechos.append(t)
			ant = nid
	p["nodes"] = nodes
	p["trechos"] = trechos
	p["params"]["pop_ini"] = 30000.0
	p["params"]["pop_fin"] = 50000.0
	p["area"] = {"e0": -50.0, "n0": -50.0, "le": n_col * 120.0 + 100.0, "ln": n_tr * 80.0 + 100.0, "grid": 100.0}
