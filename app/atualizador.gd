extends Node
## Atualização automática pelos Releases do GitHub (fase 9, tests/PHASE-9.md).
##
## Fluxo:
##   1. lê a lista de releases do repositório (API pública do GitHub);
##   2. escolhe a maior versão acima da atual que publica o manifesto assinado;
##   3. baixa o manifesto (dimesgoto-atualizacao.json) e a assinatura (.sig) e confere a
##      assinatura com a CHAVE_PUBLICA embutida. Sem assinatura válida, nada é baixado;
##   4. baixa o zip da plataforma, confere tamanho e SHA-256 do manifesto e extrai o executável;
##   5. troca o executável: o atual vira <nome>.old (o Windows deixa renomear um .exe em uso)
##      e o novo toma o lugar dele. Se a troca falhar, o original volta. O .old é apagado na
##      próxima vez que o programa abrir.
##
## A chave privada que assina os manifestos NÃO fica no repositório (docs/ATUALIZACAO.md).
## As funções estáticas não usam rede nem interface, e os testes as chamam direto.

const REPO := "CESAM-LASANGE/Proj-Dimensionamento-Hidraulico"
const API_RELEASES := "https://api.github.com/repos/%s/releases?per_page=30"
const MANIFESTO := "dimesgoto-atualizacao.json"
const ASSINATURA := MANIFESTO + ".sig"
const FORMATO := "dimesgoto-atualizacao"
const LIMITE_JSON := 4 * 1024 * 1024
const CHAVE_PUBLICA := """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAxuZWEi3MZkFcbsRAXzcx
H3ri2xE/yPIYASP+bEBlmtnAv1LnVZquuCLWl/emd2O3ZyBWQSJqjcZ6NgaV/b4h
ezQne54m8VHqMOpZRMx07QuQI/uBqYpgVq1UuVO2yuRsfNoy25cOucChDat1mvP6
l5n0JQ5BoztkuX8c0WJzoYvOUPxbSmoTRhu01P7l4InWbvt2g6XnMEYdyJgxqlRL
xyXoSb4gxgOAJ0V5m2uTTckZhI3hzdd9xL7UoJrxfrTHJNUR/q2yLBNasV4Uh3pE
HpAFbRln9W1aJjiVveVX47Mz1Dr2G78slmTGlqPAFY5hfx/qzvQ1ykwQK8nrUw/T
CZ5kdhFlAhl+FjyKIs1p0KnOD+DbYFcO3QUL/RexV3aLCCVdvkdBI8k4xIfHtTbM
eu7C+xHpVsuzxgoP7vdl58ppqP3PYlOdU/XOUQ6v2wGbKQg4Z/RB2hDoVx+aKuAM
pKdJdxEdMByHWuxfM2kgcZReyINaQzCWK++2TT6jCOalAgMBAAE=
-----END PUBLIC KEY-----
"""

var api_url := API_RELEASES % REPO
var chave_publica := CHAVE_PUBLICA
var versao_atual := ""
## Executável que será trocado. Vazio = o próprio programa (só no programa exportado).
var exe_atual := ""
var plataforma_atual := plataforma()
var aceitar_teste := true
var pasta_tmp := "user://atualizacao"
var timeout_s := 30.0
var ocupado := false
## Download em andamento (para a barra de status mostrar o progresso).
var baixando: HTTPRequest = null
var tamanho_esperado := 0


# ------------------------------------------------------------------ versões

static func versao_valida(v: String) -> bool:
	var re := RegEx.create_from_string("^[vV]?\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$")
	return re.search(v.strip_edges()) != null


static func _partes(v: String) -> Array:
	v = v.strip_edges()
	if v.begins_with("v") or v.begins_with("V"):
		v = v.substr(1)
	var mais := v.find("+")
	if mais >= 0:
		v = v.substr(0, mais)
	var pre: Array = []
	var h := v.find("-")
	if h >= 0:
		pre = Array(v.substr(h + 1).split("."))
		v = v.substr(0, h)
	var nums: Array = []
	for s in v.split("."):
		nums.append(int(s) if s.is_valid_int() else 0)
	while nums.size() < 3:
		nums.append(0)
	return [nums, pre]


## Compara duas versões no padrão SemVer (com pré-lançamento: 0.3.0-alpha.1 < 0.3.0-alpha.2 < 0.3.0).
## Devolve -1, 0 ou 1.
static func comparar_versoes(a: String, b: String) -> int:
	var pa := _partes(a)
	var pb := _partes(b)
	for i in 3:
		if pa[0][i] != pb[0][i]:
			return -1 if pa[0][i] < pb[0][i] else 1
	var ra: Array = pa[1]
	var rb: Array = pb[1]
	if ra.is_empty() or rb.is_empty():
		if ra.is_empty() and rb.is_empty():
			return 0
		return 1 if ra.is_empty() else -1
	for i in mini(ra.size(), rb.size()):
		var x := str(ra[i])
		var y := str(rb[i])
		if x == y:
			continue
		var nx := x.is_valid_int()
		var ny := y.is_valid_int()
		if nx and ny:
			return -1 if int(x) < int(y) else 1
		if nx != ny:
			return -1 if nx else 1
		return -1 if x < y else 1
	if ra.size() == rb.size():
		return 0
	return -1 if ra.size() < rb.size() else 1


