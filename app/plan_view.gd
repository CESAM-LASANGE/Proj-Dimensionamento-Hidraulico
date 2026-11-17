extends Control
## Área de trabalho (planta): grade de coordenadas N/E, topografia, ruas,
## pontos cotados, imagem de fundo e o traçado da rede.
##
## Mouse (manual 1.5.1):
##   Botão 2 na área vazia ......... inicia / finaliza o traçado
##   Botão 1 durante o traçado ...... cria nós intermediários (ou liga a um nó existente)
##   Botão 1 + arrastar sobre nó .... move o nó
##   Botão 2 sobre nó / trecho ...... propriedades
##   Shift + botão 1 sobre nó ....... continua o traçado a partir do nó
##   Shift + botão 1 sobre trecho ... marca o coletor inteiro
##   Ctrl + botão 1 sobre trecho .... marca / desmarca o trecho
##   Ctrl + botão 2 sobre nó ........ mostra o nome do coletor
##   Botão 1 + arrastar na área vazia  caixa de seleção (seleciona o que estiver inteiro dentro)
##   Ctrl + caixa / Ctrl + clique ... soma à seleção / alterna nó ou trecho
##   Botão 1 sobre nó ou trecho ..... seleciona só ele
##   Del ............................ apaga a seleção (com confirmação)
##   F9 ORTO ........................ trecho/arrasto só na horizontal ou na vertical
##   F10 OSNAP ...................... magnetismo: PV, ponto cotado, vértice de rua, curva de nível, rua
##   Roda / botão do meio ........... zoom / deslocar

const Net = preload("res://net.gd")
const Geo = preload("res://geo.gd")

const CORES_CAMADA := [Color(0.0, 0.55, 0.85), Color(0.15, 0.6, 0.25), Color(0.75, 0.3, 0.75), Color(0.85, 0.5, 0.0), Color(0.45, 0.45, 0.45)]

signal cursor_moved(e: float, n: float, z: float, dist: float)

var main
var marked := {} # trechos selecionados (id → true)
var sel_nos := {} # nós selecionados (id → true)
var mode := "" # "", "pan", "janela"

var scale_px := 1.0
var center := Vector2.ZERO
var hist: Array = []

var tracing := false
var trace_from := -1
var trace_col := ""
var drag_node := -1
var drag_moved := false
var panning := false
var pan_last := Vector2.ZERO
var win_on := false
var win_a := Vector2.ZERO
var box_on := false
var box_a := Vector2.ZERO
var box_somar := false
## Magnetismo (osnap): raio de captura em pixels.
const OSNAP_PX := 12.0
var snap := {} # alvo do osnap sob o cursor ({} = nenhum)
var cursor_w := Vector2.ZERO # posição efetiva do cursor (com osnap / orto), em metros
var cursor_orto := false
var previa := {} # prévia da cota do próximo PV: raio de busca, retas, cota
var drag_origem := Vector2.ZERO
var drag_snap := {}
var mouse_s := Vector2.ZERO
var rastro := {}
var destaque := Vector2(NAN, NAN)
var bg_tex: Texture2D
var bg_path := ""

var base: Control
var over: Control
var _font: Font


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	base = Control.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.draw.connect(_draw_base)
	add_child(base)
	over = Control.new()
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.draw.connect(_draw_over)
	add_child(over)
	resized.connect(redesenhar)


func redesenhar() -> void:
	if base:
		base.queue_redraw()
		over.queue_redraw()


# ------------------------------------------------------------------ coordenadas

func w2s(w: Vector2) -> Vector2:
	return size / 2.0 + Vector2((w.x - center.x) * scale_px, -(w.y - center.y) * scale_px)


func s2w(s: Vector2) -> Vector2:
	return Vector2(center.x + (s.x - size.x / 2.0) / scale_px, center.y - (s.y - size.y / 2.0) / scale_px)


func _push_hist() -> void:
	hist.append([center, scale_px])
	if hist.size() > 30:
		hist.pop_front()


func zoom(f: float, at_s := Vector2(NAN, NAN)) -> void:
	_push_hist()
	if is_nan(at_s.x):
		at_s = size / 2.0
	var w := s2w(at_s)
	scale_px = clampf(scale_px * f, 0.0005, 2000.0)
	var w2 := s2w(at_s)
	center += w - w2
	redesenhar()


func ultimo_zoom() -> void:
	if hist.is_empty():
		return
	var h: Array = hist.pop_back()
	center = h[0]
	scale_px = h[1]
	redesenhar()


func ajustar(r: Rect2, guardar := true) -> void:
	if r.size.x <= 0.0 and r.size.y <= 0.0:
		r = r.grow(50.0)
	if guardar:
		_push_hist()
	r = r.grow(maxf(r.size.x, r.size.y) * 0.04 + 1.0)
	var sz := size if size.x > 10 else Vector2(1200, 700)
	scale_px = minf(sz.x / maxf(r.size.x, 1e-3), sz.y / maxf(r.size.y, 1e-3))
	center = r.get_center()
	redesenhar()


func area_rect() -> Rect2:
	var a: Dictionary = main.proj["area"]
	return Rect2(float(a["e0"]), float(a["n0"]), float(a["le"]), float(a["ln"]))


func sem_zoom() -> void:
	ajustar(area_rect())


func ajuste_maximo() -> void:
	var r := Rect2()
	var first := true
	for n in main.proj["nodes"]:
		var p := Net.pos(n)
		if first:
			r = Rect2(p, Vector2.ZERO)
			first = false
		else:
			r = r.expand(p)
	if not main.topo.vazio():
		var te: Rect2 = main.topo.extents()
		r = te if first else r.merge(te)
		first = false
	if first:
		r = area_rect()
	ajustar(r)


func centralizar(w: Vector2) -> void:
	_push_hist()
	center = w
	destaque = w
	redesenhar()


# ------------------------------------------------------------------ imagem de fundo

func set_imagem(path: String) -> void:
	if path == bg_path:
		return
	bg_path = path
	bg_tex = null
	if path != "" and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			bg_tex = ImageTexture.create_from_image(img)
	redesenhar()


