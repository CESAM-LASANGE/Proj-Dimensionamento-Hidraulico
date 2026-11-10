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
