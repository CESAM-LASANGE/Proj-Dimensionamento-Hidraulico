# 03 — Portões de qualidade, ciclo de trabalho e autonomia

Mesmo processo do Flight Watch (`docs/design-refactor/05` a `07`) e do Portal de Resíduos, adaptado a este projeto (Godot, sem CI, suíte própria em `tests/run_tests.py`). Nada aqui afrouxa o que as fases 0 a 7 já exigem.

## Ciclo por tarefa

```text
Ler → Red → Green → Refactor → Eval → Review → Registrar
```

1. **Ler.** `git status --short` (não mexer no que não é seu), a ficha da tarefa em [04-backlog.md](04-backlog.md), a spec em [02-specs.md](02-specs.md), o caso em [tests/PHASE-8.md](../../tests/PHASE-8.md), as respostas do chefe já recebidas ([05-perguntas-chefe.md](05-perguntas-chefe.md)) e os arquivos do código citados.
2. **Red.** Escrever primeiro o teste do caso T8-NN em `tests/test_fase8.gd` e rodar `python3 tests/run_tests.py --fase 8`. Ele precisa falhar **pelo motivo certo**: por exemplo, em T8-01, "y/D de início = 1,00 com ø150, aprovado", e não um erro de script.
3. **Green.** O menor código que passa, com a regra no domínio (`net.gd`, `calc.gd`, `db.gd`) e a interface (`plan_view.gd`, `main.gd`, `dialogs.gd`) só chamando o domínio.
4. **Refactor.** Limpar sem mudar o comportamento, com a fase verde.
5. **Eval.** Rodar os portões abaixo, na ordem.
6. **Review.** Reler o diff inteiro procurando o que pode quebrar: Desfazer, salvar/abrir, importação DXF, GeoJSON/GeoPackage, planilhas e projetos antigos.
7. **Registrar.** Atualizar [PROGRESS.md](PROGRESS.md) (uma linha por tarefa, com a saída real do runner) e, se houve decisão, `tests/DECISOES.md`.

Bug sempre ganha teste de regressão (T8-01 nasce do bug da lâmina).

## Portões

| # | Portão | Comando / ação | Passa quando |
|---|---|---|---|
| G0 | Escopo | ficha da tarefa | o diff só toca os arquivos da ficha, ou a ficha foi atualizada antes |
| G1 | Script carrega | `python3 tests/run_tests.py --fase 8 --sem-grafico` | nenhum erro de parse do Godot; o runner chega ao fim |
| G2 | Fase 8 | idem | os casos da tarefa estão PASS; os casos de tarefas futuras estão SKIP com motivo, nunca FAIL escondido |
| G3 | Suíte completa | `python3 tests/run_tests.py` (com tela, para os testes gráficos) | `FAIL: 0`, "Falhas novas: nenhuma", "Regressões: nenhuma" |
| G4 | Tela | capturas do app (`app/shots/`) do que mudou visualmente | olhadas uma a uma; anexadas ao registro da tarefa |
| G5 | Documentação | `tests/PHASE-8.md`, `EVALS.md` (seção fase 8), `tests/DECISOES.md`, `CHANGELOG.md` ("Não publicado"), `README.md` e ajuda F1 (`dialogs.gd`) | o que mudou para o usuário está escrito, em português, para o engenheiro |
| G6 | Revisão | releitura adversarial do diff | nenhum item aberto sem justificativa |
| G7 | Versão (só no fechamento) | `tools/build_release.py` → `dist/v<versão>/`; executável abre | zips e SHA256SUMS gerados; push e Release só com aprovação |

Durante o trabalho, rode só a fase (`--fase 8`). Antes de dar a tarefa por feita, rode G3. Nunca declare verde o que não rodou: portão não executado vai no PROGRESS com o motivo.

## Proibido para chegar ao verde

- remover, pular ou afrouxar teste ou critério, inclusive os testes gráficos e os EVAL de referência;
- trocar um critério por "olhei e parece ok";
- mudar a fixture para o teste passar (fixture nova, sim; mudar a antiga, não);
- mudar resultado de cálculo do caso de referência sem decisão registrada;
- implementar regra de negócio [Q] diferente do padrão proposto sem resposta do chefe.

## Autonomia

Níveis do Flight Watch (`07-autonomia-progressiva.md`):

| Nível | Pode |
|---|---|
| 1 | propor plano e diff, e esperar |
| 2 | alterar testes e documentação aprovados |
| 3 | implementar uma tarefa da ficha |
| 4 | alterar vários módulos dentro de uma spec aprovada |

- **Nível 3** para as tarefas da onda A.
- **Nível 1** (propor e esperar) para:
  - B4, formato do arquivo, porque muda o contrato de dados;
  - a migração de bancos editados pelo usuário em B1;
  - a mudança no motor de cálculo em A1, que já está aprovada pelo chefe no áudio 12: a proposta vai junto com o Red, para você ver os números antes;
  - qualquer regra [Q] sem resposta.
- **Sempre com aprovação humana explícita:** commit em `main`, push, tag, Release no GitHub, versão nova, e qualquer texto que fale em nome do chefe ou da CESAM.
