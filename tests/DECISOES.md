# Decisões técnicas da suíte de evals

Cada linha iniciada por "- " entra no relatório obrigatório do runner.

- Suíte unificada em setup/tests/ (antes em app/tests/); os scripts rodam com caminho absoluto via `--path app --script`.
- EVAL-105: parâmetros inválidos BLOQUEIAM o cálculo com mensagem que cita o parâmetro (não há correção automática).
- EVAL-104: `ok` = rede calculada sem erro estrutural; `aprovado` = ok e sem restrição impeditiva; .RES, memorial final, planta/perfil DXF e planilhas de resultados/orçamento só saem com resultado aprovado e atualizado.
- Severidade (EVAL-103): impeditivo = lâmina acima do limite e declividade nula/negativa; o resto é advertência. A validar com o responsável técnico.
- T2-01/T2-02: papel do layer pelo nome (TOPO/CURVA/NIVEL → curvas; PT_/PTCT/PONTO/COTADO → pontos; RUA/QUADRA/LOTE → ruas; demais → outros, ignorados).
- T2-06: DXF vazio ou truncado (sem EOF) é rejeitado; curvas com menos de 2 vértices são ignoradas com aviso; curvas/pontos sem elevação geram aviso.
- T2-08: leitura de DXF binário implementada (códigos de 1 ou 2 bytes); o teste converte a fixture ASCII em binário e compara.
- T3-03: a coluna consumo_l_hab_dia é somada como consumo diário da ligação (l/dia), para obter os 400 l/dia do caso de teste; vazão da ligação = consumo × C(fim de plano) / 86400. Se a coluna for per capita, o total passaria a 1.320 l/dia — confirmar.
- T3: a ligação vai para a sub-bacia mais interna que a contém e é lançada no trecho de saída dela (ou do ancestral); sem bacias, vai ao trecho mais próximo até 20 m.
- T3-07: formato geográfico suportado = GeoJSON (nós como Point, trechos como LineString com todas as propriedades).
- T4-01: XLSX gerado sem bibliotecas (ZIP + XML mínimos); PDF em texto Courier/WinAnsi; títulos de coluna com quebra de linha são exportados com quebra protegida por aspas no CSV.
- T4-03: identificador = SHA-256 (16 hex) de projeto + parâmetros + topografia + conteúdo do banco + versão do motor; vai no memorial, HTML, XLSX, PDF e DXF (o CSV é só dados).
- T5-02: o arquivo .esg guarda a identificação do banco usado e os resultados com suas flags; ao reabrir, resultados cujo identificador não bate ficam marcados como desatualizados.
- T5-04: arquivo vazio, JSON inválido, sem lista de nós/trechos ou com tipos errados é rejeitado sem tocar no projeto aberto; referências entre nós e trechos são checadas pelo motor (EVAL-104).
- T5-06: toda gravação é atômica (arquivo temporário + renomear).
- T5-07: rede de teste com 1.600 nós e 1.500 trechos (numa rede em árvore cada nó tem uma só saída, então 1.000 nós não comportam 1.500 trechos).
- Fase 6 (pedido de 16/11/2026): regras da rede no domínio (`Net.pode_ligar`, `Net.simular_apagar`) — afluente só liga em PV com saída; no máximo 3 entradas por PV (`Net.MAX_ENTRADAS`); nenhuma exclusão pode deixar um PV com 2+ chegadas sem saída. O lançamento final que já tem 2 chegadas (ex.: rede de exemplo) continua válido; a regra vale para o que a edição cria.
- T6-03: "apagar ponto" = apagar nó. Ponto intermediário (1 chegada e 1 saída) une os dois trechos (extensão fixa somada); nó de cabeceira/saída sai com o trecho ligado; PV com 2+ chegadas não pode ser apagado. Toda exclusão pede confirmação e é desfeita com Ctrl+Z.
- T6-05 / T5-03: iniciar um coletor sem criar trecho não é mais um passo do histórico (o nó inicial é descartado ao finalizar/cancelar). O caso "traçado" do T5-03 passou a traçar um trecho de fato.
- T6-06: a caixa seleciona o que está inteiramente dentro (nós; trechos com os dois nós dentro). Apagar um nó selecionado leva junto os trechos ligados a ele (exceto no ponto intermediário, que une os trechos); a confirmação mostra quantos trechos e nós saem.
- T6-08: colunas fixas desenhadas por cima da planilha (o Tree do Godot não congela colunas); no XLSX exportado vão como painel congelado (xSplit) com a linha de títulos.
- T6-09: rede em DXF = LINE/POLYLINE/LWPOLYLINE dos layers escolhidos, sentido do desenho = sentido do escoamento, vértices a até 5 cm viram o mesmo nó. "GPK" interpretado como GeoPackage (.gpkg, OGC 1.3), escrito sem bibliotecas (SQLite montado página a página) e validado com o sqlite3 do Python (integrity_check). SRC: o código EPSG citado na referência do projeto; sem EPSG, srs_id −1 (cartesiano indefinido).
- Fase 7: não há item de NBR que fixe o raio de busca para interpolar a cota do PV; mantido o padrão de 100 m (decisão do usuário em 16/11/2026), editável em Opções › Cálculo automático de cotas e mostrado no cursor durante o traçado. "Sobre a curva" = até 5 cm dela (`Topo.TOL_CURVA`): vale a cota da curva, sem interpolação.
- T7-02: osnap com captura de 12 px e prioridade PV › ponto cotado › vértice de rua › curva/rua (ponto mais próximo). Só captura o que está visível (camadas de exibição). Ponto cotado capturado define a cota do PV mesmo no modo INT. No arrasto, um PV não gruda em outro PV.
- T7-03: atalhos F9 (orto) e F10 (osnap); F3 e F8 (padrão do AutoCAD) já eram "Localizar próxima" e "INT". O osnap tem prioridade sobre o orto.
- T7-04: "trecho isolado sem caída" = os dois casos (decisão do usuário): parte da rede que não deságua na rede principal (a principal é a de mais trechos e, no empate, a mais extensa) e terreno sem caimento (CT jusante ≥ CT montante). São alertas (janela ao calcular pelo diálogo + Planilha de Observações): não alteram o status dos trechos nem o "aprovado" (EVAL-002 intacto).
- T7-04 × EVAL-101: o caso de referência do EVAL-101 é um trecho em terreno plano (CT 100 → 100) e exige luz verde. O alerta de terreno sem caimento marca esse trecho, como pedido, mas a luz (verde/amarela/vermelha) passou a refletir só a hidráulica. Os alertas da rede ficam à parte: janela, Planilha de Observações e texto do diálogo ("sem restrições hidráulicas, com N alerta(s) da rede").
- T7-01 / T7-02 (gráfico, 16/11/2026, ao fechar a 0.2.0-alpha): numa rodada completa, a captura do marcador do osnap deu 0 px (a fase 7 sozinha passou 3 de 3). A causa provável é um movimento real do mouse sobre a janela do teste, que move o cursor simulado. Agora o movimento é reinjetado antes de cada captura, com até 3 tentativas. Os critérios de pixels são os mesmos (círculo ≥ 60% dos pontos; mais de 8 px verdes) e não foram afrouxados.
