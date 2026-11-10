extends SceneTree
## Fase 4 — T4-01 a T4-07 (planilhas, memorial, rastreabilidade, planta, perfil, reprodutibilidade, bloqueio).
## A exportação do perfil em PNG é verificada em test_grafico.gd (precisa de renderização).

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")
const Report = preload("res://report.gd")
const Dxf = preload("res://dxf.gd")

var T
var m
var CHAVES := ["trechos", "nos", "dimens", "quant", "res", "orc", "obs"]


func _initialize() -> void:
	T = Lib.new()
	m = await T.novo_main(self)
	T.usar_banco_teste(m)
	m.proj["info"]["responsavel"] = "Eng. Responsável"
	m.proj["info"]["local"] = "Bairro Exemplo"
	print("META|" + JSON.stringify(T.meta(m)))
	m.executar_calculo(false)
	_t401()
	_t402()
	_t403()
	_t404()
	_t405()
	_t406()
	_t407()
	quit(T.fim())


# ------------------------------------------------------------------ utilidades

static func csv_parse(txt: String) -> Array:
	if txt.begins_with("﻿"):
		txt = txt.substr(1)
	var rows: Array = []
	var row: Array = []
	var cell := ""
	var q := false
	var i := 0
	while i < txt.length():
		var ch := txt[i]
		if q:
			if ch == "\"":
				if i + 1 < txt.length() and txt[i + 1] == "\"":
					cell += "\""
					i += 1
				else:
					q = false
			else:
				cell += ch
		else:
			if ch == "\"":
				q = true
			elif ch == ";":
				row.append(cell)
				cell = ""
			elif ch == "\n":
				row.append(cell)
				rows.append(row)
				row = []
				cell = ""
			elif ch != "\r":
				cell += ch
		i += 1
	if cell != "" or not row.is_empty():
		row.append(cell)
		rows.append(row)
	return rows


func _ler(p: String) -> String:
	return FileAccess.get_file_as_string(p)


func _win(s: String) -> PackedByteArray:
	return Report._pdf_texto(s)


func _contem_bytes(dados: PackedByteArray, alvo: PackedByteArray) -> bool:
	if alvo.is_empty():
		return true
	var n := dados.size() - alvo.size()
	for i in n + 1:
		if dados[i] == alvo[0]:
			var ok := true
			for j in alvo.size():
				if dados[i + j] != alvo[j]:
					ok = false
					break
			if ok:
				return true
	return false


# ------------------------------------------------------------------ T4-01

