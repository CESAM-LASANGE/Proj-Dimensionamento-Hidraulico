#!/usr/bin/env python3
"""Ensaio da atualização automática com os executáveis EXPORTADOS (Linux).

Simula o que acontece na máquina do usuário, sem tocar no GitHub:
  1. pega o executável da versão atual já gerado (dist/v<versão>/linux/DimEsgoto.x86_64);
  2. exporta uma versão seguinte de mentira (<versão>.ensaio), empacota igual ao build_release
     e assina o manifesto com a chave privada real;
  3. sobe um servidor HTTP local com uma lista de releases no formato da API do GitHub;
  4. roda o executável atual com --ensaio-atualizacao=<servidor>: ele confere a assinatura com
     a chave embutida, baixa, confere o SHA-256 e troca a si mesmo;
  5. abre o executável trocado e confere a versão nova e a limpeza do .old;
  6. repete com o pacote adulterado: tem de recusar e manter o executável.

Uso (depois de tools/build_release.py --linux):
    python3 tools/ensaio_atualizacao.py
A troca de executável em uso no Windows não é coberta aqui (sem Windows nesta máquina).
"""
import functools
import hashlib
import http.server
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import zipfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(RAIZ, "app")
sys.path.insert(0, APP)
sys.path.insert(0, os.path.join(RAIZ, "tools"))
from main import find_godot  # noqa: E402
import build_release as br  # noqa: E402

MAN = br.MANIFESTO


