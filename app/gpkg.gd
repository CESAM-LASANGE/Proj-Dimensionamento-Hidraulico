extends RefCounted
## GeoPackage (OGC 12-128, versão 1.3) gravado sem bibliotecas: o arquivo SQLite 3 é montado
## página a página (cabeçalho, árvores B de tabelas e dos índices automáticos).
##
## Camadas: "pvs" (pontos) e "trechos" (linhas), com os atributos do projeto e, quando há
## resultado aprovado e atualizado, os resultados do dimensionamento. Abre no QGIS/ArcGIS.

const Net = preload("res://net.gd")

const PAGE := 4096
const APP_ID := 0x47504B47 # "GPKG"
const USER_VERSION := 10300 # GeoPackage 1.3.0

const WKT_4326 := "GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,AUTHORITY[\"EPSG\",\"7030\"]],AUTHORITY[\"EPSG\",\"6326\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AUTHORITY[\"EPSG\",\"4326\"]]"

const SQL_SRS := "CREATE TABLE gpkg_spatial_ref_sys (srs_name TEXT NOT NULL, srs_id INTEGER NOT NULL PRIMARY KEY, organization TEXT NOT NULL, organization_coordsys_id INTEGER NOT NULL, definition TEXT NOT NULL, description TEXT)"
const SQL_CONTENTS := "CREATE TABLE gpkg_contents (table_name TEXT NOT NULL PRIMARY KEY, data_type TEXT NOT NULL, identifier TEXT UNIQUE, description TEXT DEFAULT '', last_change DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')), min_x DOUBLE, min_y DOUBLE, max_x DOUBLE, max_y DOUBLE, srs_id INTEGER, CONSTRAINT fk_gc_r_srs_id FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys(srs_id))"
const SQL_GEOMCOLS := "CREATE TABLE gpkg_geometry_columns (table_name TEXT NOT NULL, column_name TEXT NOT NULL, geometry_type_name TEXT NOT NULL, srs_id INTEGER NOT NULL, z TINYINT NOT NULL, m TINYINT NOT NULL, CONSTRAINT pk_geom_cols PRIMARY KEY (table_name, column_name), CONSTRAINT uk_gc_table_name UNIQUE (table_name), CONSTRAINT fk_gc_tn FOREIGN KEY (table_name) REFERENCES gpkg_contents(table_name), CONSTRAINT fk_gc_srs FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys (srs_id))"

var pages: Array = [] # páginas (PackedByteArray); índice 0 = página 1


# ------------------------------------------------------------------ API

## Monta o GeoPackage da rede. res = resultados (vazio se não aprovados/atualizados).
static func rede(proj: Dictionary, res := {}) -> PackedByteArray:
	var g = load("res://gpkg.gd").new()
	return g._montar_rede(proj, res)


## Código EPSG citado na referência do projeto (ex.: "SIRGAS 2000 / UTM 22S (EPSG:31982)"); -1 se não houver.
static func epsg(crs: String) -> int:
	var re := RegEx.create_from_string("(?i)EPSG\\s*[:=]?\\s*(\\d{4,6})")
	var m := re.search(crs)
	return int(m.get_string(1)) if m != null else -1


