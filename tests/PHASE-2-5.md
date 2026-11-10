# Testes das fases 2 a 5

Este documento transforma os evals em casos de teste concretos para orientar o agente de código. Os testes são contratos: antes da implementação de uma funcionalidade, o teste pode permanecer vermelho, mas não deve ser removido ou enfraquecido.

## Convenções

- Coordenadas horizontais em metros.
- Cotas em metros.
- Vazões em l/s.
- Distâncias de associação espacial em metros.
- Tolerância geométrica padrão: `0,001 m`.
- Tolerância numérica padrão: `1e-6`.
- Cada teste deve devolver `PASS`, `FAIL` ou `SKIP`.
- `SKIP` só é permitido quando a funcionalidade ainda não faz parte da fase em execução; deve informar o motivo.

Fixtures desta suíte:

- `tests/fixtures/topografia_phase2.dxf`
- `tests/fixtures/ligacoes_phase3.csv`
- `tests/fixtures/interferencias_phase3.geojson`
- `tests/fixtures/projeto_v2_phase5.json`

---

## Fase 2 — topografia e qualidade geográfica

### T2-01 — leitura de layers DXF

Entrada: `topografia_phase2.dxf`.

Esperado:

```json
{
  "ok": true,
  "layers": ["INTERF_AGUA", "PT_COTADOS", "RUAS", "TOPO_CURVAS"],
  "curvas": 2,
  "ruas": 1,
  "pontos": 2,
  "textos": 2
}
```

Falha se uma entidade for atribuída ao layer errado, se a cota Z for perdida ou se o arquivo causar crash.

### T2-02 — seleção de layers

Ler o mesmo DXF selecionando somente `TOPO_CURVAS`.

Esperado:

- duas curvas;
- zero ruas;
- zero pontos cotados;
- zero entidades de `INTERF_AGUA`.

Repetir para `PT_COTADOS` e `RUAS`.

### T2-03 — interpolação linear conhecida

As curvas horizontais da fixture têm cotas 100 m e 110 m. Verificar:

| Ponto | Cota esperada |
|---|---:|
| `(50, 50)` | `105,000` |
| `(25, 25)` | `102,500` |
| `(75, 75)` | `107,500` |

O teste deve aceitar erro máximo de `0,001 m`.

### T2-04 — ponto cotado mais próximo

Os pontos cotados da fixture são `(20, 20, 101,5)` e `(80, 80, 108,5)`.

Esperado:

- consulta em `(21,20)` retorna `101,5`;
- consulta em `(79,80)` retorna `108,5`;
- consulta fora do raio configurado retorna `ok=false`;
- o resultado informa distância do ponto utilizado.

### T2-05 — mistura de curvas e pontos

Com o critério “curvas + pontos”:

- um ponto dentro de `10%` do raio de busca deve usar o ponto cotado;
- se nenhum ponto estiver próximo, deve usar a interpolação das curvas;
- se nenhum dos dois métodos funcionar, deve retornar cota inválida, nunca `0,000` silencioso.

### T2-06 — dados topográficos inválidos

Executar com:

- DXF truncado;
- curva com menos de dois vértices;
- curva sem elevação;
- ponto sem elevação;
- layer inexistente;
- arquivo vazio.

Esperado: mensagem de diagnóstico, log gravado e processo sem crash.

### T2-07 — referência espacial

Criar projeto com:

```json
{
  "crs": "EPSG:31983",
  "unidade_horizontal": "m",
  "unidade_vertical": "m",
  "datum_vertical": "não informado",
  "origem_topografia": "topografia_phase2.dxf"
}
```

Salvar e reabrir. Todos os campos devem permanecer iguais. Projeto sem CRS deve ser marcado como “referência não informada”.

### T2-08 — DXF binário

Caso o suporte ainda não exista, o teste deve passar somente com o estado `SKIP` e a mensagem “DXF binário não implementado”. Nunca deve passar como se o arquivo tivesse sido importado.

Quando implementado, o mesmo conteúdo do DXF ASCII deve produzir a mesma quantidade de curvas, pontos e ruas.

---

## Fase 3 — SIG, bacias e cadastro

### T3-01 — importação de ligações

