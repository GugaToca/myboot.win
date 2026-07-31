# Como subir as imagens do Windows

As imagens (`boot.wim`, `Install*.swm`) têm vários GB. Elas **não** vão para o
GitHub nem para o Netlify — os dois recusam arquivos desse tamanho. Elas vão
para o **Cloudflare R2**, que guarda arquivos grandes e não cobra pela saída
de dados (que é justamente o que você mais vai usar, já que cada formatação
baixa a imagem inteira).

O site só guarda o *endereço* delas, no `catalogo.json`.

```
GitHub/Netlify          Cloudflare R2
─────────────────       ─────────────────
site (KB)               imagens (GB)
catalogo.json  ──────►  boot.wim, Install*.swm
```

---

## Parte 1 — Criar o bucket (uma vez só)

1. Entre em <https://dash.cloudflare.com> (crie a conta se não tiver)
2. No menu da esquerda: **R2 Object Storage** → **Create bucket**
3. Nome: `myboot-imagens` · Location: **Automatic** → **Create bucket**

O R2 vai pedir um cartão de crédito para ativar. Os primeiros 10 GB de
armazenamento são gratuitos; acima disso são centavos de dólar por GB/mês.
Download não é cobrado.

### Liberar o acesso público

Sem isso o sistema não consegue baixar nada.

1. Dentro do bucket: aba **Settings**
2. Procure **Public access** → **R2.dev subdomain** → **Allow Access**
3. Confirme digitando `allow`
4. Copie a URL que aparece, algo como:
   `https://pub-a1b2c3d4e5.r2.dev`

**Guarde essa URL** — é o `urlBase` do `catalogo.json`.

---

## Parte 2 — Preparar os arquivos da imagem

Junte numa pasta local tudo que pertence a uma imagem:

```
D:\imagens\pc114sp-v15\
    boot.wim          ← ambiente de boot (do WinPE ou da ISO)
    boot.sdi          ← opcional
    Install.swm       ← partes da instalação, em ordem
    Install2.swm
    Install3.swm
    Install4.swm
    unattend.xml      ← opcional, instalação automática
```

Se você tem um `install.wim` inteiro (maior que 4 GB, o que quebra em pendrive
FAT32 e complica o download), divida em partes de 3 GB:

```powershell
dism /Split-Image /ImageFile:"D:\install.wim" /SWMFile:"D:\saida\Install.swm" /FileSize:3000
```

---

## Parte 3 — Subir para o R2

1. No painel do bucket, aba **Objects**
2. **Create folder** com o nome da versão, ex.: `pc114sp-v15`
3. Entre na pasta e clique em **Upload** → arraste os arquivos

Pelo navegador o limite é **300 MB por arquivo**, o que não serve para as
imagens. Para arquivos grandes use o **rclone**:

### Subindo com rclone (o jeito que funciona)

1. Baixe em <https://rclone.org/downloads> (Windows / AMD64 / .zip),
   extraia em `C:\rclone`
2. No painel do R2: **Manage R2 API Tokens** → **Create API Token**
   → permissão **Object Read & Write** → guarde o **Access Key ID** e o
   **Secret Access Key** (o secret só aparece uma vez)
3. Anote também seu **Account ID**, que fica na página inicial do R2
4. No PowerShell:

```powershell
cd C:\rclone
.\rclone config
```

Responda: `n` (new remote) → nome `r2` → tipo `s3` → provider
`Cloudflare` → cole o Access Key e o Secret → region `auto` →
endpoint `https://SEU-ACCOUNT-ID.r2.cloudflarestorage.com` → resto em branco
→ `q` para sair.

5. Envie a pasta:

```powershell
.\rclone copy "D:\imagens\pc114sp-v15" r2:myboot-imagens/pc114sp-v15 --progress
```

O `--progress` mostra a barra. Se a conexão cair, rode o mesmo comando de novo:
ele continua de onde parou.

### Conferir

Abra no navegador:
`https://pub-SEU-ID.r2.dev/pc114sp-v15/boot.wim`

Se começar a baixar, está certo. Se der **401** ou **403**, o acesso público
não foi liberado (volte à Parte 1).

---

## Parte 4 — Registrar no catálogo

Rode o gerador na pasta local da imagem — ele soma os bytes e monta a lista de
partes na ordem certa:

```powershell
cd "C:\Users\gusta\OneDrive\Área de Trabalho\myBoot_win\ferramentas"

.\gerar-entrada-catalogo.ps1 -Pasta "D:\imagens\pc114sp-v15" `
                             -Id "pc114sp-win11-v15" `
                             -Nome "Windows 11 Pro 24H2 - Escolar V15" `
                             -Descricao "PC114SP - MLSE03, MLSE13, SAX05"
```

Ele imprime o bloco JSON pronto e salva numa cópia dentro da pasta da imagem.

Agora no `github.com`, no seu repositório:

1. Abra o `catalogo.json` → clique no **lápis**
2. Ajuste o `urlBase` para a URL pública do R2 (com a barra no final):
   ```json
   "urlBase": "https://pub-a1b2c3d4e5.r2.dev/",
   ```
3. Cole o bloco gerado dentro de `imagens`, separando com vírgula se já houver
   outra imagem lá
4. Atualize o `atualizadoEm`
5. **Commit changes**

O Netlify republica em segundos. Confira em
<https://myboot-win.netlify.app/imagens> — a imagem nova tem que aparecer.

---

## Erros que acontecem

**A imagem aparece no site mas o download falha na hora de formatar.**
O `urlBase` ou os caminhos estão errados. Teste colando a URL montada no
navegador: `urlBase` + `arquivos[0]`. Tem que baixar.

**403 ao baixar.** Acesso público do bucket não liberado, ou você criou o
bucket certo mas subiu numa pasta com nome diferente do que está no catálogo.
Maiúscula e minúscula contam.

**O site não mostra a imagem nova.** JSON quebrado — quase sempre uma vírgula
sobrando ou faltando. Cole o conteúdo em <https://jsonlint.com> para achar a
linha.

**"Espaço insuficiente" no computador que vai formatar.** O sistema exige o
tamanho da imagem + 5 GB livres. Libere espaço ou use uma imagem menor.

---

## Sobre o endereço

O `instalador.bat` já está apontando para `https://myboot-win.netlify.app`.
Quando o domínio `myboot.win` entrar no ar, troque a linha do começo do
arquivo para `set "SITE=https://myboot.win"`, faça o commit e pronto — quem
baixar dali em diante já pega o endereço novo.
