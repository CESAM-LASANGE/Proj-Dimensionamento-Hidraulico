extends RefCounted
## Banco de itens de custo (equivalente ao CESGCUST do manual, cap. 6).
## Materiais, tubos, tipos de PV, pavimentos, situações, escoramentos,
## reduções e acessórios. Os preços são apenas referências: o usuário
## deve atualizá-los no menu Banco de dados.

const USOS := ["Terminal de limpeza", "Manual"]

const SPECS := {
	"materiais": {"titulo": "Materiais", "cols": [
		{"t": "Material", "k": "nome", "w": 280, "f": "s", "edit": true},
		{"t": "n Manning", "k": "n", "w": 90, "f": "f4", "edit": true},
		{"t": "Rugosidade k (mm)", "k": "k", "w": 130, "f": "f3", "edit": true},
		{"t": "Padrão", "k": "padrao", "w": 70, "f": "chk", "edit": true}]},
	"tubos": {"titulo": "Tubos", "cols": [
		{"t": "Material", "k": "material", "w": 280, "f": "choice", "edit": true},
		{"t": "Diâmetro (mm)", "k": "d", "w": 100, "f": "f0", "edit": true},
		{"t": "Largura da vala (m)", "k": "largura", "w": 130, "f": "f2", "edit": true},
		{"t": "Fornecimento (R$/m)", "k": "fornecimento", "w": 140, "f": "f2", "edit": true},
		{"t": "Assentamento (R$/m)", "k": "assentamento", "w": 140, "f": "f2", "edit": true}]},
	"pvs": {"titulo": "PVs", "cols": [
		{"t": "Sigla", "k": "sigla", "w": 70, "f": "s", "edit": true},
		{"t": "Sigla p/ impressão", "k": "sigla_imp", "w": 120, "f": "s", "edit": true},
		{"t": "Descrição", "k": "nome", "w": 260, "f": "s", "edit": true},
		{"t": "Custo un. (R$/m prof.)", "k": "custo", "w": 150, "f": "f2", "edit": true}]},
	"pavimentos": {"titulo": "Pavimentos", "cols": [
		{"t": "Tipo de pavimento", "k": "nome", "w": 220, "f": "s", "edit": true},
		{"t": "Retirada (R$/m²)", "k": "retirada", "w": 130, "f": "f2", "edit": true},
		{"t": "Colocação (R$/m²)", "k": "colocacao", "w": 130, "f": "f2", "edit": true}]},
	"situacoes": {"titulo": "Situações", "cols": [
		{"t": "Situação de trecho de rede (vira layer no DXF)", "k": "nome", "w": 360, "f": "s", "edit": true}]},
	"escoramentos": {"titulo": "Escoramentos", "cols": [
		{"t": "Tipo de escoramento", "k": "nome", "w": 220, "f": "s", "edit": true},
		{"t": "Prof. mínima (m)", "k": "pmin", "w": 120, "f": "f2", "edit": true},
		{"t": "Prof. máxima (m)", "k": "pmax", "w": 120, "f": "f2", "edit": true},
		{"t": "Custo (R$/m²)", "k": "custo", "w": 120, "f": "f2", "edit": true}]},
	"reducoes": {"titulo": "Reduções", "cols": [
		{"t": "Descrição", "k": "nome", "w": 280, "f": "s", "edit": true},
		{"t": "Diâmetro 1 (mm)", "k": "d1", "w": 110, "f": "f0", "edit": true},
		{"t": "Diâmetro 2 (mm)", "k": "d2", "w": 110, "f": "f0", "edit": true},
		{"t": "Custo (R$/un)", "k": "custo", "w": 110, "f": "f2", "edit": true}]},
	"acessorios": {"titulo": "Acessórios", "cols": [
		{"t": "Descrição", "k": "nome", "w": 280, "f": "s", "edit": true},
		{"t": "Diâmetro (mm)", "k": "d", "w": 100, "f": "f0", "edit": true},
		{"t": "Uso no orçamento", "k": "uso", "w": 160, "f": "choice", "edit": true},
		{"t": "Custo (R$/un)", "k": "custo", "w": 110, "f": "f2", "edit": true}]},
}

