# Evals do DimEsgoto

Plano de avaliação incremental para o desenvolvimento do clone do CEsg. O agente de código deve executar os evals na ordem indicada e não avançar uma fase enquanto os critérios obrigatórios da fase anterior não estiverem aprovados.

## Regras gerais

- Os evals devem ser automatizados sempre que possível.
- Cada resultado deve registrar: versão do app, versão do banco de dados, parâmetros, entrada usada, saída obtida e data da execução.
- Um cálculo com erro estrutural não pode ser exportado como resultado válido.
- Advertência técnica e erro impeditivo são estados diferentes.
- Alterações de fórmulas devem atualizar os casos de referência e registrar a justificativa.
- O manual do CEsg e o artigo da Embrapa são referências funcionais; não substituem a validação com a norma vigente, concessionária ou responsável técnico.

## Estrutura esperada para os testes

Criar uma estrutura semelhante a:

```text
tests/
  fixtures/
    rede_unica.esg
    rede_ramificada.esg
    rede_invalida.esg
    topografia_simples.dxf
    pontos_cotados.dxf
  expected/
    rede_unica.json
    rede_ramificada.json
  test_calc.gd
  test_net.gd
  test_topo.gd
  test_dxf.gd
  test_reports.gd
  run_tests.py
```

O runner deve retornar código de saída diferente de zero quando qualquer eval falhar.

Os casos concretos das fases 2 a 5 estão em [tests/PHASE-2-5.md](<tests/PHASE-2-5.md>) e os das fases 6 e 7 em [tests/PHASE-6.md](<tests/PHASE-6.md>) e [tests/PHASE-7.md](<tests/PHASE-7.md>). O agente deve implementar os testes mantendo os IDs `T2-*` a `T7-*` para que os relatórios sejam comparáveis entre versões.

---

## Fase 0 — baseline e infraestrutura de avaliação

Prioridade: P0. Bloqueia todas as fases seguintes.

### EVAL-000 — inicialização limpa

Em um diretório de dados vazio, o app deve iniciar, carregar a rede de exemplo e encerrar sem erro fatal.

Critérios:

- processo termina com código 0;
- nenhum `SCRIPT ERROR`, `Parse Error` ou crash;
- rede de exemplo contém nós, trechos e resultados;
- o log de sessão é gravado.

### EVAL-001 — runner reproduzível

O projeto deve possuir um comando documentado para executar todos os testes sem interface gráfica.

Critérios:

- execução em modo headless;
- código 0 quando todos passam;
- código diferente de 0 quando um teste falha;
- saída resumida por ID do eval;
- nenhuma dependência externa obrigatória para os testes básicos.

### EVAL-002 — snapshot de baseline

Salvar os resultados atuais da rede de exemplo como baseline, sem afirmar que são normativamente corretos.

O snapshot deve conter pelo menos:

- vazões por trecho;
- diâmetro;
- declividade;
- cotas do coletor;
- recobrimento;
- velocidade;
- tensão trativa;
- tipo dos nós;
- quantitativos e custo.

---

## Fase 1 — confiabilidade do motor hidráulico

Prioridade: P0. Deve ser concluída antes de novos recursos de GIS ou otimização.

### EVAL-101 — cálculo de trecho único

Usar um trecho com comprimento, população e parâmetros conhecidos.

Validar:

- vazão inicial e final;
- contribuição linear;
- diâmetro comercial selecionado;
- declividade mínima por tensão trativa;
- velocidade inicial e final;
- lâmina relativa;
- recobrimento.

As tolerâncias devem ser explícitas, por exemplo `1e-6` para cálculos internos e `0,001` para cotas exibidas.

### EVAL-102 — rede ramificada

Criar dois trechos de montante convergindo em um trecho de jusante.

Validar:

- soma das vazões afluentes;
- propagação correta das vazões de início e fim de plano;
- seleção de diâmetro não inferior ao maior diâmetro de montante;
- cálculo correto de degrau e tubo de queda.

### EVAL-103 — restrições hidráulicas

Forçar individualmente:

- velocidade acima do máximo;
- tensão trativa abaixo do mínimo;
- lâmina acima do limite;
- declividade negativa;
- recobrimento insuficiente;
- profundidade acima do máximo;
- trecho acima da distância máxima.

Cada caso deve gerar o aviso correto, com severidade correta, sem alterar silenciosamente a entrada fixada pelo usuário.

### EVAL-104 — erro estrutural bloqueia resultado

