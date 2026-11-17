extends SceneTree
## Chave de assinatura das atualizações (docs/ATUALIZACAO.md).
## Rodar com o projeto do app (--path app), por exemplo:
##   godot --headless --path app --script ../tools/chave_atualizacao.gd -- gerar <privada.pem> <publica.pem>
##   godot --headless --path app --script ../tools/chave_atualizacao.gd -- assinar <privada.pem> <arquivo> <arquivo.sig>
##   godot --headless --path app --script ../tools/chave_atualizacao.gd -- conferir <manifesto> <manifesto.sig> <versao> <pasta>
## "conferir" usa a CHAVE_PUBLICA embutida no app (a mesma que o programa instalado usa)
## e confere tamanho e SHA-256 de cada pacote listado no manifesto, na pasta indicada.

const Atualizador = preload("res://atualizador.gd")


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var rc := 2
	if a.size() >= 3 and a[0] == "gerar":
		rc = _gerar(a[1], a[2])
	elif a.size() >= 4 and a[0] == "assinar":
		rc = _assinar(a[1], a[2], a[3])
	elif a.size() >= 5 and a[0] == "conferir":
		rc = _conferir(a[1], a[2], a[3], a[4])
	else:
		printerr("uso: gerar <privada> <publica> | assinar <privada> <arquivo> <sig> | conferir <manifesto> <sig> <versao> <pasta>")
	quit(rc)


func _gerar(priv: String, pub: String) -> int:
	if FileAccess.file_exists(priv):
		printerr("já existe uma chave em %s; não vou sobrescrever." % priv)
		return 1
	var k := Crypto.new().generate_rsa(3072)
	if k.save(priv) != OK or k.save(pub, true) != OK:
		printerr("não foi possível gravar a chave")
		return 1
	FileAccess.set_unix_permissions(priv, 384) # 0600
	print("chave privada: %s\nchave pública: %s" % [priv, pub])
	return 0


func _assinar(priv: String, arq: String, sig: String) -> int:
	var k := CryptoKey.new()
	if k.load(priv) != OK:
		printerr("chave privada ilegível: " + priv)
		return 1
	var dados := FileAccess.get_file_as_bytes(arq)
	if dados.is_empty():
		printerr("arquivo vazio ou ilegível: " + arq)
		return 1
	var s := Atualizador.assinar(dados, k)
	var f := FileAccess.open(sig, FileAccess.WRITE)
	if f == null or s.is_empty():
		printerr("não foi possível assinar")
		return 1
	f.store_buffer(s)
	f.close()
	print("assinatura: " + sig)
	return 0


func _conferir(man: String, sig: String, versao: String, pasta: String) -> int:
	var rc := 0
	for plat in ["windows", "linux"]:
		var r := Atualizador.verificar_manifesto(FileAccess.get_file_as_bytes(man), FileAccess.get_file_as_bytes(sig),
			Atualizador.CHAVE_PUBLICA, versao, "0.0.0", plat)
		if not r["ok"]:
			if str(r["motivo"]).contains("não tem pacote"):
				continue
			printerr("%s: RECUSADO — %s" % [plat, r["motivo"]])
			return 1
		var it: Dictionary = r["item"]
		var p := pasta.path_join(str(it["arquivo"]))
		var tam := FileAccess.open(p, FileAccess.READ)
		var ok_tam := tam != null and tam.get_length() == int(it["tamanho"])
		tam = null
		var ok_sha := Atualizador.sha256_arquivo(p) == str(it["sha256"])
		print("%s: assinatura ok, tamanho %s, SHA-256 %s" % [plat, "ok" if ok_tam else "DIFERENTE", "ok" if ok_sha else "DIFERENTE"])
		if not (ok_tam and ok_sha):
			rc = 1
	return rc