const ORDEM := ["materiais", "tubos", "pvs", "pavimentos", "situacoes", "escoramentos", "reducoes", "acessorios"]

# Larguras de vala para tubos de PVC (tabela do manual, item 6.2.2)
# [diâmetro até, [0-2 m por classe de escoramento], [2-4 m por classe]]
# classes: 0 = sem escoramento/pontalete, 1 = descontínuo/contínuo, 2 = especial, 3 = metálico-madeira
const LARGURAS := [
	[150, [0.50, 0.60, 0.65, 0.85], [0.60, 0.70, 0.75, 0.85]],
	[200, [0.55, 0.65, 0.70, 0.90], [0.65, 0.75, 0.80, 0.90]],
	[250, [0.60, 0.70, 0.75, 0.95], [0.70, 0.80, 0.85, 0.95]],
	[300, [0.65, 0.75, 0.80, 1.00], [0.75, 0.85, 0.90, 1.00]],
	[350, [0.70, 0.80, 0.85, 1.05], [0.80, 0.90, 0.95, 1.05]],
	[400, [0.75, 0.85, 0.90, 1.10], [0.85, 0.90, 1.00, 1.10]],
]


static func defaults() -> Dictionary:
	var vf := "PVC Vinilfort Tigre - NBR7362"
	var dfo := "PVC Tigre Vinilfer DEFoFo JEI"
	var tubos: Array = []
	var vf_tab := [[100, 0.70, 4.90, 0.45], [150, 0.75, 7.69, 0.53], [200, 0.80, 11.92, 0.70],
		[250, 0.85, 18.50, 0.85], [300, 0.90, 26.40, 1.00], [350, 0.95, 35.80, 1.20], [400, 1.00, 46.20, 1.40]]
	for r in vf_tab:
		tubos.append({"material": vf, "d": float(r[0]), "largura": r[1], "fornecimento": r[2], "assentamento": r[3]})
	var df_tab := [[100, 0.70, 9.60, 0.50], [150, 0.75, 16.80, 0.60], [200, 0.80, 27.40, 0.80],
		[250, 0.85, 41.90, 0.95], [300, 0.90, 58.70, 1.10]]
	for r in df_tab:
		tubos.append({"material": dfo, "d": float(r[0]), "largura": r[1], "fornecimento": r[2], "assentamento": r[3]})
	return {
		"formato": "dimesgoto-banco", "versao": 1,
		"materiais": [
			{"nome": vf, "n": 0.010, "k": 0.06, "padrao": true},
			{"nome": dfo, "n": 0.010, "k": 0.06, "padrao": false},
		],
		"tubos": tubos,
		"pvs": [
			{"sigla": "CP", "sigla_imp": "CP", "nome": "Caixa de Passagem", "custo": 0.0},
			{"sigla": "PI", "sigla_imp": "PI", "nome": "Poço de Inspeção", "custo": 85.00},
			{"sigla": "PV", "sigla_imp": "PV", "nome": "Poço de Visita", "custo": 131.60},
			{"sigla": "TL", "sigla_imp": "TL", "nome": "Terminal de Limpeza", "custo": 45.00},
			{"sigla": "TQ", "sigla_imp": "TQ", "nome": "PV com tubo de queda", "custo": 137.60},
			{"sigla": "TR", "sigla_imp": "TIL", "nome": "TIL radial rede VINILFORT", "custo": 98.00},
			{"sigla": "TT", "sigla_imp": "TIL-TQ", "nome": "TIL tubo de queda VINILFORT", "custo": 112.00},
		],
		"pavimentos": [
			{"nome": "Asfáltico", "retirada": 5.16, "colocacao": 10.50},
			{"nome": "Cimentado", "retirada": 3.20, "colocacao": 8.40},
			{"nome": "Concreto", "retirada": 6.80, "colocacao": 14.20},
			{"nome": "Gramado", "retirada": 1.10, "colocacao": 2.60},
			{"nome": "Ladrilho Hidráulico", "retirada": 4.10, "colocacao": 12.80},
			{"nome": "Mosaico", "retirada": 4.10, "colocacao": 13.50},
			{"nome": "Paralelepípedo", "retirada": 3.40, "colocacao": 7.90},
			{"nome": "Sem revestimento", "retirada": 0.0, "colocacao": 0.0},
		],
		"situacoes": [
			{"nome": "Rede Projetada"}, {"nome": "Rede Existente"}, {"nome": "Rede 1a Etapa"},
			{"nome": "Rede 2a Etapa"}, {"nome": "Coletor Tronco"},
		],
		"escoramentos": [
			{"nome": "Sem escoramento", "pmin": 0.0, "pmax": 1.25, "custo": 0.0},
			{"nome": "Pontalete", "pmin": 1.25, "pmax": 2.0, "custo": 3.10},
			{"nome": "Descontínuo", "pmin": 2.0, "pmax": 2.3, "custo": 5.40},
			{"nome": "Contínuo", "pmin": 2.3, "pmax": 3.0, "custo": 8.59},
			{"nome": "Especial", "pmin": 3.0, "pmax": 4.5, "custo": 12.80},
			{"nome": "Metálico e Madeira", "pmin": 4.5, "pmax": 99.0, "custo": 21.50},
		],
		"reducoes": [
			{"nome": "Redução excêntrica PVC 125x100", "d1": 125.0, "d2": 100.0, "custo": 8.20},
			{"nome": "Redução excêntrica PVC 150x100", "d1": 150.0, "d2": 100.0, "custo": 9.80},
			{"nome": "Redução excêntrica PVC 200x150", "d1": 200.0, "d2": 150.0, "custo": 18.40},
			{"nome": "Redução excêntrica PVC 250x200", "d1": 250.0, "d2": 200.0, "custo": 32.00},
			{"nome": "Redução excêntrica PVC 300x250", "d1": 300.0, "d2": 250.0, "custo": 51.00},
			{"nome": "Redução excêntrica PVC 350x300", "d1": 350.0, "d2": 300.0, "custo": 68.00},
			{"nome": "Redução excêntrica PVC 400x350", "d1": 400.0, "d2": 350.0, "custo": 92.00},
		],
		"acessorios": [
			{"nome": "Curva PVC 45° diam. 100 mm", "d": 100.0, "uso": "Manual", "custo": 11.00},
			{"nome": "Curva PVC 90° diam. 100 mm", "d": 100.0, "uso": "Terminal de limpeza", "custo": 14.50},
			{"nome": "Curva PVC 90° diam. 150 mm", "d": 150.0, "uso": "Terminal de limpeza", "custo": 26.50},
			{"nome": "Curva PVC 90° diam. 200 mm", "d": 200.0, "uso": "Terminal de limpeza", "custo": 48.00},
			{"nome": "Tampão PVC diam. 100 mm", "d": 100.0, "uso": "Terminal de limpeza", "custo": 9.80},
			{"nome": "Tampão PVC diam. 150 mm", "d": 150.0, "uso": "Terminal de limpeza", "custo": 18.99},
			{"nome": "Tampão PVC diam. 200 mm", "d": 200.0, "uso": "Terminal de limpeza", "custo": 31.00},
		],
	}


