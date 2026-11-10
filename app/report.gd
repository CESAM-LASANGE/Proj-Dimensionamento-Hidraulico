extends RefCounted
## Relatórios e exportações: memorial de cálculo (arquivo .RES), planta e perfil
## em DXF, planilhas em CSV / HTML.

const Net = preload("res://net.gd")
const Dxf = preload("res://dxf.gd")
const Db = preload("res://db.gd")
const Calc = preload("res://calc.gd")


static func _br(v, dec: int) -> String:
	return (("%." + str(dec) + "f") % float(v)).replace(".", ",")


static func _data() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%02d/%02d/%04d %02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"]]


# ------------------------------------------------------------------ memorial

## extra: {banco: Db.identificacao(), materiais: [...], identificador: hash, aprovado: bool}
static func memorial(proj: Dictionary, res: Dictionary, app: String, extra := {}) -> String:
	var p: Dictionary = proj["params"]
	var info: Dictionary = proj.get("info", {})
	var s := ""
	var linha := "=".repeat(160) + "\n"
	var aprovado := bool(res.get("aprovado", false))
	s += linha + "MEMORIAL DE CÁLCULO — REDE COLETORA DE ESGOTO SANITÁRIO%s\n" % ("" if aprovado else "   [RASCUNHO — RESULTADO NÃO APROVADO]") + linha
	s += "Projeto:      %s\n" % str(info.get("projeto", ""))
	s += "Responsável:  %s\n" % str(info.get("responsavel", ""))
	s += "Local:        %s\n" % str(info.get("local", ""))
	s += "Data:         %s\n" % _data()
	s += "Aplicativo:   %s  •  motor de cálculo %s\n" % [app, str(res.get("motor", "?"))]
	s += "Norma:        %s\n" % Calc.NORMA
	var b: Dictionary = extra.get("banco", {})
	s += "Banco:        %s  •  versão %s  •  conteúdo %s\n" % [str(b.get("arquivo", "padrão")) if str(b.get("arquivo", "")) != "" else "banco padrão",
		str(b.get("versao", "?")), str(b.get("hash", "?"))]
	s += "Referência:   %s\n" % Net.referencia_texto(proj)
	s += "Identificador do resultado: %s\n" % str(extra.get("identificador", "?"))
	s += "Situação:     %s\n\n" % ("aprovado (sem erro estrutural nem restrição impeditiva)" if aprovado else "NÃO aprovado — não usar como documento final")
	s += "1. DADOS DE CONSUMO                         Início de plano     Fim de plano\n"
	s += "   População (hab) ........................ %15s %16s\n" % [_br(p["pop_ini"], 0), _br(p["pop_fin"], 0)]
	s += "   Consumo efetivo per capita (l/hab/dia) . %15s %16s\n" % [_br(p["qpc_ini"], 1), _br(p["qpc_fin"], 1)]
	s += "   Coeficiente de retorno ................. %15s %16s\n" % [_br(p["c_ini"], 2), _br(p["c_fin"], 2)]
	s += "   K1 ..................................... %15s %16s\n" % ["—", _br(p["k1"], 2)]
	s += "   K2 ..................................... %15s %16s\n\n" % [_br(p["k2_ini"], 2), _br(p["k2_fin"], 2)]
	s += "2. DADOS GERAIS E CRITÉRIOS\n"
	s += "   Vazão mínima %s l/s  •  Diâmetro mínimo %s mm  •  Infiltração %s l/s/km\n" % [_br(p["q_min"], 2), _br(p["d_min"], 0), _br(p["infiltracao"], 3)]
	s += "   Recobrimento mínimo %s m  •  Profundidade máxima %s m  •  Distância máx. entre PVs %s m\n" % [_br(p["recob_min"], 2), _br(p["prof_max"], 2), _br(p["dist_max_pv"], 1)]
	s += "   Tensão trativa mínima %s Pa  •  Velocidade máxima %s m/s  •  Degrau mín./máx. %s / %s m\n" % [_br(p["tensao_min"], 2), _br(p["v_max"], 2), _br(p["degrau_min"], 2), _br(p["degrau_max"], 2)]
	s += "   Declividade mínima construtiva %s m/m\n" % _br(p["i_min_constr"], 4)
	s += "   Método de cálculo: %s  •  Ajuste de rugosidade: %s\n" % [["Manning", "Fórmula Universal"][int(p["metodo"])],
		["inferior (otimista)", "superior (pessimista)", "valor do banco de dados"][int(p["ajuste_rug"])]]
	s += "   Cotas intermediárias: %s  •  Rede 100%% plástico: %s  •  Escoramento automático: %s\n\n" % [
		["somente cotas de PVs", "curvas de nível", "pontos cotados"][int(p["cotas_interm"])],
		"sim" if bool(p["rede_plastica"]) else "não", "sim" if bool(p["escoramento_auto"]) else "não"]
	s += "   Rugosidade por material (método %s):\n" % ["Manning (n)", "Fórmula Universal (k, mm)"][int(p["metodo"])]
	for m in extra.get("materiais", []):
		s += "      %-40s n = %s   k = %s mm\n" % [str(m.get("nome", "")), _br(m.get("n", 0.0), 4), _br(m.get("k", 0.0), 3)]
	s += "\n"
	s += "3. CONTRIBUIÇÃO LINEAR\n"
	s += "   Extensão total da rede ........ %s m\n" % _br(res.get("ltot", 0.0), 2)
	s += "   Contribuição linear inicial ... %s l/s/km\n" % _br(float(res.get("tx_i", 0.0)) * 1000.0, 4)
	s += "   Contribuição linear final ..... %s l/s/km\n\n" % _br(float(res.get("tx_f", 0.0)) * 1000.0, 4)
	s += "4. PLANILHA DE DIMENSIONAMENTO\n"
	var heads := ["Col", "Trecho", "PV ini", "PV fim", "L(m)", "Qmi", "Qmf", "Qji", "Qjf", "DN", "I(m/m)", "CT mon", "CT jus", "CC mon", "CC jus",
		"Rec m", "Rec j", "y/Di", "y/Df", "Vi", "Vf", "Vc", "σ(Pa)"]
	var w := [4, 6, 6, 6, 7, 6, 6, 6, 6, 4, 7, 9, 9, 9, 9, 5, 5, 5, 5, 5, 5, 5, 5]
	var hl := ""
	for k in heads.size():
		hl += str(heads[k]).lpad(w[k]) + " "
	s += hl + "\n" + "-".repeat(hl.length()) + "\n"
	var rows: Dictionary = res.get("rows", {})
	for sq in Net.sequencias(proj):
		for tid in sq["trechos"]:
			if not rows.has(tid):
				continue
			var r: Dictionary = rows[tid]
			var vals := [r["coletor"], r["nome"], r["pv_i"], r["pv_f"], _br(r["L"], 2), _br(r["qm_i"], 2), _br(r["qm_f"], 2),
				_br(r["qj_i"], 2), _br(r["qj_f"], 2), _br(r["d"], 0), _br(r["i"], 4), _br(r["ct_m"], 3), _br(r["ct_j"], 3),
				_br(r["cc_m"], 3), _br(r["cc_j"], 3), _br(r["rec_m"], 2), _br(r["rec_j"], 2), _br(r["yd_i"], 2), _br(r["yd_f"], 2),
				_br(r["v_i"], 2), _br(r["v_f"], 2), _br(r["vc"], 2), _br(r["sigma"], 2)]
			var ln := ""
			for k in vals.size():
				ln += str(vals[k]).lpad(w[k]) + " "
			s += ln + "\n"
	s += "   Vazões em l/s (m = montante, j = jusante; i = início, f = fim de plano). Cotas em m.\n\n"
	s += "5. OBSERVAÇÕES\n"
	var obs: Array = res.get("obs", [])
	if obs.is_empty():
		s += "   Nenhuma restrição encontrada.\n"
	for o in obs:
		s += "   %-8s %s\n" % [str(o[0]), str(o[1])]
	s += "\n6. ORÇAMENTO E QUANTITATIVOS\n"
	var orc: Dictionary = res.get("orc", {})
	for l in orc.get("linhas", []):
		match str(l["tipo"]):
			"sec":
				s += "   %s\n" % str(l["desc"])
			"item":
				var q := _br(l.get("q", 0.0), int(l.get("dec", 2)))
				var tot := _br(l["total"], 2) if l.has("total") else ""
				s += "      %-58s %12s %-3s %14s\n" % [str(l["desc"]), q, str(l.get("un", "")), tot]
			"total":
				s += "      %-58s %31s\n" % ["TOTAL (R$)", _br(l["total"], 2)]
	s += "\n   Preços de referência do banco de itens de custo; atualize-os para valores reais.\n"
	return s


