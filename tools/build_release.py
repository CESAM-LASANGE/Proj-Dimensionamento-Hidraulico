#!/usr/bin/env python3
"""Gera os pacotes de release do DimEsgoto (Windows .exe e Linux).

Uso (a partir da pasta raiz do repositório):
    python3 tools/build_release.py              # Windows e Linux
    python3 tools/build_release.py --windows    # só Windows

Requisitos: Godot 4.4.1 (variável GODOT ou instalado no PATH) e os modelos de
exportação 4.4.1 instalados (Editor › Gerenciar modelos de exportação, ou extraia
o arquivo Godot_v4.4.1-stable_export_templates.tpz em
~/.local/share/godot/export_templates/4.4.1.stable/ no Linux,
%APPDATA%\\Godot\\export_templates\\4.4.1.stable\\ no Windows).

Saída, numa pasta por tag (dist/v<versão>/):
    DimEsgoto-<versão>-windows-x86_64.zip, DimEsgoto-<versão>-linux-x86_64.zip,
    SHA256SUMS.txt e as pastas windows/ e linux/ com os executáveis soltos;
    dimesgoto-atualizacao.json e dimesgoto-atualizacao.json.sig (manifesto assinado da
    atualização automática, docs/ATUALIZACAO.md). A assinatura usa a chave privada de
    DIMESGOTO_CHAVE ou ~/.config/dimesgoto/chave-atualizacao.pem; sem ela, o release sai
    sem atualização automática (os programas instalados não o enxergam).
"""
import argparse
import datetime
import json
import hashlib
import os
import re
import shutil
import subprocess
import sys
import zipfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(RAIZ, "app")
DIST = os.path.join(RAIZ, "dist")
FERRAMENTA_CHAVE = os.path.join(RAIZ, "tools", "chave_atualizacao.gd")
MANIFESTO = "dimesgoto-atualizacao.json"
CHAVE_PADRAO = os.path.join(os.path.expanduser("~"), ".config", "dimesgoto", "chave-atualizacao.pem")
sys.path.insert(0, APP)
from main import find_godot  # noqa: E402

ALVOS = {
    "windows": ("Windows Desktop", os.path.join("windows", "DimEsgoto.exe"), "windows-x86_64"),
    "linux": ("Linux", os.path.join("linux", "DimEsgoto.x86_64"), "linux-x86_64"),
}

LEIA_ME = """DimEsgoto {versao} — versão ALPHA

Dimensionamento de redes coletoras de esgoto sanitário (critérios da NBR 9649),
com traçado gráfico, topografia DXF, planilhas, orçamento, perfis e exportações.

COMO USAR
  {como}
  Ao abrir, a rede de exemplo já vem carregada. Aperte F1 para ver os comandos.

ATUALIZAÇÕES
  Ao abrir, o programa procura versão nova no GitHub e pergunta antes de instalar
  (Ajuda › Verificar atualizações…). Deixe a pasta do programa num lugar onde você
  pode gravar (Documentos, Área de Trabalho), não dentro do zip nem em Arquivos de Programas.

AVISO
  Esta é uma versão alpha, para avaliação. Os resultados devem ser conferidos por
  um responsável técnico e validados contra a norma vigente e as exigências da
  concessionária antes de qualquer uso em projeto real.

DADOS DO USUÁRIO
  Configurações, banco de custos e registros de erros ficam em:
    Windows: %APPDATA%\\Godot\\app_userdata\\DimEsgoto
    Linux:   ~/.local/share/godot/app_userdata/DimEsgoto
  Em caso de problema, envie o relatório gerado em Ajuda › Registro de erros.

Código-fonte e notas da versão: veja o repositório do projeto no GitHub.
"""


