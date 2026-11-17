# Fase 8 — pedidos do engenheiro de 17/11/2026

Pacote de planejamento da terceira leva de alterações do DimEsgoto. Os pedidos vieram em 19 áudios e 2 prints do engenheiro responsável (o dono das regras de negócio). Quem implementa é o dev, com agentes de IA. As regras de negócio não se inventam: na dúvida, a pergunta vai para o engenheiro.

| Arquivo | Para quê |
|---|---|
| [transcricao.md](transcricao.md) | o que foi dito, áudio por áudio (fonte da verdade dos pedidos) |
| [01-pedidos.md](01-pedidos.md) | a lista de pedidos (P8-01 a P8-11): o que o programa faz hoje e o que falta saber |
| [02-specs.md](02-specs.md) | o contrato de cada pedido (Dado / Quando / Então e critérios de aceite) |
| [../../tests/PHASE-8.md](../../tests/PHASE-8.md) | os evals: casos de teste T8-01 a T8-11 |
| [03-quality-gates.md](03-quality-gates.md) | ciclo Red/Green, portões G0 a G7 e níveis de autonomia |
| [04-backlog.md](04-backlog.md) | o plano de trabalho: ordem, fichas, arquivos, riscos |
| [05-perguntas-chefe.md](05-perguntas-chefe.md) | texto pronto para o engenheiro e a tabela de respostas |
| [PROGRESS.md](PROGRESS.md) | estado atual: ler no início e atualizar no fim de toda sessão |

Para um agente começar uma sessão de trabalho:

1. ler `PROGRESS.md`, depois a ficha da próxima tarefa em `04-backlog.md`;
2. ler a spec e o caso de teste citados, e as respostas já anotadas em `05-perguntas-chefe.md`;
3. seguir o ciclo de `03-quality-gates.md`, sem pular portão;
4. ao terminar, atualizar `PROGRESS.md` e, se houve decisão, `tests/DECISOES.md`.