# ------------------------------------------------------------------ planilhas

## CSV: separador ";" e decimal "," (padrão brasileiro do Excel/LibreOffice), UTF-8 com BOM.
static func csv(dados: Array) -> String:
	var linhas: Array = []
	for r in dados:
		var cel: Array = []
		for c in r:
			var t := str(c).replace("\"", "\"\"")
			if t.contains(";") or t.contains("\"") or t.contains("\n") or t.contains("\r"):
				t = "\"" + t + "\""
			cel.append(t)
		linhas.append(";".join(PackedStringArray(cel)))
	return "\n".join(PackedStringArray(linhas)) + "\n"


static func html(titulo: String, dados: Array, subtitulo := "", rodape := "") -> String:
	var s := "<!doctype html><html lang=\"pt-BR\"><head><meta charset=\"utf-8\"><title>%s</title>" % titulo.xml_escape()
	s += "<style>body{font-family:Arial,Helvetica,sans-serif;font-size:12px;margin:18px}h1{font-size:16px;margin:0 0 4px}"
	s += "p{margin:0 0 10px;color:#555}table{border-collapse:collapse}th,td{border:1px solid #999;padding:3px 6px;white-space:nowrap}"
	s += "th{background:#dde3ea}td.n{text-align:right}tr:nth-child(even) td{background:#f6f8fa}@media print{body{margin:0}}</style></head><body>"
	s += "<h1>%s</h1><p>%s</p><table>" % [titulo.xml_escape(), subtitulo.xml_escape()]
	for k in dados.size():
		s += "<tr>"
		for c in dados[k]:
			var t := str(c)
			if k == 0:
				s += "<th>%s</th>" % t.xml_escape()
			else:
				var num := t.replace(".", "").replace(",", ".").is_valid_float()
				s += "<td%s>%s</td>" % [" class=\"n\"" if num else "", t.xml_escape()]
		s += "</tr>"
	s += "</table><p>Separador decimal: vírgula. %s</p></body></html>\n" % rodape.xml_escape()
	return s


