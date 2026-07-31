# Myboot.win

Site estático da ferramenta de formatação pela rede. Sem build, sem backend:
o Netlify publica esta pasta como está.

## Arquivos

```
index.html          Página inicial (download + lista de imagens)
imagens.html        Catálogo com detalhes técnicos
ajuda.html          Passo a passo e problemas comuns
404.html            Página de erro
assets/             estilo.css, app.js, favicon.svg
catalogo.json       << o que aparece na lista de imagens
arquivos.json       << lista opcional de arquivos pequenos para download
arquivos/           onde ficam esses arquivos pequenos
instalador.bat      o que o usuário baixa (~5 KB)
sistema.zip         pacote que o instalador baixa
versao.txt          versão do pacote
_headers            cabeçalhos do Netlify (download forçado, no-cache)
_redirects          atalhos: /baixar, /imagens, /ajuda
netlify.toml        configuração de publicação
robots.txt          bloqueia indexação
```

## Publicar a primeira vez

1. Entre em [app.netlify.com](https://app.netlify.com) → **Add new site** → **Deploy manually**.
2. Arraste esta pasta inteira para a área de upload.
3. Em **Domain management**, adicione o domínio `myboot.win` e aponte o DNS
   conforme as instruções que o Netlify mostrar.
4. Confira: abrir `https://myboot.win/versao.txt` tem que devolver `1.0.0`.

Enquanto o domínio não estiver ativo, o Netlify dá um endereço tipo
`nome-aleatorio.netlify.app`. Se for usar esse endereço, troque a linha
`set "SITE=https://myboot.win"` no começo do `instalador.bat`.

## Publicar uma imagem nova

As imagens (vários GB) **não** ficam no Netlify — ficam no Cloudflare R2.

1. Suba os arquivos (`boot.wim`, `boot.sdi`, `Install*.swm`) para o bucket R2,
   dentro de uma pasta com nome próprio, ex.: `pc114sp-v15/`.
2. Deixe o bucket com acesso público de leitura e copie a URL pública.
3. Edite o `catalogo.json`:
   - `urlBase` = a URL pública do bucket (com a barra no final).
   - Adicione um bloco novo em `imagens` copiando o que já existe e ajustando
     `id`, `nome`, `descricao`, `indice`, `tamanhoBytes` e os caminhos.
   - Atualize `atualizadoEm`.
4. Republique a pasta no Netlify. A lista do site e do instalador muda sozinha.

Campos de cada imagem:

| campo | o que é |
|---|---|
| `id` | identificador interno, sem espaço |
| `nome` | o que aparece na lista |
| `descricao` | modelos de máquina a que se destina |
| `indice` | índice da edição dentro do WIM (normalmente `1`) |
| `tamanhoBytes` | soma dos arquivos, em bytes — só para exibir |
| `bootWim` / `bootSdi` | caminhos relativos a `urlBase` |
| `arquivos` | partes do install, em ordem |
| `unattend` | caminho do XML de instalação automática, ou `""` |

## Publicar um arquivo pequeno

1. Coloque o arquivo em `arquivos/`.
2. Acrescente a entrada correspondente em `arquivos.json`
   (o modelo está em `arquivos/LEIA-ME.txt`).
3. Republique. A seção "Arquivos para download" aparece sozinha na home.

Limite do Netlify: 100 MB por arquivo. Acima disso, use o R2.

## Atualizar o sistema (sistema.zip)

O `sistema.zip` é o pacote com os scripts PowerShell. Quando mudar algo em
`sistema/`, gere o zip de novo — a raiz do zip precisa conter a pasta `sistema`:

```powershell
Compress-Archive -Path "C:\caminho\sistema" -DestinationPath ".\sistema.zip" -Force
```

Suba o zip novo e incremente o `versao.txt`.

## Testar localmente

`fetch` não funciona com `file://`. Rode um servidor simples na pasta:

```powershell
python -m http.server 8080
```

Depois abra `http://localhost:8080`.
