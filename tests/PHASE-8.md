# Testes da fase 8 — pedidos do engenheiro de 17/11/2026

> **Situação (17/11/2026): T8-01 a T8-05 e T8-08 implementados e aprovados; T8-06, T8-07 (só o rótulo feito), T8-09 e T8-10 aguardam as respostas do engenheiro.** Os casos abaixo são o contrato da fase 8. Eles entram na suíte (`test_fase8.gd`, runner fase 8) à medida que as tarefas de [docs/fase-8/04-backlog.md](../docs/fase-8/04-backlog.md) são feitas. Os itens **[Q]** dependem de resposta do chefe e podem mudar o critério. Nunca para menos: cada mudança fica registrada em [DECISOES.md](DECISOES.md).

Convenções de [PHASE-2-5.md](PHASE-2-5.md): coordenadas e cotas em metros, tolerância geométrica de 0,001 m, estados `PASS` / `FAIL` / `SKIP`. Specs em [docs/fase-8/02-specs.md](../docs/fase-8/02-specs.md).

Implementação prevista:

- `test_fase8.gd` (headless): T8-01 a T8-10;
- `test_grafico.gd --fase=8`: as partes de tela de T8-02, T8-08 e T8-09.

Fixtures:

- `rede_unica.esg` e `rede_ramificada.esg` (existentes);
- novas: `rede_tl_meio_v3.esg` (projeto da versão 3 com TL de 1 e de 2 entradas), `banco_marcas_v1.json` (banco antigo com os nomes comerciais) e `rede_numeracao.esg` (coletor principal com 3 afluentes de extensões diferentes, mais um sub-afluente).

---

### T8-01 — lâmina ≤ 75% com as duas vazões (SPEC-8.01)

Em `rede_unica.esg`, vazão pontual na cabeceira.

Critérios:

- **Red (falha hoje):** com início 35 l/s e fim 20 l/s, y/D de início = 1,00 com ø150, e o resultado sai aprovado;
- com início 35 e fim 20: ø > 150, y/D de início ≤ 0,75 e y/D de fim ≤ 0,75;
- com início 20 e fim 35: mesmo diâmetro e mesmas cotas de antes da correção (350 mm);
- sem vazão pontual: resultados idênticos aos de antes (comparar todas as colunas da linha);
- com diâmetro fixado em 150 e início 35: "Verifique: lâmina inicial y/D = 1,00 maior que o limite de 0,75", status impeditivo, resultado não aprovado;
- velocidade acima da crítica com a vazão de início: limite de 50% aplicado a essa vazão;
- o memorial cita `motor-3.2`;
- EVAL-101 a EVAL-107 continuam PASS (o runner confere).

### T8-02 — TL que recebe rede: pergunta e escolha (SPEC-8.02)

Coletor A: TL1 → PV2 → PV3 (saída). Novo coletor B: TL4 → (clique em TL1).

Critérios:

- ao clicar em TL1, aparece a pergunta com PV, PI, TIL de passagem e Cancelar; o trecho ainda não existe;
- escolher PI: o trecho TL4 → TL1 é criado e TL1 vira PI; um Ctrl+Z desfaz os dois, e TL1 volta a ser TL sem o trecho;
- escolher PV e escolher TIL de passagem: idem, com o tipo correspondente;
- Cancelar: nenhum trecho novo, TL1 continua TL, o traçado segue ativo **[Q2]**;
- clicar num PV não abre a pergunta;
- DXF: uma polilinha que termina num TL importado de outra polilinha faz dele PV, sem pergunta;
- gráfico: o símbolo de TL1 muda na tela logo depois da escolha.

### T8-03 — 2 ou mais entradas: PV automático (SPEC-8.03)

Critérios:

- TIL de passagem com 1 entrada recebe a 2ª: vira PV, sem diálogo (nenhuma janela visível);
- idem para PI e CP **[Q3]**;
- dividir o trecho de chegada não altera o tipo (a divisão cria um PV novo, e o nó continua com as mesmas entradas);
- apagar uma das 2 entradas: o nó continua PV **[Q3]**;
- Ctrl+Z da 2ª ligação devolve o tipo anterior (TIL de passagem);
- `rede_tl_meio_v3.esg`: ao abrir, o TL com 2 entradas vira PV (o status avisa), e o TL com 1 entrada aparece nos alertas ao dimensionar ("TL no meio da rede");
- TQ e TT com 2 entradas não mudam;
- a regra está no domínio: chamada direta de `Net` sem a interface produz o mesmo tipo.

### T8-04 — TIL de passagem (SPEC-8.04)