## Tabela em texto de largura fixa (para PDF e listagens).
static func tabela_texto(dados: Array, max_col := 34) -> Array:
	if dados.is_empty():
		return []
	var larg: Array = []
	for c in dados[0].size():
		var w := 1
		for r in dados:
			if c < r.size():
				w = maxi(w, mini(str(r[c]).replace("\n", " / ").length(), max_col))
		larg.append(w)
	var out: Array = []
	for k in dados.size():
		var partes: Array = []
		for c in larg.size():
			var t := str(dados[k][c]).replace("\n", " / ") if c < dados[k].size() else ""
			t = t.left(max_col)
			var num := t.replace(",", ".").is_valid_float()
			partes.append(t.lpad(larg[c]) if num and k > 0 else t.rpad(larg[c]))
		out.append(" | ".join(PackedStringArray(partes)))
		if k == 0:
			out.append("-".repeat(out[0].length()))
	return out


# ------------------------------------------------------------------ XLSX

static func _col(i: int) -> String:
	var s := ""
	var n := i + 1
	while n > 0:
		var r := (n - 1) % 26
		s = char(65 + r) + s
		n = (n - 1) / 26
	return s


static func numero_br(t: String) -> Variant:
	var re := RegEx.create_from_string("^-?\\d+(,\\d+)?$")
	if re.search(t.strip_edges()) != null:
		return t.strip_edges().replace(",", ".").to_float()
	return null


