<#
    servidor-local.ps1
    ---------------------------------------------------------------
    Transforma este PC num servidor de imagens para a rede local.

    Voce aponta para uma pasta com as imagens, ele:
      - varre as subpastas e monta o catalogo sozinho
      - serve o catalogo.json e os arquivos por HTTP
      - aceita download em partes (BITS consegue pausar e continuar)
      - atende VARIAS maquinas ao mesmo tempo (padrao: 8)

    Nos PCs que serao formatados, no botao roxo "1. Importar minha
    imagem", responda SIM e digite o endereco que este script mostrar.

    ---------------------------------------------------------------
    COMO USAR

      1. Organize a pasta assim, uma subpasta por imagem:

         D:\imagens\
             pc114sp-v15\
                 boot.wim
                 boot.sdi
                 Install.swm
                 Install2.swm
             dell-3420-v3\
                 boot.wim
                 Install.swm

      2. Abra o PowerShell COMO ADMINISTRADOR e rode:

         .\servidor-local.ps1 -Pasta "D:\imagens"

      3. Deixe a janela aberta enquanto estiver formatando.
         Ctrl+C encerra.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Pasta,
    [int]$Porta = 8080,

    # Quantas maquinas podem baixar ao mesmo tempo
    [int]$Simultaneos = 8,

    # Libera a porta no firewall do Windows automaticamente
    [switch]$AbrirFirewall
)

$ErrorActionPreference = 'Stop'

# ============================================================ VERIFICACOES

if (-not (Test-Path $Pasta)) {
    Write-Host "Pasta nao encontrada: $Pasta" -ForegroundColor Red
    exit 1
}
$Pasta = (Resolve-Path $Pasta).Path

$souAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $souAdmin) {
    Write-Host ''
    Write-Host '  Precisa rodar como ADMINISTRADOR.' -ForegroundColor Red
    Write-Host '  Sem isso o Windows nao deixa o servidor aceitar conexoes da rede.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Feche esta janela, clique com o botao direito no PowerShell' -ForegroundColor Yellow
    Write-Host '  e escolha "Executar como administrador".' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

# ============================================================ IP DA MAQUINA

function Obter-IPsLocais {
    <#
      Devolve TODOS os enderecos utilizaveis da maquina.
      Adivinhar um so da errado quando ha cabo + Wi-Fi + adaptador virtual.
    #>
    $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.PrefixOrigin -ne 'WellKnown'
        })

    # Deixa por ultimo o que quase nunca e o certo (VirtualBox, VMware, Hyper-V, WSL)
    $virtual = 'virtualbox|vmware|hyper-v|vethernet|wsl|loopback|docker'

    $reais    = @($ips | Where-Object { $_.InterfaceAlias -inotmatch $virtual })
    $virtuais = @($ips | Where-Object { $_.InterfaceAlias -imatch  $virtual })

    return @($reais) + @($virtuais)
}

$listaIP = Obter-IPsLocais
$ip = if ($listaIP.Count -gt 0) { $listaIP[0].IPAddress } else { '127.0.0.1' }
$url = "http://${ip}:$Porta"

# ============================================================ CATALOGO

