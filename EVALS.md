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

Os casos concretos das fases 2 a 5 estão em [tests/PHASE-2-5.md](<tests/PHASE-2-5.md>). O agente deve implementar os testes mantendo os IDs `T2-*`, `T3-*`, `T4-*` e `T5-*` para que os relatórios sejam comparáveis entre versões.

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
```
