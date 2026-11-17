# 05 — Perguntas ao chefe (regras de negócio)

O texto abaixo está pronto para colar no WhatsApp. Cada pergunta traz uma proposta, então basta ele responder "ok" ou corrigir. As respostas entram na tabela do fim, e cada decisão vai para `tests/DECISOES.md`.

---

**Texto para enviar:**

> Oi! Ouvimos todos os áudios. A lista está fechada e a gente já começou pelo que está claro. Antes de mexer no resto, precisamos confirmar algumas regras. Em cada item vai a nossa proposta: se estiver bom, é só responder "ok" com o número.
>
> **Já corrigimos o erro da lâmina:** o programa só conferia a lâmina com a vazão de fim de plano. No caso do seu print (35 l/s no início e 20 no fim), ele deixava o tubo de 150 mm trabalhando cheio e ainda aprovava. Agora confere com as duas vazões e aumenta o diâmetro (no teste foi para 350 mm, com lâmina de 68%).
>
> **A conversão do TL já está pronta,** como você pediu primeiro: ao ligar num TL, aparece a pergunta (PV, PI ou TIL de passagem), e com 2 ou 3 entradas ele vira PV sozinho. Também já aparece o comprimento em vermelho logo depois de traçar. Algumas escolhas abaixo foram feitas provisoriamente e é só confirmar.
>
> **1. TIL de passagem**
> a) Na planta, a sigla pode ser **TIL-P**?
> b) Qual custo usamos no orçamento? (Proposta: o mesmo do TIL radial até você mandar o valor.)
> c) Se o trecho que chega ou sai dele tiver mais de 300 mm, o programa só avisa ("Verifique") ou não deixa usar o TIL de passagem? (Proposta: só avisa.)
> d) Existe profundidade máxima para ele?
>
> **2. Ligar uma rede num TL**
> As opções são PV, Poço de Inspeção (PI) e TIL de passagem. Entra mais alguma, por exemplo caixa de passagem ou TIL radial? E se o usuário clicar em Cancelar na pergunta, o programa desiste da ligação e o TL fica como estava? (Proposta: sim.)
>
> **3. Duas ou mais entradas viram PV**
> a) A caixa de passagem (CP) também vira PV automaticamente? (Proposta: sim.)
> b) Se depois o usuário apagar uma das entradas e ficar só uma, o nó continua PV ou volta ao que era? (Proposta: continua PV.)
>
> **4. Lâmina e tensão trativa**
> A lâmina vai ser conferida com as duas vazões. A tensão trativa hoje usa a vazão de início de plano. Quando a de início for maior que a de fim, usamos a **menor** das duas (o caso pior para a autolimpeza)? (Proposta: sim.)
>
> **5. Exportação da planta bloqueada**
> A planta com resultados só sai quando o resultado está aprovado, e o mais provável é que a lâmina tenha reprovado algum trecho. Já fizemos duas coisas: o aviso agora diz quais trechos impedem e por quê, e existe "Exporta traçado para DXF (sem resultados)", que funciona a qualquer momento. Pode mandar o arquivo da rede para conferirmos? E você ainda quer uma planta **com resultados** marcada "PRELIMINAR — resultado não aprovado", mesmo com restrições? (Proposta: não é preciso, porque o traçado já resolve. Se precisar, fazemos.)
>
> **6. Materiais**
> a) PVC, PVC corrugado e ferro fundido, todos com Manning 0,010 e K 0,06? O ferro fundido costuma ter rugosidade maior (n de 0,012 a 0,013). Ficam iguais ou você passa os valores?
> b) Quais diâmetros e custos de cada um? (Proposta: até você mandar, PVC e PVC corrugado com a tabela atual, e ferro fundido a partir de DN 150.)
> c) Tiramos "VINILFORT" também do nome dos TILs (ficando "TIL radial" e "TIL com tubo de queda")? (Proposta: sim.)
>
> **7. Numeração 1/1, 1/2…**
> a) Usamos a barra mesmo (1/1) ou hífen (1-1)?
> b) Os PVs continuam numerados 1, 2, 3… de montante para jusante? (Proposta: sim.)
> c) Ordem dos coletores, neste exemplo:
> ```
> Principal:   A → B → C → D → E (saída)
> Afluente X:  X1 → X2 → B      (300 m, chega em B)
> Afluente Z:  Z1 → X2          (chega no X)
> Afluente Y:  Y1 → Y2 → D      (500 m, chega em D)
> ```
> O coletor 1 é A→E (o mais extenso). Quem é o coletor 2?
> - **Opção 1 (como está hoje):** descendo o coletor 1, quem chega primeiro. Ficaria X = 2, Z = 3 (afluente do X) e Y = 4.
> - **Opção 2:** o afluente mais extenso. Ficaria Y = 2, X = 3 e Z = 4.
>
> **8. Ferramenta Redesenhar (Ctrl+R)**
> Ela vai apagar o rastro do cálculo de cota (círculo e retas) e atualizar os símbolos. Tem mais algum "resíduo" que você vê na tela e quer que suma? E o rastro poderia sumir sozinho logo depois de colocar o PV, sem precisar do Ctrl+R?
>
> **9. Arquivo do projeto**
> O arquivo .esg do programa já é, por dentro, um JSON. A proposta é salvar com a extensão **.json** (os .esg antigos continuam abrindo) e manter o GeoPackage como exportação para o QGIS. Você precisa abrir o arquivo do projeto direto no QGIS, ou a exportação GeoPackage já resolve?

---

## Respostas

| # | Pergunta | Resposta | Data | Decisão registrada |
|---|---|---|---|---|
| Q1 | TIL de passagem: sigla, custo, DN > 300, profundidade | | | |
| Q2 | Opções ao ligar num TL; Cancelar | | | |
| Q3 | CP vira PV; nó que perde entrada | | | |
| Q4 | Tensão trativa com a menor vazão | | | |
| Q5 | Arquivo e mensagem; planta preliminar | | | |
| Q6 | Materiais: n e K, diâmetros, custos; nome dos TILs | | | |
| Q7 | Separador; PVs; ordem dos coletores | | | |
| Q8 | Resíduos do Redesenhar; rastro automático | | | |
| Q9 | Formato .json; GeoPackage só como exportação | | | |