func _montar_rede(proj: Dictionary, res: Dictionary) -> PackedByteArray:
	pages = [PackedByteArray()] # página 1 reservada para sqlite_master
	var crs := str(proj.get("referencia", {}).get("crs", "")).strip_edges()
	var srs := epsg(crs)
	var srs_rows: Array = [
		[-1, ["Undefined cartesian SRS", null, "NONE", -1, "undefined", "undefined cartesian coordinate reference system"]],
		[0, ["Undefined geographic SRS", null, "NONE", 0, "undefined", "undefined geographic coordinate reference system"]],
		[4326, ["WGS 84 geodetic", null, "EPSG", 4326, WKT_4326, "longitude/latitude coordinates in decimal degrees on the WGS 84 spheroid"]],
	]
	if srs > 0 and srs != 4326:
		srs_rows.append([srs, [crs, null, "EPSG", srs, "EPSG:%d" % srs, "SRC do projeto (definição pelo código EPSG)"]])
	var srs_id := srs if srs > 0 else -1

	# ---------------- feições
	var nodes := Net.node_map(proj)
	var lig := Net.ligacoes(proj)
	var rows: Dictionary = res.get("rows", {})
	var rnodes: Dictionary = res.get("nodes", {})
	var com_res := not rows.is_empty()
	var pv_rows: Array = []
	var bb := Rect2()
	var primeiro := true
	var fid := 0
	for n in proj["nodes"]:
		fid += 1
		var p := Net.pos(n)
		bb = Rect2(p, Vector2.ZERO) if primeiro else bb.expand(p)
		primeiro = false
		var tipo := str(n["tipo"])
		if rnodes.has(int(n["id"])):
			tipo = str(rnodes[int(n["id"])].get("tipo", tipo))
		pv_rows.append([fid, [null, _geom_ponto(srs_id, p), str(n["nome"]), tipo, float(n["ct"]), 1 if bool(n.get("ct_ok", true)) else 0,
			float(n.get("qp_i", 0.0)), float(n.get("qp_f", 0.0)), lig["inc"].get(int(n["id"]), []).size(),
			1 if not lig["out"].get(int(n["id"]), []).is_empty() else 0]])
	var tr_rows: Array = []
	fid = 0
	for t in proj["trechos"]:
		var a = nodes.get(int(t["ni"]))
		var b = nodes.get(int(t["nf"]))
		if a == null or b == null:
			continue
		fid += 1
		var r: Dictionary = rows.get(int(t["id"]), {})
		var vals: Array = [null, _geom_linha(srs_id, [Net.pos(a), Net.pos(b)]), str(t["nome"]), str(t.get("coletor", "")),
			str(a["nome"]), str(b["nome"]), Net.comprimento(nodes, t), str(t.get("material", "")), str(t.get("superficie", "")),
			str(t.get("escoramento", "")), str(t.get("situacao", ""))]
		if com_res:
			for k in ["d", "i", "cc_m", "cc_j", "pvala_m", "pvala_j", "qj_i", "qj_f", "yd_f", "v_f", "sigma"]:
				vals.append(float(r[k]) if r.has(k) else null)
			vals.append(int(r.get("status", 0)) if not r.is_empty() else null)
		tr_rows.append([fid, vals])
	if primeiro:
		bb = Rect2()

	var sql_pvs := "CREATE TABLE pvs (fid INTEGER PRIMARY KEY, geom POINT, nome TEXT, tipo TEXT, cota_terreno DOUBLE, cota_confirmada INTEGER, qp_ini DOUBLE, qp_fim DOUBLE, entradas INTEGER, tem_saida INTEGER)"
	var sql_tr := "CREATE TABLE trechos (fid INTEGER PRIMARY KEY, geom LINESTRING, nome TEXT, coletor TEXT, no_ini TEXT, no_fim TEXT, extensao DOUBLE, material TEXT, superficie TEXT, escoramento TEXT, situacao TEXT"
	if com_res:
		sql_tr += ", diametro_mm DOUBLE, declividade DOUBLE, cota_col_mon DOUBLE, cota_col_jus DOUBLE, prof_vala_mon DOUBLE, prof_vala_jus DOUBLE, q_jus_ini DOUBLE, q_jus_fim DOUBLE, y_d_fim DOUBLE, v_fim DOUBLE, tensao_trativa DOUBLE, situacao_calculo INTEGER"
	sql_tr += ")"

	var agora := Time.get_datetime_string_from_system(true) + ".000Z"
	var desc := str(proj.get("info", {}).get("projeto", ""))
	var contents := [
		[1, ["pvs", "features", "pvs", "Nós (PVs, TLs, ...) - " + desc, agora, bb.position.x, bb.position.y, bb.end.x, bb.end.y, srs_id]],
		[2, ["trechos", "features", "trechos", "Trechos da rede - " + desc, agora, bb.position.x, bb.position.y, bb.end.x, bb.end.y, srs_id]],
	]
	var geomcols := [[1, ["pvs", "geom", "POINT", srs_id, 0, 0]], [2, ["trechos", "geom", "LINESTRING", srs_id, 0, 0]]]

	# ---------------- árvores
	var master: Array = []
	master.append(["table", "gpkg_spatial_ref_sys", "gpkg_spatial_ref_sys", _arvore_tabela(_recs(srs_rows)), SQL_SRS])
	master.append(["table", "gpkg_contents", "gpkg_contents", _arvore_tabela(_recs(contents)), SQL_CONTENTS])
	master.append(["index", "sqlite_autoindex_gpkg_contents_1", "gpkg_contents", _indice(contents, [0]), null])
	master.append(["index", "sqlite_autoindex_gpkg_contents_2", "gpkg_contents", _indice(contents, [2]), null])
	master.append(["table", "gpkg_geometry_columns", "gpkg_geometry_columns", _arvore_tabela(_recs(geomcols)), SQL_GEOMCOLS])
	master.append(["index", "sqlite_autoindex_gpkg_geometry_columns_1", "gpkg_geometry_columns", _indice(geomcols, [0, 1]), null])
	master.append(["index", "sqlite_autoindex_gpkg_geometry_columns_2", "gpkg_geometry_columns", _indice(geomcols, [0]), null])
	master.append(["table", "pvs", "pvs", _arvore_tabela(_recs(pv_rows)), sql_pvs])
	master.append(["table", "trechos", "trechos", _arvore_tabela(_recs(tr_rows)), sql_tr])
	var cels: Array = []
	for k in master.size():
		cels.append(_celula_tabela(k + 1, _registro(master[k])))
	var p1 := _pagina(0x0D, cels, 100)
	if p1.is_empty():
		push_error("GeoPackage: esquema não coube na página 1")
		return PackedByteArray()
	_cabecalho(p1)
	pages[0] = p1
	var out := PackedByteArray()
	for pg in pages:
		out.append_array(pg)
	return out