## Carrega o banco. Campos auxiliares (não gravados): _origem ("padrao", "arquivo", "ausente",
## "invalido") e _arquivo. Um banco ausente ou ilegível NÃO é trocado em silêncio: o cálculo
## é bloqueado por validar() até o usuário escolher outro banco ou o padrão.
static func carregar(path: String) -> Dictionary:
	var base := defaults()
	base["_arquivo"] = path
	if path == "":
		base["_origem"] = "padrao"
		return base
	if not FileAccess.file_exists(path):
		base["_origem"] = "ausente"
		return base
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		base["_origem"] = "invalido"
		return base
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary:
		base["_origem"] = "invalido"
		return base
	base["_origem"] = "arquivo"
	if data.has("versao"):
		base["versao"] = data["versao"]
	for k in ORDEM:
		if data.has(k) and data[k] is Array:
			base[k] = _normalizar(k, data[k])
	return base


## Identificação do banco para relatórios: arquivo, versão e hash do conteúdo.
static func identificacao(db: Dictionary) -> Dictionary:
	return {"arquivo": str(db.get("_arquivo", "")), "origem": str(db.get("_origem", "padrao")),
		"versao": str(db.get("versao", "?")), "hash": hash_conteudo(db)}


static func hash_conteudo(db: Dictionary) -> String:
	var limpo := {}
	for k in ORDEM:
		limpo[k] = db.get(k, [])
	return JSON.stringify(limpo).sha256_text().substr(0, 16)