static func _sheet_xml(dados: Array) -> String:
	var s := "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
	s += "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>"
	for k in dados.size():
		s += "<row r=\"%d\">" % (k + 1)
		for c in dados[k].size():
			var ref := "%s%d" % [_col(c), k + 1]
			var t := str(dados[k][c])
			var v = numero_br(t) if k > 0 else null
			if v != null:
				s += "<c r=\"%s\"><v>%s</v></c>" % [ref, str(v)]
			elif t != "":
				s += "<c r=\"%s\" t=\"inlineStr\"><is><t xml:space=\"preserve\">%s</t></is></c>" % [ref, t.xml_escape()]
		s += "</row>"
	s += "</sheetData></worksheet>"
	return s


## Pasta de trabalho XLSX mínima: aba "Dados" (números como números) e aba "Info".
static func gravar_xlsx(path: String, titulo: String, dados: Array, info: Dictionary) -> bool:
	var info_rows: Array = [["Campo", "Valor"], ["Planilha", titulo]]
	for k in info.keys():
		info_rows.append([str(k), str(info[k])])
	info_rows.append(["Números", "células numéricas (sem separador de milhar); no CSV o separador decimal é vírgula"])
	var arquivos := {
		"[Content_Types].xml": "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/><Override PartName=\"/xl/worksheets/sheet2.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
		"_rels/.rels": "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
		"xl/workbook.xml": "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Dados\" sheetId=\"1\" r:id=\"rId1\"/><sheet name=\"Info\" sheetId=\"2\" r:id=\"rId2\"/></sheets></workbook>",
		"xl/_rels/workbook.xml.rels": "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet2.xml\"/></Relationships>",
		"xl/worksheets/sheet1.xml": _sheet_xml(dados),
		"xl/worksheets/sheet2.xml": _sheet_xml(info_rows),
	}
	var tmp := path + ".tmp~"
	var z := ZIPPacker.new()
	if z.open(tmp) != OK:
		return false
	for nome in arquivos.keys():
		z.start_file(nome)
		z.write_file(str(arquivos[nome]).to_utf8_buffer())
		z.close_file()
	z.close()
	return DirAccess.rename_absolute(tmp, path) == OK


static func ler_xlsx(path: String) -> Dictionary:
	var z := ZIPReader.new()
	if z.open(path) != OK:
		return {}
	var out := {}
	for f in z.get_files():
		out[f] = z.read_file(f).get_string_from_utf8()
	z.close()
	return out


# ------------------------------------------------------------------ PDF (texto em Courier, A4 paisagem)

const _WINANSI := {"€": 0x80, "…": 0x85, "‘": 0x91, "’": 0x92, "“": 0x93, "”": 0x94, "•": 0x95, "–": 0x96, "—": 0x97}


static func _pdf_texto(s: String) -> PackedByteArray:
	var b := PackedByteArray()
	for ch in s.replace("→", "->").replace("≥", ">=").replace("≤", "<="):
		var c := ch.unicode_at(0)
		if ch == "(" or ch == ")" or ch == "\\":
			b.append(92)
			b.append(c)
		elif c < 128 and c >= 32:
			b.append(c)
		elif c >= 160 and c <= 255:
			b.append(c)
		elif _WINANSI.has(ch):
			b.append(_WINANSI[ch])
		else:
			b.append(63)
	return b


