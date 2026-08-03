<#
    gerar-entrada-catalogo.ps1
    ---------------------------------------------------------------
    Le a pasta com os arquivos de uma imagem e imprime o bloco JSON
    pronto para colar dentro de "imagens" no catalogo.json.

    Faz a soma dos bytes e monta a lista de partes na ordem certa,
    que e onde mais se erra na mao.

    Como usar (PowerShell na pasta da imagem):

      .\gerar-entrada-catalogo.ps1 -Pasta "D:\imagens\pc114sp-v15" `
                                   -Id "pc114sp-win11-v15" `
                                   -Nome "Windows 11 Pro 24H2 - Escolar V15" `
                                   -Descricao "PC114SP - MLSE03, MLSE13, SAX05"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Pasta,
    [Parameter(Mandatory)][string]$Id,
    [Parameter(Mandatory)][string]$Nome,
    [string]$Descricao = '',
    [int]$Indice = 1,

    # Nome da pasta dentro do bucket R2. Por padrao usa o Id.
    [string]$PastaRemota = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Pasta)) {
    Write-Host "Pasta nao encontrada: $Pasta" -ForegroundColor Red
    exit 1
}

if (-not $PastaRemota) { $PastaRemota = $Id }
$PastaRemota = $PastaRemota.TrimEnd('/')

# ---------------------------------------------------------------- coleta
$todos = Get-ChildItem -Path $Pasta -File -Recurse

$bootWim = $todos | Where-Object { $_.Name -ieq 'boot.wim' } | Select-Object -First 1
$bootSdi = $todos | Where-Object { $_.Name -ieq 'boot.sdi' } | Select-Object -First 1
$unatt   = $todos | Where-Object { $_.Name -imatch '^(auto)?unattend\.xml$' } | Select-Object -First 1

# Partes da instalacao: Install.swm, Install2.swm, ... ou install.wim / install.esd
# Winre.wim e boot.wim ficam de fora de proposito.
$partes = @($todos | Where-Object { $_.Extension -imatch '^\.(swm|wim|esd)$' -and $_.BaseName -imatch '^install' })

# Ordena pelo numero no fim do nome (Install.swm = 1, Install2.swm = 2, ...)
$partes = @($partes | Sort-Object {
    if ($_.BaseName -match '(\d+)$') { [int]$Matches[1] } else { 1 }
})

if ($partes.Count -eq 0) {
    Write-Host "Nenhum arquivo de imagem (.swm/.wim/.esd) encontrado em $Pasta" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------- relatorio
Write-Host ''
Write-Host '  ARQUIVOS ENCONTRADOS' -ForegroundColor Cyan
Write-Host '  --------------------------------------------------------'

function Mostrar($rotulo, $item) {
    if ($item) {
        $gb = [math]::Round($item.Length / 1GB, 2)
        Write-Host ("  {0,-22} {1,-26} {2,8} GB" -f $rotulo, $item.Name, $gb)
    } else {
        Write-Host ("  {0,-22} (nao encontrado)" -f $rotulo) -ForegroundColor DarkYellow
    }
}

Mostrar 'Ambiente de boot'  $bootWim
Mostrar 'boot.sdi'          $bootSdi
foreach ($p in $partes) { Mostrar 'Parte da imagem' $p }
if ($unatt) { Mostrar 'Instalacao automatica' $unatt }

if (-not $bootWim) {
    Write-Host ''
    Write-Host '  AVISO: sem boot.wim o sistema nao consegue montar o ambiente de boot.' -ForegroundColor Yellow
}

# ---------------------------------------------------------------- total
$paraSomar = @($partes)
if ($bootWim) { $paraSomar += $bootWim }
if ($bootSdi) { $paraSomar += $bootSdi }
if ($unatt)   { $paraSomar += $unatt }

$total = ($paraSomar | Measure-Object -Property Length -Sum).Sum

Write-Host '  --------------------------------------------------------'
Write-Host ("  TOTAL{0,42:N2} GB" -f ($total / 1GB)) -ForegroundColor Green
Write-Host ("  tamanhoBytes = {0}" -f $total) -ForegroundColor Green
Write-Host ''

# ---------------------------------------------------------------- json
$listaPartes = ($partes | ForEach-Object {
    '        "{0}/{1}"' -f $PastaRemota, $_.Name
}) -join ",`n"

$linhaBootWim = if ($bootWim) { '"{0}/{1}"' -f $PastaRemota, $bootWim.Name } else { '""' }
$linhaBootSdi = if ($bootSdi) { '"{0}/{1}"' -f $PastaRemota, $bootSdi.Name } else { '""' }
$linhaUnatt   = if ($unatt)   { '"{0}/{1}"' -f $PastaRemota, $unatt.Name }   else { '""' }

# Escapa aspas e barras invertidas, para nao quebrar o JSON
function EscJson($t) { if ($null -eq $t) { return '' } ($t -replace '\\','\\' -replace '"','\"') }

$IdEsc   = EscJson $Id
$NomeEsc = EscJson $Nome
$DescEsc = EscJson $Descricao

$json = @"
    {
      "id": "$IdEsc",
      "nome": "$NomeEsc",
      "descricao": "$DescEsc",
      "indice": $Indice,
      "tamanhoBytes": $total,

      "bootWim": $linhaBootWim,
      "bootSdi": $linhaBootSdi,

      "arquivos": [
$listaPartes
      ],

      "unattend": $linhaUnatt
    }
"@

Write-Host '  COLE ISTO DENTRO DE "imagens" NO catalogo.json' -ForegroundColor Cyan
Write-Host '  (se ja houver outra imagem, ponha uma virgula antes)'
Write-Host '  --------------------------------------------------------'
Write-Host ''
Write-Host $json
Write-Host ''

# Tambem salva num arquivo, para nao depender de copiar do terminal
$saida = Join-Path $Pasta ("entrada-catalogo-$Id.json")
$json | Out-File -FilePath $saida -Encoding UTF8
Write-Host "  Salvo tambem em: $saida" -ForegroundColor DarkGray
Write-Host ''
Write-Host "  Nao esqueca: no R2, os arquivos precisam ficar na pasta '$PastaRemota/'" -ForegroundColor Yellow
Write-Host ''
