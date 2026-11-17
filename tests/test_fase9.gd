extends SceneTree
## Fase 9 — atualização automática (tests/PHASE-9.md, docs/ATUALIZACAO.md).
##   T9-01 comparação de versões             T9-02 escolha do release
##   T9-03 manifesto assinado                T9-04 troca do executável no disco
##   T9-05 fluxo completo por HTTP           T9-06 interface (menu, opção, janelas)
##   T9-07 pacote de release assinado        (T9-08, regressão das fases 0–8, é do runner)
## O T9-05 e parte do T9-06 usam o servidor HTTP local que o runner sobe
## (DIMESGOTO_TESTE_HTTP / DIMESGOTO_TESTE_WWW); sem ele, esses casos saem SKIP.

const Lib = preload("lib.gd")
const Atu = preload("res://atualizador.gd")
const NOVA_UI := "99.0.0-teste.1"

var T
var m
var chave: CryptoKey
var chave_pub := ""
var outra: CryptoKey
var base := ""
var www := ""


func _initialize() -> void:
	T = Lib.new()
	m = await T.novo_main(self)
	print("META|" + JSON.stringify(T.meta(m)))
	var c := Crypto.new()
	chave = c.generate_rsa(2048)
	chave_pub = chave.save_to_string(true)
	outra = c.generate_rsa(2048)
	base = OS.get_environment("DIMESGOTO_TESTE_HTTP")
	www = OS.get_environment("DIMESGOTO_TESTE_WWW")
	_t901()
	_t902()
	_t903()
	_t904()
	await _t905()
	await _t906()
	_t907()
	quit(T.fim())


# ------------------------------------------------------------------ utilidades

func _manifesto(versao: String, plats: Dictionary) -> PackedByteArray:
	return JSON.stringify({"formato": "dimesgoto-atualizacao", "versao_formato": 1, "versao": versao,
		"plataformas": plats}, "  ").to_utf8_buffer()


func _item(arquivo: String, conteudo: PackedByteArray, exe := "DimEsgoto-x/DimEsgoto.exe") -> Dictionary:
	return {"arquivo": arquivo, "sha256": Atu.sha256_bytes(conteudo).hex_encode(), "tamanho": conteudo.size(),
		"executavel": exe}


func _zip(path: String, interno: String, dados: PackedByteArray) -> void:
	var z := ZIPPacker.new()
	z.open(path)
	z.start_file(interno)
	z.write_file(dados)
	z.close_file()
	z.close()


