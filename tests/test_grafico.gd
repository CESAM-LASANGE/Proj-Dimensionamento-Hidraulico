extends SceneTree
## Partes que precisam de renderização (janela real; o runner só executa havendo display):
##   --fase=3 → T3-05: interferências visíveis na planta (pixels com a cor da camada)
##   --fase=4 → T4-05: exportação do perfil em PNG
##   --fase=5 → T5-07: tempo de redraw da planta com a rede grande
##   --fase=6 → T6-08: colunas fixas desenhadas na planilha de resultados rolada para a direita
##   --fase=7 → T7-01 / T7-02: círculo do raio de busca e marcador do osnap desenhados na planta

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
		"6":
			await _t608()
		"7":
			await _t7()
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


func _t608() -> void:
	var id := "T6-08"
	m._do_action("exemplo")
	root.size = Vector2i(1000, 700)
	m._mostrar("planilhas")
	m.sheets.current_tab = 4
	await _frames(4)
	var gt = m.tables["res"]
	var hs = gt._scrollbars()[1]
	hs.value = 400.0
	await _frames(4)
	var img := root.get_texture().get_image()
	var o: Vector2 = gt._fixas.get_global_rect().position
	var larg: float = gt.largura_fixas()
	o.x += float(gt.fixas_info()["margem"])
	var x := int(o.x + larg + 1.0)
	var borda := 0
	var total := 0
	for y in range(int(o.y), int(o.y + gt._fixas.size.y) - 2, 2):
		total += 1
		if x < img.get_width() and _cor_perto(img.get_pixel(x, y), Color(0.35, 0.4, 0.5), 0.15):
			borda += 1
	T.check(id, total > 0 and borda >= total * 0.8, "borda da faixa fixa desenhada na tela (%d de %d pontos)" % [borda, total])
	var escuros := 0
	var claros := 0
	var amostra := 0
	for y in range(int(o.y) + 60, int(o.y + gt._fixas.size.y) - 2, 2):
		for xx in range(int(o.x), int(o.x + larg), 2):
			amostra += 1
			var v := img.get_pixel(xx, y).v
			if v < 0.35:
				escuros += 1
			elif v > 0.85:
				claros += 1
	T.check(id, amostra > 0 and claros >= amostra * 0.6, "células da faixa fixa com o fundo da planilha (%d%% de pixels claros)" % (100 * claros / maxi(amostra, 1)))
	T.check(id, escuros > 40 and escuros < amostra * 0.25, "textos das colunas fixas visíveis por cima das colunas roladas (%d px escuros)" % escuros)
	root.size = Vector2i(1366, 820)


func _t7() -> void:
	m._novo()
	m.proj["area"] = {"e0": -100.0, "n0": -100.0, "le": 500.0, "ln": 300.0, "grid": 50.0}
	var cs: Array = []
	for k in range(-5, 16):
		cs.append({"z": 100.0 + k, "pts": PackedVector2Array([Vector2(-100, 10.0 * k), Vector2(400, 10.0 * k)])})
	m.topo.set_curvas(cs)
	m.topo.set_pontos([Vector3(200.0, 33.0, 123.45)])
	m.proj["topo"] = m.topo.to_dict()
	m.opts.merge({"cota_modo": "int", "raio": 60.0, "osnap": true, "orto": false, "rastro": true, "topo_desenho": 0, "pontos_desenho": true}, true)
	m._mostrar("tracado")
	var p = m.plan
	p.scale_px = 4.0
	p.center = Vector2(100, 40)
	var mv := InputEventMouseMotion.new()
	mv.position = p.w2s(Vector2(60, 25))
	p._gui_input(mv)
	p._right_press(p.w2s(Vector2(0, 25)), false)
	var img: Image
	var o: Vector2 = p.get_global_rect().position
	var centro: Vector2 = p.w2s(Vector2(60, 25))
	var no_circulo := 0
	var amostras := 0
	# Um movimento real do mouse sobre a janela durante a captura tira o cursor
	# do lugar; o movimento é reinjetado a cada tentativa (critério inalterado).
	for tentativa in 3:
		p._gui_input(mv)
		await _frames(4)
		img = root.get_texture().get_image()
		no_circulo = _pontos_circulo(img, p, o, centro)
		amostras = _amostras_circulo(p, o, centro)
		if amostras > 10 and no_circulo >= amostras * 0.6:
			break
	T.check("T7-01", amostras > 10 and no_circulo >= amostras * 0.6, "círculo do raio de busca (60 m) desenhado em volta do cursor (%d de %d pontos)" % [no_circulo, amostras])
	mv.position = p.w2s(Vector2(201.5, 33.5))
	var pc: Vector2 = p.w2s(Vector2(200, 33)) + o
	var verdes := 0
	for tentativa in 3:
		p._gui_input(mv)
		await _frames(4)
		img = root.get_texture().get_image()
		verdes = 0
		for dx in range(-9, 10):
			for dy in range(-9, 10):
				if _cor_perto(img.get_pixel(int(pc.x) + dx, int(pc.y) + dy), Color(0.0, 0.62, 0.2), 0.15):
					verdes += 1
		if verdes > 8:
			break
	T.check("T7-02", verdes > 8, "marcador verde do osnap desenhado sobre o ponto cotado (%d px)" % verdes)
	p.cancelar()


func _amostras_circulo(p, o: Vector2, centro: Vector2) -> int:
	var n := 0
	for k in 72:
		var q: Vector2 = centro + Vector2(cos(TAU * k / 72.0), sin(TAU * k / 72.0)) * 240.0 + o
		if not (q.x < o.x + 2 or q.y < o.y + 2 or q.x > o.x + p.size.x - 2 or q.y > o.y + p.size.y - 2):
			n += 1
	return n


func _pontos_circulo(img: Image, p, o: Vector2, centro: Vector2) -> int:
	var no_circulo := 0
	for k in 72:
		var a := TAU * k / 72.0
		var q: Vector2 = centro + Vector2(cos(a), sin(a)) * 240.0 + o
		if q.x < o.x + 2 or q.y < o.y + 2 or q.x > o.x + p.size.x - 2 or q.y > o.y + p.size.y - 2:
			continue
		var achou := false
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var c := img.get_pixel(int(q.x) + dx, int(q.y) + dy)
				if c.b > c.r + 0.2 and c.b > 0.6:
					achou = true
		if achou:
			no_circulo += 1
	return no_circulo
