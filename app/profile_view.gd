extends Control
## Perfil longitudinal de uma seqüência de trechos (manual 5.1.3):
## terreno, tubo (geratrizes inferior e superior), NA de início e de fim de plano,
## poços de visita e faixa de dados. Grid e escala configuráveis.

var rows: Array = []
var titulo := ""
var grid_modo := 0 # 0 nenhum, 1 horizontal, 2 vertical, 3 ambos
var escala := {"auto_x": true, "auto_y": true, "xmin": 0.0, "xmax": 100.0, "xpasso": 10.0,
	"ymin": 0.0, "ymax": 10.0, "ypasso": 1.0}

const C_TERRENO := Color(0.55, 0.08, 0.08)
const C_TUBO := Color(0.05, 0.05, 0.05)
const C_NA_INI := Color(0.0, 0.52, 0.55)
const C_NA_FIM := Color(0.12, 0.15, 0.62)

var _plot := Rect2()
var _x0 := 0.0
var _x1 := 1.0
var _y0 := 0.0
var _y1 := 1.0


func set_data(r: Array, t: String) -> void:
	rows = r
	titulo = t
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _br(v: float, dec: int) -> String:
	if absf(v) < 0.5 * pow(10.0, -dec):
		v = 0.0
	return (("%." + str(dec) + "f") % v).replace(".", ",")


func xs() -> Array:
	var out: Array = [0.0]
	for r in rows:
		out.append(float(out[-1]) + float(r["L"]))
	return out


static func _passo(span: float, alvo: int) -> float:
	var bruto := span / maxf(alvo, 1)
	var mag := pow(10.0, floor(log(maxf(bruto, 1e-9)) / log(10.0)))
	for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if bruto <= m * mag:
			return m * mag
	return 10.0 * mag


func limites_auto() -> Dictionary:
	var x := xs()
	var ymin := INF
	var ymax := -INF
	for r in rows:
		ymin = minf(ymin, minf(float(r["cc_m"]), float(r["cc_j"])))
		ymax = maxf(ymax, maxf(float(r["ct_m"]), float(r["ct_j"])))
	if ymin == INF:
		ymin = 0.0
		ymax = 1.0
	var span := maxf(ymax - ymin, 1.0)
	var yp := _passo(span * 1.2, 8)
	var xmax: float = maxf(float(x[-1]), 1.0)
	return {"xmin": 0.0, "xmax": xmax, "xpasso": _passo(xmax, 10),
		"ymin": floorf((ymin - span * 0.08) / yp) * yp, "ymax": ceilf((ymax + span * 0.1) / yp) * yp, "ypasso": yp}


func _px(x: float) -> float:
	return _plot.position.x + (x - _x0) / maxf(_x1 - _x0, 1e-6) * _plot.size.x


func _py(y: float) -> float:
	return _plot.position.y + (_y1 - y) / maxf(_y1 - _y0, 1e-6) * _plot.size.y