def versao():
    txt = open(os.path.join(APP, "project.godot"), encoding="utf-8").read()
    m = re.search(r'config/version="([^"]+)"', txt)
    return m.group(1) if m else "0.0.0"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--windows", action="store_true")
    ap.add_argument("--linux", action="store_true")
    a = ap.parse_args()
    alvos = [k for k in ALVOS if getattr(a, k)] or list(ALVOS)
    godot = find_godot()
    if not godot:
        print("Godot 4.4.1 não encontrado (defina a variável GODOT).")
        return 2
    v = versao()
    dist_v = os.path.join(DIST, "v" + v)
    os.makedirs(dist_v, exist_ok=True)
    print("DimEsgoto %s — Godot: %s" % (v, godot))
    subprocess.run([godot, "--headless", "--path", APP, "--import"], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ok = True
    for k in alvos:
        preset, rel, sufixo = ALVOS[k]
        destino = os.path.join(dist_v, rel)
        pasta = os.path.dirname(destino)
        shutil.rmtree(pasta, ignore_errors=True)
        os.makedirs(pasta)
        print("\n> exportando %s ..." % preset)
        p = subprocess.run([godot, "--headless", "--path", APP, "--export-release", preset, destino],
                           capture_output=True, text=True)
        erros = [l for l in (p.stdout + p.stderr).splitlines() if "ERROR" in l or "No export template" in l]
        if p.returncode != 0 or not os.path.exists(destino):
            print("  FALHOU (código %d)\n  %s" % (p.returncode, "\n  ".join(erros[:8])))
            ok = False
            continue
        como = "Extraia o zip e abra DimEsgoto.exe. O Windows pode avisar que o editor é\n  desconhecido (o executável ainda não é assinado): clique em \"Mais informações\" › \"Executar assim mesmo\"." \
            if k == "windows" else "Extraia o zip e execute ./DimEsgoto.x86_64 (se preciso: chmod +x DimEsgoto.x86_64)."
        with open(os.path.join(pasta, "LEIA-ME.txt"), "w", encoding="utf-8", newline="\r\n" if k == "windows" else "\n") as f:
            f.write(LEIA_ME.format(versao=v, como=como))
        nome_zip = os.path.join(dist_v, "DimEsgoto-%s-%s.zip" % (v, sufixo))
        with zipfile.ZipFile(nome_zip, "w", zipfile.ZIP_DEFLATED) as z:
            for arq in sorted(os.listdir(pasta)):
                caminho = os.path.join(pasta, arq)
                info = zipfile.ZipInfo.from_file(caminho, "DimEsgoto-%s/%s" % (v, arq))
                if arq.endswith(".x86_64"):
                    info.external_attr = 0o755 << 16
                with open(caminho, "rb") as src:
                    z.writestr(info, src.read(), zipfile.ZIP_DEFLATED)
        print("  ok: %s (%.1f MB)" % (os.path.relpath(nome_zip, RAIZ), os.path.getsize(nome_zip) / 1048576))
    gravar_sha256(dist_v)
    if ok:
        ok = gravar_manifesto(godot, dist_v, v)
    return 0 if ok else 1


def _sha256(caminho):
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


def gravar_manifesto(godot, dist_v, v):
    """Manifesto da atualização automática, assinado e conferido com a chave embutida no app."""
    plats = {}
    for k, (_, rel, sufixo) in ALVOS.items():
        nome = "DimEsgoto-%s-%s.zip" % (v, sufixo)
        caminho = os.path.join(dist_v, nome)
        if os.path.exists(caminho):
            plats[k] = {"arquivo": nome, "sha256": _sha256(caminho), "tamanho": os.path.getsize(caminho),
                        "executavel": "DimEsgoto-%s/%s" % (v, os.path.basename(rel))}
    man = os.path.join(dist_v, MANIFESTO)
    with open(man, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"formato": "dimesgoto-atualizacao", "versao_formato": 1, "versao": v,
                   "data": datetime.date.today().isoformat(), "plataformas": plats}, f, ensure_ascii=False, indent=2)
    chave = os.environ.get("DIMESGOTO_CHAVE") or CHAVE_PADRAO
    if not os.path.exists(chave):
        os.remove(man)
        print("\n  AVISO: chave de assinatura não encontrada (%s).\n  Este release sai SEM atualização automática." % chave)
        return True
    base = [godot, "--headless", "--path", APP, "--script", FERRAMENTA_CHAVE, "--"]
    p = subprocess.run(base + ["assinar", chave, man, man + ".sig"], capture_output=True, text=True)
    if p.returncode != 0 or not os.path.exists(man + ".sig"):
        print("  FALHOU ao assinar o manifesto:\n" + (p.stdout + p.stderr)[-1500:])
        return False
    p = subprocess.run(base + ["conferir", man, man + ".sig", v, dist_v], capture_output=True, text=True)
    linhas = [l for l in p.stdout.splitlines() if l.startswith(("windows:", "linux:"))]
    for l in linhas:
        print("  " + l)
    if p.returncode != 0 or not linhas:
        print("  FALHOU a conferência do manifesto com a chave do programa:\n" + (p.stdout + p.stderr)[-1500:])
        return False
    print("  ok: %s e %s.sig (assinados)" % (os.path.relpath(man, RAIZ), MANIFESTO))
    print("\n  Para publicar: anexe ao Release da tag v%s os zips, o SHA256SUMS.txt,\n  o %s e o %s.sig." % (v, MANIFESTO, MANIFESTO))
    return True


def gravar_sha256(pasta):
    """SHA256SUMS.txt com todos os zips da pasta da versão (formato do sha256sum)."""
    linhas = []
    for arq in sorted(os.listdir(pasta)):
        if arq.endswith(".zip"):
            linhas.append("%s  %s\n" % (_sha256(os.path.join(pasta, arq)), arq))
    if linhas:
        with open(os.path.join(pasta, "SHA256SUMS.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.writelines(linhas)
        print("\n  ok: %s" % os.path.relpath(os.path.join(pasta, "SHA256SUMS.txt"), RAIZ))


if __name__ == "__main__":
    sys.exit(main())