func _recs(linhas: Array) -> Array:
	var out: Array = []
	for l in linhas:
		out.append([int(l[0]), _registro(l[1])])
	return out


# ------------------------------------------------------------------ geometria (GeoPackageBinary + WKB)

static func _le_i32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_s32(0, v)
	return b


static func _le_u32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b


static func _le_f64(v: float) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, v)
	return b


static func _geom_ponto(srs: int, p: Vector2) -> PackedByteArray:
	var b := PackedByteArray([0x47, 0x50, 0, 0x01]) # "GP", versão 0, little endian, sem envelope
	b.append_array(_le_i32(srs))
	b.append(1)
	b.append_array(_le_u32(1)) # Point
	b.append_array(_le_f64(p.x))
	b.append_array(_le_f64(p.y))
	return b


static func _geom_linha(srs: int, pts: Array) -> PackedByteArray:
	var b := PackedByteArray([0x47, 0x50, 0, 0x03]) # little endian + envelope [minx, maxx, miny, maxy]
	b.append_array(_le_i32(srs))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	for v in [r.position.x, r.end.x, r.position.y, r.end.y]:
		b.append_array(_le_f64(v))
	b.append(1)
	b.append_array(_le_u32(2)) # LineString
	b.append_array(_le_u32(pts.size()))
	for p in pts:
		b.append_array(_le_f64(p.x))
		b.append_array(_le_f64(p.y))
	return b


# ------------------------------------------------------------------ formato SQLite

static func _be(buf: PackedByteArray, ofs: int, v: int, n: int) -> void:
	for k in n:
		buf[ofs + k] = (v >> (8 * (n - 1 - k))) & 0xFF


## Inteiro de tamanho variável do SQLite (1 a 9 bytes, big-endian, 7 bits por byte).
static func _varint(v: int) -> PackedByteArray:
	if v < 0 or v >= (1 << 56):
		var b9 := PackedByteArray()
		b9.resize(9)
		b9[8] = v & 0xFF
		var x := v >> 8
		for k in range(7, -1, -1):
			b9[k] = (x & 0x7F) | 0x80
			x = x >> 7
		return b9
	var grupos: Array = [v & 0x7F]
	var y := v >> 7
	while y > 0:
		grupos.push_front((y & 0x7F) | 0x80)
		y = y >> 7
	return PackedByteArray(grupos)


