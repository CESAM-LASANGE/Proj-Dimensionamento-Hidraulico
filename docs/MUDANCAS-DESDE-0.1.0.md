# DimEsgoto 0.2.0-alpha — o que mudou desde a 0.1.0-alpha

Resumo das melhorias feitas em 16/11/2026, em duas levas de pedidos. O detalhe completo está no [CHANGELOG](../CHANGELOG.md).

## Em uma frase

A rede agora se protege de erros de traçado: não deixa ligar nem apagar de um jeito que deixe trechos sem saída. O traçado ficou mais preciso, com osnap, orto e a cota do PV aparecendo antes do clique. As planilhas exportam melhor, e o programa passou a trocar arquivos com CAD (DXF) e SIG (GeoPackage).

## 1. Regras da rede (proteção contra erros)

| Situação | Antes | Agora |
|---|---|---|
| Ligar um trecho num PV sem saída | Permitido | Recusado com aviso. O PV fica vermelho ao passar o mouse. |
| 4ª entrada no mesmo PV | Permitido | Recusado: no máximo 3 entradas por PV. |
| Apagar o trecho de saída de um PV que recebe 2 ou mais trechos | Permitido | Recusado com aviso, porque os trechos ficariam sem saída. |
| Apagar um ponto ou uma seleção | Sem confirmação | Pede confirmação. Um ponto intermediário apagado une os dois trechos. |
| Começar um coletor e desistir | Ficava um nó solto | Não sobra nada, e não conta como passo no Desfazer. |

As regras valem também para a rede importada de DXF.

## 2. Edição e traçado

- **Seleção por caixa:** arraste na área vazia para selecionar, como no CorelDraw ou no Illustrator. Ctrl soma à seleção, Del apaga e Esc desfaz a seleção. Também há o comando Trechos › Seleciona tudo.
- **Raio de interpolação:** durante o traçado, aparece em volta do cursor um círculo com o raio de busca (100 m por padrão), as retas usadas e a cota que o PV vai receber. Em cima de uma curva de nível, o PV recebe a cota da curva, sem interpolar.
- **Osnap (F10):** o cursor gruda em PVs, pontos cotados, vértices de rua, curvas e ruas, e mostra o nome do alvo. Um PV colocado num ponto cotado recebe a cota do ponto.
- **Orto (F9):** trechos e PVs arrastados andam só na horizontal ou na vertical.

## 3. Cálculo

Ao dimensionar, o programa avisa sobre:

- **trechos isolados**, que não chegam à saída principal;
- **trechos com terreno sem caimento**.

Esses avisos aparecem numa janela e na Planilha de Observações e não impedem o cálculo. A luz verde, amarela ou vermelha continua mostrando só o resultado hidráulico.

## 4. Planilhas

- Barra de exportação na vista de planilhas: a aba atual em CSV, XLSX, HTML ou PDF, ou **todas as planilhas** num único XLSX, uma aba por planilha.
- **Colunas fixas:** Col., Trecho, PV e Ext. ficam paradas ao rolar a planilha de Resultados para a direita. O XLSX exportado abre com as mesmas colunas congeladas.

## 5. Intercâmbio de arquivos

- **Importar rede de DXF:** as linhas e polilinhas dos layers escolhidos viram coletores, e o sentido do desenho é o sentido do escoamento. Os segmentos inválidos (contorno fechado, bifurcação) são listados.
- **Exportar GeoPackage (.gpkg):** camadas de PVs e trechos, com os resultados quando o cálculo estiver aprovado, prontas para abrir no QGIS.

## Atalhos novos

| Tecla | Função |
|---|---|
| F9 | Liga ou desliga o orto |
| F10 | Liga ou desliga o osnap |
| Del | Apaga a seleção, com confirmação |
| Esc | Desfaz a seleção ou cancela o traçado |
| Ctrl + clique ou caixa | Soma à seleção |

## Qualidade

- Duas fases novas de testes automáticos: a Fase 6 (T6-01 a T6-10, edição, planilhas e intercâmbio) e a Fase 7 (T7-01 a T7-05, traçado assistido e alertas). Os casos estão descritos em [PHASE-6.md](../tests/PHASE-6.md) e [PHASE-7.md](../tests/PHASE-7.md).
- A suíte passou de **42 para 57 verificações**, todas aprovadas, sem regressão nas fases anteriores. Para rodar: `python3 tests/run_tests.py`.
- Nenhum teste antigo foi removido ou afrouxado. Onde uma regra nova mudou um comportamento, o motivo está registrado em [DECISOES.md](../tests/DECISOES.md).