Usar rede com ciclo, nó inexistente, trecho sem conexão e nó com múltiplas saídas.

Critérios obrigatórios:

- `resultado.aprovado == false`;
- `resultados_validos == false`;
- nenhum arquivo `.RES` é gravado;
- nenhum orçamento é apresentado como final;
- a planilha de observações mostra o erro estrutural;
- a interface não informa “dimensionamento concluído”.

Este eval cobre o problema atual de `calc.gd` considerar `ok` quando existe apenas uma linha calculada.

### EVAL-105 — parâmetros inválidos

Testar valores nulos, negativos, `NaN`, coeficientes fora do intervalo e relações impossíveis, como degrau mínimo maior que o máximo.

O sistema deve rejeitar ou corrigir explicitamente a entrada e explicar o motivo.

### EVAL-106 — métodos de cálculo

Executar a mesma rede com:

- Manning;
- Fórmula Universal;
- rugosidade otimista;
- rugosidade pessimista;
- rugosidade do banco.

Validar que os resultados mudam de forma coerente e que o método usado aparece no memorial.

### EVAL-107 — orçamento determinístico

Com banco de custos fixo, validar:

- comprimento de tubos;
- quantidade e profundidade de PVs;
- escoramento;
- pavimento;
- reaterro;
- reduções e acessórios;
- total final.

O mesmo projeto e o mesmo banco devem produzir exatamente o mesmo resultado.

---

## Fase 2 — topografia e qualidade geográfica

Prioridade: P0/P1.

### EVAL-201 — leitura DXF ASCII

Validar LINE, POLYLINE, LWPOLYLINE, ARC, CIRCLE, TEXT e POINT, incluindo seleção por layer.

### EVAL-202 — DXF binário e formatos inválidos

O app deve:

- aceitar DXF binário quando o suporte for implementado; ou
- rejeitar com mensagem clara, sem crash;
- rejeitar arquivo truncado ou sem entidades reconhecidas;
- registrar o erro no log.

### EVAL-203 — interpolação por curvas

Usar curvas paralelas com cotas conhecidas e verificar cotas intermediárias em pontos conhecidos.

Testar também:

- cume;
- fundo de vale;
- ponto fora da área;
- curvas com mesma cota;
- curvas sem elevação;
- baixa e alta precisão.

O resultado deve informar quando é aproximado.

### EVAL-204 — pontos cotados

Validar ponto mais próximo, raio máximo, pontos sem elevação e textos numéricos associados a pontos.

### EVAL-205 — unidade e referência espacial

O projeto deve guardar:

- unidade horizontal;
- unidade vertical;
- sistema de referência;
- EPSG, quando aplicável;
- datum vertical, quando conhecido;
- origem e data da base topográfica.

Projetos sem referência espacial devem ser marcados como “referência não informada”.

---

## Fase 3 — integração SIG e gestão de projeto

Prioridade: P1.

### EVAL-301 — áreas de contribuição

Permitir associar população, consumo, infiltração ou vazão a bacias/sub-bacias e distribuir a contribuição nos trechos correspondentes.

Validar conservação de massa entre áreas, nós e trechos.

### EVAL-302 — ligações domiciliares

Importar uma tabela de ligações contendo identificador, coordenada, população ou consumo e situação.

Validar:

- contagem espacial por bacia;
- associação ao trecho mais próximo;
- ligações fora da área;
- duplicidades;
- dados incompletos.

### EVAL-303 — camadas de interferência

Importar redes existentes, drenagem, água, telefone, pavimentação e obstáculos. Cada camada deve manter nome, origem, data e sistema de coordenadas.

### EVAL-304 — exportação e reimportação

Exportar a rede para um formato geográfico e reimportá-la. Os identificadores, coordenadas, diâmetros, cotas e situações devem permanecer consistentes.

### EVAL-305 — atualização de base

Alterar a topografia ou o cadastro e verificar que o projeto identifica resultados desatualizados e exige novo dimensionamento.

---

## Fase 4 — entregáveis de engenharia

Prioridade: P1.

### EVAL-401 — planilhas

Cada planilha deve ser exportável sem perda de colunas, unidades, nomes, casas decimais ou separadores.

Formatos mínimos:

- CSV;
- XLSX;
- HTML;
- PDF ou memorial formatado.

### EVAL-402 — memorial de cálculo

O memorial deve conter:

- identificação do projeto;
- responsável e local;
- versão do app;
- versão da norma/configuração normativa;
- parâmetros de início e fim de plano;
- método hidráulico;
- banco de materiais e custos;
- resultados por trecho;
- observações;
- quantitativos e orçamento;
- data de geração.

### EVAL-403 — planta e perfil

Validar escala, norte, legenda, layers, cotas, sentido de fluxo, diâmetros, declividades, PVs, tubos de queda e situações de rede.

### EVAL-404 — reprodutibilidade do documento

Dado o mesmo projeto, banco e parâmetros, duas gerações do mesmo documento devem produzir conteúdo equivalente, ignorando apenas timestamps quando necessário.

---

## Fase 5 — robustez, manutenção e funcionalidades futuras

Prioridade: P2, depois da aprovação das fases 1 a 4.

### EVAL-501 — migração de projetos

Testar abertura de projetos das versões anteriores, preservando extensões fixas, cotas, diâmetros e dados de custo.

### EVAL-502 — undo/redo

Validar desfazer/refazer para traçado, edição de nó, edição de trecho, importação topográfica, divisão, deslocamento e alteração de parâmetros.

### EVAL-503 — persistência

Salvar, fechar, reabrir e comparar o projeto completo, incluindo topografia, parâmetros, banco selecionado e estado de resultados.

### EVAL-504 — grandes projetos

Testar pelo menos 1.000 nós e 1.500 trechos, medindo tempo de abertura, cálculo, redraw e exportação.

### EVAL-505 — falhas e recuperação

Interromper gravação, abrir arquivo corrompido, remover banco de custos e importar DXF inválido. O app deve preservar o projeto anterior e exibir uma mensagem recuperável.

### EVAL-506 — extensibilidade

Novas funcionalidades devem consumir o modelo de domínio e os serviços existentes, sem duplicar fórmulas na interface.

---

## Fase 6 — edição da rede, planilhas e intercâmbio

Prioridade: P1 (pedido do usuário de 16/11/2026). Casos concretos em [tests/PHASE-6.md](<tests/PHASE-6.md>), IDs `T6-*`.

### EVAL-601 — regras de ligação

Um afluente só pode ser ligado a um PV que já tenha saída (trecho de jusante), e cada PV recebe no máximo 3 trechos. Ligações fora das regras são recusadas com alerta ao usuário (T6-01, T6-04).

### EVAL-602 — exclusão segura

Nenhuma exclusão pode deixar trechos sem saída. Apagar ponto ou seleção pede confirmação, une trechos quando o ponto é intermediário e não deixa nós soltos. Iniciar e abandonar um traçado não deixa resíduo (T6-02, T6-03, T6-05).

### EVAL-603 — seleção por caixa

Arrastar na área vazia seleciona tudo o que estiver inteiramente dentro da caixa. Ctrl soma, e Del apaga com confirmação (T6-06).

### EVAL-604 — planilhas

Cada planilha é exportável a partir da própria vista (CSV, XLSX, HTML e PDF), e todas juntas num XLSX. As colunas de identificação ficam fixas ao rolar, na tela e no XLSX (T6-07, T6-08).

### EVAL-605 — intercâmbio CAD/SIG

Importação da rede a partir de DXF (linhas e polilinhas) e exportação em GeoPackage válido, conferida com um leitor SQLite independente (T6-09).

---

## Fase 7 — traçado assistido e alertas de cálculo

Prioridade: P1 (pedido do usuário de 16/11/2026, segunda leva). Casos concretos em [tests/PHASE-7.md](<tests/PHASE-7.md>), IDs `T7-*`.

### EVAL-701 — cota do PV pelo raio de busca

Ao colocar um PV, o raio de busca da interpolação aparece no cursor junto com a cota que o PV vai receber. Sobre uma curva de nível, vale a cota da curva, sem interpolar (T7-01).

### EVAL-702 — osnap e orto

O magnetismo captura PVs, pontos cotados, vértices de ruas, curvas e ruas, com marcador visível. O orto restringe o traçado e o arrasto à horizontal e à vertical. Atalhos: F10 e F9 (T7-02, T7-03).

### EVAL-703 — alertas de rede no cálculo

Trecho isolado (sem deságue na rede principal) e terreno sem caimento geram alerta ao calcular, sem bloquear o resultado e sem alterar o status hidráulico dos trechos (T7-04).

## Fase 8 — pedidos do engenheiro de 17/11/2026

