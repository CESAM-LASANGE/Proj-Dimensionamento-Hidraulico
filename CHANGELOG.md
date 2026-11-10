# Notas de versão

## 0.1.0-alpha — primeira versão pública

Primeira versão para avaliação. Os resultados ainda precisam ser conferidos por um responsável técnico.

### Projeto da rede
- Área de trabalho gráfica estilo CAD: traçado de coletores com o mouse (de montante para jusante), zoom, pan, janela e grade de coordenadas N/E.
- Topografia por DXF (curvas de nível, ruas e pontos cotados, ASCII ou binário), com cálculo automático da cota dos nós pelas linhas de maior declive.
- Janelas de nó e de trecho; dividir, deslocar e apagar trechos; numeração automática de nós, trechos e coletores.
- Desfazer e refazer (Ctrl+Z / Ctrl+Y).

### Cálculo
- Dimensionamento conforme os critérios da NBR 9649: vazão mínima, tensão trativa, lâmina máxima (75% / 50%), velocidade crítica e velocidade máxima.
- Fórmula de Manning ou Universal, com ajuste de rugosidade pela velocidade.
- Degraus e tubos de queda, cotas intermediárias do terreno e escoramento automático.
- Validação de parâmetros, da estrutura da rede e do banco de custos antes do cálculo.

### Cadastro e SIG
- Ligações domiciliares em CSV, com relatório de importação.
- Bacias e sub-bacias em GeoJSON, com balanço de contribuições.
- Interferências em GeoJSON.
- Exportação e importação da rede em GeoJSON.

### Entregáveis
- Sete planilhas (trechos, nós, dimensionamento, quantitativos, resultados, orçamento e observações), exportáveis em CSV, XLSX, HTML e PDF.
- Memorial de cálculo em TXT ou PDF, com identificador de rastreabilidade.
- Planta e perfil em DXF, e perfil em PNG.
- Banco editável de materiais, tubos, PVs, pavimentos, escoramentos, reduções e acessórios.
- Resultados desatualizados ou não aprovados não são exportados como finais.

### Robustez
- Gravação atômica dos arquivos.
- Rejeição de arquivos corrompidos sem perder o projeto aberto.
- Registro de erros com rastreio, limitado a cerca de 10 MB.
- Detecção de encerramento inesperado.
- 42 verificações automatizadas (`python3 tests/run_tests.py`).

### Limitações conhecidas
- O executável do Windows ainda não é assinado nem tem ícone próprio no Explorer; o ícone aparece na janela.
- Impressão direta não existe: a planilha abre em HTML e a planta em PNG, e se imprime a partir deles.
- Os preços do banco são apenas referências.
- As curvas de ajuste de rugosidade foram lidas dos gráficos do manual do CEsg e são aproximadas.