func _t401() -> void:
	var id := "T4-01"
	for key in CHAVES:
		var base: String = T.tmp("planilha_" + key)
		var rc: Dictionary = m.exportar_planilha_arquivo(key, base + ".csv")
		var rx: Dictionary = m.exportar_planilha_arquivo(key, base + ".xlsx")
		var rh: Dictionary = m.exportar_planilha_arquivo(key, base + ".html")
		var rp: Dictionary = m.exportar_planilha_arquivo(key, base + ".pdf")
		var dados: Array = m.tables[key].dados()
		var n_lin := dados.size()
		var n_col: int = dados[0].size()
		if not T.check(id, bool(rc["ok"]) and bool(rx["ok"]) and bool(rh["ok"]) and bool(rp["ok"]), "%s: CSV, XLSX, HTML e PDF gravados" % key):
			continue
		# CSV
		var cs := csv_parse(_ler(base + ".csv"))
		var col_ok := true
		for r in cs:
			col_ok = col_ok and r.size() == n_col
		var igual := cs.size() == n_lin and col_ok
		if igual:
			for k in n_lin:
				for c in n_col:
					if str(cs[k][c]) != str(dados[k][c]):
						igual = false
		T.check(id, igual, "%s CSV: %d linhas × %d colunas, nomes e valores idênticos à planilha (decimal com vírgula)" % [key, cs.size(), n_col])
		# XLSX
		var xs: Dictionary = Report.ler_xlsx(base + ".xlsx")
		var sh: String = xs.get("xl/worksheets/sheet1.xml", "")
		var info: String = xs.get("xl/worksheets/sheet2.xml", "")
		var n_num := 0
		var n_txt := 0
		for k in range(1, n_lin):
			for c in n_col:
				var t := str(dados[k][c])
				if Report.numero_br(t) != null:
					n_num += 1
				elif t != "":
					n_txt += 1
		var n_head := 0
		for c in n_col:
			if str(dados[0][c]) != "":
				n_head += 1
		T.check(id, sh.count("<row ") == n_lin and sh.count("<v>") == n_num and sh.count("<is>") == n_txt + n_head,
			"%s XLSX: %d linhas, %d números como número e %d textos como texto" % [key, sh.count("<row "), sh.count("<v>"), sh.count("<is>")])
		T.check(id, str(dados[0][0]).xml_escape() in sh and "Separador decimal" in info, "%s XLSX: cabeçalhos preservados e aba Info documenta o separador decimal" % key)
		# HTML
		var ht := _ler(base + ".html")
		T.check(id, ht.count("<tr>") == n_lin and ht.count("<th>") == n_col and ht.contains("Separador decimal: vírgula"),
			"%s HTML: %d linhas, %d colunas, separador decimal documentado" % [key, ht.count("<tr>"), ht.count("<th>")])
		# PDF
		var pb := FileAccess.get_file_as_bytes(base + ".pdf")
		var ptxt := pb.get_string_from_ascii()
		var linhas_pdf := ptxt.count(") Tj T*")
		var cab: String = str(dados[0][0]).replace("\n", " / ")
		T.check(id, ptxt.begins_with("%PDF-1.4") and ptxt.strip_edges().ends_with("%%EOF") and linhas_pdf == n_lin + 5 and _contem_bytes(pb, _win(cab)),
			"%s PDF: válido, %d linhas de texto (esperado %d) e cabeçalho \"%s\"" % [key, linhas_pdf, n_lin + 5, cab])
	# acentos e unidades
	var nos_csv := _ler(T.tmp("planilha_nos.csv"))
	var nos_x: String = Report.ler_xlsx(T.tmp("planilha_nos.xlsx")).get("xl/worksheets/sheet1.xml", "")
	T.check(id, nos_csv.contains("Nó") and nos_x.contains("Nó") and _ler(T.tmp("planilha_nos.html")).contains("Nó")
		and _contem_bytes(FileAccess.get_file_as_bytes(T.tmp("planilha_nos.pdf")), _win("Nó")), "acentos preservados (\"Nó\") em CSV, XLSX, HTML e PDF")
	var res_csv := _ler(T.tmp("planilha_res.csv"))
	T.check(id, res_csv.contains("(m)") and res_csv.contains("(l/s)") and res_csv.contains("(m/s)"), "unidades presentes nos cabeçalhos dos resultados")
	var mem: Dictionary = m.exportar_memorial(T.tmp("memorial.pdf"))
	T.check(id, bool(mem["ok"]) and FileAccess.get_file_as_bytes(T.tmp("memorial.pdf")).get_string_from_ascii().begins_with("%PDF"), "memorial exportado em PDF")


# ------------------------------------------------------------------ T4-02

func _t402() -> void:
	var id := "T4-02"
	var arq: String = T.tmp("memorial.txt")
	m.exportar_memorial(arq)
	var t := _ler(arq)
	var campos := {"projeto": "Projeto:      Rede coletora", "responsável": "Responsável:  Eng. Responsável", "local": "Local:        Bairro Exemplo",
		"versão do aplicativo": "Aplicativo:   DimEsgoto " + str(m.VERSAO), "versão/configuração normativa": "Norma:        ABNT NBR 9649", "data": "Data:",
		"parâmetros de início e fim de plano": "Início de plano     Fim de plano", "método hidráulico": "Método de cálculo:",
		"rugosidade": "Rugosidade por material", "banco utilizado": "Banco:", "resultados por trecho": "PLANILHA DE DIMENSIONAMENTO",
		"observações": "OBSERVAÇÕES", "quantitativos": "Volume de escavação", "orçamento": "TOTAL (R$)"}
	var faltam: Array = []
	for k in campos.keys():
		if not t.contains(str(campos[k])):
			faltam.append(k)
	T.check(id, faltam.is_empty(), "memorial com os %d campos obrigatórios" % campos.size() + ("" if faltam.is_empty() else " — faltam: %s" % str(faltam)))
	T.check(id, t.contains("banco_teste.json") and t.contains("teste-1"), "o banco identificado é o realmente usado (arquivo e versão)")


