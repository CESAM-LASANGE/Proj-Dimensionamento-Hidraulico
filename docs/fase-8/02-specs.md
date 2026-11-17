# 02 — Specs da fase 8

Contrato de comportamento de cada pedido, no formato Dado / Quando / Então. Os testes que garantem cada spec estão em [tests/PHASE-8.md](../../tests/PHASE-8.md), com o mesmo número (SPEC-8.NN ↔ T8-NN).

Itens marcados **[Q]** dependem de resposta do chefe ([05-perguntas-chefe.md](05-perguntas-chefe.md)). Enquanto não houver resposta, vale o padrão proposto, e a decisão fica registrada em `tests/DECISOES.md`.

Invariantes que valem para toda a fase, herdadas das fases 6 e 7:

- as regras de rede ficam no domínio (`net.gd`, `calc.gd`), não só na interface;
- a rede continua consistente depois de qualquer edição: no máximo 3 entradas e 1 saída por nó, sem laço e sem nó solto;
- toda mudança no projeto é um passo de Desfazer, e o Ctrl+Z volta ao estado anterior inteiro (tipo do nó incluído);
- nenhum teste existente é removido ou afrouxado.

---

## SPEC-8.01 — Lâmina máxima com as duas vazões (P8-04)

- **Dado** um trecho cuja vazão de projeto de início de plano é maior que a de fim de plano,
- **quando** a rede é dimensionada,
- **então** o diâmetro escolhido mantém y/D ≤ 0,75 com **as duas** vazões (ou ≤ 0,50 quando a velocidade passa da crítica com aquela vazão).

Critérios de aceite:

- o caso do print (35 / 20 l/s em `rede_unica.esg`) sai com diâmetro maior que 150 mm e y/D de início ≤ 0,75;
- quando nenhum diâmetro cadastrado atende, o trecho sai com "Verifique: lâmina … maior que o limite" (início ou fim, conforme o caso), status impeditivo, e o resultado **não** é aprovado;
- com vazão de início ≤ vazão de fim, os resultados são **idênticos** aos de hoje (EVAL-101 a 107 intactos);
- a versão do motor sobe (`motor-3.1` → `motor-3.2`), e o memorial e o identificador de rastreio mostram a nova versão;
- **[Q4]** tensão trativa: continua com a vazão de início até a resposta. Se o chefe confirmar, passa a usar a menor das duas.

## SPEC-8.02 — TL que recebe rede: o usuário escolhe o novo tipo (P8-01)

- **Dado** um nó do tipo TL com 0 entradas e 1 saída,
- **quando** o usuário termina um trecho nesse nó (traçado, osnap ou ligação ao PV),
- **então** aparece a pergunta "Este TL deixa de ser início de rede. Transformar em:" com as opções **Poço de visita (PV)**, **Poço de inspeção (PI)** e **TIL de passagem**, e Cancelar.

Critérios de aceite:

- a escolha troca o tipo do nó e cria o trecho, **num só passo** de Desfazer;
- Cancelar não cria o trecho e não muda o tipo; o traçado continua ativo, como na recusa de ligação da fase 6 **[Q2]**;
- o símbolo novo aparece na hora (sem Ctrl+R);
- a regra também vale para a rede importada de DXF: o TL que recebe rede vira PV, sem pergunta (importação não é interativa);
- vale para um TL só: um nó que já é PV, PI ou TIL de passagem não gera pergunta.

## SPEC-8.03 — Duas ou mais entradas: PV automático (P8-02)

- **Dado** um nó do tipo TL, PI, TIL de passagem ou CP **[Q3]**,
- **quando** ele passa a ter 2 ou 3 entradas (ligação, importação, divisão de trecho ou desfazer/refazer),
- **então** ele vira PV automaticamente, **sem mensagem**.

Critérios de aceite:

- ligar o 2º trecho num TIL de passagem ou num PI faz dele PV, sem diálogo;
- num projeto salvo antes da fase 8, um TL que já tem 1 entrada vira PV direto ao receber a 2ª, sem a pergunta do SPEC-8.02. Ao abrir esse projeto, TL com 2 ou mais entradas vira PV, e TL com 1 entrada aparece nos alertas ao dimensionar como "TL no meio da rede" (não bloqueia o cálculo);
- a regra mora no domínio (`Net.tipo_por_entradas` ou equivalente) e é aplicada em todos os caminhos que criam entradas;
- quando um nó perde entradas e volta a ter 1, ele **continua PV** (não volta sozinho) **[Q3]**;
- TQ e TT não mudam (já são PV).

## SPEC-8.04 — TIL de passagem no cadastro (P8-03)

- **Dado** o banco padrão,
- **então** existe o órgão acessório "TIL de passagem", com sigla de planta provisória `TIL-P` e custo provisório igual ao do TIL radial **[Q1]**.

Critérios de aceite:

- aparece em "Tipo do nó" na janela do nó, com símbolo próprio na planta e no DXF, e na legenda;
- entra no orçamento como os outros órgãos;
- se o trecho ligado ao TIL de passagem tiver diâmetro maior que 300 mm, o cálculo registra "Verifique" (advertência, não impeditivo) **[Q1]**;
- bancos antigos ganham o item ao abrir, sem perder o que o usuário editou;
- é salvo e lido em .esg/.json, GeoJSON e GeoPackage (campo `tipo`).

