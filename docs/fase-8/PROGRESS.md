# PROGRESS — fase 8

Comece toda sessão lendo este arquivo e termine atualizando. Uma linha por tarefa fechada; pendências em lista.

## Estado

- Fase atual: **onda A concluída** (17/11/2026): F0.1, A2, A3, A4, A1, A5, A6 e A7. **U1 (atualização automática, fase 9) concluída**; versão de teste 0.3.0-alpha.1 gerada e assinada.
- Próxima tarefa: **onda B**, que depende das respostas do chefe (Q1 a Q9). Sem resposta, nada da onda B começa.
- Suíte completa: **72 PASS, 0 FAIL, 4 SKIP** (T8-06, T8-07 parcial, T8-09 e T8-10), sem falhas novas e sem regressões (0.3.0-alpha.1, com o T9-07 conferindo o pacote). Ensaio exportado: 8/8.
- Nível de autonomia: 3 na onda A; 1 em A1 (mostrar os números do Red antes), B4 e na migração de bancos editados (ver [03-quality-gates.md](03-quality-gates.md)).
- Linha de base: suíte completa 57/57 PASS (0.2.0-alpha, 16/11/2026).

## Pendências do dono

- [ ] Enviar ao chefe as perguntas de [05-perguntas-chefe.md](05-perguntas-chefe.md) e anotar as respostas na tabela.
- [ ] Pedir ao chefe o arquivo da rede em que a exportação da planta foi bloqueada (Q5).
- [ ] Decidir o formato do arquivo de projeto (Q9, opção a ou b).
- [x] Aprovar a tarefa U1 (atualização automática): aprovada em 17/11/2026, feita como troca do executável inteiro, com manifesto assinado (fase 9).
- [ ] Publicar o Release da tag `v0.3.0-alpha.1` (pre-release) com os 5 arquivos de `dist/v0.3.0-alpha.1/` e o texto de `docs/NOTAS-v0.3.0-alpha.1.md`.
- [ ] Guardar uma cópia de segurança da chave privada `~/.config/dimesgoto/chave-atualizacao.pem`.
- [ ] Pedir ao chefe que instale a 0.3.0-alpha.1 à mão (última vez) numa pasta onde ele possa gravar.

## Evidências já coletadas

- 17/11/2026 — bug da lâmina reproduzido em `rede_unica.esg` (motor 3.1): com 35 / 20 l/s, ø150, y/D de início 1,00 e aprovado. Ver [01-pedidos.md](01-pedidos.md), P8-04.

## Tarefas fechadas

| Data | Tarefa | Resultado do runner | Observação |
|---|---|---|---|
| 17/11 | F0.1 runner fase 8 + `test_fase8.gd` + fixture `rede_tl_meio_v3.esg` | fase 8 no runner; casos futuros em SKIP | grafico: T8-02 e T8-08 no `test_grafico.gd --fase=8` |
| 17/11 | A2 PV automático (2+ entradas) | T8-03 PASS | regra em `Net.ajustar_tipos`, aplicada em `Net.ligar` e em todo `on_changed`; ao abrir e importar GeoJSON. **Sem Red separado** (código antes do teste) |
| 17/11 | A3 TIL de passagem | T8-04 PASS | sigla TP/TIL-P e custo provisórios (Q1); `Db.completar` para bancos antigos. **Sem Red separado** |
| 17/11 | A4 pergunta ao ligar num TL | T8-02 PASS (+ gráfico: 82 px do símbolo mudam) | captura olhada: pergunta e símbolos. **Sem Red separado** |
| 17/11 | A1 lâmina com as duas vazões, motor 3.2 | Red: ø150, y/D início 1,00 → Green: ø350, y/D 0,68 | casos com início ≤ fim idênticos ao motor 3.1 (travados no teste) |
| 17/11 | A5 rótulo "PVs e trechos" | T8-07 SKIP (rótulo OK, 1/1 aguarda Q7) | |
| 17/11 | A6 comprimento ao traçar | T8-08 PASS (+ gráfico: 32 px vermelhos, 0 com rótulos desligados) | captura olhada |
| 17/11 | A7 aviso de bloqueio + exportação do traçado | T8-05 PASS | achado: não existia exportação só do traçado; criada. A captura mostrou o aviso de 2 linhas esticando a barra de status: corrigido (só a 1ª linha vai para a barra) |
| 17/11 | Suíte completa (G3) | 64 PASS, 0 FAIL, 4 SKIP | sem falhas novas, sem regressões |
| 17/11 | U1 atualização automática (fase 9) | T9-01 a T9-08 PASS; T9-06 Red (menu) → Green; ensaio exportado 8/8 | estáticas de `atualizador.gd` **sem Red separado**. A API real do GitHub foi consultada pelo Godot (TLS ok, releases sem manifesto ignorados). Troca no Windows sem teste automático |
| 17/11 | Z3 versão de teste 0.3.0-alpha.1 | build assinado em `dist/v0.3.0-alpha.1/` | aprovada pelo dono |