## Problemas do banco que impedem o cálculo, com tabela e registro (T5-05).
static func validar(db: Dictionary, proj := {}) -> Array:
	var erros: Array = []
	match str(db.get("_origem", "padrao")):
		"ausente":
			erros.append("Banco de itens de custo não encontrado: %s. Escolha outro em Arquivos › Parâmetros ou use o banco padrão." % str(db.get("_arquivo", "")))
			return erros
		"invalido":
			erros.append("Banco de itens de custo ilegível (JSON inválido): %s." % str(db.get("_arquivo", "")))
			return erros
	var mats := nomes(db, "materiais")
	var com_tubo := {}
	var k := 0
	for t in db.get("tubos", []):
		k += 1
		var d := float(t.get("d", NAN))
		if is_nan(d) or d <= 0.0:
			erros.append("Banco › tubos: registro %d (material \"%s\") com diâmetro inválido (%s)." % [k, str(t.get("material", "")), str(t.get("d", ""))])
		else:
			com_tubo[str(t.get("material", ""))] = true
		if not str(t.get("material", "")) in mats:
			erros.append("Banco › tubos: registro %d usa o material \"%s\", que não está cadastrado em materiais." % [k, str(t.get("material", ""))])
	for m in db.get("materiais", []):
		if not com_tubo.has(str(m["nome"])):
			erros.append("Banco › materiais: \"%s\" não tem nenhum tubo com diâmetro válido cadastrado." % str(m["nome"]))
		for c in ["n", "k"]:
			var v := float(m.get(c, NAN))
			if is_nan(v) or v <= 0.0:
				erros.append("Banco › materiais: \"%s\" com %s inválido (%s)." % [str(m["nome"]), "n de Manning" if c == "n" else "rugosidade k", str(m.get(c, ""))])
	for pv_ in db.get("pvs", []):
		var c := float(pv_.get("custo", NAN))
		if is_nan(c) or c < 0.0:
			erros.append("Banco › pvs: registro \"%s\" sem custo válido (%s)." % [str(pv_.get("sigla", "?")), str(pv_.get("custo", "ausente"))])
	for t in proj.get("trechos", []):
		var mat := str(t.get("material", ""))
		if mat != "" and not mat in mats:
			erros.append("Trecho %s: material \"%s\" não existe no banco (tabela materiais)." % [str(t.get("nome", "?")), mat])
	return erros


static func _normalizar(tabela: String, linhas: Array) -> Array:
	var out: Array = []
	var cols: Array = SPECS[tabela]["cols"]
	for l in linhas:
		if not l is Dictionary:
			continue
		var r := {}
		for c in cols:
			var k: String = c["k"]
			var f: String = c["f"]
			var v = l.get(k, null)
			if f == "chk":
				r[k] = bool(v) if v != null else false
			elif f == "s" or f == "choice":
				r[k] = str(v) if v != null else ""
			else:
				# valor ausente ou não numérico vira NaN para a validação apontar o registro
				r[k] = float(v) if (v is float or v is int or (v is String and str(v).is_valid_float())) else NAN
		out.append(r)
	return out


static func salvar(path: String, db: Dictionary) -> bool:
	var limpo := {}
	for k in db.keys():
		if not str(k).begins_with("_"):
			limpo[k] = db[k]
	var tmp := path + ".tmp~"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(limpo, "  "))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK


static func nomes(db: Dictionary, tabela: String, chave := "nome") -> Array:
	var out: Array = []
	for r in db.get(tabela, []):
		out.append(str(r.get(chave, "")))
	return out


static func material(db: Dictionary, nome: String) -> Dictionary:
	for m in db["materiais"]:
		if str(m["nome"]) == nome:
			return m
	return material_padrao_dict(db)