# ------------------------------------------------------------------ T4-03

func _t403() -> void:
	var id := "T4-03"
	var base: String = m.identificador()
	T.dado(id, "identificador", base)
	var mem := _ler(T.tmp("memorial.txt"))
	var ht := _ler(T.tmp("planilha_res.html"))
	var info: String = Report.ler_xlsx(T.tmp("planilha_res.xlsx")).get("xl/worksheets/sheet2.xml", "")
	var pdf := FileAccess.get_file_as_bytes(T.tmp("planilha_res.pdf")).get_string_from_ascii()
	m.exportar_planta(T.tmp("planta.dxf"))
	var dxf := _ler(T.tmp("planta.dxf"))
	T.check(id, base.length() == 16 and mem.contains(base) and ht.contains(base) and info.contains(base) and pdf.contains(base) and dxf.contains(base),
		"identificador %s presente no memorial, HTML, XLSX, PDF e DXF" % base)
	var p: Dictionary = m.proj["params"]
	p["pop_fin"] = float(p["pop_fin"]) + 1.0
	var c1: String = m.identificador()
	p["pop_fin"] = float(p["pop_fin"]) - 1.0
	var n: Dictionary = m.proj["nodes"][0]
	n["ct"] = float(n["ct"]) + 0.01
	var c2: String = m.identificador()
	n["ct"] = float(n["ct"]) - 0.01
	var pts: Array = m.topo.pontos.duplicate()
	m.topo.set_pontos(pts + [Vector3(1, 1, 100)])
	var c3: String = m.identificador()
	m.topo.set_pontos(pts)
	var tb: Dictionary = m.db["tubos"][0]
	tb["fornecimento"] = float(tb["fornecimento"]) + 0.01
	var c4: String = m.identificador()
	tb["fornecimento"] = float(tb["fornecimento"]) - 0.01
	var c5: String = m.identificador("motor-9.9")
	T.dado(id, "alterados", [c1, c2, c3, c4, c5])
	T.check(id, c1 != base and c2 != base and c3 != base and c4 != base and c5 != base,
		"muda ao alterar parâmetro, projeto (cota de nó), topografia, banco e versão do motor")
	T.check(id, m.identificador() == base, "volta ao mesmo valor quando tudo volta ao estado original")


# ------------------------------------------------------------------ T4-04

