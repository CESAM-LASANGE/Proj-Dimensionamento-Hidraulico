extends SceneTree
## Partes que precisam de renderização (janela real; o runner só executa havendo display):
##   --fase=3 → T3-05: interferências visíveis na planta (pixels com a cor da camada)
##   --fase=4 → T4-05: exportação do perfil em PNG
##   --fase=5 → T5-07: tempo de redraw da planta com a rede grande

const Lib = preload("lib.gd")
const Net = preload("res://net.gd")

var T
var m


func _initialize() -> void:
	var fase := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--fase="):
			fase = str(a).substr(7)
	T = Lib.new()
	m = await T.novo_main(self)
	print("META|" + JSON.stringify(T.meta(m)))
	match fase:
		"3":
			await _t305()
		"4":
			await _t405()
		"5":
			await _t507()
	quit(T.fim())


func _frames(n := 4) -> void:
	for _k in n:
		await RenderingServer.frame_post_draw


func _cor_perto(a: Color, b: Color, tol := 0.12) -> bool:
	return absf(a.r - b.r) < tol and absf(a.g - b.g) < tol and absf(a.b - b.b) < tol


func _t305() -> void:
	var id := "T3-05"
	m._novo()
	m.proj["area"] = {"e0": -10.0, "n0": -10.0, "le": 120.0, "ln": 120.0, "grid": 50.0}
	m.importar_interferencias(T.fix("interferencias_phase3.geojson"))
	m._mostrar("tracado")
	m.plan.ajustar(Rect2(0, 0, 100, 100), false)
	await _frames()
	var img := root.get_texture().get_image()
	var origem: Vector2 = m.plan.get_global_rect().position
	var cores := [m.plan.CORES_CAMADA[0], m.plan.CORES_CAMADA[1]]
	var linhas := [[Vector2(10, 20), Vector2(90, 20)], [Vector2(20, 80), Vector2(80, 80)]]
	for k in 2:
		var achou := 0
		for i in 60:
			var w: Vector2 = linhas[k][0].lerp(linhas[k][1], 0.2 + 0.6 * i / 59.0)
			var s: Vector2 = m.plan.w2s(w) + origem
			for dy in [-1, 0, 1]:
				var px := Vector2i(int(s.x), int(s.y) + dy)
				if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height() and _cor_perto(img.get_pixelv(px), cores[k]):
					achou += 1
					break
		T.check(id, achou >= 15, "camada %s visível na planta (%d de 60 pontos da linha com a cor da camada)" % [["AGUA_EXISTENTE", "DRENAGEM"][k], achou])


func _t405() -> void:
	var id := "T4-05"
	m.executar_calculo(false)
	var rows: Array = []
	for sq in Net.sequencias(m.proj):
		if str(sq["nome"]) == "C1":
			for tid in sq["trechos"]:
				if rows.size() < 3:
					rows.append(m.results["rows"][tid])
	var arq: String = T.tmp("perfil.png")
	var r: Dictionary = await m.exportar_perfil_png(rows, "Perfil — teste", arq)
	var img := Image.load_from_file(arq) if FileAccess.file_exists(arq) else null
	T.check(id, bool(r.get("ok", false)) and img != null and img.get_size() == Vector2i(1600, 900), "perfil exportado em PNG (%s)" % str(img.get_size() if img else "sem arquivo"))
	if img == null:
		return
	var terreno := 0
	var tubo := 0
	for y in range(0, 900, 2):
		for x in range(0, 1600, 2):
			var c := img.get_pixel(x, y)
			if _cor_perto(c, Color(0.55, 0.08, 0.08), 0.1):
				terreno += 1
			elif c.r < 0.12 and c.g < 0.12 and c.b < 0.12:
				tubo += 1
	T.check(id, terreno > 100 and tubo > 100, "PNG contém terreno (%d px) e tubo/textos (%d px)" % [terreno, tubo])


func _t507() -> void:
	var id := "T5-07"
	T.gerar_rede_grande(m)
	m.executar_calculo(false)
	m._mostrar("tracado")
	m.plan.ajuste_maximo()
	await _frames(3)
	var pior := 0
	for _k in 3:
		var t0 := Time.get_ticks_msec()
		m.plan.redesenhar()
		await RenderingServer.frame_post_draw
		pior = maxi(pior, Time.get_ticks_msec() - t0)
	T.dado(id, "redraw_ms", pior)
	T.check(id, pior <= 3000, "redraw da planta com %d trechos: %d ms (limite 3000 ms)" % [m.proj["trechos"].size(), pior])
