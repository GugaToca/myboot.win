# Publicar o Myboot.win — GitHub + Netlify

Roteiro completo, do zero até o site no ar. Faz uma vez só; depois cada
atualização são dois cliques.

---

## Parte 1 — Subir pelo site do GitHub (github.com)

Nada para instalar. Tudo pelo navegador — use **Chrome ou Edge**, porque só
neles o arrastar de pasta funciona direito.

### 1. Antes de tudo: mostre os arquivos ocultos

O arquivo `.gitignore` começa com ponto, então o Windows esconde ele. Se você
não mostrar, ele fica de fora e o GitHub vai aceitar as imagens gigantes depois.

No Explorador de Arquivos: aba **Exibir** → **Mostrar** → marque
**Itens ocultos**.

(No Windows 10: aba **Exibir** → marque a caixa **Itens ocultos**.)

### 2. Crie o repositório

1. Entre em <https://github.com> logado na sua conta
2. Botão verde **New** (ou o **+** no canto superior direito → **New repository**)
3. Preencha:
   - **Repository name:** `myboot-win`
   - **Description:** `Site de formatação pela rede`
   - Marque **Private** — o site é de uso interno
   - **NÃO** marque "Add a README file", nem .gitignore, nem license
4. **Create repository**

### 3. Suba os arquivos

Na tela que abre depois, clique no link **uploading an existing file**
(fica na frase "…or upload an existing file" no meio da página).

Agora a parte que a maioria erra:

> **Abra a pasta `myBoot_win`, selecione tudo o que está DENTRO dela
> (Ctrl+A) e arraste. Não arraste a pasta `myBoot_win` inteira.**

Se você arrastar a pasta, o GitHub cria tudo dentro de `myBoot_win/` e o
Netlify não acha o `index.html`.

Confira se estes 12 itens apareceram na lista de upload:

```
.gitignore      404.html        LEIA-ME.md      PUBLICAR.md
_headers        _redirects      ajuda.html      arquivos.json
assets/         arquivos/       catalogo.json   imagens.html
index.html      instalador.bat  netlify.toml    robots.txt
sistema.zip     versao.txt
```

Faltou o `.gitignore`? Volte ao passo 1 — os itens ocultos não estão visíveis.

### 4. Confirme

Embaixo, no campo de commit, escreva `Primeira versão do site` e clique em
**Commit changes**. O upload leva alguns segundos.

Pronto. O código está em `github.com/SEU-USUARIO/myboot-win`.

---

## Parte 2 — Conectar no Netlify

### 1. Crie o site

1. Entre em <https://app.netlify.com>
2. **Add new site** → **Import an existing project**
3. Escolha **GitHub** e autorize o acesso quando ele pedir
4. Na lista, selecione o repositório **myboot-win**
   - Se ele não aparecer, clique em **Configure the Netlify app on GitHub** e
     libere o acesso a esse repositório

### 2. Configuração do build

O Netlify vai perguntar como construir o site. Como é HTML puro:

| Campo | Valor |
|---|---|
| Branch to deploy | `main` |
| Build command | *(deixe vazio)* |
| Publish directory | `.` |

O arquivo `netlify.toml` já traz esses valores, então normalmente ele preenche
sozinho. Clique em **Deploy site**.

Em menos de um minuto o site está no ar num endereço tipo
`nome-aleatorio.netlify.app`. Abra e confira.

### 3. Aponte o domínio myboot.win

1. No painel do site: **Domain management** → **Add a domain**
2. Digite `myboot.win` e confirme
3. O Netlify mostra os servidores de DNS dele (algo como `dns1.p01.nsone.net`)
4. Entre no painel de onde você registrou o domínio e troque os nameservers
   pelos que o Netlify mostrou
5. Espere a propagação (de minutos a algumas horas)

O certificado HTTPS o Netlify emite sozinho depois que o domínio resolver.

### 4. Confira

Abra `https://myboot.win/versao.txt` — tem que aparecer `1.0.0`.
Depois abra `https://myboot.win` e clique em **Baixar instalador**: o arquivo
tem que baixar, não abrir na tela.

> Enquanto o domínio não estiver funcionando, se precisar usar o endereço
> `.netlify.app`, troque a linha `set "SITE=https://myboot.win"` no começo do
> `instalador.bat`.

---

## Depois: como atualizar o site

Tudo pelo site do GitHub. O Netlify percebe a mudança e republica sozinho em
segundos — você nunca mais precisa entrar no painel dele.

**Para mudar um texto ou o `catalogo.json`** (o caso mais comum):

1. Abra o repositório no `github.com`
2. Clique no arquivo (ex.: `catalogo.json`)
3. Clique no **lápis** no canto superior direito
4. Edite direto na tela
5. Botão verde **Commit changes** → **Commit changes** de novo

**Para subir um arquivo novo** (ex.: um driver em `arquivos/`):

1. No repositório, entre na pasta onde ele vai ficar
2. **Add file** → **Upload files**
3. Arraste o arquivo e clique em **Commit changes**
4. Não esqueça de editar o `arquivos.json` depois, senão ele não aparece no site

**Para trocar o `sistema.zip` por uma versão nova:**

1. Clique no `sistema.zip` no repositório → botão **⋯** → **Delete file** → commit
2. **Add file** → **Upload files** → arraste o zip novo → commit
3. Edite o `versao.txt` e suba o número

> Só cuidado com uma coisa: se você editar pelo site, o arquivo lá na sua
> pasta do computador fica desatualizado. Escolha um lugar para editar e
> mantenha o hábito — ou sempre no site, ou sempre no PC e reenviando.

---

## Cuidados

**Nunca versione as imagens.** Arquivos `.wim`, `.swm` e `.iso` têm vários GB e
o GitHub recusa arquivos acima de 100 MB. O `.gitignore` já bloqueia essas
extensões — não remova essas linhas. As imagens ficam no Cloudflare R2.

**O `.gitignore` não protege upload manual.** Ele vale para quem usa o Git de
verdade. Arrastando arquivo no site, o GitHub aceita qualquer coisa até 25 MB
por arquivo e recusa acima de 100 MB. Ou seja: a responsabilidade de não subir
imagem é sua. Imagem vai para o R2, ponto.

**Repositório privado.** O `robots.txt` bloqueia buscadores, mas isso não
protege nada de verdade. Mantenha o repositório privado.