## Registro (record format): cabeçalho com os tipos seriais + corpo.
static func _registro(vals: Array) -> PackedByteArray:
	var tipos := PackedByteArray()
	var corpo := PackedByteArray()
	for v in vals:
		if v == null:
			tipos.append_array(_varint(0))
		elif v is bool or v is int:
			var i := int(v)
			if i == 0:
				tipos.append_array(_varint(8))
			elif i == 1:
				tipos.append_array(_varint(9))
			else:
				var tam := [[1, 1, 7], [2, 2, 15], [3, 3, 23], [4, 4, 31], [5, 6, 47], [6, 8, 63]]
				for t in tam:
					var lim: int = 1 << int(t[2])
					if i >= -lim and i < lim:
						tipos.append_array(_varint(int(t[0])))
						var bb := PackedByteArray()
						bb.resize(int(t[1]))
						_be(bb, 0, i, int(t[1]))
						corpo.append_array(bb)
						break
		elif v is float:
			tipos.append_array(_varint(7))
			var d := PackedByteArray()
			d.resize(8)
			d.encode_double(0, v)
			d.reverse()
			corpo.append_array(d)
		elif v is PackedByteArray:
			tipos.append_array(_varint(12 + 2 * v.size()))
			corpo.append_array(v)
		else:
			var s: PackedByteArray = str(v).to_utf8_buffer()
			tipos.append_array(_varint(13 + 2 * s.size()))
			corpo.append_array(s)
	var hs := tipos.size() + 1
	while _varint(hs).size() + tipos.size() != hs:
		hs = _varint(hs).size() + tipos.size()
	var out := _varint(hs)
	out.append_array(tipos)
	out.append_array(corpo)
	return out


func _alocar(pg: PackedByteArray) -> int:
	pages.append(pg)
	return pages.size()


## Célula de folha de tabela, com páginas de transbordo quando o registro não cabe.
func _celula_tabela(rowid: int, rec: PackedByteArray) -> PackedByteArray:
	var u := PAGE
	var p := rec.size()
	var x := u - 35
	var cel := _varint(p)
	cel.append_array(_varint(rowid))
	if p <= x:
		cel.append_array(rec)
		return cel
	@warning_ignore("integer_division")
	var m := ((u - 12) * 32 / 255) - 23
	var k := m + ((p - m) % (u - 4))
	var local := k if k <= x else m
	cel.append_array(rec.slice(0, local))
	var ptr := PackedByteArray()
	ptr.resize(4)
	_be(ptr, 0, _transbordo(rec.slice(local)), 4)
	cel.append_array(ptr)
	return cel


func _transbordo(resto: PackedByteArray) -> int:
	var cap := PAGE - 4
	@warning_ignore("integer_division")
	var n := (resto.size() + cap - 1) / cap
	var nums: Array = []
	for k in n:
		nums.append(_alocar(PackedByteArray()))
	for k in n:
		var pg := PackedByteArray()
		pg.resize(4)
		_be(pg, 0, int(nums[k + 1]) if k + 1 < n else 0, 4)
		pg.append_array(resto.slice(k * cap, mini((k + 1) * cap, resto.size())))
		pg.resize(PAGE)
		pages[int(nums[k]) - 1] = pg
	return int(nums[0])