static func pdf(titulo: String, linhas: Array) -> PackedByteArray:
	var fonte := 7.0
	var lead := 8.6
	var por_pag := int((595.0 - 72.0) / lead)
	var paginas: Array = []
	var todas: Array = [titulo, ""] + linhas
	var k := 0
	while k < todas.size():
		paginas.append(todas.slice(k, k + por_pag))
		k += por_pag
	if paginas.is_empty():
		paginas.append([titulo])
	var objs: Array = [] # PackedByteArray por objeto (1-based)
	var n_pag := paginas.size()
	var kids := ""
	for i in n_pag:
		kids += "%d 0 R " % (4 + i * 2)
	objs.append("<< /Type /Catalog /Pages 2 0 R >>".to_ascii_buffer())
	objs.append(("<< /Type /Pages /Kids [%s] /Count %d >>" % [kids.strip_edges(), n_pag]).to_ascii_buffer())
	objs.append("<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>".to_ascii_buffer())
	for i in n_pag:
		var cont := PackedByteArray()
		cont.append_array(("BT /F1 %s Tf %s TL 36 %s Td\n" % [str(fonte), str(lead), str(595.0 - 40.0)]).to_ascii_buffer())
		for l in paginas[i]:
			cont.append_array("(".to_ascii_buffer())
			cont.append_array(_pdf_texto(str(l)))
			cont.append_array(") Tj T*\n".to_ascii_buffer())
		cont.append_array(("ET\nBT /F1 7 Tf 760 20 Td (%d / %d) Tj ET\n" % [i + 1, n_pag]).to_ascii_buffer())
		objs.append(("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 842 595] /Resources << /Font << /F1 3 0 R >> >> /Contents %d 0 R >>" % (5 + i * 2)).to_ascii_buffer())
		var stream := ("<< /Length %d >>\nstream\n" % cont.size()).to_ascii_buffer()
		stream.append_array(cont)
		stream.append_array("\nendstream".to_ascii_buffer())
		objs.append(stream)
	var out := "%PDF-1.4\n".to_ascii_buffer()
	out.append_array(PackedByteArray([37, 226, 227, 207, 211, 10]))
	var offs: Array = []
	for i in objs.size():
		offs.append(out.size())
		out.append_array(("%d 0 obj\n" % (i + 1)).to_ascii_buffer())
		out.append_array(objs[i])
		out.append_array("\nendobj\n".to_ascii_buffer())
	var xref := out.size()
	var x := "xref\n0 %d\n0000000000 65535 f \n" % (objs.size() + 1)
	for o in offs:
		x += "%010d 00000 n \n" % o
	x += "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [objs.size() + 1, xref]
	out.append_array(x.to_ascii_buffer())
	return out


# ------------------------------------------------------------------ DXF da planta