## SPEC-8.05 — Exportação da planta depois de dimensionar (P8-05)

- **Dado** uma rede dimensionada,
- **quando** o usuário exporta a planta DXF com resultados,
- **então** ou ela sai, ou o aviso diz exatamente o motivo **e quais trechos** impedem (ex.: "T4: lâmina final 0,82 > 0,75").

Critérios de aceite:

- com o P8-04 corrigido, a rede do chefe (ou o caso do print) exporta normalmente quando o resultado é aprovado;
- a planta **sem** resultados (só o traçado) fica sempre disponível. Ela não existia: só havia a planta com resultados. Foi criada em Arquivos › Exporta traçado para DXF (sem resultados), e o aviso de bloqueio aponta para ela;
- a regra do EVAL-104 continua: resultado desatualizado ou não aprovado não sai como final;
- **[Q5]** se o chefe quiser, uma opção "Exportar planta preliminar", com o carimbo "PRELIMINAR — resultado não aprovado" no DXF.

## SPEC-8.06 — Materiais sem marca (P8-06)

- **Dado** um banco padrão novo,
- **então** os materiais são **PVC**, **PVC corrugado** e **Ferro fundido**, cada um com Manning 0,010 e K 0,06 (valores provisórios para o ferro fundido) **[Q6]**, e nenhum nome comercial (Vinilfort, Vinilfer, Tigre, DEFoFo) aparece no banco padrão.

Critérios de aceite:

- cada material tem a sua tabela de diâmetros; até a resposta, as de PVC e PVC corrugado copiam a do PVC atual, e a de ferro fundido começa em DN 150 **[Q6]**;
- ao abrir um projeto com "PVC Vinilfort Tigre - NBR7362", o trecho passa para "PVC", e "PVC Tigre Vinilfer DEFoFo JEI" também passa para "PVC" **[Q6]**, com um aviso único;
- um banco **editado pelo usuário** não é alterado sem pedir (o aviso oferece a migração);
- os TILs perdem "VINILFORT" no nome **[Q6]**;
- os resultados do caso de referência não mudam (n e K iguais).

## SPEC-8.07 — Numeração coletor/trecho (P8-07, P8-08)

- **Dado** a opção "Numeração automática de PVs e trechos" marcada,
- **quando** a rede é dimensionada,
- **então** cada trecho é nomeado "coletor/ordem" (1/1, 1/2, …), o coletor 1 é o caminho mais extenso até a saída e os demais coletores seguem a regra confirmada pelo chefe **[Q7]**.

Critérios de aceite:

- a opção se chama "Numeração automática de PVs e trechos" (rótulo e ajuda F1);
- sem a opção, os nomes continuam como o usuário deixou (T1, T2, …);
- os nomes novos aparecem em todas as planilhas, no perfil, no memorial, no DXF e no GeoPackage, e o "/" não quebra nenhum nome de arquivo exportado;
- busca (Localizar) e referências por nome continuam funcionando;
- PVs: numeração sequencial de montante para jusante, como hoje **[Q7]**.

## SPEC-8.08 — Comprimento do trecho ao traçar (P8-09)

- **Dado** um trecho recém-traçado, sem resultado de cálculo,
- **então** a extensão aparece embaixo dele, em vermelho, no mesmo lugar e com o mesmo estilo do rótulo de resultado ("45,32 m").

Critérios de aceite:

- o comprimento acompanha o arrasto dos nós e a divisão do trecho;
- depois de dimensionar, o rótulo volta a ser o completo (ø, extensão e declividade);
- respeita a opção de exibição de rótulos e não aparece quando o trecho é curto demais na tela (como o rótulo atual);
- gráfico: os pixels vermelhos do texto aparecem junto ao trecho.

## SPEC-8.09 — Redesenhar limpa a tela (P8-10)

- **Dado** a tela com o rastro do cálculo de cota (área de influência e retas) ou outro resíduo de desenho,
- **quando** o usuário usa Redesenha (Ctrl+R ou botão),
- **então** os resíduos somem, os símbolos dos nós refletem o tipo atual e o desenho é refeito com os dados atuais, sem mudar o projeto.

Critérios de aceite:

- Ctrl+R não cria passo de Desfazer e não marca o projeto como alterado;
- depois do Ctrl+R, nenhum pixel do rastro aparece;
- o traçado em andamento não é cancelado pelo Ctrl+R **[Q8]**;
- a lista do que é resíduo vem da resposta Q8.

## SPEC-8.10 — Formato do arquivo de projeto (P8-11)

Proposta (a), a confirmar com você e com o chefe (Q9):

- **Dado** um projeto,
- **quando** o usuário salva,
- **então** o arquivo é `.json`, com o conteúdo atual (`"formato": "dimesgoto"`, versão 4).

Critérios de aceite:

- Abrir aceita `.json` e `.esg` (todos os arquivos antigos continuam abrindo);
- salvar um projeto aberto de `.esg` propõe o mesmo nome com `.json` (o `.esg` original não é apagado);
- recentes e título da janela mostram o `.json`;
- a gravação continua atômica (T5-06), e o arquivo corrompido continua sendo rejeitado sem perder o projeto aberto (T5);
- as fixtures `.esg` dos testes **não** são renomeadas: elas passam a ser o teste de compatibilidade.
