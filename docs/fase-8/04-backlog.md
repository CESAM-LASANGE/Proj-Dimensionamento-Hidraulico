# 04 — Plano de trabalho (backlog da fase 8)

Uma tarefa de cada vez, na ordem abaixo, com o ciclo e os portões de [03-quality-gates.md](03-quality-gates.md). Cada linha é uma ficha: Red, arquivos permitidos, nível de autonomia e de que resposta depende.

## Visão geral

```text
F0 (preparação)
 ├─ Onda A — não depende de resposta (começa já)
 │    A2 PV automático ─► A3 TIL de passagem ─► A4 pergunta do TL ─► A1 lâmina
 │    A5 rótulo PVs e trechos     A6 comprimento ao traçar     A7 aviso da planta
 │
 ├─ Onda B — depende das respostas do chefe (Q1 a Q9)
 │    B1 materiais (Q6)   B2 numeração 1/1 (Q7)   B3 redesenhar (Q8)
 │    B4 formato .json (Q9 + sua decisão)   B5 planta preliminar (Q5, se ele quiser)
 │
 └─ Z — fechamento: regressão, documentação, versão 0.3.0-alpha (com sua aprovação)
```

Ordem pedida pelo chefe e confirmada pelo dono em 17/11/2026: **conversão do TL primeiro** (A2, A3 e A4), redesenhar depois (áudio 18). A lâmina (A1) vem logo depois da conversão do TL. Ela é um erro de resultado (hoje o cálculo aprova um tubo cheio, com y/D = 1,00), então não espera a onda B.

Os itens A3 e A4 usam os padrões provisórios (sigla `TIL-P`, Cancelar desiste da ligação). Se a resposta do chefe mudar algum padrão, o ajuste é pequeno e fica registrado.

## F0 — Preparação (sem mudar comportamento)

| ID | Tarefa | Red | Arquivos | Nível |
|---|---|---|---|---|
| F0.1 | Fase 8 no runner (`FASES[8]`, `REGRESSAO[8] = "T8-11"`), `tests/test_fase8.gd` com os casos em SKIP ("a implementar") e as fixtures novas | `--fase 8` não existe | `tests/run_tests.py`, `tests/test_fase8.gd`, `tests/fixtures/` | 2 |
| F0.2 | Mandar as perguntas ao chefe | — | [05-perguntas-chefe.md](05-perguntas-chefe.md) (você envia) | — |

## Onda A — começa já

| ID | Tarefa | Pedido / spec / teste | Red | Arquivos | Nível |
|---|---|---|---|---|---|
| A1 | Lâmina conferida com as duas vazões; motor 3.2 | P8-04 / SPEC-8.01 / T8-01 | 35/20 l/s em `rede_unica.esg` → ø150, y/D de início 1,00, aprovado | `calc.gd` (`_avaliar`, `_dim`, `MOTOR_VERSAO`), `report.gd` (se o texto da observação mudar) | 1 → 3 (mostrar os números do Red antes) |
| A2 | Nó com 2 ou 3 entradas vira PV, no domínio, em todos os caminhos (traçado, osnap, DXF, abrir projeto antigo, Desfazer) | P8-02 / SPEC-8.03 / T8-03 | TIL de passagem/PI com 2 entradas continua com o tipo antigo | `net.gd`, `plan_view.gd` (`_tracar_ate`), `main.gd` (abrir, importar DXF), `calc.gd` (validação "TL no meio da rede") | 3 |
| A3 | TIL de passagem no banco, no símbolo, no DXF, na legenda e no orçamento | P8-03 / SPEC-8.04 / T8-04 | "TIL de passagem" não existe em `db.pvs` | `db.gd`, `plan_view.gd` (`_simbolo`), `report.gd` (DXF e legenda), `calc.gd` (orçamento e aviso de DN > 300) | 3 |
| A4 | Pergunta ao ligar num TL (PV / PI / TIL de passagem / Cancelar), num passo só de Desfazer | P8-01 / SPEC-8.02 / T8-02 | ligar em TL não abre nada, e o nó continua TL | `plan_view.gd`, `main.gd` (diálogo e Desfazer), `net.gd` | 3 |
| A5 | Rótulo "Numeração automática de PVs e trechos" (e ajuda F1) | P8-08 / SPEC-8.07 / T8-07 (1º critério) | o texto antigo aparece | `dialogs.gd` | 3 |
| A6 | Comprimento em vermelho logo depois de traçar | P8-09 / SPEC-8.08 / T8-08 | sem cálculo, nenhum rótulo de extensão | `plan_view.gd` | 3 |
| A7 | O aviso de bloqueio diz quais trechos impedem e por quê | P8-05 / SPEC-8.05 / T8-05 | o aviso só diz "há restrições impeditivas" | `main.gd` (`motivo_bloqueio`) | 3 |