function Montar-Catalogo {
    param([string]$Raiz, [string]$UrlBase)

    $imagens = @()

    # A pasta indicada pode estar de duas formas:
    #   (a) varias subpastas, uma por imagem
    #   (b) a propria imagem ja extraida, com Sources\ e Boot\ dentro
    # E a propria imagem se tem uma pasta Sources ao lado, ou um install solto aqui.
    $temSources = Test-Path (Join-Path $Raiz 'Sources')
    $temInstallSolto = @(Get-ChildItem -Path $Raiz -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -imatch '^\.(swm|wim|esd)$' -and $_.BaseName -imatch '^install' }).Count -gt 0
    $temInstallNaRaiz = ($temSources -or $temInstallSolto)

    if ($temInstallNaRaiz) {
        $pastas = @(Get-Item -Path $Raiz)
        Write-Host '  (a propria pasta indicada e a imagem)' -ForegroundColor DarkGray
    } else {
        $pastas = @(Get-ChildItem -Path $Raiz -Directory | Sort-Object Name)
    }

    foreach ($sub in $pastas) {

        # Prefixo do caminho: vazio quando a raiz ja e a propria imagem
        $pref = if ($temInstallNaRaiz) { '' } else { "$($sub.Name)/" }

        # -Recurse: o zip da imagem vem com Sources\ e Boot\ dentro
        $arqs = Get-ChildItem -Path $sub.FullName -File -Recurse

        # Caminho relativo a subpasta da imagem, no formato de URL
        function Rel($f) { $f.FullName.Substring($sub.FullName.Length + 1) -replace '\\','/' }

        $bootWim = $arqs | Where-Object { $_.Name -ieq 'boot.wim' } | Select-Object -First 1
        $bootSdi = $arqs | Where-Object { $_.Name -ieq 'boot.sdi' } | Select-Object -First 1
        $unatt   = $arqs | Where-Object { $_.Name -imatch '^(auto)?unattend\.xml$' } | Select-Object -First 1

        # So os arquivos de instalacao. Winre.wim e boot.wim NAO entram aqui.
        $partes = @($arqs | Where-Object {
            $_.Extension -imatch '^\.(swm|wim|esd)$' -and $_.BaseName -imatch '^install'
        })

        if ($partes.Count -eq 0) {
            Write-Host ("  [ignorada] {0} - nenhum .swm/.wim/.esd dentro" -f $sub.Name) -ForegroundColor DarkYellow
            continue
        }

        # Install.swm = 1, Install2.swm = 2, ...
        $partes = @($partes | Sort-Object {
            if ($_.BaseName -match '(\d+)$') { [int]$Matches[1] } else { 1 }
        })

        $soma = @($partes)
        if ($bootWim) { $soma += $bootWim }
        if ($bootSdi) { $soma += $bootSdi }
        if ($unatt)   { $soma += $unatt }
        $total = ($soma | Measure-Object -Property Length -Sum).Sum

        $img = [ordered]@{
            id           = $sub.Name
            nome         = $sub.Name
            descricao    = 'Servida pela rede local'
            indice       = 1
            tamanhoBytes = [int64]$total
            bootWim      = $(if ($bootWim) { "$pref$(Rel $bootWim)" } else { '' })
            bootSdi      = $(if ($bootSdi) { "$pref$(Rel $bootSdi)" } else { '' })
            arquivos     = @($partes | ForEach-Object { "$pref$(Rel $_)" })
            unattend     = $(if ($unatt) { "$pref$(Rel $unatt)" } else { '' })
        }

        $imagens += $img

        $gb = [math]::Round($total / 1GB, 2)
        Write-Host ("  [ok] {0,-28} {1,7} GB   {2} parte(s)" -f $sub.Name, $gb, $partes.Count) -ForegroundColor Green
        if (-not $bootWim) {
            Write-Host ("       AVISO: sem boot.wim, o ambiente de boot nao sera montado") -ForegroundColor Yellow
        }
    }

    return [ordered]@{
        versao       = 1
        atualizadoEm = (Get-Date -Format 'dd/MM/yyyy HH:mm')
        urlBase      = "$UrlBase/img/"
        imagens      = $imagens
    }
}

Write-Host ''
Write-Host '  LENDO A PASTA' -ForegroundColor Cyan
Write-Host '  --------------------------------------------------------'

$catalogo = Montar-Catalogo -Raiz $Pasta -UrlBase $url
$catJson  = $catalogo | ConvertTo-Json -Depth 6

if (@($catalogo.imagens).Count -eq 0) {
    Write-Host ''
    Write-Host '  Nenhuma imagem valida encontrada.' -ForegroundColor Red
    Write-Host '  Cada imagem precisa estar numa SUBPASTA, com pelo menos um .swm/.wim/.esd.' -ForegroundColor DarkGray
    Write-Host ''
    exit 1
}

# ============================================================ FIREWALL