func _gravar(path: String, dados: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(dados)
	f.close()


func _ler(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _rel(tag: String, pre := false, rascunho := false, com_manifesto := true) -> Dictionary:
	var assets: Array = [{"name": "DimEsgoto-%s-windows-x86_64.zip" % tag.trim_prefix("v"), "browser_download_url": "https://x/z"}]
	if com_manifesto:
		assets.append({"name": Atu.MANIFESTO, "browser_download_url": "https://x/m"})
		assets.append({"name": Atu.ASSINATURA, "browser_download_url": "https://x/s"})
	return {"tag_name": tag, "prerelease": pre, "draft": rascunho, "assets": assets, "body": "notas " + tag,
		"html_url": "https://github.com/x/releases/tag/" + tag}


# ------------------------------------------------------------------ T9-01

func _t901() -> void:
	var menor := [
		["0.1.0-alpha", "0.2.0-alpha"], ["0.2.0-alpha", "0.3.0-alpha.1"], ["0.3.0-alpha.1", "0.3.0-alpha.2"],
		["0.3.0-alpha.2", "0.3.0-alpha.10"], ["0.3.0-alpha.10", "0.3.0-beta"], ["0.3.0-beta", "0.3.0"],
		["0.3.0", "0.3.1"], ["0.9.9", "0.10.0"], ["1.0.0-alpha", "1.0.0-alpha.1"], ["0.3.0-1", "0.3.0-alpha"],
	]
	var ok := true
	for p in menor:
		if Atu.comparar_versoes(p[0], p[1]) != -1 or Atu.comparar_versoes(p[1], p[0]) != 1:
			ok = false
			T.check("T9-01", false, "%s < %s" % p)
	T.check("T9-01", ok, "%d pares em ordem SemVer (inclui alpha.2 < alpha.10 < beta < final)" % menor.size())
	T.check("T9-01", Atu.comparar_versoes("v0.3.0-alpha.1", "0.3.0-alpha.1") == 0 and Atu.comparar_versoes("0.3.0+build5", "0.3.0") == 0,
		"prefixo v e metadados (+...) não mudam a versão")
	T.check("T9-01", Atu.versao_valida("v0.3.0-alpha.1") and not Atu.versao_valida("versao-nova") and not Atu.versao_valida("0.3"),
		"tag sem versão válida é reconhecida")
	T.check("T9-01", Atu.comparar_versoes(m.VERSAO, ProjectSettings.get_setting("application/config/version")) == 0,
		"VERSAO do programa (%s) = versão do project.godot" % m.VERSAO)


# ------------------------------------------------------------------ T9-02

func _t902() -> void:
	var lista := [_rel("v0.1.0-alpha"), _rel("v0.3.0-alpha.1", true), _rel("v0.3.0-alpha.2", true, true),
		_rel("v0.2.5-alpha"), _rel("v9.0.0", false, false, false), _rel("nightly"), "lixo"]
	var r := Atu.escolher_release(lista, "0.2.0-alpha")
	T.check("T9-02", str(r.get("versao", "")) == "0.3.0-alpha.1",
		"escolhe a maior versão publicada com manifesto: %s (ignora rascunho, release sem manifesto e tag inválida)" % r.get("versao", "—"))
	T.check("T9-02", r.get("assets", {}).has(Atu.MANIFESTO) and str(r.get("notas", "")) == "notas v0.3.0-alpha.1" and bool(r.get("teste")),
		"traz os arquivos, as notas e a marca de versão de teste")
	var s := Atu.escolher_release(lista, "0.2.0-alpha", false)
	T.check("T9-02", str(s.get("versao", "")) == "0.2.5-alpha", "sem versões de teste: fica com a 0.2.5-alpha")
	T.check("T9-02", Atu.escolher_release(lista, "0.3.0-alpha.1").is_empty(), "na versão mais nova: nada a atualizar")
	T.check("T9-02", Atu.escolher_release(lista, "1.0.0").is_empty(), "nunca volta para uma versão mais antiga")
	T.check("T9-02", Atu.escolher_release({"message": "API rate limit exceeded"}, "0.1.0").is_empty() and Atu.escolher_release(null, "0.1.0").is_empty(),
		"resposta que não é lista (erro da API) não quebra")


# ------------------------------------------------------------------ T9-03

func _t903() -> void:
	var it := _item("pacote.zip", "conteudo".to_utf8_buffer())
	var man := _manifesto("0.3.0-alpha.1", {"windows": it, "linux": it})
	var sig := Atu.assinar(man, chave)
	var r := Atu.verificar_manifesto(man, sig, chave_pub, "0.3.0-alpha.1", "0.2.0-alpha", "windows")
	T.check("T9-03", r["ok"] and str(r["item"]["sha256"]) == str(it["sha256"]), "manifesto assinado e coerente: aceito")
	var mexido := man.duplicate()
	mexido[mexido.size() / 2] = (mexido[mexido.size() / 2] + 1) % 256
	r = Atu.verificar_manifesto(mexido, sig, chave_pub, "0.3.0-alpha.1", "0.2.0-alpha", "windows")
	T.check("T9-03", not r["ok"] and str(r["motivo"]).contains("assinatura"), "1 byte alterado no manifesto: recusado (%s)" % r["motivo"])
	r = Atu.verificar_manifesto(man, Atu.assinar(man, outra), chave_pub, "0.3.0-alpha.1", "0.2.0-alpha", "windows")
	T.check("T9-03", not r["ok"] and str(r["motivo"]).contains("assinatura"), "assinado com outra chave: recusado")
	r = Atu.verificar_manifesto(man, PackedByteArray(), chave_pub, "0.3.0-alpha.1", "0.2.0-alpha", "windows")
	T.check("T9-03", not r["ok"], "sem assinatura: recusado")
	r = Atu.verificar_manifesto(man, sig, chave_pub, "0.3.0-alpha.2", "0.2.0-alpha", "windows")
	T.check("T9-03", not r["ok"] and str(r["motivo"]).contains("release"), "manifesto de outra versão que a do release: recusado")
	r = Atu.verificar_manifesto(man, sig, chave_pub, "0.3.0-alpha.1", "0.3.0-alpha.1", "windows")
	T.check("T9-03", not r["ok"], "manifesto antigo (não mais novo que a instalada): recusado")
	r = Atu.verificar_manifesto(man, sig, chave_pub, "0.3.0-alpha.1", "0.2.0-alpha", "macos")
	T.check("T9-03", not r["ok"] and str(r["motivo"]).contains("pacote"), "sem pacote da plataforma: recusado")
	var ruim := _manifesto("0.3.0-alpha.1", {"windows": {"arquivo": "../x.zip", "sha256": "abc", "tamanho": 0, "executavel": "x"}})
	r = Atu.verificar_manifesto(ruim, Atu.assinar(ruim, chave), chave_pub, "0.3.0-alpha.1", "0.2.0-alpha", "windows")
	T.check("T9-03", not r["ok"], "pacote com SHA-256, tamanho ou caminho inválido: recusado mesmo assinado")
	var k := CryptoKey.new()
	var pem_arq := _ler(T.DIR.get_base_dir().path_join("tools/chave-atualizacao-publica.pem"))
	T.check("T9-03", k.load_from_string(Atu.CHAVE_PUBLICA, true) == OK and pem_arq.strip_edges() == Atu.CHAVE_PUBLICA.strip_edges(),
		"a chave pública embutida é válida e igual a tools/chave-atualizacao-publica.pem")


# ------------------------------------------------------------------ T9-04

func _t904() -> void:
	var dir: String = T.tmp("atu_disco")
	DirAccess.make_dir_recursive_absolute(dir)
	var exe := dir.path_join("DimEsgoto.exe")
	for suf in ["", ".old", ".novo"]:
		DirAccess.remove_absolute(exe + suf)
	_gravar(exe, "VERSAO VELHA".to_utf8_buffer())
	var zip := dir.path_join("p.zip")
	var novo_bytes := "VERSAO NOVA".to_utf8_buffer()
	_zip(zip, "DimEsgoto-x/DimEsgoto.exe", novo_bytes)
	T.check("T9-04", Atu.extrair(zip, "DimEsgoto-x/Outro.exe", exe + ".novo").contains("não contém"), "zip sem o executável esperado: erro claro")
	T.check("T9-04", Atu.extrair(dir.path_join("nao-existe.zip"), "x", exe + ".novo") != "", "zip inexistente: erro claro")
	var e := Atu.extrair(zip, "DimEsgoto-x/DimEsgoto.exe", exe + ".novo")
	T.check("T9-04", e == "" and _ler(exe + ".novo") == "VERSAO NOVA", "executável extraído do zip")
	if OS.get_name() != "Windows":
		T.check("T9-04", (FileAccess.get_unix_permissions(exe + ".novo") & FileAccess.UNIX_EXECUTE_OWNER) != 0,
			"no Linux, o executável novo tem permissão de execução")
	var r := Atu.instalar(exe + ".novo", exe)
	T.check("T9-04", r["ok"] and _ler(exe) == "VERSAO NOVA" and _ler(exe + ".old") == "VERSAO VELHA" and not FileAccess.file_exists(exe + ".novo"),
		"troca: o novo fica no lugar, o antigo vira .old")
	r = Atu.instalar(exe + ".novo", exe)
	T.check("T9-04", not r["ok"] and _ler(exe) == "VERSAO NOVA", "sem arquivo novo: nada muda")
	T.check("T9-04", Atu.limpar_antigo(exe) == 1 and not FileAccess.file_exists(exe + ".old") and _ler(exe) == "VERSAO NOVA",
		"ao abrir de novo, o .old é apagado e o executável fica")
	T.check("T9-04", Atu.sha256_arquivo(exe) == Atu.sha256_bytes(novo_bytes).hex_encode() and Atu.sha256_arquivo(dir.path_join("x")) == "",
		"SHA-256 do arquivo confere com o dos bytes")


# ------------------------------------------------------------------ T9-05 (HTTP local)

## Publica no servidor local um "GitHub" com os releases dados. Cada release é
## [tag, prerelease, plataformas{plat: bytes do executável}] e ganha zip, manifesto e assinatura.
func _publicar(releases: Array, chave_assina: CryptoKey = null) -> void:
	var lista: Array = []
	for rel in releases:
		var tag: String = rel[0]
		var v := tag.trim_prefix("v")
		var pasta := www.path_join(tag)
		DirAccess.make_dir_recursive_absolute(pasta)
		var plats := {}
		var assets: Array = []
		for plat in rel[2]:
			var nome := "DimEsgoto-%s-%s-x86_64.zip" % [v, plat]
			var interno := "DimEsgoto-%s/%s" % [v, "DimEsgoto.exe" if plat == "windows" else "DimEsgoto.x86_64"]
			_zip(pasta.path_join(nome), interno, rel[2][plat])
			var zb := FileAccess.get_file_as_bytes(pasta.path_join(nome))
			plats[plat] = _item(nome, zb, interno)
			assets.append({"name": nome, "browser_download_url": base + tag + "/" + nome})
		var man := _manifesto(v, plats)
		_gravar(pasta.path_join(Atu.MANIFESTO), man)
		_gravar(pasta.path_join(Atu.ASSINATURA), Atu.assinar(man, chave_assina if chave_assina != null else chave))
		assets.append({"name": Atu.MANIFESTO, "browser_download_url": base + tag + "/" + Atu.MANIFESTO})
		assets.append({"name": Atu.ASSINATURA, "browser_download_url": base + tag + "/" + Atu.ASSINATURA})
		lista.append({"tag_name": tag, "prerelease": rel[1], "draft": false, "assets": assets,
			"body": "Novidades da %s" % v, "html_url": base + tag + "/"})
	_gravar(www.path_join("releases.json"), JSON.stringify(lista).to_utf8_buffer())


func _novo_atu(atual := "0.2.0-alpha") -> Node:
	var a: Node = Atu.new()
	root.add_child(a)
	a.api_url = base + "releases.json"
	a.chave_publica = chave_pub
	a.versao_atual = atual
	a.plataforma_atual = "windows"
	a.pasta_tmp = T.tmp("atu_baixados")
	a.timeout_s = 10.0
	return a


func _exe_teste(nome: String) -> String:
	var dir: String = T.tmp("atu_http")
	DirAccess.make_dir_recursive_absolute(dir)
	var exe := dir.path_join(nome)
	for suf in ["", ".old", ".novo"]:
		DirAccess.remove_absolute(exe + suf)
	_gravar(exe, "INSTALADA 0.2.0".to_utf8_buffer())
	return exe


func _t905() -> void:
	if base == "" or www == "":
		T.skip("T9-05", "sem servidor HTTP local (rode pelo tests/run_tests.py)")
		return
	var novo := "EXECUTAVEL 0.3.0-alpha.1".to_utf8_buffer()
	_publicar([["v0.1.0-alpha", false, {"windows": "antigo".to_utf8_buffer()}],
		["v0.3.0-alpha.1", true, {"windows": novo, "linux": "linux".to_utf8_buffer()}]])
	var a := _novo_atu()
	var r: Dictionary = await a.verificar()
	T.check("T9-05", str(r.get("estado")) == "disponivel" and str(r.get("versao")) == "0.3.0-alpha.1",
		"verificar: versão 0.3.0-alpha.1 disponível (%s %s)" % [r.get("estado"), r.get("motivo", "")])
	T.check("T9-05", str(r.get("notas", "")) == "Novidades da 0.3.0-alpha.1", "traz as notas do release")
	var exe := _exe_teste("DimEsgoto.exe")
	a.exe_atual = exe
	var b: Dictionary = await a.baixar_e_instalar(r)
	T.check("T9-05", b["ok"] and _ler(exe) == "EXECUTAVEL 0.3.0-alpha.1" and _ler(exe + ".old") == "INSTALADA 0.2.0",
		"baixar e instalar: executável trocado, antigo guardado como .old (%s)" % b.get("motivo", ""))
	T.check("T9-05", not FileAccess.file_exists(exe + ".novo") and DirAccess.get_files_at(ProjectSettings.globalize_path(a.pasta_tmp)).is_empty(),
		"sem sobras: .novo e zip baixado removidos")
	a.aceitar_teste = false
	r = await a.verificar()
	T.check("T9-05", str(r.get("estado")) == "atualizado", "sem versões de teste: a 0.1.0 (mais antiga) não é oferecida")
	a.aceitar_teste = true
	a.versao_atual = "0.3.0-alpha.1"
	r = await a.verificar()
	T.check("T9-05", str(r.get("estado")) == "atualizado", "já na versão mais nova: \"atualizado\"")
	# pacote adulterado no servidor (mesmo tamanho, outro conteúdo)
	a.versao_atual = "0.2.0-alpha"
	r = await a.verificar()
	var zip_srv := www.path_join("v0.3.0-alpha.1/DimEsgoto-0.3.0-alpha.1-windows-x86_64.zip")
	var zb := FileAccess.get_file_as_bytes(zip_srv)
	zb[zb.size() - 30] = (zb[zb.size() - 30] + 7) % 256
	_gravar(zip_srv, zb)
	exe = _exe_teste("Adulterado.exe")
	a.exe_atual = exe
	b = await a.baixar_e_instalar(r)
	T.check("T9-05", not b["ok"] and str(b["motivo"]).contains("SHA-256") and _ler(exe) == "INSTALADA 0.2.0" and not FileAccess.file_exists(exe + ".old"),
		"pacote adulterado: recusado pelo SHA-256, executável intacto (%s)" % b.get("motivo", ""))
	# assinatura de outra chave
	_publicar([["v0.3.0-alpha.1", true, {"windows": novo}]], outra)
	r = await a.verificar()
	T.check("T9-05", str(r.get("estado")) == "erro" and str(r.get("motivo")).contains("assinatura"),
		"manifesto assinado por outra chave: recusado antes de baixar o pacote")
	# erros de rede
	a.api_url = base + "nao-existe.json"
	r = await a.verificar()
	T.check("T9-05", str(r.get("estado")) == "erro" and str(r.get("motivo")).contains("404"), "API com 404: erro tratado (%s)" % r.get("motivo"))
	a.api_url = "http://127.0.0.1:9/releases.json"
	var t0 := Time.get_ticks_msec()
	r = await a.verificar()
	T.check("T9-05", str(r.get("estado")) == "erro" and Time.get_ticks_msec() - t0 < 15000,
		"servidor fora do ar: erro tratado em %d ms (%s)" % [Time.get_ticks_msec() - t0, r.get("motivo")])
	# rodando pelo editor (sem exe_atual): nunca troca o binário do Godot
	_publicar([["v0.3.0-alpha.1", true, {"windows": novo}]])
	a.api_url = base + "releases.json"
	a.exe_atual = ""
	r = await a.verificar()
	var godot_antes := Atu.sha256_arquivo(OS.get_executable_path())
	b = await a.baixar_e_instalar(r)
	T.check("T9-05", not b["ok"] and str(b["motivo"]).contains("programa instalado") and Atu.sha256_arquivo(OS.get_executable_path()) == godot_antes,
		"fora do programa exportado: recusa instalar (o Godot não é tocado)")
	a.queue_free()


# ------------------------------------------------------------------ T9-06 (interface)

func _t906() -> void:
	var pm: PopupMenu = m.menus.get("Ajuda")
	var i74: int = pm.get_item_index(74) if pm else -1
	var i75: int = pm.get_item_index(75) if pm else -1
	T.check("T9-06", i74 >= 0 and pm.get_item_text(i74) == "Verificar atualizações…", "Ajuda › Verificar atualizações…")
	T.check("T9-06", i75 >= 0 and pm.is_item_checkable(i75) and pm.is_item_checked(i75) and bool(m.opts.get("verificar_atualizacoes", false)),
		"Ajuda › Verificar atualizações ao abrir: ligada por padrão")
	if i75 >= 0:
		m._on_menu(75)
		var desl: bool = not bool(m.opts["verificar_atualizacoes"]) and not pm.is_item_checked(i75)
		m._on_menu(75)
		T.check("T9-06", desl and bool(m.opts["verificar_atualizacoes"]) and pm.is_item_checked(i75), "a opção liga e desliga pelo menu")
	T.check("T9-06", m.atualizador != null and str(m.atualizador.versao_atual) == m.VERSAO, "o atualizador conhece a versão do programa")
	T.check("T9-06", not m.deve_verificar_ao_abrir(), "fora do programa exportado (testes, editor), não consulta a internet ao abrir")
	if base == "" or www == "":
		T.skip("T9-06", "janelas de atualização: sem servidor HTTP local")
		return
	var a: Node = m.atualizador
	a.api_url = base + "releases.json"
	a.chave_publica = chave_pub
	a.plataforma_atual = "windows"
	a.pasta_tmp = T.tmp("atu_baixados")
	# versão fictícia sempre acima da do programa (a 0.3.0-alpha.1 virou a própria versão atual)
	_publicar([["v" + NOVA_UI, true, {"windows": "NOVA PELA JANELA".to_utf8_buffer()}]])
	await m.verificar_atualizacao(true)
	var pergunta: ConfirmationDialog = m.find_child("PerguntaAtualizacao", true, false)
	T.check("T9-06", pergunta != null and pergunta.visible and pergunta.dialog_text.contains(NOVA_UI) and pergunta.dialog_text.contains(m.VERSAO)
		and pergunta.get_ok_button().text == "Atualizar agora", "verificação manual: janela com a versão nova, a atual e \"Atualizar agora\"")
	if pergunta:
		pergunta.hide()
	var exe := _exe_teste("PelaJanela.exe")
	a.exe_atual = exe
	await m.instalar_atualizacao(m.atu_info)
	var fim: ConfirmationDialog = m.find_child("AtualizacaoInstalada", true, false)
	T.check("T9-06", _ler(exe) == "NOVA PELA JANELA" and fim != null and fim.visible and fim.get_ok_button().text == "Reiniciar agora",
		"\"Atualizar agora\": baixa, troca e oferece reiniciar")
	if fim:
		fim.hide()
	a.versao_atual = NOVA_UI
	await m.verificar_atualizacao(true)
	T.check("T9-06", m.status_label.text.contains("mais recente"), "já atualizado: a barra de status avisa (%s)" % m.status_label.text)
	a.versao_atual = m.VERSAO
	a.api_url = "http://127.0.0.1:9/releases.json"
	await m.verificar_atualizacao(true)
	var erro: AcceptDialog = m.find_child("AtualizacaoErro", true, false)
	T.check("T9-06", erro != null and erro.visible and erro.dialog_text.contains("conexão") and erro.dialog_text.contains("github.com"),
		"sem conexão na verificação manual: janela com o motivo e o endereço para baixar à mão")
	if erro:
		erro.hide()
	a.exe_atual = ""


# ------------------------------------------------------------------ T9-07

func _t907() -> void:
	var raiz: String = T.DIR.get_base_dir()
	var pasta := raiz.path_join("dist/v" + m.VERSAO)
	var man := pasta.path_join(Atu.MANIFESTO)
	if not FileAccess.file_exists(man):
		T.skip("T9-07", "sem pacote de release desta versão em dist/v%s (rode tools/build_release.py)" % m.VERSAO)
		return
	var bytes := FileAccess.get_file_as_bytes(man)
	var sig := FileAccess.get_file_as_bytes(man + ".sig")
	var n := 0
	for plat in ["windows", "linux"]:
		var r := Atu.verificar_manifesto(bytes, sig, Atu.CHAVE_PUBLICA, m.VERSAO, "0.0.0", plat)
		if not r["ok"] and str(r["motivo"]).contains("não tem pacote"):
			continue
		T.check("T9-07", r["ok"], "%s: manifesto assinado com a chave do programa (%s)" % [plat, r.get("motivo", "")])
		if not r["ok"]:
			continue
		var it: Dictionary = r["item"]
		var zip := pasta.path_join(str(it["arquivo"]))
		T.check("T9-07", Atu.sha256_arquivo(zip) == str(it["sha256"]), "%s: SHA-256 do %s confere" % [plat, it["arquivo"]])
		var z := ZIPReader.new()
		var tem := z.open(zip) == OK and z.get_files().has(str(it["executavel"]))
		z.close()
		T.check("T9-07", tem, "%s: o zip contém %s" % [plat, it["executavel"]])
		n += 1
	T.check("T9-07", n >= 1, "%d plataforma(s) no manifesto da %s" % [n, m.VERSAO])