# ------------------------------------------------------------------ desenho

func _cor(nome: String, padrao: Color) -> Color:
	var v = main.opts.get(nome, null)
	if v is Color:
		return v
	if v is String and v != "":
		return Color(v)
	return padrao


func _draw_base() -> void:
	_font = get_theme_default_font()
	var c := base
	var opts: Dictionary = main.opts
	var pal: Dictionary = main.pal
	c.draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	var vis := Rect2(s2w(Vector2(0, size.y)), Vector2(size.x, size.y) / scale_px)
	var area := area_rect()
	# imagem de fundo esticada na área de trabalho
	if bg_tex != null and bool(opts.get("mostra_imagem", true)):
		var a0 := w2s(Vector2(area.position.x, area.end.y))
		var a1 := w2s(Vector2(area.end.x, area.position.y))
		c.draw_texture_rect(bg_tex, Rect2(a0, a1 - a0), false)
	# grade de coordenadas
	if bool(opts.get("mostra_grid", true)):
		var g := float(main.proj["area"]["grid"])
		if g > 0.0 and g * scale_px >= 6.0:
			var gc := Color(0.82, 0.84, 0.87)
			var x := ceilf(maxf(vis.position.x, area.position.x) / g) * g
			while x <= minf(vis.end.x, area.end.x):
				c.draw_line(w2s(Vector2(x, area.position.y)), w2s(Vector2(x, area.end.y)), gc, 1.0)
				x += g
			var y := ceilf(maxf(vis.position.y, area.position.y) / g) * g
			while y <= minf(vis.end.y, area.end.y):
				c.draw_line(w2s(Vector2(area.position.x, y)), w2s(Vector2(area.end.x, y)), gc, 1.0)
				y += g
		var a0 := w2s(Vector2(area.position.x, area.end.y))
		var a1 := w2s(Vector2(area.end.x, area.position.y))
		c.draw_rect(Rect2(a0, a1 - a0), Color(0.55, 0.58, 0.62), false, 1.0)
	_draw_topo(c, vis)
	_draw_cadastro(c)
	_draw_rede(c, vis, pal)