Entrada: `ligacoes_phase3.csv`.

Esperado:

- 5 registros lidos;
- 4 identificadores únicos;
- 1 registro duplicado;
- 1 registro com consumo ausente;
- 1 registro fora da área de estudo;
- nenhum registro válido deve ser descartado sem aparecer no relatório.

### T3-02 — associação espacial ao trecho

Usar uma rede com dois trechos:

```text
T1: (0,0) -> (100,0)
T2: (0,100) -> (100,100)
```

Esperado:

- ligação `(10,5)` associa a `T1`;
- ligação `(90,95)` associa a `T2`;
- ligação a mais de `20 m` de qualquer trecho fica sem associação;
- a distância calculada é armazenada.

### T3-03 — conservação de massa por bacia

Para a bacia da fixture:

- população válida: `9 habitantes`;
- consumo válido: `400 l/dia`;
- registros inválidos não entram na vazão;
- soma das contribuições das áreas deve ser igual à soma lançada nos nós, com tolerância `1e-6`.

### T3-04 — duplicidade e dados incompletos

O relatório de importação deve classificar cada linha como:

- válida;
- duplicada;
- fora da área;
- sem consumo;
- sem coordenada;
- inválida.

O usuário deve poder exportar esse relatório para CSV.

### T3-05 — importação de interferências

Entrada: `interferencias_phase3.geojson`.

Esperado:

- duas camadas reconhecidas: `AGUA_EXISTENTE` e `DRENAGEM`;
- geometria preservada;
- propriedades `id`, `origem`, `data` e `crs` preservadas;
- interferências visíveis na planta;
- exportação mantém os mesmos identificadores.

### T3-06 — bacias e sub-bacias

Criar uma bacia principal com duas sub-bacias e um trecho de saída.

Esperado:

- cada ligação pertence a apenas uma sub-bacia;
- a contribuição das sub-bacias chega ao trecho de saída;
- áreas sobrepostas são rejeitadas ou sinalizadas;
- ligação fora de qualquer bacia aparece como erro.

### T3-07 — exportação e reimportação

Exportar a rede para o formato geográfico suportado pelo produto e reimportar em um novo projeto.

Comparar:

- identificadores dos nós;
- identificadores dos trechos;
- coordenadas;
- cotas;
- diâmetros;
- situação da rede;
- sentido de escoamento.

Todos devem permanecer iguais dentro das tolerâncias definidas.

### T3-08 — resultados desatualizados

1. Dimensionar uma rede.
2. Alterar uma cota topográfica.
3. Reabrir a tela de resultados.

Esperado:

- resultados marcados como desatualizados;
- exportação final bloqueada ou explicitamente marcada como desatualizada;
- novo dimensionamento limpa o estado desatualizado.

---

## Fase 4 — entregáveis de engenharia

### T4-01 — exportação das planilhas

Para cada aba de resultados, exportar CSV, XLSX, HTML e PDF/memorial.

Validar:

- mesma quantidade de linhas;
- mesma quantidade de colunas;
- nomes de colunas preservados;
- unidades presentes;
- números não convertidos em texto incorreto;
- acentos preservados;
- separador decimal documentado.

### T4-02 — conteúdo mínimo do memorial

O memorial deve falhar no teste se faltar qualquer campo obrigatório:

- projeto;
- responsável;
- local;
- versão do aplicativo;
- versão/configuração normativa;
- data;
- parâmetros de início e fim de plano;
- método hidráulico;
- rugosidade;
- banco utilizado;
- resultados por trecho;
- observações;
- quantitativos;
- orçamento.

### T4-03 — rastreabilidade do resultado

O arquivo exportado deve conter um identificador ou hash do conjunto:

```text
projeto + parâmetros + topografia + banco + versão do motor
```

Alterando qualquer componente, o identificador deve mudar.

### T4-04 — planta DXF

Verificar a presença dos layers:

- rede projetada;
- rede existente;
- PVs;
- textos dos PVs;
- cotas;
- textos dos trechos;
- setas de fluxo;
- ruas;
- curvas principais e secundárias;
- pontos cotados;
- malha;
- margem.

Verificar também escala, diâmetro, declividade, sentido de fluxo e situação de cada trecho.

