extends RefCounted
## Ícones vetoriais da barra de ferramentas (desenhados em 20x20 e escalados).


static func desenhar(c: CanvasItem, id: String, sz: Vector2, col: Color) -> void:
	if sz.x < 6.0 or sz.y < 6.0:
		return
	var s := minf(sz.x, sz.y) / 20.0
	var o := (sz - Vector2(20, 20) * s) / 2.0
	var P := func(x, y): return o + Vector2(x, y) * s
	var w := maxf(1.0, 1.3 * s)
	var azul := Color(0.15, 0.35, 0.8)
	var verde := Color(0.1, 0.65, 0.25)
	var verm := Color(0.85, 0.15, 0.15)
	match id:
		"novo":
			c.draw_polyline(PackedVector2Array([P.call(5, 2), P.call(12, 2), P.call(16, 6), P.call(16, 18), P.call(5, 18), P.call(5, 2)]), col, w)
			c.draw_polyline(PackedVector2Array([P.call(12, 2), P.call(12, 6), P.call(16, 6)]), col, w)
		"abre":
			c.draw_polyline(PackedVector2Array([P.call(2, 16), P.call(2, 5), P.call(7, 5), P.call(9, 7), P.call(16, 7), P.call(16, 9)]), col, w)
			c.draw_colored_polygon(PackedVector2Array([P.call(2, 16), P.call(5, 9), P.call(19, 9), P.call(16, 16)]), Color(0.95, 0.78, 0.3))
			c.draw_polyline(PackedVector2Array([P.call(2, 16), P.call(5, 9), P.call(19, 9), P.call(16, 16), P.call(2, 16)]), col, w)
		"salva":
			c.draw_rect(Rect2(P.call(3, 3), Vector2(14, 14) * s), azul.darkened(0.2))
			c.draw_rect(Rect2(P.call(6, 3), Vector2(8, 5) * s), Color.WHITE)
			c.draw_rect(Rect2(P.call(5, 11), Vector2(10, 6) * s), Color(0.85, 0.85, 0.85))
		"desfazer":
			c.draw_arc(P.call(11, 11), 6.0 * s, PI, 2.25 * PI, 18, azul, w * 1.3)
			c.draw_colored_polygon(PackedVector2Array([P.call(1.5, 9.5), P.call(8.5, 9.5), P.call(5, 14.5)]), azul)
		"refazer":
			c.draw_arc(P.call(9, 11), 6.0 * s, -1.25 * PI, 0.0, 18, azul, w * 1.3)
			c.draw_colored_polygon(PackedVector2Array([P.call(11.5, 9.5), P.call(18.5, 9.5), P.call(15, 14.5)]), azul)
		"dxf":
			c.draw_colored_polygon(PackedVector2Array([P.call(10, 2), P.call(18, 18), P.call(2, 18)]), Color(0.3, 0.3, 0.35))
			c.draw_line(P.call(10, 6), P.call(10, 18), Color.WHITE, w)
			c.draw_line(P.call(10, 9), P.call(6, 18), Color.WHITE, w * 0.7)
			c.draw_line(P.call(10, 9), P.call(14, 18), Color.WHITE, w * 0.7)
		"exp_planilha":
			_grade(c, P, s, Rect2(2, 3, 13, 13), col, w)
			c.draw_colored_polygon(PackedVector2Array([P.call(12, 8), P.call(19, 12), P.call(12, 16)]), verm)
		"imprime":
			c.draw_rect(Rect2(P.call(6, 2), Vector2(8, 6) * s), Color.WHITE)
			c.draw_rect(Rect2(P.call(6, 2), Vector2(8, 6) * s), col, false, w)
			c.draw_rect(Rect2(P.call(2, 8), Vector2(16, 7) * s), Color(0.6, 0.6, 0.65))
			c.draw_rect(Rect2(P.call(6, 13), Vector2(8, 5) * s), Color.WHITE)
			c.draw_rect(Rect2(P.call(6, 13), Vector2(8, 5) * s), col, false, w)
		"visualiza":
			c.draw_rect(Rect2(P.call(3, 2), Vector2(10, 14) * s), Color.WHITE)
			c.draw_rect(Rect2(P.call(3, 2), Vector2(10, 14) * s), col, false, w)
			c.draw_arc(P.call(12, 12), 4.0 * s, 0, TAU, 16, col, w)
			c.draw_line(P.call(15, 15), P.call(18.5, 18.5), col, w * 1.6)
		"zoom_max":
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var a: Vector2 = P.call(10, 10)
				var b: Vector2 = P.call(10 + d.x * 8, 10 + d.y * 8)
				c.draw_line(a, b, azul, w)
				var n := Vector2(-d.y, d.x)
				c.draw_colored_polygon(PackedVector2Array([b, b - d * 3 * s + n * 2.5 * s, b - d * 3 * s - n * 2.5 * s]), azul)
		"janela":
			c.draw_dashed_line(P.call(3, 4), P.call(17, 4), col, w, 2 * s)
			c.draw_dashed_line(P.call(17, 4), P.call(17, 16), col, w, 2 * s)
			c.draw_dashed_line(P.call(17, 16), P.call(3, 16), col, w, 2 * s)
			c.draw_dashed_line(P.call(3, 16), P.call(3, 4), col, w, 2 * s)
		"redesenha":
			var f := ThemeDB.fallback_font
			c.draw_string(f, P.call(4, 16), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * s), azul)
			c.draw_line(P.call(4, 17.5), P.call(15, 17.5), azul, w)
		"pan":
			c.draw_arc(P.call(10, 11), 5.5 * s, PI, TAU, 12, col, w)
			for x in [5.0, 7.5, 10.0, 12.5, 15.0]:
				c.draw_line(P.call(x, 11), P.call(x, 4 if x > 6 and x < 14 else 7), col, w)
			c.draw_line(P.call(4.5, 11), P.call(4.5, 14), col, w)
			c.draw_line(P.call(15.5, 11), P.call(15.5, 14), col, w)
			c.draw_line(P.call(4.5, 14), P.call(7, 18), col, w)
			c.draw_line(P.call(15.5, 14), P.call(13, 18), col, w)
		"tracado":
			c.draw_line(P.call(4, 15), P.call(10, 6), azul, w)
			c.draw_line(P.call(10, 6), P.call(16, 13), azul, w)
			for p in [Vector2(4, 15), Vector2(10, 6), Vector2(16, 13)]:
				c.draw_circle(P.call(p.x, p.y), 2.3 * s, Color.WHITE)
				c.draw_arc(P.call(p.x, p.y), 2.3 * s, 0, TAU, 12, azul, w)
		"planilhas":
			_grade(c, P, s, Rect2(2, 3, 16, 14), col, w)
			c.draw_rect(Rect2(P.call(2, 3), Vector2(16, 3.5) * s), azul)
		"calculo":
			c.draw_colored_polygon(PackedVector2Array([P.call(5, 3), P.call(17, 10), P.call(5, 17)]), verde)
		"apaga":
			c.draw_colored_polygon(PackedVector2Array([P.call(3, 13), P.call(11, 4), P.call(17, 9), P.call(10, 17), P.call(6, 17)]), Color(0.95, 0.6, 0.65))
			c.draw_polyline(PackedVector2Array([P.call(3, 13), P.call(11, 4), P.call(17, 9), P.call(10, 17), P.call(6, 17), P.call(3, 13)]), col, w)
			c.draw_line(P.call(7, 9), P.call(13, 14), col, w)
		"desmarca":
			c.draw_rect(Rect2(P.call(2, 2), Vector2(10, 10) * s), verm, false, w)
			c.draw_rect(Rect2(P.call(8, 8), Vector2(10, 10) * s), azul, false, w)
		"desloca":
			c.draw_line(P.call(3, 3), P.call(3, 17), verm, w)
			c.draw_line(P.call(17, 3), P.call(17, 17), azul, w)
			c.draw_line(P.call(4, 10), P.call(15, 10), azul, w)
			c.draw_colored_polygon(PackedVector2Array([P.call(16, 10), P.call(12, 7), P.call(12, 13)]), azul)
		"divide":
			c.draw_line(P.call(2, 15), P.call(18, 5), azul, w)
			c.draw_circle(P.call(2.5, 15), 2 * s, azul)
			c.draw_circle(P.call(17.5, 5), 2 * s, azul)
			c.draw_circle(P.call(10, 10), 2.5 * s, Color.WHITE)
			c.draw_arc(P.call(10, 10), 2.5 * s, 0, TAU, 12, verm, w)
		"perfil":
			c.draw_line(P.call(3, 3), P.call(3, 17), col, w)
			c.draw_line(P.call(3, 17), P.call(18, 17), col, w)
			c.draw_polyline(PackedVector2Array([P.call(4, 7), P.call(9, 9), P.call(13, 6), P.call(18, 5)]), Color(0.6, 0.1, 0.1), w)
			c.draw_polyline(PackedVector2Array([P.call(4, 11), P.call(18, 9)]), azul, w)
		"obs":
			var f := ThemeDB.fallback_font
			c.draw_string(f, P.call(1, 14), "OBS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * s), azul)


static func _grade(c: CanvasItem, P: Callable, s: float, r: Rect2, col: Color, w: float) -> void:
	c.draw_rect(Rect2(P.call(r.position.x, r.position.y), r.size * s), Color.WHITE)
	c.draw_rect(Rect2(P.call(r.position.x, r.position.y), r.size * s), col, false, w)
	for k in range(1, 4):
		var y := r.position.y + r.size.y * k / 4.0
		c.draw_line(P.call(r.position.x, y), P.call(r.end.x, y), col, w * 0.6)
	var x := r.position.x + r.size.x / 2.0
	c.draw_line(P.call(x, r.position.y), P.call(x, r.end.y), col, w * 0.6)
