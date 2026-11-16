# Testes da fase 7 — traçado assistido e alertas de cálculo

Casos concretos das alterações pedidas em 16/11/2026 (segunda leva). Convenções de [PHASE-2-5.md](PHASE-2-5.md). Implementação: [test_tracado.gd](test_tracado.gd) (headless) e [test_grafico.gd](test_grafico.gd) `--fase=7` (o que precisa de tela).

Terreno de teste, montado no próprio teste:

- curvas de nível retas `y = 10·k` com cota `100 + k`, para `k` de −5 a 15 (cota exata em qualquer ponto = `100 + y/10`);
- pontos cotados em (200; 33) com 123,45 m e em (150; −33) com 111,11 m, de propósito diferentes das curvas;
- ruas: (250; −50)–(250; 150) e (250; 150)–(350; 150);
- escala de 4 px/m (os 12 px de captura do osnap equivalem a 3 m).

---

### T7-01 — raio de busca e interpolação na colocação do PV

Critérios:

- durante o traçado, o raio de busca (Opções › Cálculo automático de cotas; padrão 100 m) aparece como círculo em volta do cursor, com as retas de maior declive e a cota que o próximo PV vai receber;
- fora das curvas, a cota é interpolada (em (40; 25): 102,500 m), e o PV colocado recebe exatamente a cota mostrada;
- sobre uma curva (até 5 cm dela), a cota é a da curva, sem interpolar e sem retas (em (80; 30): 103,000 m); a 50 cm já interpola (103,050 m);
- se não houver curva dentro do raio, a prévia avisa e o PV fica sem cota confirmada;
- fora do traçado, o raio não aparece;
- gráfico: o círculo aparece de fato na tela.

### T7-02 — osnap (magnetismo)

Critérios:

- a até 12 px, o cursor gruda em: PV › ponto cotado › vértice de rua › ponto mais próximo sobre curva de nível ou rua (nessa ordem de prioridade);
- marcador verde com o nome do alvo (ex.: "Ponto cotado 123,45 m", "Curva 103,00 m", "PV 17");
- PV colocado no ponto cotado recebe as coordenadas e a cota dele, sem interpolar; sobre a curva, a cota da curva;
- durante o traçado, o osnap liga o afluente a um PV que o clique comum não alcançaria (10,5 px); sobre um PV, não há prévia de cota;
- arrastando um PV, ele não gruda em outro PV; levado ao ponto cotado, assume a posição e a cota dele;
- F10 (ou o botão OSNAP) liga e desliga;
- gráfico: o marcador aparece de fato na tela.

### T7-03 — orto

Critérios:

- F9 (ou o botão ORTO) liga e desliga; os atalhos aparecem no menu Opções;
- com o orto ligado, o novo trecho sai só na horizontal ou na vertical a partir do último PV, e o nó arrastado anda só na horizontal ou na vertical a partir da posição inicial;
- o osnap tem prioridade sobre o orto;
- desligado, o traçado é livre.

### T7-04 — alertas ao calcular

Rede ramificada (A, B → C → D) com um trecho solto E→F cujo terreno sobe (99,0 → 99,5).

Critérios:

- rede conectada: nenhum alerta de isolado;
- trecho isolado: alerta "sem deságue na rede principal" com o nome do trecho (a rede principal é a parte com mais trechos);
- terreno sem caimento: alerta exatamente nos trechos com CT de jusante ≥ CT de montante;
- os alertas são advertências: não mudam o status dos trechos nem bloqueiam o cálculo, e vão para a Planilha de Observações;
- calculando pelo diálogo (Ctrl+D › Inicia), aparece a janela de alerta com os dois casos;
- rede de exemplo (uma só saída): nenhum alerta de isolado.

### T7-05 — regressão completa

Calculado pelo runner: fases 0 a 6 executadas na mesma rodada, sem FAIL.