func _draw_topo(c: Control, vis: Rect2) -> void:
	var opts: Dictionary = main.opts
	var topo = main.topo
	var modo := int(opts.get("topo_desenho", 0))
	if modo != 2:
		var cp := _cor("cor_principal", Color(0.93, 0.45, 0.25))
		var cs := _cor("cor_secundaria", Color(0.98, 0.85, 0.35))
		var leg := bool(opts.get("topo_legenda", true))
		var leg_int := float(opts.get("topo_leg_int", 5.0))
		var passo := 3 if modo == 1 else 1
		for cv in topo.curvas:
			var bb: Rect2 = cv["bb"]
			if not bb.intersects(vis, true):
				continue
			var z := float(cv["z"])
			var principal := fmod(absf(z) + 1e-4, 5.0) < 1e-3
			var pts: PackedVector2Array = cv["pts"]
			var sp := PackedVector2Array()
			var k := 0
			while k < pts.size():
				sp.append(w2s(pts[k]))
				k += passo
			if (pts.size() - 1) % passo != 0:
				sp.append(w2s(pts[pts.size() - 1]))
			if sp.size() >= 2:
				c.draw_polyline(sp, cp if principal else cs, 1.4 if principal else 1.0)
			if leg and pts.size() >= 2 and scale_px > 0.25:
				if fmod(absf(z) + 1e-4, leg_int) < 1e-3:
					var pm := w2s(pts[pts.size() / 2])
					c.draw_string(_font, pm + Vector2(2, -2), _z(z), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cp.darkened(0.25))
		if bool(opts.get("topo_texto", false)):
			for t in topo.textos:
				if vis.has_point(t["p"]):
					c.draw_string(_font, w2s(t["p"]), str(t["s"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.4, 0.4))
	if bool(opts.get("ruas_desenho", true)):
		var cr := _cor("cor_ruas", Color(0.2, 0.62, 0.72))
		for rua in topo.ruas:
			var sp := PackedVector2Array()
			for p in rua:
				sp.append(w2s(p))
			if sp.size() >= 2:
				c.draw_polyline(sp, cr, 1.0)
	if bool(opts.get("pontos_desenho", true)) and topo.pontos.size() > 0:
		var cpt := _cor("cor_pontos", Color(0.15, 0.45, 0.75))
		var val := bool(opts.get("pontos_valor", true)) and scale_px > 0.6
		for p in topo.pontos:
			var w := Vector2(p.x, p.y)
			if not vis.has_point(w):
				continue
			var s := w2s(w)
			c.draw_line(s - Vector2(4, 0), s + Vector2(4, 0), cpt, 1.0)
			c.draw_line(s - Vector2(0, 4), s + Vector2(0, 4), cpt, 1.0)
			if val:
				c.draw_string(_font, s + Vector2(4, -3), _z(p.z), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cpt)


## Bacias (contorno verde), interferências (tracejado por camada) e ligações (quadradinhos).
func _draw_cadastro(c: Control) -> void:
	for b in main.proj.get("bacias", []):
		var pts := PackedVector2Array()
		for v in b.get("poligono", []):
			pts.append(w2s(Vector2(float(v[0]), float(v[1]))))
		if pts.size() >= 3:
			pts.append(pts[0])
			c.draw_polyline(pts, Color(0.2, 0.6, 0.3, 0.9), 2.0 if str(b.get("pai", "")) == "" else 1.2)
			c.draw_string(_font, pts[0] + Vector2(4, 14), "Bacia %s" % str(b.get("id", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.45, 0.2))
	var interf: Dictionary = main.proj.get("interferencias", {})
	var camadas: Array = interf.get("camadas", [])
	for f in interf.get("feicoes", []):
		var cor: Color = CORES_CAMADA[maxi(camadas.find(str(f["camada"])), 0) % CORES_CAMADA.size()]
		for linha in Geo.linhas(f):
			if linha.size() == 1:
				c.draw_circle(w2s(linha[0]), 3.5, cor)
				continue
			for k in linha.size() - 1:
				c.draw_dashed_line(w2s(linha[k]), w2s(linha[k + 1]), cor, 2.0, 8.0)
			if linha.size() >= 2:
				c.draw_string(_font, w2s(linha[0]) + Vector2(4, -4), "%s %s" % [f["camada"], f["id"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cor)
	for r in main.proj.get("ligacoes", []):
		if is_nan(float(r["e"])) or is_nan(float(r["n"])):
			continue
		var p := w2s(Vector2(float(r["e"]), float(r["n"])))
		var cor := Color(0.2, 0.5, 0.2) if bool(r["valido"]) else Color(0.85, 0.15, 0.15)
		c.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), cor, false, 1.5)


func _z(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.2f" % v).replace(".", ",")


## Texto do rótulo vermelho do trecho: com resultado, "ø  L m  I=…"; sem resultado,
## só a extensão ("45,32 m").
func rotulo_trecho(t: Dictionary, r, nodes: Dictionary) -> String:
	if r != null:
		return "ø%d  %s m  I=%s" % [int(r["d"]), main.fmt(r["L"], 1), main.fmt(r["i"], 4)]
	return "%s m" % main.fmt(Net.comprimento(nodes, t), 2)


func _draw_rede(c: Control, _vis: Rect2, pal: Dictionary) -> void:
	var opts: Dictionary = main.opts
	var nodes := Net.node_map(main.proj)
	var res: Dictionary = main.results
	var valido: bool = main.resultados_validos
	var lw := float(opts.get("espessura", 2.0))
	var azul := Color(0.12, 0.25, 0.75)
	var verm := Color(0.85, 0.1, 0.1)
	var rot_tr := bool(opts.get("rotulo_trecho", true))
	# rótulo vermelho do trecho: resultado (ø, L, I) depois de dimensionar; antes disso,
	# só a extensão, logo depois de traçar (fase 8, SPEC-8.08)
	var rot_res := bool(opts.get("rotulo_resultado", true))
	for t in main.proj["trechos"]:
		var a = nodes.get(int(t["ni"]))
		var b = nodes.get(int(t["nf"]))
		if a == null or b == null:
			continue
		var sa := w2s(Net.pos(a))
		var sb := w2s(Net.pos(b))
		var mk := marked.has(int(t["id"]))
		var col := verm if mk else azul
		var r = res.get("rows", {}).get(int(t["id"])) if valido else null
		c.draw_line(sa, sb, col, lw, true)
		var mid := (sa + sb) / 2.0
		var dir := (sb - sa).normalized() if sa.distance_to(sb) > 0.1 else Vector2.RIGHT
		# caixa de indicação de sentido (clique aqui para o trecho)
		var box := Rect2(mid - Vector2(7, 6), Vector2(14, 12))
		c.draw_rect(box, Color.WHITE)
		var bcol := verm if mk else (Color(0.85, 0.45, 0.0) if r != null and int(r["status"]) > 0 else col)
		c.draw_rect(box, bcol, false, 1.2)
		var tip := mid + dir * 5.0
		var tail := mid - dir * 4.0
		var nrm := Vector2(-dir.y, dir.x)
		c.draw_line(tail, tip, bcol, 1.5)
		c.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 3.5 + nrm * 2.5, tip - dir * 3.5 - nrm * 2.5]), bcol)
		if rot_tr:
			c.draw_string(_font, mid + Vector2(8, -6), str(t["nome"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.05, 0.2))
		if rot_res:
			var txt := rotulo_trecho(t, r, nodes)
			var tsz := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			if r != null and sa.distance_to(sb) <= tsz.x + 40.0:
				txt = "ø%d  %s" % [int(r["d"]), main.fmt(r["i"], 4)]
				tsz = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			if sa.distance_to(sb) > tsz.x + 24.0:
				var ang := dir.angle()
				if cos(ang) < -1e-3 or (absf(cos(ang)) <= 1e-3 and sin(ang) < 0.0):
					ang += PI
				var leitura := Vector2(cos(ang), sin(ang))
				var lado_n := Vector2(-dir.y, dir.x)
				if lado_n.x > 1e-3 or (absf(lado_n.x) <= 1e-3 and lado_n.y < 0.0):
					lado_n = -lado_n
				var centro := mid + lado_n * 13.0
				c.draw_set_transform(centro, ang, Vector2.ONE)
				var base_y := 4.0 if lado_n.dot(Vector2(-leitura.y, leitura.x)) > 0.0 else 4.0
				c.draw_string(_font, Vector2(-tsz.x / 2.0, base_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.12, 0.12))
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var rot_no := bool(opts.get("rotulo_no", true))
	var res_nodes: Dictionary = res.get("nodes", {}) if valido else {}
	for n in main.proj["nodes"]:
		var s := w2s(Net.pos(n))
		if s.x < -40 or s.y < -40 or s.x > size.x + 40 or s.y > size.y + 40:
			continue
		var tipo := str(n["tipo"])
		if res_nodes.has(int(n["id"])):
			tipo = str(res_nodes[int(n["id"])]["tipo"])
		_simbolo(c, s, tipo, azul)
		if sel_nos.has(int(n["id"])):
			c.draw_rect(Rect2(s - Vector2(9, 9), Vector2(18, 18)), verm, false, 1.6)
		if rot_no:
			c.draw_string(_font, s + Vector2(7, -5), str(n["nome"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.05, 0.25))
			c.draw_string(_font, s + Vector2(7, 9), main.fmt(n["ct"], 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.1, 0.5, 0.75))
		if not bool(n.get("ct_ok", true)):
			c.draw_line(s + Vector2(-7, -7), s + Vector2(7, 7), verm, 2.5)
			c.draw_line(s + Vector2(-7, 7), s + Vector2(7, -7), verm, 2.5)


func _simbolo(c: Control, s: Vector2, tipo: String, col: Color) -> void:
	var r := 5.0
	match tipo:
		"CP":
			c.draw_rect(Rect2(s - Vector2(r, r), Vector2(r, r) * 2), Color.WHITE)
			c.draw_rect(Rect2(s - Vector2(r, r), Vector2(r, r) * 2), col, false, 1.4)
			c.draw_line(s - Vector2(r, r), s + Vector2(r, r), col, 1.0)
			c.draw_line(s + Vector2(-r, r), s + Vector2(r, -r), col, 1.0)
		"PI":
			c.draw_circle(s, r, Color.WHITE)
			c.draw_arc(s, r, 0, TAU, 20, col, 1.4)
			var k := r * 0.7
			c.draw_line(s - Vector2(k, k), s + Vector2(k, k), col, 1.0)
			c.draw_line(s + Vector2(-k, k), s + Vector2(k, -k), col, 1.0)
		"TL":
			c.draw_circle(s, 3.5, col)
		"TQ", "TT":
			c.draw_circle(s, r, Color.WHITE)
			c.draw_arc(s, r, 0, TAU, 20, col, 1.4)
			var pts := PackedVector2Array([s])
			for k in 11:
				var a := -PI / 2.0 + PI * k / 10.0
				pts.append(s + Vector2(cos(a), sin(a)) * r)
			c.draw_colored_polygon(pts, col)
		"TR":
			c.draw_circle(s, r, Color.WHITE)
			c.draw_arc(s, r, 0, TAU, 20, col, 1.4)
			c.draw_circle(s, 1.6, col)
		"TP":
			# TIL de passagem: círculo com anel interno
			c.draw_circle(s, r, Color.WHITE)
			c.draw_arc(s, r, 0, TAU, 20, col, 1.4)
			c.draw_arc(s, r * 0.5, 0, TAU, 14, col, 1.2)
		_:
			c.draw_circle(s, r, Color.WHITE)
			c.draw_arc(s, r, 0, TAU, 20, col, 1.4)


func _draw_over() -> void:
	if _font == null:
		_font = get_theme_default_font()
	var c := over
	_draw_previa(c)
	if bool(main.opts.get("rastro", true)) and not rastro.is_empty() and (previa.is_empty() or not (tracing or drag_node >= 0)):
		for rr in rastro.get("raios", []):
			c.draw_line(w2s(rr[0]), w2s(rr[1]), Color(0.5, 0.5, 0.5, 0.6), 1.0)
		var par: Array = rastro.get("par", [])
		if par.size() == 2:
			c.draw_line(w2s(par[0]), w2s(par[1]), Color(0.85, 0.0, 0.85), 2.0)
	if tracing and trace_from >= 0:
		var n = Net.node_map(main.proj).get(trace_from)
		if n != null:
			var a := w2s(Net.pos(n))
			var fim := w2s(cursor_w)
			var dist := Net.pos(n).distance_to(cursor_w)
			var longe := dist > float(main.proj["params"]["dist_max_pv"])
			var col := Color(0.9, 0.1, 0.1) if longe else Color(0.1, 0.3, 0.9)
			c.draw_dashed_line(a, fim, col, 1.5, 6.0)
			c.draw_string(_font, fim + Vector2(12, 46 if not snap.is_empty() else 18), "%s m%s%s" % [main.fmt(dist, 2), "  ORTO" if cursor_orto else "",
				"  > dist. máx. entre PVs!" if longe else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	if tracing and trace_from >= 0:
		var alvo := hit_no(mouse_s)
		if alvo >= 0 and alvo != trace_from:
			var r := Net.pode_ligar(main.proj, trace_from, alvo)
			if not bool(r["ok"]):
				var sa := w2s(Net.pos(Net.node_map(main.proj)[alvo]))
				var curto: String = {"sem_saida": "PV sem saída: ligação não permitida", "max_entradas": "PV já tem %d entradas" % Net.MAX_ENTRADAS,
					"laco": "formaria um laço"}.get(str(r["regra"]), "ligação não permitida")
				c.draw_arc(sa, 11, 0, TAU, 28, Color(0.9, 0.1, 0.1), 2.5)
				c.draw_string(_font, sa + Vector2(14, -12), curto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.1, 0.1))
	if box_on:
		var rb := Rect2(box_a, mouse_s - box_a).abs()
		var cb := Color(0.1, 0.1, 0.1)
		c.draw_rect(rb, Color(0.2, 0.45, 0.95, 0.07))
		for seg in [[rb.position, Vector2(rb.end.x, rb.position.y)], [Vector2(rb.end.x, rb.position.y), rb.end],
				[rb.end, Vector2(rb.position.x, rb.end.y)], [Vector2(rb.position.x, rb.end.y), rb.position]]:
			c.draw_dashed_line(seg[0], seg[1], cb, 1.0, 4.0)
	_draw_snap(c)
	if win_on:
		c.draw_rect(Rect2(win_a, mouse_s - win_a).abs(), Color(0.1, 0.4, 0.9), false, 1.0)
		c.draw_rect(Rect2(win_a, mouse_s - win_a).abs(), Color(0.1, 0.4, 0.9, 0.08))
	if not is_nan(destaque.x):
		c.draw_arc(w2s(destaque), 22, 0, TAU, 40, Color(0.9, 0.0, 0.8), 3.0)


## Raio de busca e retas da interpolação em volta do ponto onde o próximo PV vai ficar.
func _draw_previa(c: Control) -> void:
	if previa.is_empty() or not (tracing or drag_node >= 0) or not bool(main.opts.get("rastro", true)):
		return
	var cs := w2s(previa["w"])
	var azul := Color(0.15, 0.45, 0.85)
	var rpx := float(previa.get("raio", 0.0)) * scale_px
	if rpx > 6.0 and rpx < 20000.0:
		c.draw_circle(cs, rpx, Color(azul, 0.05))
		c.draw_arc(cs, rpx, 0, TAU, 128, Color(azul, 0.75), 1.2, true)
	for rr in previa.get("raios", []):
		c.draw_line(w2s(rr[0]), w2s(rr[1]), Color(0.45, 0.45, 0.45, 0.7), 1.0)
	var par: Array = previa.get("par", [])
	if par.size() == 2:
		c.draw_line(w2s(par[0]), w2s(par[1]), Color(0.85, 0.0, 0.85), 2.0)
	if previa.has("ponto"):
		c.draw_line(cs, w2s(previa["ponto"]), Color(0.85, 0.0, 0.85), 2.0)
	var txt := ""
	var cor := Color(0.1, 0.3, 0.7)
	if not bool(previa.get("ok", false)):
		txt = "Sem cota: nada no raio de %s m" % main.fmt(previa.get("raio", 0.0), 0)
		cor = Color(0.85, 0.1, 0.1)
	elif bool(previa.get("sobre_curva", false)):
		txt = "Z %s m — sobre a curva (sem interpolação)" % main.fmt(previa["z"], 2)
	elif str(previa.get("metodo", "")) == "ponto":
		txt = "Z %s m — ponto cotado" % main.fmt(previa["z"], 2)
	else:
		txt = "Z %s m — %s (raio %s m)" % [main.fmt(previa["z"], 2), "aproximada" if bool(previa.get("aprox", false)) else "interpolada", main.fmt(previa.get("raio", 0.0), 0)]
	c.draw_string(_font, cs + Vector2(12, -10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cor)


## Marcador do osnap (como nos programas de desenho): forma conforme o alvo + rótulo.
func _draw_snap(c: Control) -> void:
	if snap.is_empty():
		return
	var p := w2s(snap["w"])
	var cor := Color(0.0, 0.62, 0.2)
	var k := 7.0
	match str(snap["tipo"]):
		"no":
			c.draw_rect(Rect2(p - Vector2(k, k), Vector2(k, k) * 2.0), cor, false, 2.0)
		"pc":
			c.draw_polyline(PackedVector2Array([p + Vector2(0, -k), p + Vector2(k, 0), p + Vector2(0, k), p + Vector2(-k, 0), p + Vector2(0, -k)]), cor, 2.0)
			c.draw_line(p - Vector2(3, 3), p + Vector2(3, 3), cor, 1.5)
			c.draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), cor, 1.5)
		"vertice":
			c.draw_polyline(PackedVector2Array([p + Vector2(0, -k), p + Vector2(k, k * 0.8), p + Vector2(-k, k * 0.8), p + Vector2(0, -k)]), cor, 2.0)
		_:
			# "mais próximo" sobre a linha (ampulheta)
			c.draw_polyline(PackedVector2Array([p + Vector2(-k, -k), p + Vector2(k, -k), p + Vector2(-k, k), p + Vector2(k, k), p + Vector2(-k, -k)]), cor, 2.0)
	var rot := str(snap.get("rotulo", ""))
	if rot != "":
		var tam := _font.get_string_size(rot, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var bp := p + Vector2(10, 10)
		c.draw_rect(Rect2(bp, tam + Vector2(8, 4)), Color(1, 1, 0.85, 0.95))
		c.draw_rect(Rect2(bp, tam + Vector2(8, 4)), cor, false, 1.0)
		c.draw_string(_font, bp + Vector2(4, tam.y - 2), rot, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.1, 0.25, 0.1))


# ------------------------------------------------------------------ osnap / orto

func orto_ligado() -> bool:
	return bool(main.opts.get("orto", false))


func osnap_ligado() -> bool:
	return bool(main.opts.get("osnap", true))


## Alvo do magnetismo mais próximo do cursor, até OSNAP_PX pixels. Prioridade: PV, ponto
## cotado, vértice de rua; depois o ponto mais próximo sobre curva de nível ou rua.
## Retorna {} ou {w, tipo ("no" | "pc" | "vertice" | "curva" | "rua"), rotulo, nid, z, dist_px}.
func buscar_snap(s: Vector2, excluir := -1, nos := true) -> Dictionary:
	var w := s2w(s)
	var r := OSNAP_PX / scale_px
	var cand: Array = []
	for n in main.proj["nodes"]:
		if not nos or int(n["id"]) == excluir:
			continue
		var d := w2s(Net.pos(n)).distance_to(s)
		if d <= OSNAP_PX:
			cand.append({"w": Net.pos(n), "tipo": "no", "prio": 0, "dist_px": d, "nid": int(n["id"]),
				"rotulo": "%s %s" % [str(n["tipo"]), str(n["nome"])]})
	var topo = main.topo
	var opts: Dictionary = main.opts
	if bool(opts.get("pontos_desenho", true)) and topo.tem_pontos():
		var pp: Dictionary = topo.ponto_proximo(w, r)
		if bool(pp["ok"]):
			cand.append({"w": Vector2(pp["pt"].x, pp["pt"].y), "tipo": "pc", "prio": 1, "dist_px": float(pp["dist"]) * scale_px,
				"z": float(pp["pt"].z), "rotulo": "Ponto cotado %s m" % main.fmt(pp["pt"].z, 2)})
	if bool(opts.get("ruas_desenho", true)) and not topo.ruas.is_empty():
		var rr: Dictionary = topo.rua_proxima(w, r, r)
		if bool(rr["ok"]):
			var vert := bool(rr["vertice"])
			cand.append({"w": rr["ponto"], "tipo": "vertice" if vert else "rua", "prio": 2 if vert else 3,
				"dist_px": float(rr["dist"]) * scale_px, "rotulo": "Rua (vértice)" if vert else "Rua"})
	if int(opts.get("topo_desenho", 0)) != 2 and topo.tem_curvas():
		var cv: Dictionary = topo.curva_proxima(w, r)
		if bool(cv["ok"]):
			cand.append({"w": cv["ponto"], "tipo": "curva", "prio": 3, "dist_px": float(cv["dist"]) * scale_px,
				"z": float(cv["z"]), "rotulo": "Curva %s m" % main.fmt(cv["z"], 2)})
	if cand.is_empty():
		return {}
	cand.sort_custom(func(a, b):
		if int(a["prio"]) != int(b["prio"]):
			return int(a["prio"]) < int(b["prio"])
		return float(a["dist_px"]) < float(b["dist_px"]))
	return cand[0]


## Ponto de referência do ORTO: último nó do traçado ou posição inicial do nó arrastado.
func _ref_orto():
	if drag_node >= 0:
		return drag_origem
	if tracing and trace_from >= 0:
		var n = Net.node_map(main.proj).get(trace_from)
		if n != null:
			return Net.pos(n)
	return null


## Posição efetiva do cursor: o osnap tem prioridade; sem alvo, o ORTO alinha na horizontal
## ou na vertical a partir do ponto de referência. Retorna {w, snap, orto}.
func ponto_cursor(s: Vector2) -> Dictionary:
	var w := s2w(s)
	var excl := drag_node if drag_node >= 0 else (trace_from if tracing else -1)
	if osnap_ligado():
		# arrastando um PV, ele não gruda em outro PV (ficariam dois nós no mesmo lugar)
		var sn := buscar_snap(s, excl, drag_node < 0)
		if not sn.is_empty():
			return {"w": sn["w"], "snap": sn, "orto": false}
	var ref = _ref_orto()
	if orto_ligado() and ref != null:
		var d: Vector2 = w - ref
		w = ref + (Vector2(d.x, 0.0) if absf(d.x) >= absf(d.y) else Vector2(0.0, d.y))
		return {"w": w, "snap": {}, "orto": true}
	return {"w": w, "snap": {}, "orto": false}


## Cota para um nó novo ou movido: ponto cotado capturado pelo osnap vale direto; senão,
## o cálculo automático (sobre uma curva, a cota da curva; fora dela, interpolação no raio).
func cota_no(w: Vector2, sn: Dictionary) -> Dictionary:
	if str(main.opts.get("cota_modo", "int")) != "none" and str(sn.get("tipo", "")) == "pc":
		return {"ok": true, "z": float(sn["z"]), "metodo": "ponto", "raios": [], "par": []}
	return main.cota_auto(w)


func _atualizar_previa() -> void:
	previa = {}
	if not (tracing or drag_node >= 0) or main.topo.vazio():
		return
	var modo := str(main.opts.get("cota_modo", "int"))
	if modo == "none":
		return
	# sobre um PV existente o clique liga o trecho a ele: não há PV novo para cotar
	if tracing and str(snap.get("tipo", "")) == "no":
		return
	var cr := cota_no(cursor_w, snap)
	previa = cr.duplicate()
	previa["w"] = cursor_w
	previa["raio"] = float(main.opts.get("raio", 100.0)) if modo == "int" else float(main.opts.get("raio_pontos", 100.0))
	if str(cr.get("metodo", "")) == "ponto":
		previa["raio"] = 0.0
	elif modo in ["cc", "prx"] and bool(cr["ok"]):
		var pp: Dictionary = main.topo.ponto_proximo(cursor_w, float(previa["raio"]))
		if bool(pp["ok"]):
			previa["ponto"] = Vector2(pp["pt"].x, pp["pt"].y)
			previa["metodo"] = "ponto"


# ------------------------------------------------------------------ busca por clique

func hit_no(s: Vector2) -> int:
	var best := -1
	var bd := 9.0
	for n in main.proj["nodes"]:
		var d := w2s(Net.pos(n)).distance_to(s)
		if d < bd:
			bd = d
			best = int(n["id"])
	return best


func hit_trecho(s: Vector2) -> int:
	var nodes := Net.node_map(main.proj)
	var best := -1
	var bd := 10.0
	for t in main.proj["trechos"]:
		var a = nodes.get(int(t["ni"]))
		var b = nodes.get(int(t["nf"]))
		if a == null or b == null:
			continue
		var mid := (w2s(Net.pos(a)) + w2s(Net.pos(b))) / 2.0
		var d := mid.distance_to(s)
		if d < bd:
			bd = d
			best = int(t["id"])
	return best


func hit_linha(s: Vector2) -> int:
	var nodes := Net.node_map(main.proj)
	for t in main.proj["trechos"]:
		var a = nodes.get(int(t["ni"]))
		var b = nodes.get(int(t["nf"]))
		if a == null or b == null:
			continue
		var p := Geometry2D.get_closest_point_to_segment(s, w2s(Net.pos(a)), w2s(Net.pos(b)))
		if p.distance_to(s) < 5.0:
			return int(t["id"])
	return -1


# ------------------------------------------------------------------ entrada

func cancelar() -> void:
	drag_node = -1
	if encerrar_tracado():
		base.queue_redraw()
	mode = ""
	win_on = false
	box_on = false
	panning = false
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	over.queue_redraw()


## Encerra o traçado em andamento. Se o coletor foi iniciado mas nenhum trecho chegou a ser
## criado, o nó inicial é descartado (não deixa resíduo). Retorna true se removeu algo.
func encerrar_tracado() -> bool:
	var removeu := false
	if tracing and trace_from >= 0:
		removeu = Net.remover_orfaos(main.proj) > 0
		sel_nos.erase(trace_from)
	tracing = false
	trace_from = -1
	return removeu


func limpar_selecao() -> void:
	marked.clear()
	sel_nos.clear()


func tem_selecao() -> bool:
	return not marked.is_empty() or not sel_nos.is_empty()


## Seleção por caixa (como nas ferramentas de seleção de programas de desenho): entra tudo o
## que estiver inteiramente dentro do retângulo (coordenadas de tela). Um trecho entra quando
## os dois nós estão dentro. "somar" mantém a seleção anterior.
func selecionar_retangulo(a: Vector2, b: Vector2, somar := false) -> void:
	var r := Rect2(a, b - a).abs()
	if not somar:
		limpar_selecao()
	var nodes := Net.node_map(main.proj)
	var dentro := {}
	for nid in nodes.keys():
		if r.has_point(w2s(Net.pos(nodes[nid]))):
			dentro[nid] = true
			sel_nos[nid] = true
	for t in main.proj["trechos"]:
		if dentro.has(int(t["ni"])) and dentro.has(int(t["nf"])):
			marked[int(t["id"])] = true
	main.on_marcados()
	redesenhar()


func marcar_coletor(tid: int) -> void:
	var t: Dictionary = Net.trecho_map(main.proj).get(tid, {})
	if t.is_empty():
		return
	var col := str(t["coletor"])
	var todos := true
	for t2 in main.proj["trechos"]:
		if str(t2["coletor"]) == col and not marked.has(int(t2["id"])):
			todos = false
	for t2 in main.proj["trechos"]:
		if str(t2["coletor"]) == col:
			if todos:
				marked.erase(int(t2["id"]))
			else:
				marked[int(t2["id"])] = true
	main.on_marcados()
	redesenhar()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse_s = ev.position
		if panning:
			center -= Vector2(ev.relative.x, -ev.relative.y) / scale_px
			base.queue_redraw()
		var cur := ponto_cursor(mouse_s) if not panning and not box_on and not win_on else {"w": s2w(mouse_s), "snap": {}, "orto": false}
		var w: Vector2 = cur["w"]
		cursor_w = w
		snap = cur["snap"]
		cursor_orto = bool(cur["orto"])
		if drag_node >= 0 and not panning:
			var n = Net.node_map(main.proj).get(drag_node)
			if n != null and w.distance_to(drag_origem) * scale_px > 0.5:
				n["e"] = w.x
				n["n"] = w.y
				drag_snap = snap
				drag_moved = true
				base.queue_redraw()
		_atualizar_previa()
		var z := NAN
		if not previa.is_empty():
			z = float(previa["z"]) if bool(previa.get("ok", false)) else NAN
		elif not main.topo.vazio():
			var cr: Dictionary = main.cota_auto(w, true)
			if bool(cr["ok"]):
				z = float(cr["z"])
		var dist := 0.0
		if tracing and trace_from >= 0:
			var n0 = Net.node_map(main.proj).get(trace_from)
			if n0 != null:
				dist = Net.pos(n0).distance_to(w)
		cursor_moved.emit(w.x, w.y, z, dist)
		over.queue_redraw()
		return
	if ev is InputEventMouseButton:
		grab_focus()
		var s: Vector2 = ev.position
		mouse_s = s
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			zoom(1.25, s)
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			zoom(0.8, s)
			return
		if ev.button_index == MOUSE_BUTTON_MIDDLE:
			panning = ev.pressed
			return
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_left_press(s, ev.shift_pressed, ev.is_command_or_control_pressed())
			else:
				_left_release(s)
			return
		if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			_right_press(s, ev.is_command_or_control_pressed())
			return
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_ESCAPE:
			if not tracing and mode == "" and not box_on and tem_selecao():
				limpar_selecao()
				main.on_marcados()
				redesenhar()
				main.set_status("Seleção desfeita.")
			else:
				cancelar()
				main.set_status("Comando cancelado.")
			accept_event()
		elif ev.keycode == KEY_DELETE:
			main.apagar_selecao()
			accept_event()


func _left_press(s: Vector2, shift: bool, ctrl: bool) -> void:
	destaque = Vector2(NAN, NAN)
	if mode == "pan":
		panning = true
		return
	if mode == "janela":
		win_on = true
		win_a = s
		return
	var nid := hit_no(s)
	var tid := hit_trecho(s) if nid < 0 else -1
	if shift:
		if nid >= 0:
			_continuar_de(nid)
		elif tid >= 0:
			marcar_coletor(tid)
		return
	if ctrl and not tracing:
		if tid < 0 and nid < 0:
			tid = hit_linha(s)
		if nid >= 0:
			if sel_nos.has(nid):
				sel_nos.erase(nid)
			else:
				sel_nos[nid] = true
		elif tid >= 0:
			if marked.has(tid):
				marked.erase(tid)
			else:
				marked[tid] = true
		else:
			_iniciar_caixa(s, true)
			return
		main.on_marcados()
		redesenhar()
		return
	if tracing:
		var cur := ponto_cursor(s)
		var sn: Dictionary = cur["snap"]
		_tracar_ate(s, int(sn["nid"]) if str(sn.get("tipo", "")) == "no" else nid, cur)
		return
	if nid >= 0:
		drag_node = nid
		drag_moved = false
		drag_snap = {}
		drag_origem = Net.pos(Net.node_map(main.proj)[nid])
		return
	if tid < 0:
		tid = hit_linha(s)
	if tid >= 0:
		limpar_selecao()
		marked[tid] = true
		main.on_marcados()
		redesenhar()
		return
	_iniciar_caixa(s, false)


func _iniciar_caixa(s: Vector2, somar: bool) -> void:
	box_on = true
	box_a = s
	box_somar = somar


func _left_release(s: Vector2) -> void:
	if panning and mode == "pan":
		panning = false
		return
	if box_on:
		box_on = false
		if box_a.distance_to(s) > 4.0:
			selecionar_retangulo(box_a, s, box_somar)
			main.set_status("%d nó(s) e %d trecho(s) selecionado(s). Del apaga; Esc desfaz a seleção." % [sel_nos.size(), marked.size()])
		elif not box_somar and tem_selecao():
			limpar_selecao()
			main.on_marcados()
			redesenhar()
		over.queue_redraw()
		return
	if win_on:
		win_on = false
		var a := s2w(win_a)
		var b := s2w(s)
		if win_a.distance_to(s) > 6.0:
			ajustar(Rect2(a, Vector2.ZERO).expand(b))
		mode = ""
		mouse_default_cursor_shape = Control.CURSOR_CROSS
		over.queue_redraw()
		return
	if drag_node >= 0:
		if drag_moved:
			var n = Net.node_map(main.proj).get(drag_node)
			var modo := str(main.opts.get("cota_modo", "int"))
			if n != null and modo != "none":
				var cr: Dictionary = cota_no(Net.pos(n), drag_snap)
				if bool(cr["ok"]):
					n["ct"] = snappedf(float(cr["z"]), 0.001)
					n["ct_ok"] = true
					if cr.has("w"):
						n["e"] = cr["w"].x
						n["n"] = cr["w"].y
				rastro = cr
			main.on_changed("mover")
			main.set_status("Nó %s movido." % str(n["nome"]) if n != null else "")
		else:
			limpar_selecao()
			sel_nos[drag_node] = true
			main.on_marcados()
			redesenhar()
		drag_node = -1
		previa = {}
		over.queue_redraw()


func _right_press(s: Vector2, ctrl: bool) -> void:
	var nid := hit_no(s)
	if ctrl and nid >= 0:
		var cols := Net.coletores_do_no(main.proj, nid)
		main.set_status("Nó %s — coletor(es): %s" % [str(Net.node_map(main.proj)[nid]["nome"]), ", ".join(PackedStringArray(cols))])
		return
	if tracing:
		if encerrar_tracado():
			base.queue_redraw()
			main.set_status("Traçado cancelado: nenhum trecho foi criado, o nó inicial foi descartado.")
		else:
			main.set_status("Traçado finalizado. Botão 2 numa área vazia inicia um novo coletor.")
		over.queue_redraw()
		return
	if mode != "":
		cancelar()
		return
	if nid >= 0:
		main.abrir_no(nid)
		return
	var tid := hit_trecho(s)
	if tid >= 0:
		main.abrir_trecho(tid)
		return
	# inicia um novo coletor (ponta seca), no ponto capturado pelo osnap se houver
	var cur := ponto_cursor(s)
	var w: Vector2 = cur["w"]
	var cr: Dictionary = cota_no(w, cur["snap"])
	rastro = cr
	var pos_w: Vector2 = cr.get("w", w)
	var ct: float = float(cr["z"]) if bool(cr["ok"]) else 0.0
	var n := Net.novo_no(main.proj, pos_w, snappedf(ct, 0.001), bool(cr["ok"]), "TL")
	tracing = true
	trace_from = int(n["id"])
	trace_col = Net.coletor_novo(main.proj)
	# o nó inicial só entra no histórico junto com o primeiro trecho; se o traçado for
	# encerrado sem trechos, ele é descartado (encerrar_tracado)
	redesenhar()
	main.set_status("Coletor %s iniciado no nó %s. Botão 1 cria os próximos nós; botão 2 finaliza." % [trace_col, str(n["nome"])])


func _continuar_de(nid: int) -> void:
	if Net.tem_saida(main.proj, nid):
		main.set_status("Só é possível continuar o traçado a partir do último nó de um coletor (este nó já tem saída).")
		return
	tracing = true
	trace_from = nid
	trace_col = Net.coletor_de_chegada(main.proj, nid)
	if trace_col == "":
		trace_col = Net.coletor_novo(main.proj)
	main.set_status("Continuando o coletor %s a partir do nó %s." % [trace_col, str(Net.node_map(main.proj)[nid]["nome"])])
	over.queue_redraw()


## Liga o traçado em andamento ao nó existente "nid" (afluente). "tipo" é o novo tipo
## do TL de início de rede, quando ele precisa ser escolhido. Um passo só de desfazer.
func concluir_ligacao(nid: int, tipo: String) -> bool:
	if not tracing or not Net.node_map(main.proj).has(trace_from):
		return false
	var r := Net.ligar(main.proj, main.db, trace_from, nid, trace_col, tipo)
	if not bool(r["ok"]):
		main.set_status(str(r["motivo"]))
		return false
	tracing = false
	trace_from = -1
	main.on_changed("traçado")
	var extra := ""
	if tipo != "":
		extra = " O TL %s passou a ser %s." % [Net.nome_no(main.proj, nid), _nome_tipo(tipo)]
	for c in r["convertidos"]:
		extra += " O nó %s passou a ser PV (%d entradas)." % [str(c["nome"]), Net.entradas(main.proj, int(c["id"])).size()]
	main.set_status("Trecho %s ligado ao nó existente (afluente). Traçado finalizado.%s" % [str(r["trecho"]["nome"]), extra])
	return true


func _nome_tipo(tipo: String) -> String:
	for o in Net.OPCOES_TL:
		if o[0] == tipo:
			return o[1]
	return tipo


func _tracar_ate(s: Vector2, nid: int, cur := {}) -> void:
	if nid == trace_from:
		return
	if not Net.node_map(main.proj).has(trace_from):
		cancelar()
		return
	if nid >= 0:
		var regra := Net.pode_ligar(main.proj, trace_from, nid)
		if not bool(regra["ok"]):
			if str(regra["regra"]) in ["sem_saida", "max_entradas"]:
				main.alertar("Ligação não permitida", str(regra["motivo"]))
			else:
				main.set_status(str(regra["motivo"]))
			return
		if Net.precisa_escolher_tipo(main.proj, nid):
			# TL de início de rede: o usuário escolhe PV, PI ou TIL de passagem (SPEC-8.02);
			# a ligação só acontece depois da escolha (concluir_ligacao)
			main.perguntar_tipo_tl(trace_from, nid)
			return
		concluir_ligacao(nid, "")
		return
	if cur.is_empty():
		cur = ponto_cursor(s)
	var w: Vector2 = cur["w"]
	var cr: Dictionary = cota_no(w, cur["snap"])
	rastro = cr
	var pos_w: Vector2 = cr.get("w", w)
	var ct: float = float(cr["z"]) if bool(cr["ok"]) else float(Net.node_map(main.proj)[trace_from]["ct"])
	var n := Net.novo_no(main.proj, pos_w, snappedf(ct, 0.001), bool(cr["ok"]), "PV")
	var t := Net.novo_trecho(main.proj, main.db, trace_from, int(n["id"]), trace_col)
	var l: float = Net.comprimento(Net.node_map(main.proj), t)
	trace_from = int(n["id"])
	main.on_changed("traçado")
	if l > float(main.proj["params"]["dist_max_pv"]):
		main.set_status("Atenção: trecho %s com %s m, maior que a distância máxima entre PVs." % [str(t["nome"]), main.fmt(l, 2)])
	else:
		main.set_status("Trecho %s criado (%s m)." % [str(t["nome"]), main.fmt(l, 2)])
