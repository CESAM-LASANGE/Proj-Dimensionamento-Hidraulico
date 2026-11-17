# Testes da fase 9: atualização automática

> **Situação (17/11/2026):** T9-01 a T9-08 implementados e aprovados. O T9-07 só roda quando há pacote da versão atual em `dist/`. O ensaio com os executáveis exportados (`tools/ensaio_atualizacao.py`) deu 8/8.

**Por que existe.** Os programas instalados não se atualizavam. Cada versão nova exigia baixar o zip e trocar o executável à mão. A fase 9 permite que o programa instalado procure, confira e instale a versão nova sozinho, sempre com a confirmação do usuário.

Como funciona e como publicar: [docs/ATUALIZACAO.md](../docs/ATUALIZACAO.md). Convenções de [PHASE-2-5.md](PHASE-2-5.md): estados `PASS` / `FAIL` / `SKIP`.

Implementação:

- `app/atualizador.gd`: as funções estáticas (versões, escolha do release, manifesto, disco) e o fluxo por HTTP;
- `app/main.gd`: o menu, as janelas e a verificação ao abrir;
- `tests/test_fase9.gd`: T9-01 a T9-07, em modo headless;
- `tests/run_tests.py`: sobe um servidor HTTP local, que faz o papel do GitHub (`DIMESGOTO_TESTE_HTTP`, `DIMESGOTO_TESTE_WWW`), e calcula o T9-08;
- `tools/build_release.py` e `tools/chave_atualizacao.gd`: geram, assinam e conferem o manifesto;
- `tools/ensaio_atualizacao.py`: ensaio manual com os executáveis exportados, feito antes de cada release.

Invariantes:

- nada é instalado sem a assinatura do manifesto conferida com a chave embutida no programa;
- nada é instalado sem o tamanho e o SHA-256 do pacote conferidos;
- nunca se instala uma versão igual ou mais antiga que a atual;
- em qualquer falha, o executável atual continua intacto e funcionando;
- o programa nunca consulta a internet durante os testes nem quando roda pelo editor, e nunca troca o binário do Godot.

---

### T9-01: comparação de versões

- Ordem SemVer com pré-lançamento: `0.2.0-alpha` < `0.3.0-alpha.1` < `0.3.0-alpha.2` < `0.3.0-alpha.10` < `0.3.0-beta` < `0.3.0` < `0.3.1`. Também `0.9.9` < `0.10.0`.
- O prefixo `v` e os metadados `+…` não mudam a versão. Uma tag sem versão válida (`nightly`) é reconhecida como tal.
- `VERSAO` do `main.gd` = `config/version` do `project.godot`.

### T9-02: escolha do release

Lista no formato da API do GitHub.

- Escolhe a maior versão acima da atual que publica `dimesgoto-atualizacao.json` e `.sig`.
- Ignora rascunhos, releases sem manifesto e tags inválidas.
- Sem versões de teste (`prerelease`), fica com a maior versão final.
- Na versão mais nova, ou acima de todas, não oferece nada (não há downgrade).
- Uma resposta de erro da API (objeto, `null`) não quebra.

### T9-03: manifesto assinado

O manifesto é aceito só se for assinado com a chave certa e for coerente. É recusado quando:

- 1 byte do manifesto foi alterado;
- foi assinado com outra chave;
- não tem assinatura;
- é de outra versão que a do release;
- não é mais novo que a versão instalada;
- não tem pacote da plataforma;
- o SHA-256, o tamanho ou o caminho são inválidos, mesmo com a assinatura certa.

Além disso, a chave pública embutida (`Atualizador.CHAVE_PUBLICA`) é válida e igual a `tools/chave-atualizacao-publica.pem`.

### T9-04: troca do executável no disco

- Zip sem o executável esperado, ou zip inexistente: erro claro.
- O executável é extraído do zip e, no Linux, ganha permissão de execução.
- Na troca, o novo fica no lugar e o antigo vira `<exe>.old`. Sem o arquivo novo, nada muda.
- Ao abrir de novo, `limpar_antigo` apaga o `.old`.

### T9-05: fluxo completo por HTTP (servidor local)

- `verificar()` encontra a versão de teste com as notas, e `baixar_e_instalar()` troca o executável. Não sobram `.novo` nem zip baixado.
- Sem versões de teste, ou já na versão mais nova: "atualizado".
- Pacote adulterado no servidor (mesmo tamanho): recusado pelo SHA-256, executável intacto.
- Manifesto assinado por outra chave: recusado antes de baixar o pacote.
- API com 404 ou servidor fora do ar: erro tratado, sem travar (servidor fora do ar: menos de 15 s).
- Fora do programa exportado e sem `exe_atual`: recusa instalar, e o binário do Godot não é tocado.

### T9-06: interface

- Ajuda › Verificar atualizações… existe.
- Ajuda › Verificar atualizações ao abrir vem ligada, liga e desliga pelo menu e fica salva na configuração.
- O atualizador conhece a versão do programa. Fora do programa exportado, ele não consulta a internet ao abrir.
- Verificação manual com versão nova: abre a janela "Nova versão disponível", com a versão nova, a atual e o botão "Atualizar agora".
- "Atualizar agora" baixa e troca o executável, e oferece "Reiniciar agora". Reiniciar passa pela pergunta de alterações não salvas.
- Já atualizado: a barra de status avisa.
- Sem conexão: janela com o motivo e o endereço para baixar à mão.

### T9-07: pacote de release assinado

Quando existe `dist/v<VERSAO>/dimesgoto-atualizacao.json`:

- o manifesto confere com a chave embutida;
- o SHA-256 de cada zip confere;
- cada zip contém o executável indicado.

Sem pacote: SKIP.

### T9-08: regressão completa

Calculado pelo runner: fases 0 a 8 executadas na mesma rodada, sem FAIL.

---

### Ensaio com os executáveis exportados (manual, antes de cada release)

`python3 tools/build_release.py && python3 tools/ensaio_atualizacao.py` faz, só com o executável Linux exportado:

1. o executável da versão atual encontra uma versão seguinte de mentira (`<versão>.ensaio`), com o manifesto assinado pela chave real, num servidor local;
2. ele instala essa versão sobre si mesmo;
3. ao abrir, o programa já é a versão nova e o `.old` some;
4. com o pacote adulterado, a instalação é recusada e o executável fica intacto.

**Não coberto aqui:** renomear o `.exe` em uso no Windows (não há Windows nesta máquina). É o procedimento padrão: o Windows deixa renomear um executável em uso, mas não sobrescrevê-lo. Se falhar, o programa desfaz a troca e mostra o link para baixar à mão. A confirmação vem na primeira atualização real no Windows.
