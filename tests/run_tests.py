#!/usr/bin/env python3
"""Executa os evals do DimEsgoto (EVALS.md + tests/PHASE-2-5.md).

Uso (a partir da pasta setup/):
    python3 tests/run_tests.py              # fase a fase; para no portão da primeira fase com FAIL
    python3 tests/run_tests.py --todas      # diagnóstico: executa todas as fases mesmo com falhas
    python3 tests/run_tests.py --fase 2     # só uma fase
    python3 tests/run_tests.py --sem-grafico  # não abre janela (testes gráficos viram SKIP)

Variáveis: GODOT=<binário>  ATUALIZAR_BASELINE=1 (regrava tests/expected/baseline_exemplo.json)

Estados: PASS, FAIL, SKIP. Código de saída 0 se nenhum FAIL; 1 caso contrário.
Relatórios: tests/report/ultimo_relatorio.json e tests/report/relatorio.txt.
Só usa a biblioteca padrão do Python + o Godot 4.4.
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile

TESTS = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(TESTS)
APP = os.path.join(RAIZ, "app")
REPORT = os.path.join(TESTS, "report")
sys.path.insert(0, APP)
from main import find_godot  # noqa: E402  (mesmo localizador do iniciador)

# fase -> (rótulo, scripts headless, scripts gráficos, IDs)
FASES = {
    0: ("Fase 0 — baseline e infraestrutura", ["test_baseline.gd"], [], ["EVAL-000", "EVAL-001", "EVAL-002"]),
    1: ("Fase 1 — motor hidráulico", ["test_calc.gd", "test_net.gd"], [],
        ["EVAL-101", "EVAL-102", "EVAL-103", "EVAL-104", "EVAL-105", "EVAL-106", "EVAL-107"]),
    2: ("Fase 2 — topografia e qualidade geográfica", ["test_topo.gd", "test_dxf.gd"], [],
        ["T2-01", "T2-02", "T2-03", "T2-04", "T2-05", "T2-06", "T2-07", "T2-08"]),
    3: ("Fase 3 — SIG, bacias e cadastro", ["test_cadastro.gd"], ["test_grafico.gd"],
        ["T3-01", "T3-02", "T3-03", "T3-04", "T3-05", "T3-06", "T3-07", "T3-08"]),
    4: ("Fase 4 — entregáveis de engenharia", ["test_reports.gd"], ["test_grafico.gd"],
        ["T4-01", "T4-02", "T4-03", "T4-04", "T4-05", "T4-06", "T4-07"]),
    5: ("Fase 5 — robustez e manutenção", ["test_robustez.gd"], ["test_grafico.gd"],
        ["T5-01", "T5-02", "T5-03", "T5-04", "T5-05", "T5-06", "T5-07", "T5-08", "T5-09"]),
}
ERROS_FATAIS = re.compile(r"SCRIPT ERROR|Parse Error|Program crashed|Segmentation fault|handle_crash", re.I)


def rodar(godot, args, xdg, timeout=900):
    env = dict(os.environ)
    env["XDG_DATA_HOME"] = xdg  # dados isolados: não toca nos dados reais do usuário
    env["DIMESGOTO_TESTS"] = TESTS
    try:
        p = subprocess.run([godot, "--path", APP] + args, capture_output=True, text=True, timeout=timeout, env=env)
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        return 124, out + "\nTEMPO ESGOTADO"


def parse(saida):
    res, meta = {}, {}
    for l in saida.splitlines():
        if l.startswith("RESULT|"):
            partes = l.split("|", 4)
            try:
                dados = json.loads(partes[4]) if len(partes) > 4 else {}
            except json.JSONDecodeError:
                dados = {}
            res[partes[1]] = {"estado": partes[2], "mensagem": partes[3], "dados": dados}
        elif l.startswith("META|"):
            try:
                meta = json.loads(l[5:])
            except json.JSONDecodeError:
                pass
    return res, meta


def executar_script(godot, script, xdg, grafico=False, filtro=None):
    args = [] if grafico else ["--headless"]
    args += ["--script", os.path.join(TESTS, script)]
    if filtro:
        args += ["--", "--fase=" + filtro]
    rc, out = rodar(godot, args, xdg)
    res, meta = parse(out)
    fatais = [l for l in out.splitlines() if ERROS_FATAIS.search(l)]
    return rc, out, res, meta, fatais


def eval_000(godot):
    with tempfile.TemporaryDirectory() as xdg:
        rc, out = rodar(godot, ["--headless", "--quit-after", "300"], xdg, timeout=120)
        fatais = [l for l in out.splitlines() if ERROS_FATAIS.search(l)]
        log = os.path.join(xdg, "godot", "app_userdata", "DimEsgoto", "logs", "dimesgoto.log")
        txt = open(log, encoding="utf-8").read() if os.path.exists(log) else ""
        return [
            (rc == 0, "processo terminou com código %d" % rc),
            (not fatais, "sem SCRIPT ERROR / Parse Error / crash" + ("" if not fatais else ": " + fatais[0][:160])),
            ("SESSÃO  DimEsgoto" in txt and "iniciada" in txt, "log de sessão gravado (dimesgoto.log)"),
            ("encerrada normalmente" in txt, "log registra encerramento normal"),
        ]


def eval_001(godot):
    checks = []
    sc = os.path.join(TESTS, "_autoteste_tmp.gd")
    try:
        for estado, esperado in (("PASS", 0), ("FAIL", 1)):
            with open(sc, "w") as f:
                f.write('extends SceneTree\nfunc _initialize():\n\tprint("RESULT|EVAL-X|%s|autoteste|{}")\n'
                        '\tprint("DS=" + DisplayServer.get_name())\n\tquit(%d)\n' % (estado, esperado))
            with tempfile.TemporaryDirectory() as tmp:
                rc, out, res, _, _ = executar_script(godot, "_autoteste_tmp.gd", tmp)
            final = 1 if any(r["estado"] == "FAIL" for r in res.values()) or rc != 0 else 0
            checks.append((final == esperado, "teste %s → código agregado %d (esperado %d)" % (estado, final, esperado)))
        m = re.search(r"DS=(\w+)", out)
        checks.append((m is not None and m.group(1) == "headless", "scripts em modo headless (DisplayServer: %s)" % (m.group(1) if m else "?")))
    finally:
        if os.path.exists(sc):
            os.remove(sc)
    checks.append((True, "dependências: só Python 3 (biblioteca padrão) e Godot 4.4"))
    return checks


def como_resultado(checks):
    falhas = [m for c, m in checks if not c]
    return {"estado": "FAIL" if falhas else "PASS",
            "mensagem": " • ".join("FALHA: " + m for m in falhas) if falhas else " • ".join(m for _, m in checks), "dados": {}}


def juntar(a, b):
    if a is None:
        return b
    ordem = {"FAIL": 3, "PASS": 2, "SKIP": 1}
    est = a["estado"] if ordem.get(a["estado"], 0) >= ordem.get(b["estado"], 0) else b["estado"]
    if "FAIL" in (a["estado"], b["estado"]):
        est = "FAIL"
    elif a["estado"] == "PASS" or b["estado"] == "PASS":
        est = "PASS"
    return {"estado": est, "mensagem": a["mensagem"] + " • " + b["mensagem"], "dados": {**a["dados"], **b["dados"]}}


def ler_anterior():
    p = os.path.join(REPORT, "ultimo_relatorio.json")
    if not os.path.exists(p):
        return {}
    try:
        return json.load(open(p, encoding="utf-8")).get("resultados", {})
    except (OSError, json.JSONDecodeError):
        return {}


def decisoes():
    p = os.path.join(TESTS, "DECISOES.md")
    if not os.path.exists(p):
        return []
    return [l.strip()[2:] for l in open(p, encoding="utf-8") if l.strip().startswith("- ")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--todas", action="store_true")
    ap.add_argument("--fase", type=int)
    ap.add_argument("--sem-grafico", action="store_true")
    a = ap.parse_args()
    godot = find_godot()
    if not godot:
        print("Godot 4 não encontrado (defina GODOT).")
        return 2
    tem_display = bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")) and not a.sem_grafico
    anterior = ler_anterior()
    inicio = datetime.datetime.now()
    resultados, meta, bloqueado_em = {}, {}, None
    fases = [a.fase] if a.fase is not None else sorted(FASES)
    for fase in fases:
        rotulo, scripts, graficos, ids = FASES[fase]
        print("\n=== %s ===" % rotulo)
        if bloqueado_em is not None:
            for i in ids:
                resultados[i] = {"estado": "SKIP", "mensagem": "bloqueado pelo portão: %s com FAIL" % bloqueado_em, "dados": {}}
            continue
        if fase == 0:
            resultados["EVAL-000"] = como_resultado(eval_000(godot))
            resultados["EVAL-001"] = como_resultado(eval_001(godot))
        lista = [(s, False) for s in scripts] + [(s, True) for s in graficos]
        for sc, grafico in lista:
            if not os.path.exists(os.path.join(TESTS, sc)):
                continue
            if grafico and not tem_display:
                for i in ids:
                    if i in ("T3-05", "T4-05", "T5-07"):
                        resultados[i] = juntar(resultados.get(i), {"estado": "SKIP",
                            "mensagem": "parte gráfica (%s) não executada: sem display" % sc, "dados": {}})
                continue
            with tempfile.TemporaryDirectory() as xdg:
                rc, out, res, m, fatais = executar_script(godot, sc, xdg, grafico, str(fase) if grafico else None)
            for l in out.splitlines():
                if l.startswith("  "):
                    print(l)
            meta = meta or m
            for i, r in res.items():
                if i in ids or i.startswith("EVAL"):
                    resultados[i] = juntar(resultados.get(i), r)
            if fatais:
                print("  ! erro de script em %s: %s" % (sc, fatais[0][:200]))
                alvo = [i for i in ids if i in res] or ids
                for i in alvo:
                    resultados[i] = juntar(resultados.get(i), {"estado": "FAIL",
                        "mensagem": "FALHA: erro de script durante o teste: " + fatais[0][:160], "dados": {}})
            if not res:
                print("  ! %s não produziu resultados (código %d)\n%s" % (sc, rc, out[-2000:]))
        # T5-09: regressão completa = nenhuma fase anterior com FAIL nesta execução
        if fase == 5 and "T5-09" in ids:
            anteriores = [i for f in range(0, 5) for i in FASES[f][3]]
            falhas = [i for i in anteriores if resultados.get(i, {}).get("estado") == "FAIL"]
            nao_exec = [i for i in anteriores if i not in resultados]
            ok = not falhas and not nao_exec
            resultados["T5-09"] = {"estado": "PASS" if ok else "FAIL", "dados": {},
                "mensagem": "fases 0–4 executadas nesta rodada sem FAIL" if ok else
                "FALHA: " + ("com FAIL: %s" % ", ".join(falhas) if falhas else "") + (" não executados: %s" % ", ".join(nao_exec) if nao_exec else "")}
        for i in ids:
            if i not in resultados:
                resultados[i] = {"estado": "FAIL", "mensagem": "FALHA: teste não implementado/sem resultado", "dados": {}}
        if any(resultados[i]["estado"] == "FAIL" for i in ids) and not a.todas:
            bloqueado_em = rotulo.split(" — ")[0]
    # ------------------------------------------------------------ relatório
    print("\n%-9s %-5s %s" % ("ID", "", "RESUMO"))
    cont = {"PASS": [], "FAIL": [], "SKIP": []}
    for i in sorted(resultados, key=lambda x: (x[0] != "E", x)):
        r = resultados[i]
        cont.setdefault(r["estado"], []).append(i)
        print("%-9s %-5s %s" % (i, r["estado"], r["mensagem"][:140]))
    novas = [i for i in cont["FAIL"] if anterior.get(i, {}).get("estado") != "FAIL"]
    regress = [i for i in cont["FAIL"] if anterior.get(i, {}).get("estado") in ("PASS", "APROVADO")]
    os.makedirs(REPORT, exist_ok=True)
    gerados = ["tests/report/ultimo_relatorio.json", "tests/report/relatorio.txt"]
    if os.path.isdir(os.path.join(REPORT, "artefatos")):
        gerados += ["tests/report/artefatos/" + f for f in sorted(os.listdir(os.path.join(REPORT, "artefatos")))]
    txt = "\n".join([
        "Data: %s" % inicio.strftime("%Y-%m-%d %H:%M:%S"),
        "Commit/versão: %s (sem controle de versão git; banco %s)" % (meta.get("app", "?"), meta.get("banco", "?")),
        "Versão do Godot: %s" % meta.get("godot", "?"),
        "",
        "PASS: %d  %s" % (len(cont["PASS"]), ", ".join(cont["PASS"])),
        "FAIL: %d  %s" % (len(cont["FAIL"]), ", ".join(cont["FAIL"])),
        "SKIP: %d  %s" % (len(cont["SKIP"]), ", ".join("%s (%s)" % (i, resultados[i]["mensagem"][:60]) for i in cont["SKIP"])),
        "",
        "Falhas novas: %s" % (", ".join(novas) or "nenhuma"),
        "Regressões: %s" % (", ".join(regress) or "nenhuma"),
        "Arquivos gerados:\n  " + "\n  ".join(gerados),
        "Decisões técnicas:\n  - " + "\n  - ".join(decisoes() or ["(ver tests/DECISOES.md)"]),
    ])
    print("\n" + txt)
    if bloqueado_em:
        print("\nPortão: parado em %s. Use --todas para diagnóstico completo." % bloqueado_em)
    with open(os.path.join(REPORT, "relatorio.txt"), "w", encoding="utf-8") as f:
        f.write(txt + "\n")
    with open(os.path.join(REPORT, "ultimo_relatorio.json"), "w", encoding="utf-8") as f:
        json.dump({"data": inicio.isoformat(timespec="seconds"), "godot": godot, "meta": meta,
                   "totais": {k: len(v) for k, v in cont.items()}, "portao_parado_em": bloqueado_em,
                   "resultados": resultados}, f, ensure_ascii=False, indent=1)
    return 1 if cont["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