func _t404() -> void:
	var id := "T4-04"
	var t2: Dictionary = m.proj["trechos"][1]
	t2["situacao"] = "Rede Existente"
	m.executar_calculo(false)
	var arq: String = T.tmp("planta_t404.dxf")
	var r: Dictionary = m.exportar_planta(arq)
	var txt := _ler(arq)
	var re := RegEx.create_from_string("\\n0\\nLAYER\\n2\\n([^\\n]+)")
	var layers: Array = []
	for mt in re.search_all(txt):
		layers.append(mt.get_string(1).strip_edges())
	var exigidos := ["REDE_PROJETADA", "REDE_EXISTENTE", "PV", "TEXTO_PV", "COTAS_PV", "TEXTO_TRECHO", "SETAS", "RUAS",
		"CURVAS_PRINCIPAIS", "CURVAS_SECUNDARIAS", "PONTOS_COTADOS", "MALHA", "MARGEM"]
	var faltam: Array = []
	for l in exigidos:
		if not l in layers:
			faltam.append(l)
	T.check(id, bool(r["ok"]) and faltam.is_empty(), "todos os layers exigidos presentes" + ("" if faltam.is_empty() else " — faltam %s" % str(faltam)))
	var lido := Dxf.ler(arq)
	var n_tr: int = m.proj["trechos"].size()
	var setas := 0
	var exist := 0
	var textos_tr: Array = []
	var escala := false
	var norte := false
	for e in lido["ents"]:
		if str(e["layer"]) == "SETAS":
			setas += 1
		if str(e["layer"]) == "REDE_EXISTENTE":
			exist += 1
		if str(e["tipo"]) == "TEXT":
			if str(e["layer"]) == "TEXTO_TRECHO":
				textos_tr.append(str(e["s"]))
			if str(e["s"]) == "ESCALA 1:1000":
				escala = true
			if str(e["s"]) == "N" and str(e["layer"]) == "LEGENDA":
				norte = true
	T.check(id, escala and norte, "escala (\"ESCALA 1:1000\") e norte presentes")
	T.check(id, setas == n_tr, "uma seta de fluxo por trecho (%d de %d)" % [setas, n_tr])
	var d_ok := 0
	var i_ok := 0
	for row in m.results["rows"].values():
		var s_d := "%%%%c%d" % int(row["d"])
		var s_i: String = m.fmt(row["i"], 4)
		for t in textos_tr:
			if t.begins_with(s_d) and t.contains(s_i):
				d_ok += 1
				i_ok += 1
				break
	T.check(id, d_ok == n_tr and i_ok == n_tr, "diâmetro e declividade de cada trecho anotados (%d de %d)" % [d_ok, n_tr])
	T.check(id, exist == 1, "o trecho \"Rede Existente\" está no layer REDE_EXISTENTE (%d entidade)" % exist)
	t2["situacao"] = "Rede Projetada"
	m.executar_calculo(false)


# ------------------------------------------------------------------ T4-05

func _rows_c1(n: int) -> Array:
	var out: Array = []
	for sq in Net.sequencias(m.proj):
		if str(sq["nome"]) == "C1":
			for tid in sq["trechos"]:
				if out.size() < n:
					out.append(m.results["rows"][tid])
	return out


func _t405() -> void:
	var id := "T4-05"
	var rows := _rows_c1(3)
	T.check(id, rows.size() == 3 and str(rows[0]["pv_f"]) == str(rows[1]["pv_i"]) and str(rows[1]["pv_f"]) == str(rows[2]["pv_i"]),
		"coletor C1 com três trechos em ordem montante → jusante (%s, %s, %s)" % [rows[0]["nome"], rows[1]["nome"], rows[2]["nome"]])
	var arq: String = T.tmp("perfil.dxf")
	var r: Dictionary = m.exportar_perfil(rows, "Perfil teste", arq)
	var lido := Dxf.ler(arq)
	var cont := {}
	var textos: Array = []
	for e in lido["ents"]:
		cont[e["layer"]] = int(cont.get(e["layer"], 0)) + 1
		if str(e["tipo"]) == "TEXT":
			textos.append(str(e["s"]))
	T.check(id, bool(r["ok"]) and int(cont.get("TERRENO", 0)) == 1 and int(cont.get("TUBO", 0)) == 6 and int(cont.get("PV", 0)) == 4 and int(cont.get("NA", 0)) == 3,
		"terreno, geratrizes do tubo (6), PVs (4) e nível d'água (3): %s" % str(cont))
	var pts: PackedVector2Array = []
	for e in lido["ents"]:
		if str(e["layer"]) == "TERRENO":
			pts = e["pts"]
	var cresc := true
	for k in range(1, pts.size()):
		cresc = cresc and pts[k].x >= pts[k - 1].x
	T.check(id, cresc and pts.size() == 6, "terreno desenhado de montante para jusante (x crescente)")
	var tem := func(s: String) -> bool: return s in textos
	T.check(id, tem.call(m.fmt(rows[0]["ct_m"], 3)) and tem.call(m.fmt(rows[2]["cc_j"], 3)) and tem.call("0,00") and tem.call(m.fmt(float(rows[0]["L"]), 2)),
		"cotas do terreno/coletor e distâncias acumuladas anotadas")
	var esc := false
	for t in textos:
		if t.begins_with("ESCALA H 1:1000  V 1:100"):
			esc = true
	T.check(id, esc, "escala horizontal e vertical informadas")
	T.check(id, str(textos).contains(str(rows[0]["pv_i"])), "PVs identificados pelo nome")


