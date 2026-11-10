extends Node
## Registro de erros e rastreio do DimEsgoto.
##
## Onde fica: user://logs  (Linux: ~/.local/share/godot/app_userdata/DimEsgoto/logs)
##   • dimesgoto.log ...... registro do app: sessões, ações do usuário, erros com rastreio
##   • godot.log (+ antigos)  registro do motor Godot (rotação automática, 5 arquivos)
##
## Para não crescer com o tempo:
##   • dimesgoto.log é rotacionado ao passar de 512 KB (fica só 1 arquivo antigo);
##   • erros repetidos são agrupados (contados) em vez de gravados de novo;
##   • ao abrir, se a pasta passar de 10 MB, os arquivos mais antigos são apagados.
##
## O Godot 4.4 não deixa o script interceptar erros diretamente; por isso o registro
## acompanha o godot.log a cada 1,5 s, copia cada erro novo para o dimesgoto.log
## junto com as últimas ações do usuário (o "rastro") e avisa na barra de status.

signal erros_mudaram(total: int)

const PASTA := "user://logs"
const ARQ := "user://logs/dimesgoto.log"
const ARQ_ANTIGO := "user://logs/dimesgoto.old.log"
const MAX_ARQ := 512 * 1024
const LIMITE_PASTA := 10 * 1024 * 1024
const MAX_ACOES := 30
const PREFIXOS_ERRO := ["SCRIPT ERROR:", "USER SCRIPT ERROR:", "USER ERROR:", "ERROR:"]
const PREFIXOS_AVISO := ["USER WARNING:", "SCRIPT WARNING:", "WARNING:"]
# mensagens do motor que não indicam problema no app
const IGNORAR := ["ObjectDB instances leaked", "resources still in use at exit"]

var app := ""
var versao := ""
var acoes: Array = [] # [[hora, texto], ...]
var erros: Array = [] # entradas da sessão atual
var _assinaturas := {} # assinatura -> entrada (para agrupar repetidos)
var _godot_log := ""
var _pos := 0
var _resto := ""
var _timer: Timer
var _ultimo_projeto := ""


