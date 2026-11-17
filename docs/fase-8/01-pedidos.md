# 01 — Lista de pedidos (fase 8)

Cada pedido tem um ID `P8-NN`, os áudios de origem (ver [transcricao.md](transcricao.md)), o que o programa faz hoje (conferido no código e, quando possível, reproduzido) e o que falta saber.

Situação: **claro** = dá para implementar sem perguntar; **parcial** = uma parte é clara e outra depende de resposta; **bloqueado** = depende de resposta antes de começar.

| ID | Pedido | Áudios | Situação |
|---|---|---|---|
| P8-01 | Ao ligar uma rede num TL de início, perguntar se ele vira PV, PI ou TIL de passagem | 1, 13–16, img 2 | parcial |
| P8-02 | Nó com 2 ou 3 entradas vira PV automaticamente, sem mensagem | 17 | claro |
| P8-03 | Novo órgão acessório: TIL de passagem (DN 100 a 300) | 13, 14, 16, img 2 | parcial |
| P8-04 | A lâmina nunca passa de 75%, nem quando a vazão de início é maior que a de fim | 11, 12, img 1 | claro (bug confirmado) |
| P8-05 | A exportação da planta depois de dimensionar está bloqueada | 9 | parcial |
| P8-06 | Materiais sem marca: PVC, PVC corrugado e ferro fundido | 2 | parcial |
| P8-07 | Numeração automática no formato coletor/trecho (1/1, 1/2, 2/1…) | 3, 6 | parcial |
| P8-08 | Trocar o rótulo para "Numeração automática de PVs e trechos" | 4 | claro |
| P8-09 | Comprimento do trecho em vermelho logo depois de traçar | 8 | claro |
| P8-10 | Redesenhar (Ctrl+R) limpa os resíduos e atualiza os símbolos | 5, 10, 18 | parcial (o chefe pediu para depois) |
| P8-11 | Salvar o projeto em JSON ou GeoPackage, não em .esg | 7 | bloqueado (decisão de formato) |

Prioridade dada pelo chefe: primeiro a conversão do TL (P8-01 a P8-03), depois o redesenhar (áudio 18). O bug da lâmina (P8-04) entra antes de tudo, porque o cálculo hoje **aprova** um resultado errado. Ver [04-backlog.md](04-backlog.md).

---

## P8-01 — Conversão do TL ao receber uma rede

**Pedido.** O TL é criado no início de cada coletor. Quando o projetista liga depois uma rede de montante nesse TL, ele deixa de ser início de rede. Na hora da ligação, o programa pergunta se o TL vira poço de visita (PV), poço de inspeção (PI) ou TIL de passagem, e o usuário escolhe. O CEsg convertia em PV automaticamente; o chefe quer a escolha.

**Hoje.** A ligação num TL é aceita (ele tem saída), mas o nó **continua TL**. Nenhum código troca o tipo do nó depois que ele é criado (`plan_view.gd` cria TL ou PV; `net.gd` só define TL em `de_polilinhas`). O cálculo também não corrige: `calc.gd` mantém o TL. O resultado é um TL no meio da rede, na planta, no DXF e no orçamento.

**Falta saber.** O que acontece se o usuário cancelar a pergunta, e se a lista de opções inclui outros tipos (CP, TIL radial). Ver Q2 em [05-perguntas-chefe.md](05-perguntas-chefe.md).

## P8-02 — Duas ou mais entradas: PV automático

**Pedido.** As três opções do P8-01 valem para 1 entrada e 1 saída. Se o nó passar a ter 2 ou 3 entradas, ele vira PV automaticamente, sem mensagem, seja ele TIL de passagem, TL ou PI.

**Hoje.** Não existe. O limite de 3 entradas por PV já existe desde a fase 6 (`Net.MAX_ENTRADAS`).

**Suposições (a confirmar, Q3):** quando uma entrada é apagada e o nó volta a ter uma só, ele **continua PV** (não volta ao tipo anterior). A regra também vale para a caixa de passagem (CP). PV com tubo de queda (TQ, TT) já é PV e não muda.

## P8-03 — TIL de passagem

**Pedido.** Peça nova, que existe no mercado em DN 100, 150 e até 300 (foto da peça em PVC laranja).

**Hoje.** O banco tem CP, PI, PV, TL, TQ, TR ("TIL radial rede VINILFORT") e TT ("TIL tubo de queda VINILFORT"). Não tem TIL de passagem.

**Falta saber (Q1):** a sigla na planta, o custo, e o que fazer se o trecho que sai ou chega tiver mais de 300 mm (avisar, bloquear ou converter em PV). Também falta saber se existe profundidade máxima.

## P8-04 — Lâmina máxima de 75% sempre

**Pedido.** A lâmina nunca pode passar de 75%. Se passar, o programa aumenta o diâmetro. O erro aparece quando a vazão de início de plano é maior que a de fim.

**Hoje (bug confirmado em 17/11/2026).** `calc.gd` (`_avaliar`) escolhe o diâmetro conferindo a lâmina **só com a vazão de fim de plano**. Reprodução com `rede_unica.esg`, vazão pontual na cabeceira:

| Vazão pontual início / fim (l/s) | Diâmetro | y/D início | y/D fim | Aprovado |
|---|---|---|---|---|
| 0 / 0 | 150 | 0,32 | 0,52 | sim |
| **35 / 20** (o caso do print) | **150** | **1,00** | 0,69 | **sim** |
| 20 / 35 | 350 | 0,45 | 0,65 | sim |

Com 35 l/s no início, o tubo fica cheio (y/D = 1,00) e o resultado sai aprovado.