## Monta uma página de árvore B. Retorna vazio se as células não couberem.
func _pagina(tipo: int, celulas: Array, inicio := 0, direita := 0) -> PackedByteArray:
	var hdr := 12 if tipo == 0x05 or tipo == 0x02 else 8
	var total := inicio + hdr
	for c in celulas:
		total += c.size() + 2
	if total > PAGE:
		return PackedByteArray()
	var pg := PackedByteArray()
	pg.resize(PAGE)
	var fim := PAGE
	var ptrs: Array = []
	for c in celulas:
		fim -= c.size()
		for j in c.size():
			pg[fim + j] = c[j]
		ptrs.append(fim)
	pg[inicio] = tipo
	_be(pg, inicio + 3, celulas.size(), 2)
	_be(pg, inicio + 5, fim, 2)
	if hdr == 12:
		_be(pg, inicio + 8, direita, 4)
	for k in ptrs.size():
		_be(pg, inicio + hdr + 2 * k, int(ptrs[k]), 2)
	return pg


## Árvore B de tabela a partir de [[rowid, registro]] em ordem crescente de rowid. Retorna a raiz.
func _arvore_tabela(linhas: Array) -> int:
	var folhas: Array = [] # [página, maior rowid]
	var atuais: Array = []
	var uso := 0
	var maxid := 0
	var livre := PAGE - 8
	for l in linhas:
		var cel := _celula_tabela(int(l[0]), l[1])
		if uso + cel.size() + 2 > livre and not atuais.is_empty():
			folhas.append([_alocar(_pagina(0x0D, atuais)), maxid])
			atuais = []
			uso = 0
		atuais.append(cel)
		uso += cel.size() + 2
		maxid = int(l[0])
	folhas.append([_alocar(_pagina(0x0D, atuais)), maxid])
	var nivel := folhas
	@warning_ignore("integer_division")
	var cap := (PAGE - 12) / (4 + 9 + 2)
	while nivel.size() > 1:
		@warning_ignore("integer_division")
		var grupos := (nivel.size() + cap - 1) / cap
		var prox: Array = []
		var ini := 0
		for g in grupos:
			@warning_ignore("integer_division")
			var fim := (nivel.size() * (g + 1)) / grupos
			var filhos := nivel.slice(ini, fim)
			var cels: Array = []
			for f in filhos.slice(0, filhos.size() - 1):
				var c := PackedByteArray()
				c.resize(4)
				_be(c, 0, int(f[0]), 4)
				c.append_array(_varint(int(f[1])))
				cels.append(c)
			var ult: Array = filhos[filhos.size() - 1]
			prox.append([_alocar(_pagina(0x05, cels, 0, int(ult[0]))), int(ult[1])])
			ini = fim
		nivel = prox
	return int(nivel[0][0])


## Índice automático (UNIQUE / PRIMARY KEY em coluna de texto): uma folha com (chave..., rowid).
func _indice(linhas: Array, colunas: Array) -> int:
	var ents: Array = []
	for l in linhas:
		var chave: Array = []
		for c in colunas:
			chave.append(l[1][int(c)])
		chave.append(int(l[0]))
		ents.append(chave)
	ents.sort_custom(func(a, b):
		for k in a.size():
			if str(a[k]) != str(b[k]):
				return (a[k] < b[k]) if (a[k] is int and b[k] is int) else str(a[k]) < str(b[k])
		return false)
	var cels: Array = []
	for e in ents:
		var rec := _registro(e)
		var c := _varint(rec.size())
		c.append_array(rec)
		cels.append(c)
	return _alocar(_pagina(0x0A, cels))


func _cabecalho(p1: PackedByteArray) -> void:
	var magic := "SQLite format 3".to_ascii_buffer()
	for k in magic.size():
		p1[k] = magic[k]
	p1[15] = 0
	_be(p1, 16, PAGE, 2)
	p1[18] = 1
	p1[19] = 1
	p1[20] = 0
	p1[21] = 64
	p1[22] = 32
	p1[23] = 32
	_be(p1, 24, 1, 4) # contador de alterações
	_be(p1, 28, pages.size(), 4) # tamanho em páginas
	_be(p1, 40, 1, 4) # schema cookie
	_be(p1, 44, 4, 4) # formato do esquema
	_be(p1, 56, 1, 4) # UTF-8
	_be(p1, 60, USER_VERSION, 4)
	_be(p1, 68, APP_ID, 4)
	_be(p1, 92, 1, 4) # version-valid-for = contador
	_be(p1, 96, 3045000, 4)