if ($AbrirFirewall) {
    $regra = "Myboot - servidor local $Porta"
    if (-not (Get-NetFirewallRule -DisplayName $regra -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $regra -Direction Inbound -Action Allow `
            -Protocol TCP -LocalPort $Porta -Profile Any | Out-Null
        Write-Host ''
        Write-Host "  Regra de firewall criada: porta $Porta liberada." -ForegroundColor DarkGray
    }
}

# ============================================================ SERVIDOR

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$Porta/")

try {
    $listener.Start()
} catch {
    Write-Host ''
    Write-Host "  Nao consegui abrir a porta $Porta." -ForegroundColor Red
    Write-Host "  Causa comum: outro programa ja usa essa porta." -ForegroundColor DarkGray
    Write-Host "  Tente outra:  .\servidor-local.ps1 -Pasta `"$Pasta`" -Porta 8090" -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

Write-Host ''
Write-Host '  ========================================================' -ForegroundColor Cyan
Write-Host '   SERVIDOR NO AR' -ForegroundColor Cyan
Write-Host '  ========================================================' -ForegroundColor Cyan
Write-Host ''
if ($listaIP.Count -le 1) {
    Write-Host "   Endereco:  $url" -ForegroundColor Green -NoNewline
    Write-Host '   <-- digite isto no PC que vai formatar' -ForegroundColor DarkGray
} else {
    Write-Host '   Este PC tem mais de uma conexao. Use o endereco da MESMA rede' -ForegroundColor Yellow
    Write-Host '   do PC que vai ser formatado:' -ForegroundColor Yellow
    Write-Host ''
    foreach ($i in $listaIP) {
        Write-Host ("      http://{0}:{1}" -f $i.IPAddress, $Porta) -ForegroundColor Green -NoNewline
        Write-Host ("      ({0})" -f $i.InterfaceAlias) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host '   Na duvida: no PC a formatar, rode ipconfig e compare os tres' -ForegroundColor DarkGray
    Write-Host '   primeiros numeros. Ex.: 192.168.15.x combina com 192.168.15.y' -ForegroundColor DarkGray
}
Write-Host ''
Write-Host "   Imagens:   $(@($catalogo.imagens).Count)"
Write-Host "   Pasta:     $Pasta"
Write-Host "   Simultan.: ate $Simultaneos maquinas ao mesmo tempo"
Write-Host ''
Write-Host '   No PC a ser formatado: botao roxo "1. Importar minha imagem"'
Write-Host '   -> responda SIM -> digite o endereco acima.'
Write-Host ''
Write-Host '   Ctrl+C encerra o servidor.' -ForegroundColor DarkGray
Write-Host '  --------------------------------------------------------'
Write-Host ''

# ------------------------------------------------------------ atendimento
#
# Cada requisicao roda num runspace separado. Sem isso, uma maquina
# baixando 13 GB seguraria a fila e as outras ficariam esperando.
# Com o pool, as 5, 8, 10 maquinas baixam ao mesmo tempo.

$Atendente = {
    param($ctx, $Pasta, $catJson, $textoRaiz)

    # Escreve direto no console: funciona de qualquer thread.
    function Log($txt) { [Console]::WriteLine($txt) }

    function Responder-Texto {
        param($ctx, [string]$Texto, [string]$Tipo = 'text/plain; charset=utf-8', [int]$Codigo = 200)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Texto)
        $ctx.Response.StatusCode      = $Codigo
        $ctx.Response.ContentType     = $Tipo
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    }

    function Responder-Arquivo {
        param($ctx, [string]$Caminho)

        $tamanho = [int64](New-Object System.IO.FileInfo $Caminho).Length

        $inicio  = 0
        $fim     = $tamanho - 1
        $parcial = $false

        # Range: bytes=inicio-fim  (o BITS usa para continuar de onde parou)
        $range = $ctx.Request.Headers['Range']
        if ($range -and $range -match 'bytes=(\d*)-(\d*)') {
            $a = $Matches[1]; $b = $Matches[2]
            if ($a -ne '') { $inicio = [int64]$a }
            if ($b -ne '') { $fim    = [int64]$b }
            if ($fim -ge $tamanho) { $fim = $tamanho - 1 }
            if ($inicio -le $fim)  { $parcial = $true }
        }

        $qtd = $fim - $inicio + 1

        $ctx.Response.Headers['Accept-Ranges'] = 'bytes'
        $ctx.Response.ContentType     = 'application/octet-stream'
        $ctx.Response.ContentLength64 = $qtd

        if ($parcial) {
            $ctx.Response.StatusCode = 206
            $ctx.Response.Headers['Content-Range'] = "bytes $inicio-$fim/$tamanho"
        } else {
            $ctx.Response.StatusCode = 200
        }

        # HEAD: o BITS pergunta o tamanho antes de baixar. So cabecalho,
        # sem corpo. Escrever bytes aqui da erro de Content-Length.
        if ($ctx.Request.HttpMethod -eq 'HEAD') { return }

        # Leitura compartilhada: varias maquinas podem ler o mesmo arquivo juntas
        $fs = [System.IO.File]::Open($Caminho, 'Open', 'Read', 'ReadWrite')
        try {
            [void]$fs.Seek($inicio, 'Begin')
            $buf   = New-Object byte[] 1048576   # 1 MB por vez
            $resta = [int64]$qtd
            while ($resta -gt 0) {
                # Os dois lados precisam ser Int64. Sem isso, arquivo acima
                # de 2 GB estoura o Int32 e o download morre.
                $ler   = [int][Math]::Min([int64]$buf.Length, $resta)
                $lidos = $fs.Read($buf, 0, $ler)
                if ($lidos -le 0) { break }
                $ctx.Response.OutputStream.Write($buf, 0, $lidos)
                $resta -= [int64]$lidos
            }
        } finally {
            $fs.Dispose()
        }
    }

    $caminho = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    $hora    = Get-Date -Format 'HH:mm:ss'
    $de      = $ctx.Request.RemoteEndPoint.Address

    try {
        if ($caminho -eq '/catalogo.json') {
            Log "  [$hora] catalogo.json  ->  $de"
            Responder-Texto $ctx $catJson 'application/json; charset=utf-8'
        }
        elseif ($caminho -eq '/versao.txt') {
            Responder-Texto $ctx '1.0.0-local'
        }
        elseif ($caminho -eq '/' -or $caminho -eq '/index.html') {
            Responder-Texto $ctx $textoRaiz
        }
        elseif ($caminho -like '/img/*') {
            $rel  = $caminho.Substring(5) -replace '/', '\'
            $alvo = [System.IO.Path]::GetFullPath((Join-Path $Pasta $rel))

            # Impede sair da pasta servida
            if (-not $alvo.StartsWith($Pasta, [StringComparison]::OrdinalIgnoreCase)) {
                Responder-Texto $ctx 'Caminho invalido' 'text/plain' 403
            }
            elseif (Test-Path $alvo -PathType Leaf) {
                $mb   = [math]::Round((Get-Item $alvo).Length / 1MB)
                $head = ($ctx.Request.HttpMethod -eq 'HEAD')

                if (-not $head) {
                    Log ("  [$hora] {0} ({1} MB)  ->  {2}" -f $rel, $mb, $de)
                }
                Responder-Arquivo $ctx $alvo
                if (-not $head) {
                    Log ("  [{0}] concluido: {1}  ->  {2}" -f (Get-Date -Format 'HH:mm:ss'), $rel, $de)
                }
            }
            else {
                Log "  [$hora] 404  $rel  ->  $de"
                Responder-Texto $ctx 'Arquivo nao encontrado' 'text/plain' 404
            }
        }
        else {
            Responder-Texto $ctx 'Nao encontrado' 'text/plain' 404
        }
    }
    catch {
        # Cliente desconectou no meio do download: normal, nao e erro
        if ($_.Exception.Message -notmatch 'foi anulad|was aborted|closed|forcibly|interrompid') {
            Log "  [$hora] erro ($de): $($_.Exception.Message)"
        }
    }
    finally {
        try { $ctx.Response.OutputStream.Close() } catch {}
    }
}

# ------------------------------------------------------------ pool

$textoRaiz = "Myboot - servidor local`n`nImagens:`n" +
             ((@($catalogo.imagens) | ForEach-Object { "  - $($_.id)" }) -join "`n") + "`n"

$pool = [runspacefactory]::CreateRunspacePool(1, $Simultaneos)
$pool.Open()

$emAndamento = New-Object System.Collections.ArrayList

try {
    while ($listener.IsListening) {

        $ctx = $listener.GetContext()

        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript($Atendente).
                  AddArgument($ctx).
                  AddArgument($Pasta).
                  AddArgument($catJson).
                  AddArgument($textoRaiz)

        [void]$emAndamento.Add([pscustomobject]@{
            PS     = $ps
            Handle = $ps.BeginInvoke()
        })

        # Recolhe os que ja terminaram
        for ($k = $emAndamento.Count - 1; $k -ge 0; $k--) {
            $t = $emAndamento[$k]
            if ($t.Handle.IsCompleted) {
                try { [void]$t.PS.EndInvoke($t.Handle) } catch {}
                $t.PS.Dispose()
                $emAndamento.RemoveAt($k)
            }
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    foreach ($t in $emAndamento) { try { $t.PS.Dispose() } catch {} }
    $pool.Close(); $pool.Dispose()
    Write-Host ''
    Write-Host '  Servidor encerrado.' -ForegroundColor DarkGray
    Write-Host ''
}