func _txt(font: Font, pos: Vector2, s: String, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, w := 120.0) -> void:
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	draw_string(font, Vector2(x, pos.y), s, align, w, fs, col)


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	if rows.is_empty():
		_txt(font, Vector2(20, 34), "Nenhum trecho calculado na seleção.", 14, Color(0.3, 0.3, 0.3), HORIZONTAL_ALIGNMENT_LEFT, 600)
		return
	var lim := limites_auto()
	_x0 = float(lim["xmin"]) if bool(escala["auto_x"]) else float(escala["xmin"])
	_x1 = float(lim["xmax"]) if bool(escala["auto_x"]) else float(escala["xmax"])
	var xpasso: float = float(lim["xpasso"]) if bool(escala["auto_x"]) else float(escala["xpasso"])
	_y0 = float(lim["ymin"]) if bool(escala["auto_y"]) else float(escala["ymin"])
	_y1 = float(lim["ymax"]) if bool(escala["auto_y"]) else float(escala["ymax"])
	var ypasso: float = float(lim["ypasso"]) if bool(escala["auto_y"]) else float(escala["ypasso"])
	if _x1 <= _x0:
		_x1 = _x0 + 1.0
	if _y1 <= _y0:
		_y1 = _y0 + 1.0
	xpasso = maxf(xpasso, (_x1 - _x0) / 60.0)
	ypasso = maxf(ypasso, (_y1 - _y0) / 60.0)
	var band := ["PV", "Distância (m)", "Cota terreno (m)", "Cota coletor (m)", "Profundidade (m)", "ø (mm)  I (m/m)"]
	var row_h := 16.0
	var band_h := row_h * band.size() + 10.0
	_plot = Rect2(140, 40, size.x - 140 - 40, size.y - 40 - band_h - 46)
	if _plot.size.x < 60 or _plot.size.y < 60:
		return
	_txt(font, Vector2(14, 22), titulo, 15, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT, 600)
	# escalas do gráfico: metros por 100 px e exagero vertical
	var mh := (_x1 - _x0) / _plot.size.x * 100.0
	var mv := (_y1 - _y0) / _plot.size.y * 100.0
	_txt(font, Vector2(14, size.y - 8), "Escala: horizontal %s m / 100 px  •  vertical %s m / 100 px  •  exagero vertical %s×" % [
		_br(mh, 1), _br(mv, 2), _br(mh / maxf(mv, 1e-9), 1)], 11, Color(0.3, 0.3, 0.35), HORIZONTAL_ALIGNMENT_LEFT, 700)
	# legenda
	var lx := size.x - 360.0
	for item in [["Terreno", C_TERRENO], ["Tubo", C_TUBO], ["NA In.", C_NA_INI], ["NA Fim", C_NA_FIM]]:
		draw_rect(Rect2(lx, 12, 12, 10), item[1])
		_txt(font, Vector2(lx + 16, 22), item[0], 12, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT, 80)
		lx += 86.0
	var grid := Color(0.82, 0.82, 0.85)
	var eixo := Color(0.35, 0.35, 0.38)
	draw_rect(_plot, Color(0.985, 0.985, 0.99))
	var gy := ceilf(_y0 / ypasso - 1e-6) * ypasso
	while gy <= _y1 + 1e-6:
		var y := _py(gy)
		if grid_modo == 1 or grid_modo == 3:
			draw_line(Vector2(_plot.position.x, y), Vector2(_plot.end.x, y), grid, 1.0)
		draw_line(Vector2(_plot.position.x - 4, y), Vector2(_plot.position.x, y), eixo, 1.0)
		_txt(font, Vector2(_plot.position.x - 6, y + 4), _br(gy, 1 if ypasso < 1.0 else 0) if ypasso >= 0.1 else _br(gy, 2), 11, eixo, HORIZONTAL_ALIGNMENT_RIGHT, 70)
		gy += ypasso
	var gx := ceilf(_x0 / xpasso - 1e-6) * xpasso
	while gx <= _x1 + 1e-6:
		var x := _px(gx)
		if grid_modo == 2 or grid_modo == 3:
			draw_line(Vector2(x, _plot.position.y), Vector2(x, _plot.end.y), grid, 1.0)
		draw_line(Vector2(x, _plot.end.y), Vector2(x, _plot.end.y + 4), eixo, 1.0)
		_txt(font, Vector2(x, _plot.end.y + 16), _br(gx, 1), 11, eixo, HORIZONTAL_ALIGNMENT_CENTER, 70)
		gx += xpasso
	draw_rect(_plot, eixo, false, 1.0)
	_txt(font, Vector2(_plot.get_center().x, _plot.end.y + 32), "Distância (m)", 12, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 200)
	draw_set_transform(Vector2(_plot.position.x - 52, _plot.get_center().y), -PI / 2.0, Vector2.ONE)
	_txt(font, Vector2(0, 0), "Cota (m)", 12, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 120)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var x := xs()
	var terreno := PackedVector2Array()
	var na_i := PackedVector2Array()
	var na_f := PackedVector2Array()
	for k in rows.size():
		var r: Dictionary = rows[k]
		var d := float(r["d"]) / 1000.0
		var xa := _px(float(x[k]))
		var xb := _px(float(x[k + 1]))
		terreno.append(Vector2(xa, _py(float(r["ct_m"]))))
		terreno.append(Vector2(xb, _py(float(r["ct_j"]))))
		var ia := _py(float(r["cc_m"]))
		var ib := _py(float(r["cc_j"]))
		var ca := _py(float(r["cc_m"]) + d)
		var cb := _py(float(r["cc_j"]) + d)
		var fill := Color(0.6, 0.6, 0.62, 0.35)
		if xb - xa > 1.0 and minf(ia - ca, ib - cb) > 0.5:
			draw_colored_polygon(PackedVector2Array([Vector2(xa, ca), Vector2(xb, cb), Vector2(xb, ib), Vector2(xa, ia)]), fill)
		draw_line(Vector2(xa, ia), Vector2(xb, ib), C_TUBO, 1.8)
		draw_line(Vector2(xa, ca), Vector2(xb, cb), C_TUBO, 1.0)
		na_i.append(Vector2(xa, _py(float(r["cc_m"]) + float(r["yd_i"]) * d)))
		na_i.append(Vector2(xb, _py(float(r["cc_j"]) + float(r["yd_i"]) * d)))
		na_f.append(Vector2(xa, _py(float(r["cc_m"]) + float(r["yd_f"]) * d)))
		na_f.append(Vector2(xb, _py(float(r["cc_j"]) + float(r["yd_f"]) * d)))
		var cor_rot := Color(0.8, 0.1, 0.1) if int(r["status"]) >= 2 else Color.BLACK
		_txt(font, Vector2((xa + xb) / 2.0, minf(_py(float(r["ct_m"])), _py(float(r["ct_j"]))) - 8), str(r["nome"]), 11, cor_rot,
			HORIZONTAL_ALIGNMENT_CENTER, maxf(xb - xa, 30))
	for k in rows.size():
		draw_line(na_i[2 * k], na_i[2 * k + 1], C_NA_INI, 1.2)
		draw_line(na_f[2 * k], na_f[2 * k + 1], C_NA_FIM, 1.2)
		draw_line(terreno[2 * k], terreno[2 * k + 1], C_TERRENO, 2.6)
		if k > 0:
			draw_line(terreno[2 * k - 1], terreno[2 * k], C_TERRENO, 2.6)
	# poços de visita e faixa de dados
	var by := _plot.end.y + 52.0
	for j in band.size():
		var y := by + row_h * j
		_txt(font, Vector2(8, y), band[j], 11, Color(0.25, 0.25, 0.3), HORIZONTAL_ALIGNMENT_LEFT, 120)
		draw_line(Vector2(_plot.position.x, y + 4), Vector2(_plot.end.x, y + 4), Color(0.88, 0.88, 0.9), 1.0)
	for k in rows.size() + 1:
		var px := _px(float(x[k]))
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
		var top := _py(ct)
		var bot := _py(cc) + 3.0
		draw_rect(Rect2(px - 3, top, 6, maxf(bot - top, 1)), Color(0.55, 0.55, 0.6, 0.8))
		draw_rect(Rect2(px - 3, top, 6, maxf(bot - top, 1)), Color(0.25, 0.25, 0.3), false, 1.0)
		var w := 80.0
		_txt(font, Vector2(px, by), nome, 11, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, w)
		_txt(font, Vector2(px, by + row_h), _br(float(x[k]), 2), 11, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, w)
		_txt(font, Vector2(px, by + row_h * 2), _br(ct, 3), 11, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, w)
		_txt(font, Vector2(px, by + row_h * 3), _br(cc, 3), 11, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, w)
		_txt(font, Vector2(px, by + row_h * 4), _br(ct - cc, 2), 11, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, w)
	for k in rows.size():
		var r: Dictionary = rows[k]
		var xa := _px(float(x[k]))
		var xb := _px(float(x[k + 1]))
		_txt(font, Vector2((xa + xb) / 2.0, by + row_h * 5), "ø%d  %s" % [int(r["d"]), _br(float(r["i"]), 4)],
			11, Color(0.2, 0.2, 0.45), HORIZONTAL_ALIGNMENT_CENTER, maxf(xb - xa, 40))


## Listagem em texto dos trechos do perfil.
func listagem() -> String:
	var s := "%s\n" % titulo
	s += "%-8s %-6s %-6s %8s %5s %8s %9s %9s %9s %9s %6s %6s %6s %6s\n" % [
		"Trecho", "PV ini", "PV fim", "L (m)", "DN", "I (m/m)", "CT mont", "CT jus", "CC mont", "CC jus", "y/Di", "y/Df", "Vi", "Vf"]
	for r in rows:
		s += "%-8s %-6s %-6s %8s %5d %8s %9s %9s %9s %9s %6s %6s %6s %6s\n" % [
			str(r["nome"]), str(r["pv_i"]), str(r["pv_f"]), _br(float(r["L"]), 2), int(r["d"]), _br(float(r["i"]), 4),
			_br(float(r["ct_m"]), 3), _br(float(r["ct_j"]), 3), _br(float(r["cc_m"]), 3), _br(float(r["cc_j"]), 3),
			_br(float(r["yd_i"]), 2), _br(float(r["yd_f"]), 2), _br(float(r["v_i"]), 2), _br(float(r["v_f"]), 2)]
	return s