static func plataforma() -> String:
	match OS.get_name():
		"Windows":
			return "windows"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "linux"
	return OS.get_name().to_lower()


# ------------------------------------------------------------------ escolha do release

## Escolhe, na lista da API de releases, a maior versão acima de `atual` que publica o
## manifesto e a assinatura. Ignora rascunhos e, se `aceitar_teste` for falso, pré-lançamentos.
## Devolve {} quando não há nada mais novo.
static func escolher_release(lista, atual: String, aceitar_teste := true) -> Dictionary:
	var melhor := {}
	if typeof(lista) != TYPE_ARRAY:
		return melhor
	for r in lista:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		if bool(r.get("draft", false)):
			continue
		if bool(r.get("prerelease", false)) and not aceitar_teste:
			continue
		var tag := str(r.get("tag_name", ""))
		if not versao_valida(tag):
			continue
		var v := tag.substr(1) if tag.begins_with("v") or tag.begins_with("V") else tag
		if comparar_versoes(v, atual) <= 0:
			continue
		var assets := {}
		var lista_assets = r.get("assets", [])
		if typeof(lista_assets) == TYPE_ARRAY:
			for a in lista_assets:
				if typeof(a) == TYPE_DICTIONARY:
					assets[str(a.get("name", ""))] = str(a.get("browser_download_url", ""))
		if not (assets.has(MANIFESTO) and assets.has(ASSINATURA)):
			continue
		if melhor.is_empty() or comparar_versoes(v, str(melhor["versao"])) > 0:
			melhor = {
				"versao": v, "tag": tag, "assets": assets, "teste": bool(r.get("prerelease", false)),
				"notas": str(r.get("body", "")) if r.get("body") != null else "",
				"pagina": str(r.get("html_url", "")),
			}
	return melhor


# ------------------------------------------------------------------ manifesto assinado

static func sha256_bytes(b: PackedByteArray) -> PackedByteArray:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(b)
	return h.finish()