Ao fim da onda A: G3 completo, entrega parcial para o chefe testar (sem versão nova, a não ser que você peça).

## Onda B — depois das respostas

| ID | Tarefa | Depende de | Pedido / spec / teste | Arquivos | Nível |
|---|---|---|---|---|---|
| B1 | Materiais PVC / PVC corrugado / Ferro fundido; nomes sem marca; migração de projetos e bancos antigos | Q6 | P8-06 / SPEC-8.06 / T8-06 | `db.gd`, `main.gd` (abrir), `dialogs.gd` (banco) | 3 (migração de banco editado: 1) |
| B2 | Numeração coletor/trecho (1/1) | Q7 | P8-07 / SPEC-8.07 / T8-07 | `net.gd` (`renumerar`), exportações que usam nome em arquivo | 3 |
| B3 | Redesenhar limpa resíduos e atualiza símbolos | Q8 | P8-10 / SPEC-8.09 / T8-09 | `plan_view.gd`, `main.gd` (comando 37) | 3 |
| B4 | Projeto salvo em `.json` (versão 4); `.esg` continua abrindo | Q9 + sua decisão | P8-11 / SPEC-8.10 / T8-10 | `main.gd` (salvar, abrir, recentes), README, ajuda | 1 |
| B5 | Planta preliminar com carimbo (se o chefe quiser) | Q5 | P8-05 / SPEC-8.05 / T8-05 | `main.gd`, `report.gd` | 3 |

Se Q1 ou Q2 mudarem os padrões de A3 e A4, o ajuste entra como B6, com o teste mudado para o critério novo (igual ou mais forte) e a decisão registrada.

## Z — Fechamento

| ID | Tarefa | Passa quando |
|---|---|---|
| Z1 | Regressão completa (T8-11) | `python3 tests/run_tests.py`: FAIL 0, sem falhas novas, sem regressões |
| Z2 | Documentação | `EVALS.md` (fase 8), `CHANGELOG.md`, `README.md`, ajuda F1, `docs/MUDANCAS-…` da versão |
| U1 | Atualização automática (fase 9, `tests/PHASE-9.md`) | **feito em 17/11/2026**: T9-01 a T9-08 PASS, ensaio 8/8 |
| Z3 | Versão de teste 0.3.0-alpha.1 (com U1); as seguintes, 0.3.0-alpha.2, .3… | aprovada em 17/11/2026 → número nos 3 lugares, build em `dist/v0.3.0-alpha.1/`, commit, tag, push, Release (pre-release) |

## Riscos

| Risco | Como tratar |
|---|---|
| A1 muda diâmetros de projetos já calculados com vazão de início maior que a de fim | é a correção pedida; o motor 3.2 marca a diferença no memorial e o CHANGELOG avisa |
| A2 e A4 mexem no Desfazer (tipo do nó + trecho num passo só) | critério explícito em T8-02 e T8-03; T5-03 (Desfazer) na regressão |
| B1: bancos editados com os nomes antigos | migrar só o banco padrão; banco do usuário só com confirmação |
| B2: "/" nos nomes vai para nome de arquivo ou para o DXF | critério em T8-07; nome de arquivo nunca é montado a partir do nome do trecho sem saneamento |
| B4: arquivos .esg circulando entre usuários | abrir .esg para sempre; só a gravação muda |
| Resposta do chefe demora | a onda A não depende dela; B espera, sem implementar regra inventada |
