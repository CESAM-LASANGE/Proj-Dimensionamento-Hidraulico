# Notas de versão

## 0.3.0-alpha.1 — versão de teste: conversão do TL, lâmina e atualização automática

Primeira versão de teste com os pedidos do engenheiro de 17/11/2026 (onda A da fase 8) e a primeira com atualização automática. Texto do release: [docs/NOTAS-v0.3.0-alpha.1.md](docs/NOTAS-v0.3.0-alpha.1.md).

### Atualização automática
- O programa instalado procura versão nova no GitHub ao abrir e pergunta antes de instalar. Ele baixa, confere a assinatura e o SHA-256 e troca o executável. A versão nova vale a partir da próxima abertura. Ajuda › Verificar atualizações… procura na hora, e Ajuda › Verificar atualizações ao abrir liga ou desliga a busca. Detalhes em [docs/ATUALIZACAO.md](docs/ATUALIZACAO.md).
- Quem está na 0.1.0 ou na 0.2.0 instala esta versão à mão uma última vez.
- Cada release passa a trazer `dimesgoto-atualizacao.json` e `.sig` (manifesto assinado), gerados pelo `tools/build_release.py`.

### Cálculo
- **Correção:** a lâmina máxima (75%, ou 50% acima da velocidade crítica) passa a ser conferida também com a vazão de início de plano quando ela é maior que a de fim. Antes, nesse caso, o programa podia aprovar um tubo trabalhando cheio. Projetos com vazão de início maior que a de fim podem ganhar diâmetros maiores ao serem dimensionados de novo. Os demais resultados não mudam (motor 3.2).

### Rede
- Ao ligar um trecho num TL de início de rede, o programa pergunta se ele passa a ser poço de visita (PV), poço de inspeção (PI) ou TIL de passagem.
- Um nó que passa a receber 2 ou 3 trechos vira PV automaticamente, sem mensagem. Projetos antigos com TL recebendo 2 ou mais trechos são corrigidos ao abrir. TL antigo recebendo um trecho aparece nos alertas ao dimensionar.
- Novo órgão acessório: TIL de passagem (sigla TIL-P), com símbolo próprio na planta e no DXF, no orçamento e com aviso acima de DN 300.
- A extensão do trecho aparece em vermelho junto a ele logo depois de traçar.
- A opção passou a se chamar "Numeração automática de PVs e trechos".

### Exportação
- Arquivos › Exporta traçado para DXF (sem resultados): o traçado pode ser exportado a qualquer momento, mesmo sem dimensionamento aprovado.
- O aviso de exportação bloqueada diz quais trechos impedem e por quê.

### Testes
- Fase 8 (`tests/PHASE-8.md`): T8-01 a T8-05 e T8-08 aprovados; T8-06, T8-07, T8-09 e T8-10 aguardam respostas do engenheiro.
- Fase 9 (`tests/PHASE-9.md`): atualização automática, T9-01 a T9-08, com um servidor HTTP local no runner. Há também o ensaio com os executáveis exportados (`tools/ensaio_atualizacao.py`).

## 0.2.0-alpha — edição segura da rede, traçado assistido e intercâmbio DXF/GeoPackage

Segunda versão para avaliação. Resumo para quem usa o programa: [docs/MUDANCAS-DESDE-0.1.0.md](docs/MUDANCAS-DESDE-0.1.0.md).

### Edição da rede
- Regras da rede no traçado: um afluente só pode ser ligado a um PV que já tenha saída, e cada PV recebe no máximo 3 trechos. Ligações fora dessas regras são recusadas com um aviso, e o PV fica destacado em vermelho ao passar o mouse sobre ele.
- Não é mais possível apagar o trecho de jusante de um PV que recebe dois ou mais trechos, nem o próprio PV, porque esses trechos ficariam sem saída. Um aviso explica o motivo.
- Apagar pede confirmação ("Deseja mesmo apagar o ponto…?"). Apagar um ponto intermediário une os dois trechos.
- Iniciar um coletor e finalizar ou cancelar sem traçar não deixa mais um nó solto. Apagar trechos também não deixa resíduos.
- Ferramenta de seleção por caixa (arrastar na área vazia), como nos programas de desenho: seleciona nós e trechos inteiramente dentro da caixa. Ctrl soma à seleção, Del apaga e Esc desfaz a seleção. Novo comando Trechos › Seleciona tudo.

### Planilhas
- Barra de exportação na vista de planilhas: aba atual em CSV, XLSX, HTML ou PDF, ou todas as planilhas numa pasta de trabalho XLSX (Arquivos › Exporta todas as planilhas).
- Colunas fixas ao rolar para a direita: Col., Trecho, PV e Ext. em Resultados (e as colunas de identificação nas demais). O XLSX exportado abre com as mesmas colunas congeladas.

### Intercâmbio
- Arquivos › Importa rede de DXF…: linhas e polilinhas dos layers escolhidos viram coletores (o sentido do desenho é o sentido do escoamento). Os segmentos inválidos são listados.
- Arquivos › Cadastro e SIG › Exporta rede (GeoPackage)…: arquivo .gpkg com as camadas de PVs e trechos (com os resultados, quando aprovados), pronto para o QGIS.

### Traçado assistido
- Durante o traçado, o raio de busca da interpolação aparece como um círculo no cursor, com as retas usadas e a cota que o próximo PV vai receber. Sobre uma curva de nível, o PV recebe a cota da curva, sem interpolação.
- Osnap (magnetismo, F10 ou botão OSNAP): o cursor gruda em PVs, pontos cotados, vértices de ruas, curvas de nível e ruas, com marcador e nome do alvo. Um PV colocado num ponto cotado recebe a cota do ponto.
- Orto (F9 ou botão ORTO): trechos e nós arrastados só na horizontal ou na vertical.

### Cálculo
- Alerta ao dimensionar para trechos isolados (sem deságue na rede principal) e para trechos com terreno sem caimento. É uma advertência: não bloqueia o cálculo e também aparece na Planilha de Observações.

### Testes
- 57 verificações automatizadas (eram 42). Novas fases 6 (T6-01 a T6-10, `tests/PHASE-6.md`) e 7 (T7-01 a T7-05, `tests/PHASE-7.md`).

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