static func sha256_arquivo(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		h.update(f.get_buffer(1 << 20))
	f.close()
	return h.finish().hex_encode()


## Assina `dados` com a chave privada (usado pela ferramenta de release e pelos testes).
static func assinar(dados: PackedByteArray, chave_privada: CryptoKey) -> PackedByteArray:
	return Crypto.new().sign(HashingContext.HASH_SHA256, sha256_bytes(dados), chave_privada)


static func _erro(motivo: String) -> Dictionary:
	return {"ok": false, "motivo": motivo}


## Confere a assinatura do manifesto e o conteúdo dele.
## `versao_esperada` é a versão do release (a tag); o manifesto tem de dizer a mesma,
## e ela tem de ser maior que `atual` (impede voltar a uma versão antiga assinada).
static func verificar_manifesto(bytes: PackedByteArray, assinatura: PackedByteArray, chave_pem: String,
		versao_esperada: String, atual: String, plat: String) -> Dictionary:
	var chave := CryptoKey.new()
	if chave.load_from_string(chave_pem, true) != OK:
		return _erro("a chave pública do programa é inválida")
	if assinatura.is_empty() or bytes.is_empty():
		return _erro("manifesto ou assinatura vazios")
	if not Crypto.new().verify(HashingContext.HASH_SHA256, sha256_bytes(bytes), assinatura, chave):
		return _erro("assinatura inválida: o manifesto não foi gerado por quem publica o programa")
	var dados = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(dados) != TYPE_DICTIONARY or str(dados.get("formato", "")) != FORMATO:
		return _erro("manifesto em formato desconhecido")
	var v := str(dados.get("versao", ""))
	if not versao_valida(v) or comparar_versoes(v, versao_esperada) != 0:
		return _erro("o manifesto é da versão %s, mas o release é %s" % [v, versao_esperada])
	if comparar_versoes(v, atual) <= 0:
		return _erro("o manifesto é da versão %s, que não é mais nova que a instalada (%s)" % [v, atual])
	var plats = dados.get("plataformas", {})
	if typeof(plats) != TYPE_DICTIONARY or not plats.has(plat):
		return _erro("a versão %s não tem pacote para %s" % [v, plat])
	var item = plats[plat]
	if typeof(item) != TYPE_DICTIONARY:
		return _erro("pacote de %s malformado no manifesto" % plat)
	var sha := str(item.get("sha256", "")).to_lower()
	var arq := str(item.get("arquivo", ""))
	var exe := str(item.get("executavel", ""))
	var tam := int(item.get("tamanho", 0))
	if sha.length() != 64 or not sha.is_valid_hex_number() or arq == "" or exe == "" or tam <= 0 \
			or arq.contains("/") or arq.contains("\\") or exe.contains(".."):
		return _erro("pacote de %s incompleto no manifesto" % plat)
	return {"ok": true, "motivo": "", "manifesto": dados,
		"item": {"arquivo": arq, "sha256": sha, "tamanho": tam, "executavel": exe}}


# ------------------------------------------------------------------ disco

## Extrai `interno` do zip para `destino` e marca como executável (Linux).
static func extrair(zip_path: String, interno: String, destino: String) -> String:
	var z := ZIPReader.new()
	if z.open(zip_path) != OK:
		return "o pacote baixado não é um zip válido"
	if not z.get_files().has(interno):
		z.close()
		return "o pacote não contém %s" % interno
	var dados := z.read_file(interno)
	z.close()
	if dados.is_empty():
		return "o executável dentro do pacote está vazio"
	var f := FileAccess.open(destino, FileAccess.WRITE)
	if f == null:
		return "sem permissão para gravar na pasta do programa (%s)" % destino.get_base_dir()
	f.store_buffer(dados)
	f.close()
	if OS.get_name() != "Windows":
		FileAccess.set_unix_permissions(destino, 493) # 0755
	return ""


## Troca `atual` por `novo`. O atual fica como <atual>.old; se algo falhar, ele volta.
static func instalar(novo: String, atual: String) -> Dictionary:
	if not FileAccess.file_exists(novo):
		return _erro("o executável novo não foi encontrado")
	var antigo := atual + ".old"
	if FileAccess.file_exists(antigo):
		DirAccess.remove_absolute(antigo)
	var tem_atual := FileAccess.file_exists(atual)
	if tem_atual:
		var e := DirAccess.rename_absolute(atual, antigo)
		if e != OK:
			return _erro("não foi possível renomear o executável em uso (%s)" % error_string(e))
	var e2 := DirAccess.rename_absolute(novo, atual)
	if e2 != OK:
		if tem_atual:
			DirAccess.rename_absolute(antigo, atual)
		return _erro("não foi possível colocar o executável novo no lugar (%s)" % error_string(e2))
	return {"ok": true, "motivo": ""}


## Apaga as sobras de uma atualização anterior (<exe>.old e <exe>.novo).
static func limpar_antigo(atual: String) -> int:
	var n := 0
	for suf in [".old", ".novo"]:
		if FileAccess.file_exists(atual + suf) and DirAccess.remove_absolute(atual + suf) == OK:
			n += 1
	return n


# ------------------------------------------------------------------ rede

func _cabecalhos() -> PackedStringArray:
	return PackedStringArray(["User-Agent: DimEsgoto/%s (atualizador)" % versao_atual,
		"Accept: application/vnd.github+json, application/octet-stream, */*"])


func _baixar(url: String, arquivo := "", limite := LIMITE_JSON, tempo := -1.0) -> Dictionary:
	if url == "":
		return {"ok": false, "motivo": "endereço vazio", "corpo": PackedByteArray()}
	var h := HTTPRequest.new()
	h.timeout = timeout_s if tempo < 0 else tempo
	h.body_size_limit = limite
	h.max_redirects = 8
	if arquivo != "":
		h.download_file = arquivo
	add_child(h)
	var err := h.request(url, _cabecalhos())
	if err != OK:
		h.queue_free()
		return {"ok": false, "motivo": "não foi possível iniciar a conexão (%s)" % error_string(err), "corpo": PackedByteArray()}
	if arquivo != "":
		baixando = h
	var res: Array = await h.request_completed
	if baixando == h:
		baixando = null
	h.queue_free()
	var resultado: int = res[0]
	var codigo: int = res[1]
	if resultado != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "motivo": _motivo_http(resultado), "corpo": PackedByteArray()}
	if codigo != 200:
		var m := "o servidor respondeu %d" % codigo
		if codigo == 403 or codigo == 429:
			m += " (limite de consultas do GitHub; tente mais tarde)"
		return {"ok": false, "motivo": m, "corpo": PackedByteArray()}
	return {"ok": true, "motivo": "", "corpo": res[3]}


static func _motivo_http(r: int) -> String:
	match r:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "sem conexão com o servidor de atualizações"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "falha na conexão segura (TLS)"
		HTTPRequest.RESULT_TIMEOUT:
			return "o servidor demorou demais para responder"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "a resposta do servidor é maior que o esperado"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "não foi possível gravar o arquivo baixado"
	return "falha de rede (código %d)" % r


