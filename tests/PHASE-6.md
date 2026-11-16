# Testes da fase 6 — edição da rede, planilhas e intercâmbio

Casos concretos para as alterações pedidas em 16/11/2026. Seguem as convenções de [PHASE-2-5.md](PHASE-2-5.md): coordenadas e cotas em metros, tolerância geométrica `0,001 m`, estados `PASS` / `FAIL` / `SKIP`. Os testes são contratos e não devem ser removidos nem enfraquecidos.

Implementação: [test_edicao.gd](test_edicao.gd) (headless) e [test_grafico.gd](test_grafico.gd) `--fase=6` (parte gráfica do T6-08).

Fixtures:

- `tests/fixtures/rede_ramificada.esg` (T1 A→C, T2 B→C, T3 C→D)
- `tests/fixtures/rede_phase6.dxf` (rede desenhada em CAD, layer `REDE_ESGOTO`, mais um layer `TEXTOS`)
- rede de exemplo do programa (30 nós, dimensionada e aprovada)

Invariantes verificados depois de cada edição: todo nó tem pelo menos um trecho; nenhum nó fica com 2 ou mais chegadas sem saída (salvo o que já era assim antes); no máximo 3 entradas e 1 saída por nó; sem laço.

---

### T6-01 — ligação só em PV com saída

Com o traçado em andamento, clicar (botão 1) sobre um nó sem trecho de jusante.

Critérios:

- nenhum trecho é criado;
- aparece uma janela de alerta explicando que o PV não tem saída;
- o traçado continua ativo;
- clicar num PV que tem saída liga o trecho normalmente e encerra o traçado;
- a regra existe no domínio (`Net.pode_ligar` → `sem_saida`), não só na interface;
- durante o traçado, ao passar o mouse sobre um PV proibido, ele fica destacado em vermelho com o motivo.

### T6-02 — trecho de jusante de PV com 2 ou mais chegadas

Na rede ramificada, C recebe T1 e T2 e sai por T3.

Critérios:

- apagar T3 é recusado com alerta que cita T3, o PV C e o motivo (trechos sem saída);
- pelo Del, aparece o alerta e não a confirmação;
- apagar o próprio PV C também é recusado;
- apagar T1 é permitido (C fica com uma chegada), e o nó A sai junto;
- apagar T1, T2 e T3 juntos é permitido e não sobra nenhum nó.

### T6-03 — confirmação ao apagar ponto

Dividir T3 e apagar o ponto intermediário criado.

Critérios:

- Del abre a confirmação "Deseja mesmo apagar o ponto (nó) …?";
- nada é apagado antes de confirmar; Cancelar mantém tudo;
- Confirmar remove o ponto e une os dois trechos num só, de C a D, com 100,00 m;
- Ctrl+Z devolve o ponto.

### T6-04 — no máximo 3 entradas por PV

PV X com saída e 3 trechos chegando.

Critérios:

- a 4ª ligação é recusada, com alerta "Cada PV aceita no máximo 3 entradas";
- Esc encerra o traçado sem deixar o nó inicial;
- com 2 entradas, a 3ª é aceita;
- a importação de DXF respeita o mesmo limite (4 polilinhas chegando no mesmo ponto → 3 trechos e 1 recusado).

### T6-05 — sem resíduos

Critérios:

- iniciar um coletor (botão 2) e finalizar ou cancelar (botão 2 / Esc) sem criar trecho não deixa nó;
- isso também não cria passo no histórico de desfazer;
- traçar um trecho e apagá-lo devolve a rede ao número original de nós;
- Ctrl+Z do primeiro trecho remove também o nó inicial, num passo só;
- apagar com um traçado em andamento encerra o traçado sem resíduo.

### T6-06 — seleção por caixa

Rede de exemplo; caixa de E 100–300 × N 100–250, desenhada com o mouse (botão 1 arrastado na área vazia).

Critérios:

- seleciona exatamente os nós dentro da caixa e os trechos com os dois nós dentro;
- trechos que cruzam a borda ficam de fora;
- Ctrl + caixa soma à seleção; clique na área vazia desfaz a seleção; clique num nó seleciona só ele;
- Del pede confirmação e, confirmado, os nós da caixa saem e a rede continua consistente.

### T6-07 — exportação das planilhas

Critérios:

- a vista de planilhas tem uma barra com CSV, XLSX, HTML, PDF (aba atual) e "Todas as planilhas (XLSX)";
- "Todas as planilhas" gera uma pasta de trabalho com uma aba por planilha mais a aba Info;
- cada aba tem as mesmas linhas da planilha na tela;
- com resultado desatualizado, Resultados e Orçamento não entram, e a aba Info diz por quê (EVAL-104).

### T6-08 — colunas fixas na planilha de resultados

Critérios:

- Resultados: Col., Trecho, PV e Ext. ficam fixas (as 4 primeiras colunas);
- sem rolagem horizontal, a faixa fixa não aparece; rolando para a direita, ela cobre exatamente as 4 colunas;
- clicar numa célula da faixa seleciona a célula sem voltar a rolagem;
- Plan. Trechos, Dimens. e Quant. fixam coletor, nós, extensão e nome; Plan. Nós fixa coletor e nó;
- o XLSX exportado abre com as mesmas colunas e a linha de títulos congeladas;
- gráfico: a faixa aparece na tela com borda, fundo claro e textos legíveis.

### T6-09 — importação DXF da rede e exportação GeoPackage

`rede_phase6.dxf`, layer `REDE_ESGOTO`: coletor principal (LWPOLYLINE de 5 vértices + LINE de continuação), um afluente com o último vértice a 2 cm do PV de chegada, uma bifurcação e um contorno fechado.

Critérios (DXF):

- 8 nós e 7 trechos; bifurcação e contorno recusados com aviso;
- o sentido do desenho é o sentido do escoamento (cabeceira TL em (0; 100), saída em (170; 0));
- vértices a menos de 5 cm viram o mesmo PV;
- layer não selecionado é ignorado e não sobra vértice solto;
- a rede importada é dimensionada sem erro estrutural.

Critérios (GeoPackage, validado com o `sqlite3` do Python):

- `PRAGMA integrity_check = ok`, `foreign_key_check` sem erros;
- `application_id = 0x47504B47` ("GPKG") e `user_version = 10300`;
- tabelas `gpkg_spatial_ref_sys`, `gpkg_contents`, `gpkg_geometry_columns`, `pvs` e `trechos`;
- geometrias GeoPackageBinary (Point / LineString) com as coordenadas exatas do projeto;
- o SRC do projeto (EPSG citado na referência espacial) vai para `srs_id`;
- resultados do dimensionamento só com resultado aprovado e atualizado;
- rede grande (1.600 PVs, 1.500 trechos) com árvores B de várias páginas: integridade ok.

### T6-10 — regressão completa

Calculado pelo runner: fases 0 a 5 executadas na mesma rodada, sem FAIL.
