# Atualização automática

A partir da 0.3.0-alpha.1, o DimEsgoto instalado procura versão nova sozinho e se atualiza, sempre perguntando antes. As versões 0.1.0 e 0.2.0 não têm essa função: quem está nelas instala a 0.3.0-alpha.1 à mão **uma vez**, e daí em diante as versões chegam pelo programa.

## Como funciona na máquina do usuário

1. Uns 3 segundos depois de abrir, o programa consulta a lista de releases do repositório no GitHub (sem login e sem enviar dados do usuário).
2. Se houver uma versão maior que a instalada **e** o release trouxer o manifesto assinado, aparece a janela "Nova versão disponível", com as novidades e os botões **Atualizar agora** e **Depois**.
3. **Atualizar agora:**
   - o programa confere a assinatura do manifesto com a chave pública que vem dentro dele;
   - baixa o zip da plataforma (Windows ou Linux) e confere o tamanho e o SHA-256;
   - troca o executável: o atual vira `DimEsgoto.exe.old` e o novo toma o lugar.
4. Aparece "Atualização instalada", com **Reiniciar agora** e **Depois**. Reiniciar pergunta antes se houver alterações não salvas. Na abertura seguinte, o `.old` é apagado.

Se algo falhar (sem internet, assinatura errada, arquivo corrompido, pasta sem permissão de gravação), o programa atual continua igual e a janela mostra o motivo e o link dos Releases para baixar à mão.

- **Ajuda › Verificar atualizações…** procura na hora.
- **Ajuda › Verificar atualizações ao abrir** liga ou desliga a busca automática (vem ligada).

Versões de teste (marcadas como *pre-release* no GitHub) também são oferecidas. Enquanto o programa está em alpha, todo mundo é testador.

**Limitação:** a pasta do programa precisa permitir gravação. Documentos, Área de Trabalho e Downloads servem. Dentro do zip ou em "Arquivos de Programas", a troca falha e o programa mostra o link para baixar à mão.

## Como publicar uma versão (para quem mantém)

1. Suba o número da versão nos 3 lugares:
   - `app/project.godot` (`config/version`);
   - `app/main.gd` (`VERSAO`);
   - `app/export_presets.cfg` (`file_version` e `product_version`, só números).

   Use SemVer: as versões de teste seguem `0.3.0-alpha.2`, `0.3.0-alpha.3`… Nunca publique `0.3.0-alpha` (sem número) depois de uma `0.3.0-alpha.N`: pelo SemVer ela é **mais antiga** e não seria oferecida.
2. `python3 tests/run_tests.py`: tudo PASS ou SKIP.
3. `python3 tools/build_release.py`. Ele gera, em `dist/v<versão>/`:
   - os zips;
   - `SHA256SUMS.txt`;
   - `dimesgoto-atualizacao.json` (o manifesto);
   - `dimesgoto-atualizacao.json.sig` (a assinatura).

   Ele também confere o manifesto com a chave embutida e diz "assinatura ok".
4. `python3 tools/ensaio_atualizacao.py`: o executável Linux exportado se atualiza sozinho a partir de um servidor local (8/8).
5. Rode `python3 tests/run_tests.py --fase 9` de novo: o T9-07 agora confere o pacote.
6. Commit, tag `v<versão>` e push.
7. No GitHub, crie o Release da tag e anexe **os 5 arquivos**: os 2 zips, `SHA256SUMS.txt`, `dimesgoto-atualizacao.json` e `dimesgoto-atualizacao.json.sig`.
   - Marque *Set as a pre-release* para versão de teste.
   - O texto do release aparece como "Novidades" na janela do programa: escreva para quem usa.

Sem o manifesto e a assinatura, o release continua baixável à mão, mas nenhum programa instalado o oferece.

## A chave de assinatura

- **Privada:** `~/.config/dimesgoto/chave-atualizacao.pem` (RSA 3072), nesta máquina. Pode ser outra, pela variável `DIMESGOTO_CHAVE`. **Nunca vai para o repositório.**
- **Pública:** dentro do programa (`app/atualizador.gd`, `CHAVE_PUBLICA`) e em `tools/chave-atualizacao-publica.pem`. Pode ser pública.

**Faça uma cópia de segurança da chave privada** (pendrive, cofre de senhas). Ela é o que prova que a atualização veio de vocês.

- **Se ela se perder:** os programas instalados deixam de aceitar versões novas. A saída é gerar outra chave (`tools/chave_atualizacao.gd -- gerar`), pôr a pública nova no `atualizador.gd` e pedir a todos uma nova instalação manual.
- **Se ela vazar:** troque a chave do mesmo jeito. Quem tiver a chave consegue publicar uma "atualização" que os programas aceitam, mas só pelo repositório do GitHub, que exige acesso à conta.

## Arquivos

| Arquivo | Papel |
|---|---|
| `app/atualizador.gd` | consulta, conferência, download e troca do executável |
| `app/main.gd` | menu Ajuda, janelas, verificação ao abrir, `--ensaio-atualizacao=` (só servidor local) |
| `tools/build_release.py` | gera, assina e confere o manifesto |
| `tools/chave_atualizacao.gd` | gera a chave, assina e confere (`gerar`, `assinar`, `conferir`) |
| `tools/ensaio_atualizacao.py` | ensaio com os executáveis exportados |
| `tests/test_fase9.gd`, `tests/PHASE-9.md` | testes da fase 9 |