## Procura uma versão nova. Devolve {estado: "disponivel" | "atualizado" | "erro", motivo, ...}.
## Com "disponivel", traz versao, notas, pagina, assets e item (o pacote desta plataforma),
## e o manifesto já foi conferido.
func verificar() -> Dictionary:
	if ocupado:
		return {"estado": "erro", "motivo": "já há uma verificação em andamento"}
	ocupado = true
	var r := await _verificar()
	ocupado = false
	return r


func _verificar() -> Dictionary:
	var lista := await _baixar(api_url)
	if not lista["ok"]:
		return {"estado": "erro", "motivo": lista["motivo"]}
	var rel := escolher_release(JSON.parse_string(PackedByteArray(lista["corpo"]).get_string_from_utf8()),
		versao_atual, aceitar_teste)
	if rel.is_empty():
		return {"estado": "atualizado", "motivo": ""}
	var man := await _baixar(str(rel["assets"][MANIFESTO]))
	if not man["ok"]:
		return {"estado": "erro", "motivo": "manifesto da versão %s: %s" % [rel["versao"], man["motivo"]]}
	var sig := await _baixar(str(rel["assets"][ASSINATURA]), "", 64 * 1024)
	if not sig["ok"]:
		return {"estado": "erro", "motivo": "assinatura da versão %s: %s" % [rel["versao"], sig["motivo"]]}
	var conf := verificar_manifesto(man["corpo"], sig["corpo"], chave_publica, str(rel["versao"]),
		versao_atual, plataforma_atual)
	if not conf["ok"]:
		return {"estado": "erro", "motivo": "versão %s recusada: %s" % [rel["versao"], conf["motivo"]]}
	var item: Dictionary = conf["item"]
	if not rel["assets"].has(item["arquivo"]):
		return {"estado": "erro", "motivo": "o release %s não tem o arquivo %s" % [rel["tag"], item["arquivo"]]}
	rel["estado"] = "disponivel"
	rel["motivo"] = ""
	rel["item"] = item
	return rel


func progresso() -> Vector2i:
	if baixando == null:
		return Vector2i(-1, -1)
	var total := baixando.get_body_size()
	return Vector2i(baixando.get_downloaded_bytes(), total if total > 0 else tamanho_esperado)


## Baixa o pacote de `info` (resultado "disponivel" de verificar()), confere e instala.
## Devolve {ok, motivo, exe}.
func baixar_e_instalar(info: Dictionary) -> Dictionary:
	if ocupado:
		return _erro("já há uma atualização em andamento")
	ocupado = true
	var r := await _baixar_e_instalar(info)
	ocupado = false
	return r


func _baixar_e_instalar(info: Dictionary) -> Dictionary:
	var exe := exe_atual
	if exe == "":
		if not OS.has_feature("template"):
			return _erro("a atualização automática só funciona no programa instalado, não pelo editor")
		exe = OS.get_executable_path()
	var item: Dictionary = info.get("item", {})
	if item.is_empty() or not info.get("assets", {}).has(item.get("arquivo", "")):
		return _erro("informação de atualização incompleta")
	var pasta := ProjectSettings.globalize_path(pasta_tmp)
	DirAccess.make_dir_recursive_absolute(pasta)
	var zip := pasta.path_join(str(item["arquivo"]))
	if FileAccess.file_exists(zip):
		DirAccess.remove_absolute(zip)
	tamanho_esperado = int(item["tamanho"])
	var b := await _baixar(str(info["assets"][item["arquivo"]]), zip, int(item["tamanho"]) + 4096, 0.0)
	if not b["ok"]:
		DirAccess.remove_absolute(zip)
		return _erro("download: " + str(b["motivo"]))
	var tam := FileAccess.open(zip, FileAccess.READ)
	var tamanho := tam.get_length() if tam != null else -1
	tam = null
	if tamanho != int(item["tamanho"]):
		DirAccess.remove_absolute(zip)
		return _erro("o arquivo baixado tem %d bytes, e o manifesto diz %d" % [tamanho, int(item["tamanho"])])
	if sha256_arquivo(zip) != str(item["sha256"]):
		DirAccess.remove_absolute(zip)
		return _erro("o arquivo baixado não confere com o manifesto (SHA-256 diferente)")
	var novo := exe + ".novo"
	var e := extrair(zip, str(item["executavel"]), novo)
	DirAccess.remove_absolute(zip)
	if e != "":
		if FileAccess.file_exists(novo):
			DirAccess.remove_absolute(novo)
		return _erro(e)
	var inst := instalar(novo, exe)
	if not inst["ok"]:
		if FileAccess.file_exists(novo):
			DirAccess.remove_absolute(novo)
		return inst
	return {"ok": true, "motivo": "", "exe": exe, "versao": str(info.get("versao", ""))}