# ------------------------------------------------------------------ T4-06

func _t406() -> void:
	var id := "T4-06"
	var pares := {}
	for rodada in 2:
		var pre: String = T.tmp("rep%d_" % rodada)
		m.exportar_memorial(pre + "memorial.txt")
		for key in ["res", "orc"]:
			for ext in ["csv", "html", "pdf", "xlsx"]:
				m.exportar_planilha_arquivo(key, pre + key + "." + ext)
		m.exportar_planta(pre + "planta.dxf")
		m.exportar_perfil(_rows_c1(3), "Perfil", pre + "perfil.dxf")
		m.exportar_rede_geojson(pre + "rede.geojson")
	var difs: Array = []
	var nomes := ["memorial.txt", "planta.dxf", "perfil.dxf", "rede.geojson"]
	for key in ["res", "orc"]:
		for ext in ["csv", "html", "pdf"]:
			nomes.append(key + "." + ext)
	for nome in nomes:
		var a := FileAccess.get_file_as_bytes(T.tmp("rep0_" + nome))
		var b := FileAccess.get_file_as_bytes(T.tmp("rep1_" + nome))
		if nome == "memorial.txt":
			a = _sem_data(a.get_string_from_utf8()).to_utf8_buffer()
			b = _sem_data(b.get_string_from_utf8()).to_utf8_buffer()
		if a != b or a.is_empty():
			difs.append(nome)
	for key in ["res", "orc"]:
		if Report.ler_xlsx(T.tmp("rep0_%s.xlsx" % key)) != Report.ler_xlsx(T.tmp("rep1_%s.xlsx" % key)):
			difs.append(key + ".xlsx")
	T.check(id, difs.is_empty(), "%d saídas equivalentes nas duas gerações (byte a byte; XLSX por conteúdo; memorial sem a data)" % (nomes.size() + 2) +
		("" if difs.is_empty() else " — diferentes: %s" % str(difs)))


func _sem_data(t: String) -> String:
	var out: Array = []
	for l in t.split("\n"):
		if not l.begins_with("Data:"):
			out.append(l)
	return "\n".join(PackedStringArray(out))


# ------------------------------------------------------------------ T4-07

func _t407() -> void:
	var id := "T4-07"
	for caso in ["estrutural", "desatualizado"]:
		if caso == "estrutural":
			T.carregar(m, "rede_invalida.esg")
			T.usar_banco_teste(m)
			m.executar_calculo(false)
		else:
			m._do_action("exemplo")
			T.usar_banco_teste(m)
			m.executar_calculo(false)
			m.proj["nodes"][2]["ct"] = float(m.proj["nodes"][2]["ct"]) + 1.0
			m.on_changed("no")
		var n0: int = m.registro.erros.size()
		var pre: String = T.tmp("bloq_%s_" % caso)
		var rs := [m.exportar_memorial(pre + "memorial.txt"), m.exportar_planilha_arquivo("orc", pre + "orc.csv"),
			m.exportar_planilha_arquivo("res", pre + "res.xlsx"), m.exportar_planta(pre + "planta.dxf")]
		var nenhum := true
		var motivos := true
		for r in rs:
			nenhum = nenhum and not bool(r["ok"])
			motivos = motivos and str(r.get("motivo", "")).contains("bloqueada")
		var arquivos := FileAccess.file_exists(pre + "memorial.txt") or FileAccess.file_exists(pre + "orc.csv") \
			or FileAccess.file_exists(pre + "res.xlsx") or FileAccess.file_exists(pre + "planta.dxf")
		T.check(id, nenhum and not arquivos, "%s: memorial final, orçamento, resultados e planta DXF NÃO exportados" % caso)
		T.check(id, motivos and m.registro.erros.size() > n0, "%s: motivo informado e registrado (%s)" % [caso, str(rs[0].get("motivo", "")).left(110)])