### T4-05 — perfil longitudinal

Para um coletor com três trechos, validar:

- ordem montante-jusante;
- terreno;
- geratriz do tubo;
- PVs;
- lâmina ou nível hidráulico quando disponível;
- cotas e distâncias;
- escala horizontal e vertical;
- exportação PNG e DXF.

### T4-06 — reprodutibilidade

Gerar duas vezes cada saída usando os mesmos arquivos de entrada.

Após remover timestamps, UUIDs temporários e metadados voláteis, os arquivos devem ser equivalentes byte a byte ou por comparação estrutural.

### T4-07 — bloqueio de exportação inválida

Com uma rede contendo erro estrutural ou resultado desatualizado:

- não exportar memorial como final;
- não exportar orçamento aprovado;
- não gerar DXF de resultados como se estivesse validado;
- informar o motivo do bloqueio.

---

## Fase 5 — robustez e manutenção

### T5-01 — migração v2

Entrada: `projeto_v2_phase5.json`.

Esperado:

- projeto abre sem crash;
- nós são criados uma única vez por nome;
- extensões são preservadas como extensão fixa;
- diâmetros fixados permanecem fixados;
- vazões pontuais são preservadas;
- nós de cabeceira viram terminais;
- o projeto convertido pode ser salvo e reaberto.

### T5-02 — ciclo completo de persistência

1. Abrir fixture.
2. Alterar parâmetro.
3. Alterar nó.
4. Alterar trecho.
5. Alterar topografia.
6. Dimensionar.
7. Salvar.
8. Fechar e reabrir.

Comparar projeto, topografia, parâmetros, banco selecionado, resultados e flags de atualização.

### T5-03 — undo/redo

Executar uma operação por vez e verificar:

- traçado;
- mover nó;
- edição de nó;
- edição de trecho;
- dividir trecho;
- deslocar trecho;
- remoção;
- alteração de parâmetros;
- alteração de topografia.

Após desfazer, o snapshot deve ser igual ao anterior. Após refazer, deve ser igual ao posterior.

### T5-04 — arquivo corrompido

Abrir JSON vazio, JSON inválido, projeto sem nós, projeto sem trechos e projeto com tipos errados.

Esperado:

- mensagem de erro compreensível;
- projeto atual não é sobrescrito;
- erro aparece no registro;
- processo permanece aberto.

### T5-05 — banco ausente ou inconsistente

Testar banco inexistente, material sem tubo, tubo com diâmetro inválido e PV sem custo.

O sistema deve validar referências antes do cálculo e indicar a tabela e o registro problemático.

### T5-06 — interrupção de gravação

Simular falha de escrita ou diretório sem permissão.

Esperado:

- arquivo anterior permanece intacto;
- usuário recebe mensagem;
- não marcar o projeto como salvo;
- registrar a falha.

### T5-07 — carga de projeto grande

Gerar projeto com 1.000 nós e 1.500 trechos.

Registrar:

- tempo de abertura;
- tempo de cálculo;
- tempo de redraw;
- tempo de exportação;
- memória aproximada.

Critério inicial sugerido: nenhuma operação pode travar a interface por mais de 3 segundos sem apresentar progresso ou cancelamento.

### T5-08 — isolamento da lógica de domínio

Inspecionar o código e falhar se fórmulas hidráulicas forem duplicadas em `main.gd`, `dialogs.gd` ou componentes visuais.

As telas devem chamar serviços do domínio; não recalcular vazão, declividade, orçamento ou geometria por conta própria.

### T5-09 — regressão completa

Depois de cada alteração nas fases 2–5, executar:

```text
Fase 0: EVAL-000 a EVAL-002
Fase 1: EVAL-101 a EVAL-107
Fase 2: T2-01 a T2-08
Fase 3: T3-01 a T3-08
Fase 4: T4-01 a T4-07
Fase 5: T5-01 a T5-08
```

Uma fase só pode ser marcada como concluída se não houver regressão em fases anteriores.

## Relatório obrigatório do agente

```text
Data:
Commit/versão:
Versão do Godot:

PASS:
FAIL:
SKIP:

Falhas novas:
Regressões:
Arquivos gerados:
Decisões técnicas:
```