static func material_padrao_dict(db: Dictionary) -> Dictionary:
	for m in db["materiais"]:
		if bool(m.get("padrao", false)):
			return m
	if db["materiais"].size() > 0:
		return db["materiais"][0]
	return {"nome": "", "n": 0.013, "k": 0.25, "padrao": true}


static func material_padrao(db: Dictionary) -> String:
	return str(material_padrao_dict(db)["nome"])


static func diametros(db: Dictionary, mat: String) -> Array:
	var out: Array = []
	for t in db["tubos"]:
		if str(t["material"]) == mat and float(t["d"]) > 0.0 and not float(t["d"]) in out:
			out.append(float(t["d"]))
	out.sort()
	return out


static func tubo(db: Dictionary, mat: String, d: float) -> Dictionary:
	for t in db["tubos"]:
		if str(t["material"]) == mat and absf(float(t["d"]) - d) < 0.5:
			return t
	return {}


static func pv(db: Dictionary, sigla: String) -> Dictionary:
	for r in db["pvs"]:
		if str(r["sigla"]) == sigla:
			return r
	return {"sigla": sigla, "sigla_imp": sigla, "nome": sigla, "custo": 0.0}


static func linha(db: Dictionary, tabela: String, nome: String) -> Dictionary:
	for r in db.get(tabela, []):
		if str(r.get("nome", "")) == nome:
			return r
	return {}


static func primeiro(db: Dictionary, tabela: String, preferido := "") -> String:
	var ns := nomes(db, tabela)
	if preferido in ns:
		return preferido
	return str(ns[0]) if ns.size() > 0 else preferido


static func escoramento_por_prof(db: Dictionary, prof: float) -> String:
	var melhor := ""
	var maior_pmax := -1.0
	for e in db["escoramentos"]:
		var a := float(e["pmin"])
		var b := float(e["pmax"])
		if prof >= a - 1e-6 and prof < b - 1e-6:
			return str(e["nome"])
		if b > maior_pmax:
			maior_pmax = b
			melhor = str(e["nome"])
	return melhor


static func _classe_esc(nome: String) -> int:
	var n := nome.to_lower()
	if n.contains("metál") or n.contains("metal") or n.contains("madeira"):
		return 3
	if n.contains("especial"):
		return 2
	if n.contains("contínuo") or n.contains("continuo"):
		return 1
	return 0


## Largura da vala (m) em função do diâmetro, profundidade e escoramento.
## O valor do banco só vale se for maior que o da tabela (manual 6.2.2).
static func largura_vala(db: Dictionary, mat: String, d: float, prof: float, esc: String) -> float:
	var cls := _classe_esc(esc)
	var faixa := 1 if prof <= 2.0 else 2
	var w := 0.0
	var achou := false
	for r in LARGURAS:
		if d <= float(r[0]) + 0.5:
			w = float(r[faixa][cls])
			achou = true
			break
	if not achou:
		var ult: Array = LARGURAS[-1]
		w = float(ult[faixa][cls]) + (d - 400.0) / 1000.0
	if prof > 4.0 and cls == 2:
		w += 0.20
	var t := tubo(db, mat, d)
	if not t.is_empty():
		w = maxf(w, float(t["largura"]))
	return w


static func listagem(db: Dictionary) -> String:
	var s := "BANCO DE ITENS DE CUSTO\n" + "=".repeat(80) + "\n"
	for k in ORDEM:
		var spec: Dictionary = SPECS[k]
		s += "\n%s\n%s\n" % [str(spec["titulo"]).to_upper(), "-".repeat(80)]
		var cols: Array = spec["cols"]
		var head := ""
		for c in cols:
			head += str(c["t"]).rpad(int(c["w"]) / 8) + " "
		s += head + "\n"
		for r in db.get(k, []):
			var ln := ""
			for c in cols:
				var v = r.get(c["k"], "")
				var f: String = c["f"]
				var txt := ""
				if f == "chk":
					txt = "Sim" if bool(v) else "Não"
				elif f == "s" or f == "choice":
					txt = str(v)
				else:
					txt = (("%." + f.substr(1) + "f") % float(v)).replace(".", ",")
				ln += txt.rpad(int(c["w"]) / 8) + " "
			s += ln + "\n"
	s += "\nObs.: preços de referência; atualize-os para valores reais.\n"
	return s