static func dxf_planta(proj: Dictionary, res: Dictionary, topo, opts: Dictionary, db: Dictionary, identificador := "") -> String:
	var esc := maxf(float(opts.get("exp_escala", 1000.0)), 1.0)
	var h := 0.0025 * esc
	var rr := 0.0018 * esc
	var w := Dxf.Escritor.new()
	if identificador != "":
		w.comentario("DimEsgoto - identificador do resultado " + identificador)
	# todos os layers padrão existem mesmo vazios
	for sit in Db.nomes(db, "situacoes"):
		w.layer(Dxf.nome_layer(sit), 3 if sit.to_lower().contains("exist") else 5)
	for par in [["PV", 7], ["TEXTO_PV", 5], ["COTAS_PV", 1], ["TEXTO_TRECHO", 1], ["SETAS", 1], ["RUAS", 8],
			["CURVAS_PRINCIPAIS", 30], ["CURVAS_SECUNDARIAS", 2], ["PONTOS_COTADOS", 4], ["MALHA", 9], ["MARGEM", 6], ["LEGENDA", 7],
			["INTERFERENCIAS", 140]]:
		w.layer(par[0], par[1])
	w.layer("TEXTO_PV", 5)
	w.layer("COTAS_PV", 1)
	w.layer("TEXTO_TRECHO", 1)
	w.layer("SETAS", 1)
	var nodes := Net.node_map(proj)
	var rows: Dictionary = res.get("rows", {})
	var rnodes: Dictionary = res.get("nodes", {})
	if bool(opts.get("exp_rede", true)):
		for t in proj["trechos"]:
			var a = nodes.get(int(t["ni"]))
			var b = nodes.get(int(t["nf"]))
			if a == null or b == null:
				continue
			var ly := Dxf.nome_layer(str(t.get("situacao", "Rede Projetada")))
			if not w.layers.has(ly):
				w.layer(ly, 5)
			var pa := Net.pos(a)
			var pb := Net.pos(b)
			var dir := (pb - pa).normalized()
			if pa.distance_to(pb) < 1e-6:
				continue
			w.linha(ly, pa + dir * rr, pb - dir * rr)
			var mid := (pa + pb) / 2.0
			var nrm := Vector2(-dir.y, dir.x)
			var tip := mid + dir * h
			w.poli("SETAS", PackedVector2Array([tip, mid - dir * h * 0.6 + nrm * h * 0.6, mid - dir * h * 0.6 - nrm * h * 0.6, tip]))
			var ang := rad_to_deg(dir.angle())
			var ang_t := ang
			if ang_t > 90.0 or ang_t < -90.0:
				ang_t += 180.0
			var r = rows.get(int(t["id"]))
			var l := Net.comprimento(nodes, t)
			var s1 := "%s-%s" % [str(t["nome"]), _br(l, 2)]
			var s2 := "ø%d %s" % [int(r["d"]), _br(r["i"], 4)] if r != null else ""
			w.texto("TEXTO_TRECHO", mid + nrm * h * 1.6 + dir * h * 2.0, h * 0.8, s1, ang_t, 1)
			if s2 != "":
				w.texto("TEXTO_TRECHO", mid - nrm * h * 2.4 + dir * h * 2.0, h * 0.8, s2, ang_t, 1)
		for n in proj["nodes"]:
			var p := Net.pos(n)
			var nr = rnodes.get(int(n["id"]))
			var tipo := str(nr["tipo"]) if nr != null else str(n["tipo"])
			if nr != null and bool(nr.get("tq", false)):
				w.linha("PV", p + Vector2(0, -rr), p + Vector2(0, rr))
			if tipo == "TL":
				w.circulo("PV", p, rr * 0.45)
			else:
				w.circulo("PV", p, rr)
				if tipo in ["CP", "PI"]:
					w.linha("PV", p + Vector2(-rr, -rr) * 0.7, p + Vector2(rr, rr) * 0.7)
					w.linha("PV", p + Vector2(-rr, rr) * 0.7, p + Vector2(rr, -rr) * 0.7)
			var sig := str(Db.pv(db, tipo)["sigla_imp"])
			var dn := ""
			for t in proj["trechos"]:
				if int(t["ni"]) == int(n["id"]) and rows.has(int(t["id"])):
					dn = "%d " % int(rows[int(t["id"])]["d"])
			var base := p + Vector2(rr * 1.6, rr * 1.2)
			w.texto("TEXTO_PV", base + Vector2(h * 6.5, -h * 0.4), h, "%s%s-%s" % [dn, sig, str(n["nome"])])
			w.texto("COTAS_PV", base + Vector2(0, h * 0.25), h * 0.8, _br(n["ct"], 3))
			if nr != null and float(nr["cc_min"]) < INF:
				w.texto("COTAS_PV", base - Vector2(0, h * 1.05), h * 0.8, _br(nr["cc_min"], 3))
				w.linha("COTAS_PV", base + Vector2(0, h * 0.1), base + Vector2(h * 5.8, h * 0.1))
	if bool(opts.get("exp_ruas", true)):
		w.layer("RUAS", 8)
		for rua in topo.ruas:
			w.poli("RUAS", rua)
	if bool(opts.get("exp_topo", true)):
		w.layer("CURVAS_PRINCIPAIS", 30)
		w.layer("CURVAS_SECUNDARIAS", 2)
		for cv in topo.curvas:
			var z := float(cv["z"])
			var ly := "CURVAS_PRINCIPAIS" if fmod(absf(z) + 1e-4, 5.0) < 1e-3 else "CURVAS_SECUNDARIAS"
			w.poli(ly, cv["pts"], z)
	var area: Dictionary = proj["area"]
	var r0 := Vector2(float(area["e0"]), float(area["n0"]))
	var r1 := r0 + Vector2(float(area["le"]), float(area["ln"]))
	if bool(opts.get("exp_malha", true)):
		w.layer("MALHA", 9)
		var g := float(area["grid"])
		if g > 0.0:
			var x := ceilf(r0.x / g) * g
			while x <= r1.x + 1e-6:
				w.linha("MALHA", Vector2(x, r0.y), Vector2(x, r1.y))
				w.texto("MALHA", Vector2(x, r0.y - h * 1.5), h * 0.8, "E " + _br(x, 0), 0.0, 1)
				x += g
			var y := ceilf(r0.y / g) * g
			while y <= r1.y + 1e-6:
				w.linha("MALHA", Vector2(r0.x, y), Vector2(r1.x, y))
				w.texto("MALHA", Vector2(r0.x - h * 0.5, y), h * 0.8, "N " + _br(y, 0), 0.0, 2)
				y += g
	if bool(opts.get("exp_margem", true)):
		w.layer("MARGEM", 6)
		w.poli("MARGEM", PackedVector2Array([r0, Vector2(r1.x, r0.y), r1, Vector2(r0.x, r1.y), r0]))
	# legenda: escala, norte, símbolos e identificador
	var lg := Vector2(r1.x + h * 4.0, r1.y)
	w.texto("LEGENDA", lg, h * 1.4, "ESCALA 1:%d" % int(esc))
	w.texto("LEGENDA", lg - Vector2(0, h * 2.2), h * 0.8, "Unidades: metros • %s" % Net.referencia_texto(proj))
	var nb := lg + Vector2(h * 3.0, -h * 9.0)
	w.poli("LEGENDA", PackedVector2Array([nb + Vector2(-h, -h * 2.5), nb + Vector2(0, h * 2.5), nb + Vector2(h, -h * 2.5), nb + Vector2(0, -h * 1.2), nb + Vector2(-h, -h * 2.5)]))
	w.texto("LEGENDA", nb + Vector2(-h * 0.4, h * 3.0), h * 1.2, "N")
	var ly0 := lg - Vector2(0, h * 16.0)
	w.texto("LEGENDA", ly0, h, "LEGENDA")
	var itens := [["PV", "Poço de visita"], ["TL", "Terminal de limpeza"], ["TQ", "PV com tubo de queda"], ["SETA", "Sentido do escoamento"],
		["TXT", "Trecho-extensão / %%c diâmetro declividade"]]
	for i in itens.size():
		var py := ly0 - Vector2(0, h * 2.0 * (i + 1))
		match str(itens[i][0]):
			"PV":
				w.circulo("LEGENDA", py + Vector2(h, h * 0.4), rr)
			"TL":
				w.circulo("LEGENDA", py + Vector2(h, h * 0.4), rr * 0.45)
			"TQ":
				w.circulo("LEGENDA", py + Vector2(h, h * 0.4), rr)
				w.linha("LEGENDA", py + Vector2(h, h * 0.4 - rr), py + Vector2(h, h * 0.4 + rr))
			"SETA":
				w.poli("LEGENDA", PackedVector2Array([py + Vector2(0, h * 0.4), py + Vector2(h * 2, h * 0.4)]))
		w.texto("LEGENDA", py + Vector2(h * 3.0, 0), h * 0.8, str(itens[i][1]))
	if identificador != "":
		w.texto("LEGENDA", ly0 - Vector2(0, h * 14.0), h * 0.7, "Identificador do resultado: " + identificador)
	if bool(opts.get("exp_pontos", true)) and topo.pontos.size() > 0:
		w.layer("PONTOS_COTADOS", 4)
		for pt in topo.pontos:
			w.ponto("PONTOS_COTADOS", pt)
			w.texto("PONTOS_COTADOS", Vector2(pt.x, pt.y) + Vector2(h * 0.4, h * 0.4), h * 0.7, _br(pt.z, 2))
	return w.gerar()