func iniciar(nome_app: String, ver: String) -> void:
	app = nome_app
	versao = ver
	DirAccess.make_dir_recursive_absolute(PASTA)
	_godot_log = str(ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	_limpar_pasta()
	_rotacionar()
	_verificar_sessao_anterior()
	_escrever("\n" + "=".repeat(72) + "\n[%s] SESSÃO  %s %s iniciada  •  Godot %s  •  %s %s  •  idioma %s\n" % [
		_agora(), app, versao, Engine.get_version_info().get("string", "?"), OS.get_name(), OS.get_version(), OS.get_locale()])
	_pos = 0
	_timer = Timer.new()
	_timer.wait_time = 1.5
	_timer.autostart = true
	_timer.timeout.connect(verificar_godot_log)
	add_child(_timer)
	verificar_godot_log.call_deferred()


var _encerrado := false


func _exit_tree() -> void:
	encerrar()


func encerrar() -> void:
	if _encerrado or app == "":
		return
	_encerrado = true
	verificar_godot_log()
	var rep := ""
	for e in erros:
		if int(e["vezes"]) > 1:
			rep += "    %d×  %s\n" % [int(e["vezes"]), str(e["msg"])]
	if rep != "":
		_escrever("[%s] INFO  Erros repetidos nesta sessão:\n%s" % [_agora(), rep])
	_escrever("[%s] SESSÃO  encerrada normalmente\n" % _agora())


# ------------------------------------------------------------------ API

func acao(texto: String) -> void:
	acoes.append([_hora(), texto])
	while acoes.size() > MAX_ACOES:
		acoes.pop_front()
	_escrever("[%s] AÇÃO  %s\n" % [_agora(), texto])


func projeto(caminho: String) -> void:
	_ultimo_projeto = caminho


## Erro do próprio app (com rastreio da pilha de chamadas do GDScript).
func erro(msg: String, nivel := "ERRO") -> void:
	var pilha: Array = []
	var st := get_stack()
	for k in range(1, st.size()):
		var f: Dictionary = st[k]
		pilha.append("%s:%d em %s()" % [str(f.get("source", "?")).get_file(), int(f.get("line", 0)), str(f.get("function", "?"))])
	_registrar_erro(nivel, msg, "", pilha, "app")


func aviso(msg: String) -> void:
	erro(msg, "AVISO")


func total_erros() -> int:
	var n := 0
	for e in erros:
		if str(e["nivel"]) == "ERRO":
			n += 1
	return n


# ------------------------------------------------------------------ godot.log

func verificar_godot_log() -> void:
	if _godot_log == "" or not FileAccess.file_exists(_godot_log):
		return
	var f := FileAccess.open(_godot_log, FileAccess.READ)
	if f == null:
		return
	var tam := f.get_length()
	if tam < _pos:
		_pos = 0
		_resto = ""
	if tam == _pos:
		f.close()
		return
	# nunca lê mais de 256 KB de uma vez (protege contra erro em laço)
	if tam - _pos > 256 * 1024:
		_pos = tam - 256 * 1024
	f.seek(_pos)
	var txt := _resto + f.get_buffer(tam - _pos).get_string_from_utf8()
	_pos = tam
	f.close()
	var linhas := txt.split("\n")
	_resto = linhas[linhas.size() - 1]
	linhas.remove_at(linhas.size() - 1)
	var atual: Dictionary = {}
	for l in linhas:
		var t := l.strip_edges()
		var nivel := ""
		var msg := ""
		for p in PREFIXOS_ERRO:
			if t.begins_with(p):
				nivel = "ERRO"
				msg = t.substr(p.length()).strip_edges()
				if p.contains("SCRIPT"):
					msg = "[script] " + msg
				break
		if nivel == "":
			for p in PREFIXOS_AVISO:
				if t.begins_with(p):
					nivel = "AVISO"
					msg = t.substr(p.length()).strip_edges()
					break
		if nivel != "":
			_fechar(atual)
			atual = {"nivel": nivel, "msg": msg, "local": "", "pilha": []}
		elif not atual.is_empty() and (l.begins_with(" ") or l.begins_with("\t")) and t != "":
			if t.begins_with("at:") and str(atual["local"]) == "":
				atual["local"] = t.substr(3).strip_edges()
			else:
				atual["pilha"].append(t)
		else:
			_fechar(atual)
			atual = {}
	_fechar(atual)


func _fechar(e: Dictionary) -> void:
	if e.is_empty():
		return
	for ig in IGNORAR:
		if str(e["msg"]).contains(ig):
			return
	_registrar_erro(str(e["nivel"]), str(e["msg"]), str(e["local"]), e["pilha"], "motor")


func _registrar_erro(nivel: String, msg: String, local: String, pilha: Array, origem: String) -> void:
	var assin := "%s|%s|%s" % [nivel, msg, local]
	if _assinaturas.has(assin):
		var ex: Dictionary = _assinaturas[assin]
		ex["vezes"] = int(ex["vezes"]) + 1
		ex["ultima"] = _hora()
		erros_mudaram.emit(total_erros())
		return
	var e := {"quando": _agora(), "nivel": nivel, "msg": msg, "local": local, "pilha": pilha, "origem": origem,
		"acoes": acoes.duplicate(true), "projeto": _ultimo_projeto, "vezes": 1, "ultima": _hora(), "sessao": "atual"}
	_assinaturas[assin] = e
	erros.append(e)
	_escrever(formatar(e))
	erros_mudaram.emit(total_erros())


# ------------------------------------------------------------------ formatação e leitura

func formatar(e: Dictionary) -> String:
	var s := "[%s] %s  %s\n" % [str(e["quando"]), str(e["nivel"]), str(e["msg"])]
	s += "    origem: %s\n" % ("motor Godot / script" if str(e["origem"]) == "motor" else "aplicativo")
	if str(e.get("local", "")) != "":
		s += "    local: %s\n" % str(e["local"])
	var pilha: Array = e.get("pilha", [])
	if not pilha.is_empty():
		s += "    rastreio:\n"
		for p in pilha:
			s += "      %s\n" % str(p)
	if str(e.get("projeto", "")) != "":
		s += "    projeto: %s\n" % str(e["projeto"])
	var ac: Array = e.get("acoes", [])
	if not ac.is_empty():
		s += "    últimas ações (da mais antiga à mais recente):\n"
		for a in ac:
			s += "      %s  %s\n" % [str(a[0]), str(a[1])]
	if int(e.get("vezes", 1)) > 1:
		s += "    repetiu %d vezes (última às %s)\n" % [int(e["vezes"]), str(e["ultima"])]
	return s


## Erros e avisos de sessões anteriores, lidos do dimesgoto.log (e do antigo).
func historico() -> Array:
	var out: Array = []
	for arq in [ARQ_ANTIGO, ARQ]:
		if not FileAccess.file_exists(arq):
			continue
		var txt := FileAccess.get_file_as_string(arq)
		var bloco: Array = []
		var cab := ""
		for l in txt.split("\n"):
			if l.begins_with("["):
				if cab != "":
					out.append(_entrada_hist(cab, bloco))
				cab = ""
				bloco = []
				var fim := l.find("] ")
				if fim > 0:
					var resto := l.substr(fim + 2)
					if resto.begins_with("ERRO") or resto.begins_with("AVISO") or resto.begins_with("FALHA"):
						cab = l
			elif l.begins_with("====="):
				if cab != "":
					out.append(_entrada_hist(cab, bloco))
				cab = ""
				bloco = []
			elif cab != "":
				bloco.append(l)
		if cab != "":
			out.append(_entrada_hist(cab, bloco))
	return out


func _entrada_hist(cab: String, bloco: Array) -> Dictionary:
	var fim := cab.find("] ")
	var quando := cab.substr(1, fim - 1)
	var resto := cab.substr(fim + 2)
	var esp := resto.find("  ")
	var nivel := resto.substr(0, esp) if esp > 0 else resto
	var msg := resto.substr(esp + 2) if esp > 0 else ""
	return {"quando": quando, "nivel": nivel.strip_edges(), "msg": msg, "texto": cab + "\n" + "\n".join(PackedStringArray(bloco)).strip_edges(false, true)}


func uso_em_disco() -> int:
	var total := 0
	var d := DirAccess.open(PASTA)
	if d == null:
		return 0
	for f in d.get_files():
		var fa := FileAccess.open(PASTA.path_join(f), FileAccess.READ)
		if fa:
			total += fa.get_length()
			fa.close()
	return total


func pasta_global() -> String:
	return ProjectSettings.globalize_path(PASTA)


func limpar_tudo() -> void:
	var d := DirAccess.open(PASTA)
	if d == null:
		return
	var atual_godot := _godot_log.get_file()
	for f in d.get_files():
		if f == atual_godot:
			continue
		d.remove(f)
	erros.clear()
	_assinaturas.clear()
	_escrever("[%s] INFO  Registros apagados pelo usuário\n" % _agora())
	erros_mudaram.emit(0)


func texto_completo(max_bytes := 200 * 1024) -> String:
	if not FileAccess.file_exists(ARQ):
		return "(vazio)"
	var f := FileAccess.open(ARQ, FileAccess.READ)
	var tam := f.get_length()
	var ini := maxi(0, tam - max_bytes)
	f.seek(ini)
	var txt := f.get_buffer(tam - ini).get_string_from_utf8()
	f.close()
	if ini > 0:
		txt = "(… mostrando só os últimos %d KB …)\n" % (max_bytes / 1024) + txt
	return txt


# ------------------------------------------------------------------ manutenção

func _escrever(s: String) -> void:
	var f: FileAccess
	if FileAccess.file_exists(ARQ):
		f = FileAccess.open(ARQ, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
	else:
		f = FileAccess.open(ARQ, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(s)
	var tam := f.get_length()
	f.close()
	if tam > MAX_ARQ:
		_rotacionar()


func _rotacionar() -> void:
	if not FileAccess.file_exists(ARQ):
		return
	var f := FileAccess.open(ARQ, FileAccess.READ)
	var tam := f.get_length() if f else 0
	if f:
		f.close()
	if tam <= MAX_ARQ:
		return
	if FileAccess.file_exists(ARQ_ANTIGO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQ_ANTIGO))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(ARQ), ProjectSettings.globalize_path(ARQ_ANTIGO))


## Apaga os arquivos mais antigos se a pasta passar do limite.
func _limpar_pasta() -> void:
	var d := DirAccess.open(PASTA)
	if d == null:
		return
	var lista: Array = []
	var total := 0
	for f in d.get_files():
		var p := PASTA.path_join(f)
		var fa := FileAccess.open(p, FileAccess.READ)
		var tam := fa.get_length() if fa else 0
		if fa:
			fa.close()
		total += tam
		lista.append([FileAccess.get_modified_time(p), p, tam])
	if total <= LIMITE_PASTA:
		return
	lista.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var protegidos := [ARQ, _godot_log]
	for item in lista:
		if total <= LIMITE_PASTA:
			break
		if str(item[1]) in protegidos:
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(item[1])))
		total -= int(item[2])
	# se mesmo assim o registro do app estiver grande, rotaciona
	_rotacionar()


