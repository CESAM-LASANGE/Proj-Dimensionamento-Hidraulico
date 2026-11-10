extends Control
## Desenho do perfil longitudinal de um coletor.

var rows: Array = []
var coletor := ""
var pal: Dictionary = {}

var _plot := Rect2()
var _total := 1.0
var _ymin := 0.0
var _ymax := 1.0


func set_data(r: Array, c: String, p: Dictionary) -> void:
	rows = r
	coletor = c
	pal = p
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _px(x: float) -> float:
	return _plot.position.x + x / _total * _plot.size.x


func _py(y: float) -> float:
	return _plot.position.y + (_ymax - y) / (_ymax - _ymin) * _plot.size.y


func _br(v: float, dec: int) -> String:
	return (("%." + str(dec) + "f") % v).replace(".", ",")


func _text(font: Font, pos: Vector2, s: String, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, w := 120.0) -> void:
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	draw_string(font, Vector2(x, pos.y), s, align, w, fs, col)


func _draw() -> void:
	var font := get_theme_default_font()
	var bgc: Color = pal.get("field", Color.WHITE)
	var txt: Color = pal.get("text", Color.BLACK)
	var muted: Color = pal.get("muted", Color(0.4, 0.4, 0.4))
	var border: Color = pal.get("border", Color.GRAY)
	var accent: Color = pal.get("accent", Color(0.1, 0.4, 0.7))
	draw_rect(Rect2(Vector2.ZERO, size), bgc)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 1.0)
	if rows.is_empty():
		_text(font, Vector2(20, 34), "Nenhum trecho calculado para este coletor.", 14, muted, HORIZONTAL_ALIGNMENT_LEFT, 600)
		return

	var band_rows := ["PV", "Terreno (m)", "Coletor (m)", "Prof. (m)", "Trecho"]
	var row_h := 18.0
	var band_h := row_h * band_rows.size() + 8
	_plot = Rect2(140, 56, size.x - 140 - 50, size.y - 56 - band_h - 30)
	if _plot.size.x < 60 or _plot.size.y < 60:
		return

	var xs: Array = [0.0]
	for r in rows:
		xs.append(float(xs[-1]) + float(r["L"]))
	_total = max(float(xs[-1]), 1.0)
	_ymin = INF
	_ymax = -INF
	for r in rows:
		_ymin = min(_ymin, float(r["cc_m"]), float(r["cc_j"]))
		_ymax = max(_ymax, float(r["ct_m"]), float(r["ct_j"]))
	var span: float = max(_ymax - _ymin, 1.0)
	_ymin -= span * 0.12
	_ymax += span * 0.18

	# título e legenda
	_text(font, Vector2(16, 26), "Perfil longitudinal — Coletor %s" % coletor, 16, txt, HORIZONTAL_ALIGNMENT_LEFT, 500)
	_text(font, Vector2(16, 44), "Extensão: %s m  •  escala vertical exagerada" % _br(_total, 2), 12, muted, HORIZONTAL_ALIGNMENT_LEFT, 500)
	var soil := Color(0.86, 0.78, 0.64)
	var terr := Color(0.50, 0.33, 0.16)
	var pipe_fill := Color(accent.r, accent.g, accent.b, 0.30)
	var lx := size.x - 330
	for item in [["Terreno", terr], ["Coletor", accent], ["Poço de visita", Color(0.55, 0.55, 0.58)]]:
		draw_rect(Rect2(lx, 20, 14, 10), item[1])
		_text(font, Vector2(lx + 20, 30), item[0], 12, txt, HORIZONTAL_ALIGNMENT_LEFT, 100)
		lx += 100

	# grade de cotas
	var step := 0.1
	for s in [0.1, 0.2, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0]:
		step = s
		if (_ymax - _ymin) / s <= 8:
			break
	var gy: float = ceil(_ymin / step) * step
	var grid := Color(border.r, border.g, border.b, 0.6)
	while gy <= _ymax:
		var y := _py(gy)
		draw_line(Vector2(_plot.position.x, y), Vector2(_plot.end.x, y), grid, 1.0)
		_text(font, Vector2(_plot.position.x - 8, y + 4), _br(gy, 2), 11, muted, HORIZONTAL_ALIGNMENT_RIGHT, 80)
		gy += step
	draw_rect(_plot, border, false, 1.0)

	# terreno (solo)
	var tpts := PackedVector2Array()
	tpts.append(Vector2(_px(0), _py(float(rows[0]["ct_m"]))))
	for k in rows.size():
		tpts.append(Vector2(_px(xs[k + 1]), _py(float(rows[k]["ct_j"]))))
	var poly := PackedVector2Array(tpts)
	poly.append(Vector2(_px(_total), _plot.end.y))
	poly.append(Vector2(_px(0), _plot.end.y))
	draw_colored_polygon(poly, Color(soil.r, soil.g, soil.b, 0.45))

	# coletor
	for k in rows.size():
		var r: Dictionary = rows[k]
		var d: float = float(r["d"]) / 1000.0
		var x0 := _px(xs[k])
		var x1 := _px(xs[k + 1])
		var inv0 := _py(float(r["cc_m"]))
		var inv1 := _py(float(r["cc_j"]))
		var cr0 := _py(float(r["cc_m"]) + d)
		var cr1 := _py(float(r["cc_j"]) + d)
		var pp := PackedVector2Array([Vector2(x0, cr0), Vector2(x1, cr1), Vector2(x1, inv1), Vector2(x0, inv0)])
		if min(inv0, inv1) - max(cr0, cr1) < 2.0:
			pp = PackedVector2Array([Vector2(x0, cr0 - 1), Vector2(x1, cr1 - 1), Vector2(x1, inv1 + 1), Vector2(x0, inv0 + 1)])
		draw_colored_polygon(pp, pipe_fill)
		draw_line(Vector2(x0, inv0), Vector2(x1, inv1), accent, 2.0)
		draw_line(Vector2(x0, cr0), Vector2(x1, cr1), accent, 1.0)
		var col := accent
		if int(r["status"]) == 2:
			col = Color(0.8, 0.15, 0.15)
		var mid := Vector2((x0 + x1) / 2.0, (inv0 + inv1) / 2.0 + 18)
		_text(font, mid, "DN %d  I=%s" % [int(r["d"]), _br(float(r["i"]), 4)], 11, col, HORIZONTAL_ALIGNMENT_CENTER, max(x1 - x0, 40))

	draw_polyline(tpts, terr, 2.0)

	# poços de visita
	var by := _plot.end.y + 26
	for k in rows.size() + 1:
		var x := _px(xs[k])
		var ct: float
		var cc: float
		var nome: String
		if k == 0:
			ct = float(rows[0]["ct_m"])
			cc = float(rows[0]["cc_m"])
			nome = str(rows[0]["pv_m"])
		elif k == rows.size():
			ct = float(rows[k - 1]["ct_j"])
			cc = float(rows[k - 1]["cc_j"])
			nome = str(rows[k - 1]["pv_j"])
		else:
			ct = float(rows[k]["ct_m"])
			cc = min(float(rows[k]["cc_m"]), float(rows[k - 1]["cc_j"]))
			nome = str(rows[k]["pv_m"])
		var top := _py(ct)
		var bot := _py(cc) + 4
		draw_rect(Rect2(x - 5, top, 10, bot - top), Color(0.62, 0.62, 0.66))
		draw_rect(Rect2(x - 5, top, 10, bot - top), Color(0.3, 0.3, 0.33), false, 1.0)
		_text(font, Vector2(x, top - 8), nome, 11, txt)
		# faixa de dados
		var w: float = 90.0
		_text(font, Vector2(x, by + row_h * 0), nome, 11, txt, HORIZONTAL_ALIGNMENT_CENTER, w)
		_text(font, Vector2(x, by + row_h * 1), _br(ct, 3), 11, txt, HORIZONTAL_ALIGNMENT_CENTER, w)
		_text(font, Vector2(x, by + row_h * 2), _br(cc, 3), 11, txt, HORIZONTAL_ALIGNMENT_CENTER, w)
		_text(font, Vector2(x, by + row_h * 3), _br(ct - cc, 2), 11, txt, HORIZONTAL_ALIGNMENT_CENTER, w)
	for k in rows.size():
		var r: Dictionary = rows[k]
		var xm := (_px(xs[k]) + _px(xs[k + 1])) / 2.0
		_text(font, Vector2(xm, by + row_h * 4), "%s • %s m" % [str(r["trecho"]), _br(float(r["L"]), 1)], 11, muted, HORIZONTAL_ALIGNMENT_CENTER, max(_px(xs[k + 1]) - _px(xs[k]), 40))
	for j in band_rows.size():
		var y := by + row_h * j
		_text(font, Vector2(12, y), band_rows[j], 11, muted, HORIZONTAL_ALIGNMENT_LEFT, 90)
		draw_line(Vector2(_plot.position.x, y + 5), Vector2(_plot.end.x, y + 5), grid, 1.0)