Prioridade: P1. Pedidos por áudio do engenheiro responsável. Planejamento em [docs/fase-8/](<docs/fase-8/README.md>), casos concretos em [tests/PHASE-8.md](<tests/PHASE-8.md>), IDs `T8-*`. Os itens de regra de negócio sem resposta do engenheiro usam padrões provisórios, registrados em `tests/DECISOES.md`.

### EVAL-801 — lâmina máxima com as duas vazões

O diâmetro mantém y/D ≤ 0,75 (ou 0,50 acima da velocidade crítica) com a vazão de início e a de fim de plano. Antes, com início maior que fim, o cálculo aprovava tubo cheio. Motor 3.2. Os casos com início ≤ fim ficam idênticos (T8-01).

### EVAL-802 — conversão do TL e PV automático

Ligar um trecho num TL de início de rede pergunta o novo tipo (PV, PI ou TIL de passagem). Um nó de passagem com 2 ou mais entradas vira PV, sem mensagem. A regra está no domínio e vale para traçado, edição, importação e projetos antigos (T8-02, T8-03).

### EVAL-803 — TIL de passagem

Órgão acessório novo, no banco, na planta, no DXF, no orçamento e nas exportações, com advertência acima de DN 300 (T8-04).

### EVAL-804 — exportação da planta e do traçado

O aviso de bloqueio diz quais trechos impedem e por quê. O traçado, sem resultados, pode ser exportado a qualquer momento (T8-05).

### EVAL-805 — comprimento ao traçar

A extensão aparece em vermelho junto ao trecho logo depois de traçar (T8-08).

### EVAL-806 a 808 — pendentes de resposta do engenheiro

Materiais sem marca (T8-06), numeração coletor/trecho (T8-07), redesenhar (T8-09) e formato do projeto (T8-10).

## Fase 9 — atualização automática

Prioridade: P1. O programa instalado se atualiza pelos Releases do GitHub, perguntando antes. Casos concretos em [tests/PHASE-9.md](<tests/PHASE-9.md>), IDs `T9-*`; funcionamento e publicação em [docs/ATUALIZACAO.md](<docs/ATUALIZACAO.md>).

### EVAL-901 — só instala o que foi assinado por quem publica

O manifesto do release é conferido com a chave pública embutida, e o pacote com o tamanho e o SHA-256 do manifesto. Manifesto alterado, outra chave, outra versão, versão antiga, pacote adulterado: tudo é recusado, e o executável atual fica intacto (T9-03, T9-04, T9-05).

### EVAL-902 — escolhe a versão certa

A maior versão SemVer acima da instalada, com pré-lançamentos em ordem (alpha.2 < alpha.10 < beta < final), sem rascunhos e nunca para trás (T9-01, T9-02).

### EVAL-903 — o usuário decide e nada se perde

A janela mostra a versão nova, a atual e as novidades. Nada é baixado sem "Atualizar agora", e reiniciar passa pela pergunta de alterações não salvas. Os erros mostram o motivo e o link para baixar à mão. A busca ao abrir pode ser desligada (T9-06).

### EVAL-904 — o pacote publicado funciona

O manifesto em `dist/` confere com a chave do programa (T9-07). O ensaio com os executáveis exportados (`tools/ensaio_atualizacao.py`) mostra a versão instalada trocando a si mesma, abrindo na versão nova e recusando o pacote adulterado.

---

## Portão de aprovação para o agente de código

O agente só deve considerar o projeto pronto para a próxima fase quando:

1. todos os evals obrigatórios da fase estiverem verdes;
2. não houver regressão nos evals anteriores;
3. os arquivos de entrada e saída dos casos de referência estiverem versionados;
4. cada alteração hidráulica tiver justificativa e comparação antes/depois;
5. o relatório de testes indicar claramente testes aprovados, pendentes e ignorados.

### Ordem resumida

```text
Fase 0: runner + baseline
    ↓
Fase 1: motor hidráulico confiável
    ↓
Fase 2: topografia e qualidade espacial
    ↓
Fase 3: SIG, bacias e cadastro
    ↓
Fase 4: entregáveis de engenharia
    ↓
Fase 5: robustez e funcionalidades extras
    ↓
Fase 6: edição da rede, planilhas e intercâmbio (DXF / GeoPackage)
    ↓
Fase 7: traçado assistido (raio de busca, osnap, orto) e alertas de cálculo
    ↓
Fase 8: pedidos do engenheiro (conversão do TL, lâmina, numeração, materiais…)
```