## Se a última sessão não terminou normalmente, registra uma FALHA com o final
## do registro do motor daquela sessão (onde fica o rastreio de um travamento).
func _verificar_sessao_anterior() -> void:
	if not FileAccess.file_exists(ARQ):
		return
	var txt := FileAccess.get_file_as_string(ARQ)
	var ini := txt.rfind("] SESSÃO  ")
	if ini < 0:
		return
	var linha_fim := txt.find("\n", ini)
	var ultima := txt.substr(ini, (linha_fim - ini) if linha_fim > 0 else -1)
	if ultima.contains("encerrada"):
		return
	# acha o godot.log da sessão anterior (o rotacionado mais recente)
	var anterior := ""
	var maior := 0
	var d := DirAccess.open(PASTA)
	if d:
		for f in d.get_files():
			if f.begins_with("godot") and f != _godot_log.get_file() and f.ends_with(".log"):
				var t := FileAccess.get_modified_time(PASTA.path_join(f))
				if t > maior:
					maior = t
					anterior = PASTA.path_join(f)
	var cauda := ""
	if anterior != "":
		var linhas := FileAccess.get_file_as_string(anterior).split("\n")
		var k0 := maxi(0, linhas.size() - 40)
		for k in range(k0, linhas.size()):
			cauda += "      " + linhas[k] + "\n"
	var acoes_ant := ""
	var bloco := txt.substr(ini)
	var linhas_ac: Array = []
	for l in bloco.split("\n"):
		if l.contains("] AÇÃO  "):
			linhas_ac.append(l)
	for k in range(maxi(0, linhas_ac.size() - 15), linhas_ac.size()):
		acoes_ant += "      " + str(linhas_ac[k]) + "\n"
	var s := "[%s] FALHA  A sessão anterior terminou de forma inesperada (travamento ou fechamento forçado)\n" % _agora()
	if acoes_ant != "":
		s += "    últimas ações da sessão anterior:\n" + acoes_ant
	if cauda != "":
		s += "    final do registro do motor (%s):\n%s" % [anterior.get_file(), cauda]
	_escrever(s)


func _agora() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"], d["second"]]


func _hora() -> String:
	var d := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [d["hour"], d["minute"], d["second"]]