class _Silencioso(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


def sha(p):
    return br._sha256(p)


def main():
    godot = find_godot()
    v = br.versao()
    atual = os.path.join(br.DIST, "v" + v, "linux", "DimEsgoto.x86_64")
    chave = os.environ.get("DIMESGOTO_CHAVE") or br.CHAVE_PADRAO
    if not os.path.exists(atual):
        print("Falta %s (rode tools/build_release.py --linux)." % atual)
        return 2
    if not os.path.exists(chave):
        print("Falta a chave privada (%s)." % chave)
        return 2
    v2 = v + ".ensaio"
    resultados = []

    def check(ok, msg):
        resultados.append(ok)
        print("  %s %s" % ("✓" if ok else "✗", msg))

    tmp = tempfile.mkdtemp(prefix="dimesgoto-ensaio-")
    try:
        # 2. versão seguinte de mentira
        app2 = os.path.join(tmp, "app")
        shutil.copytree(APP, app2, ignore=shutil.ignore_patterns("__pycache__", "shots"))
        pg = os.path.join(app2, "project.godot")
        txt = open(pg, encoding="utf-8").read()
        assert 'config/version="%s"' % v in txt
        open(pg, "w", encoding="utf-8").write(txt.replace('config/version="%s"' % v, 'config/version="%s"' % v2))
        mg = os.path.join(app2, "main.gd")
        txt = open(mg, encoding="utf-8").read()
        assert 'const VERSAO := "%s"' % v in txt
        open(mg, "w", encoding="utf-8").write(txt.replace('const VERSAO := "%s"' % v, 'const VERSAO := "%s"' % v2))
        exe2 = os.path.join(tmp, "build2", "DimEsgoto.x86_64")
        os.makedirs(os.path.dirname(exe2))
        print("> exportando a versão de ensaio %s ..." % v2)
        subprocess.run([godot, "--headless", "--path", app2, "--import"], capture_output=True)
        subprocess.run([godot, "--headless", "--path", app2, "--export-release", "Linux", exe2], capture_output=True)
        check(os.path.exists(exe2), "versão de ensaio exportada")
        if not os.path.exists(exe2):
            return 1
        www = os.path.join(tmp, "www")
        os.makedirs(www)
        nome_zip = "DimEsgoto-%s-linux-x86_64.zip" % v2
        with zipfile.ZipFile(os.path.join(www, nome_zip), "w", zipfile.ZIP_DEFLATED) as z:
            info = zipfile.ZipInfo.from_file(exe2, "DimEsgoto-%s/DimEsgoto.x86_64" % v2)
            info.external_attr = 0o755 << 16
            z.writestr(info, open(exe2, "rb").read(), zipfile.ZIP_DEFLATED)
        man = os.path.join(www, MAN)
        json.dump({"formato": "dimesgoto-atualizacao", "versao_formato": 1, "versao": v2, "plataformas": {
            "linux": {"arquivo": nome_zip, "sha256": sha(os.path.join(www, nome_zip)),
                      "tamanho": os.path.getsize(os.path.join(www, nome_zip)),
                      "executavel": "DimEsgoto-%s/DimEsgoto.x86_64" % v2}}}, open(man, "w"), indent=2)
        p = subprocess.run([godot, "--headless", "--path", APP, "--script", br.FERRAMENTA_CHAVE, "--",
                            "assinar", chave, man, man + ".sig"], capture_output=True, text=True)
        check(p.returncode == 0, "manifesto da versão de ensaio assinado com a chave real")
        # 3. servidor
        srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(_Silencioso, directory=www))
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        url = "http://127.0.0.1:%d/" % srv.server_address[1]
        json.dump([{"tag_name": "v" + v2, "prerelease": True, "draft": False, "body": "ensaio",
                    "html_url": url, "assets": [{"name": n, "browser_download_url": url + n}
                                                for n in (nome_zip, MAN, MAN + ".sig")]}],
                  open(os.path.join(www, "releases.json"), "w"))

        def rodar(exe, *args):
            env = dict(os.environ, XDG_DATA_HOME=os.path.join(tmp, "dados"))
            return subprocess.run([exe, "--headless"] + list(args), capture_output=True, text=True, env=env, timeout=300)

        # 4. o executável atual se atualiza
        inst = os.path.join(tmp, "instalado", "DimEsgoto.x86_64")
        os.makedirs(os.path.dirname(inst))
        shutil.copy2(atual, inst)
        p = rodar(inst, "--ensaio-atualizacao=" + url + "releases.json")
        linha = next((l for l in p.stdout.splitlines() if l.startswith("ATUALIZACAO|")), "")
        print("    " + linha)
        check(p.returncode == 0 and linha.endswith("|instalada"), "versão %s encontrou e instalou a %s" % (v, v2))
        check(sha(inst) == sha(exe2) and os.access(inst, os.X_OK), "o executável instalado agora é o da versão nova (e é executável)")
        check(os.path.exists(inst + ".old") and sha(inst + ".old") == sha(atual), "o antigo ficou como .old")
        # 5. abre a versão nova
        p = rodar(inst, "--quit-after", "200")
        log = os.path.join(tmp, "dados", "godot", "app_userdata", "DimEsgoto", "logs", "dimesgoto.log")
        txt = open(log, encoding="utf-8").read() if os.path.exists(log) else ""
        if v2 not in txt:
            print("    (saída ao abrir, código %d)\n    %s" % (p.returncode, "\n    ".join((p.stdout + p.stderr).splitlines()[-15:])))
        check(v2 in txt, "ao abrir, o programa é a versão %s" % v2)
        check(not os.path.exists(inst + ".old"), "o .old foi apagado ao abrir a versão nova")
        # 6. pacote adulterado
        shutil.copy2(atual, inst)
        zb = bytearray(open(os.path.join(www, nome_zip), "rb").read())
        zb[len(zb) // 2] ^= 0xFF
        open(os.path.join(www, nome_zip), "wb").write(bytes(zb))
        p = rodar(inst, "--ensaio-atualizacao=" + url + "releases.json")
        linha = next((l for l in p.stdout.splitlines() if l.startswith("ATUALIZACAO|")), "")
        print("    " + linha)
        check(p.returncode != 0 and "SHA-256" in linha and sha(inst) == sha(atual), "pacote adulterado: recusado, executável intacto")
        srv.shutdown()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    ok = all(resultados)
    print("\nENSAIO DA ATUALIZAÇÃO: %s (%d/%d)" % ("PASS" if ok else "FAIL", sum(resultados), len(resultados)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