# ------------------------------------------------------------------ DXF do perfil

static func dxf_perfil(rows: Array, titulo: String, escala_h: float, identificador := "") -> String:
	var esc := maxf(escala_h, 1.0)
	var exag := 10.0
	var h := 0.0025 * esc
	var w := Dxf.Escritor.new()
	w.layer("TERRENO", 1)
	w.layer("TUBO", 7)
	w.layer("NA", 4)
	w.layer("PV", 8)
	w.layer("GRADE", 9)
	w.layer("TEXTO", 7)
	if rows.is_empty():
		return w.gerar()
	var ymin := INF
	var ymax := -INF
	for r in rows:
		ymin = minf(ymin, minf(float(r["cc_m"]), float(r["cc_j"])))
		ymax = maxf(ymax, maxf(float(r["ct_m"]), float(r["ct_j"])))
	var base := floorf(ymin) - 1.0
	var topo := ceilf(ymax) + 1.0
	var Y := func(z: float) -> float: return (z - base) * exag
	var xs: Array = [0.0]
	for r in rows:
		xs.append(float(xs[-1]) + float(r["L"]))
	var ltot: float = xs[-1]
	# grade de cotas a cada metro
	var zz := base
	while zz <= topo + 1e-6:
		w.linha("GRADE", Vector2(0, Y.call(zz)), Vector2(ltot, Y.call(zz)))
		w.texto("TEXTO", Vector2(-h, Y.call(zz) - h * 0.4), h * 0.8, _br(zz, 0), 0.0, 2)
		zz += 1.0
	w.texto("TEXTO", Vector2(0, Y.call(topo) + h * 2.5), h * 1.4, titulo)
	w.texto("TEXTO", Vector2(0, Y.call(topo) + h * 1.0), h * 0.8, "ESCALA H 1:%d  V 1:%d (vertical exagerada %dx)" % [int(esc), int(esc / exag), int(exag)])
	if identificador != "":
		w.texto("TEXTO", Vector2(0, Y.call(topo) + h * 4.5), h * 0.7, "Identificador do resultado: " + identificador)
	var terreno := PackedVector2Array()
	for k in rows.size():
		var r: Dictionary = rows[k]
		var d := float(r["d"]) / 1000.0
		var xa: float = xs[k]
		var xb: float = xs[k + 1]
		terreno.append(Vector2(xa, Y.call(float(r["ct_m"]))))
		terreno.append(Vector2(xb, Y.call(float(r["ct_j"]))))
		w.linha("TUBO", Vector2(xa, Y.call(float(r["cc_m"]))), Vector2(xb, Y.call(float(r["cc_j"]))))
		w.linha("TUBO", Vector2(xa, Y.call(float(r["cc_m"]) + d)), Vector2(xb, Y.call(float(r["cc_j"]) + d)))
		w.linha("NA", Vector2(xa, Y.call(float(r["cc_m"]) + float(r["yd_f"]) * d)), Vector2(xb, Y.call(float(r["cc_j"]) + float(r["yd_f"]) * d)))
		w.texto("TEXTO", Vector2((xa + xb) / 2.0, Y.call(base) - h * 9.0), h * 0.8,
			"%s  L=%s  ø%d  I=%s" % [str(r["nome"]), _br(r["L"], 2), int(r["d"]), _br(r["i"], 4)], 0.0, 1)
	w.poli("TERRENO", terreno)
	var faixa := ["PV", "Distância", "Cota terreno", "Cota coletor", "Profundidade"]
	for j in faixa.size():
		w.texto("TEXTO", Vector2(-h * 14.0, Y.call(base) - h * (2.0 + 1.5 * j)), h * 0.8, faixa[j])
	for k in rows.size() + 1:
		var x: float = xs[k]
		var ct: float
		var cc: float
		var nome: String
		if k == 0:
			ct = float(rows[0]["ct_m"])
			cc = float(rows[0]["cc_m"])
			nome = str(rows[0]["pv_i"])
		elif k == rows.size():
			ct = float(rows[k - 1]["ct_j"])
			cc = float(rows[k - 1]["cc_j"])
			nome = str(rows[k - 1]["pv_f"])
		else:
			ct = float(rows[k]["ct_m"])
			cc = minf(float(rows[k]["cc_m"]), float(rows[k - 1]["cc_j"]))
			nome = str(rows[k]["pv_i"])
		w.linha("PV", Vector2(x, Y.call(cc)), Vector2(x, Y.call(ct)))
		w.linha("GRADE", Vector2(x, Y.call(base)), Vector2(x, Y.call(base) - h * 8.0))
		var vals := [nome, _br(x, 2), _br(ct, 3), _br(cc, 3), _br(ct - cc, 2)]
		for j in vals.size():
			w.texto("TEXTO", Vector2(x, Y.call(base) - h * (2.0 + 1.5 * j)), h * 0.7, vals[j], 0.0, 1)
	return w.gerar()