**Correção proposta.** O diâmetro passa a ser escolhido conferindo a lâmina com as duas vazões (na prática, a maior). O limite de 50% acima da velocidade crítica também passa a valer para as duas.

**Falta saber (Q4):** a tensão trativa hoje usa a vazão de início. Quando o início é maior que o fim, ela deveria usar a menor das duas, que é o caso mais desfavorável para a autolimpeza?

## P8-05 — Exportação da planta bloqueada

**Pedido.** Depois de dimensionar, a exportação da planta diz "Exportação bloqueada".

**Hoje.** A planta DXF com resultados só sai se o resultado for válido, estiver atualizado e estiver **aprovado** (`main.gd`, `motivo_bloqueio`). É a regra de segurança do EVAL-104. A causa mais provável é o próprio P8-04: com a lâmina acima do limite em algum trecho, o resultado não é aprovado. Outra causa possível é o projeto ter mudado depois do cálculo.

**Achado (17/11/2026).** Além disso, **não havia como exportar só o traçado**: a única exportação DXF da planta exige resultado aprovado. Antes de dimensionar, ou com qualquer restrição impeditiva, nada saía.

**Feito.** Exportação do traçado sem resultados (sempre disponível), aviso de bloqueio com os trechos e o motivo, e a correção da lâmina (P8-04). Falta reproduzir com a rede do chefe (pedir o arquivo).

**Falta saber (Q5):** a mensagem exata que ele viu (ou o arquivo), e se ele quer poder exportar uma planta **preliminar**, marcada como tal, mesmo sem aprovação.

## P8-06 — Materiais sem marca

**Pedido.** Tirar "PVC Vinilfort Tigre - NBR7362" e "PVC Tigre Vinilfer DEFoFo JEI". Colocar PVC, PVC corrugado e ferro fundido, com Manning 0,010 e K 0,06.

**Hoje.** `db.gd` cria esses dois materiais no banco padrão. O TIL radial e o TIL de tubo de queda também levam "VINILFORT" no nome. Projetos salvos guardam o nome do material em cada trecho.

**Falta saber (Q6):** se o ferro fundido fica mesmo com n = 0,010 e K = 0,06 (os valores usuais de ferro fundido são maiores, por volta de n = 0,012 a 0,013), quais diâmetros e custos cada material tem, e se "VINILFORT" sai também dos TILs.

**Compatibilidade:** projetos e bancos antigos com os nomes de marca passam a abrir com "PVC" (migração ao abrir, com aviso).

## P8-07 — Numeração coletor/trecho

**Pedido.** Com a numeração automática marcada, os trechos passam a ser chamados pelo coletor e pela posição: 1/1, 1/2, … no coletor 1; 2/1, 2/2, … no coletor 2. No primeiro traçado, T1, T2… continua aceitável.

**Hoje.** `Net.renumerar` já define o coletor 1 como o caminho mais extenso e numera os afluentes, mas dá nomes T1, T2… aos trechos e C1, C2… aos coletores. Ela roda ao dimensionar, quando a opção está marcada.

**Falta saber (Q7):** o separador ("1/1" ou "1-1"), se os PVs mantêm números sequenciais, e a ordem dos coletores. Hoje, descendo pelo coletor 1, cada afluente recebe o próximo número na ordem em que chega, e os afluentes dele são numerados antes do afluente seguinte do coletor 1. A pergunta leva um exemplo desenhado.

## P8-08 — Nome da opção

**Pedido.** "Numeração automática de PVs e trechos", com PV maiúsculo.

**Hoje.** "Numeração automática de nós e trechos" (`dialogs.gd`).

## P8-09 — Comprimento ao traçar

**Pedido.** Logo depois de traçar o trecho, mostrar o comprimento embaixo dele em vermelho, como já aparece depois de dimensionar.

**Hoje.** O rótulo vermelho (ø, extensão e declividade) só aparece com resultado de cálculo (`plan_view.gd`).

**Proposta.** Sem cálculo, o rótulo mostra só a extensão ("45,32 m"), no mesmo lugar e com a mesma cor. Com resultado, continua como hoje.

## P8-10 — Redesenhar limpa a tela

**Pedido.** O Ctrl+R (Redesenha) atualiza o desenho sem precisar traçar de novo: apaga os resíduos (o rastro do cálculo de cota: área de influência e retas) e atualiza o símbolo dos órgãos acessórios, como de TL para PV.

**Hoje.** `plan_view.redesenhar()` só pede para a tela ser redesenhada. O rastro do último cálculo de cota (`plan_view.rastro`) continua lá.

**Observação.** Com o P8-01 e o P8-02, o símbolo passa a mudar na hora da ligação, sem precisar de Ctrl+R. O chefe pediu para tratar o redesenhar depois da conversão (áudio 18).

**Falta saber (Q8):** o que mais conta como resíduo, e se o rastro deveria sumir sozinho depois de colocar o PV.

## P8-11 — Formato do arquivo de projeto

**Pedido.** Não salvar em .esg, que é a extensão do CEsg. Usar GeoPackage ou JSON.

**Hoje.** O arquivo .esg do DimEsgoto **já é JSON** (`"formato": "dimesgoto"`, versão 3); só a extensão é a do CEsg. O GeoPackage já existe como exportação da rede para SIG (fase 6), mas o programa não sabe ler GeoPackage.

**Opções:**

- (a) Salvar como `.json`, com o mesmo conteúdo. É barato. Os arquivos .esg continuam abrindo.
- (b) Usar o GeoPackage como arquivo de projeto. É caro: exige um leitor de SQLite em GDScript e guardar parâmetros, topografia e resultados em tabelas.

Recomendação: (a), mantendo a exportação GeoPackage para o QGIS. Decisão técnica com você e confirmação de uso com o chefe (Q9).