Critérios:

- o banco padrão tem "TIL de passagem", sigla `TIL-P` **[Q1]**, e ele aparece em "Tipo do nó";
- símbolo próprio na planta (diferente de TL, PV, PI e TIL radial), na legenda e no DXF;
- o orçamento conta a peça com o custo do banco;
- trecho de ø > 300 ligado a ele: "Verifique: TIL de passagem aceita até DN 300" (advertência) **[Q1]**;
- banco antigo (`banco_teste.json`, sem o item): ao carregar, o item é acrescentado, e os itens editados ficam como estavam;
- o tipo sobrevive a salvar/abrir, GeoJSON e GeoPackage.

### T8-05 — exportação da planta (SPEC-8.05)

Critérios:

- rede do caso T8-01 (35 / 20) dimensionada depois da correção: aprovada, e a planta DXF com resultados é gravada;
- rede com trecho impeditivo (diâmetro fixado): o aviso cita o trecho e o motivo (ex.: "T1: lâmina inicial 1,00 > 0,75");
- planta só do traçado (comando novo, Arquivos › Exporta traçado para DXF): disponível com ou sem resultado, sem diâmetros e com a nota "traçado sem resultados de dimensionamento"; o aviso de bloqueio aponta esse comando;
- EVAL-104 intacto (desatualizado / não aprovado não sai como final);
- **[Q5]** se aprovada a planta preliminar: o DXF tem o texto "PRELIMINAR — resultado não aprovado" no layer de textos.

### T8-06 — materiais sem marca (SPEC-8.06)

Critérios:

- banco padrão: exatamente PVC, PVC corrugado e Ferro fundido; nenhuma ocorrência de "Vinilfort", "Vinilfer", "Tigre" ou "DEFoFo" em nenhum texto do banco padrão;
- n = 0,010 e K = 0,06 nos três **[Q6]**;
- cada material tem diâmetros e custos próprios **[Q6]**;
- `banco_marcas_v1.json` + projeto com os nomes antigos: os trechos passam para "PVC", com um aviso só; o banco editado não muda sem confirmação;
- `rede_unica.esg`: mesmos diâmetros, cotas e custos de antes (n e K iguais).

### T8-07 — numeração coletor/trecho (SPEC-8.07)

`rede_numeracao.esg` com a numeração automática marcada.

Critérios:

- a opção se chama "Numeração automática de PVs e trechos";
- trechos do coletor principal: 1/1, 1/2, … de montante para jusante;
- afluentes numerados como 2/…, 3/…, … na ordem confirmada **[Q7]** (o caso de teste tem a resposta esperada desenhada);
- sem a opção: os nomes ficam como estavam;
- os nomes aparecem iguais na planilha de resultados, no perfil, no DXF e no GeoPackage; a exportação de cada planilha grava arquivos válidos (sem "/" no nome do arquivo);
- Localizar acha "2/1".

### T8-08 — comprimento ao traçar (SPEC-8.08)

Critérios:

- trecho traçado de (0; 0) a (45,32; 0), sem cálculo: o texto do rótulo do trecho é "45,32 m";
- arrastar o nó final para (60; 0) atualiza para "60,00 m";
- depois de dimensionar: rótulo completo (ø, L, I), como hoje;
- com rótulos desligados, o comprimento não aparece;
- gráfico: há pixels vermelhos do rótulo junto ao meio do trecho.

### T8-09 — redesenhar (SPEC-8.09)

Critérios:

- depois de colocar um PV com interpolação (o rastro fica na tela), Ctrl+R limpa `rastro` e a tela redesenha;
- Ctrl+R não cria passo de Desfazer e não marca o projeto como alterado;
- os símbolos refletem os tipos atuais;
- gráfico: nenhum pixel azul do rastro depois do Ctrl+R (antes havia);
- **[Q8]** demais resíduos confirmados pelo chefe.

### T8-10 — formato do projeto (SPEC-8.10)

Critérios (opção a, a confirmar):

- salvar grava `.json` (`"formato": "dimesgoto"`, `"versao": 4`), e abrir o arquivo devolve o mesmo projeto (mesma rede, parâmetros e resultados);
- todas as fixtures `.esg` continuam abrindo;
- salvar um projeto aberto de `.esg` propõe `.json`, e o `.esg` original fica intacto;
- gravação atômica e rejeição de arquivo corrompido continuam (T5-04 e T5-06 PASS).

### T8-11 — regressão completa

Calculado pelo runner: fases 0 a 7 executadas na mesma rodada, sem FAIL.
