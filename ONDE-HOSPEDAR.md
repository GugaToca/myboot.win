# Onde subir as imagens

O sistema baixa por BITS/WebClient, então o endereço precisa devolver **o
arquivo direto**. Google Drive, OneDrive e WeTransfer não servem: eles
devolvem uma página de confirmação, não o arquivo.

Sobram três caminhos.

---

## A conta que importa antes de escolher

Uma imagem sua tem cerca de **15 GB**. Os planos gratuitos de nuvem param em
**10 GB**. Ou seja: nenhuma nuvem hospeda uma imagem dessas de graça. Vai
custar alguns centavos a poucos dólares por mês — ou nada, se ficar na rede
local.

---

## 1. Servidor na rede local — grátis, e o mais rápido

Para quando os PCs estão na mesma rede que você. Um PC seu vira o servidor.

**Custo:** zero.
**Velocidade:** de 1 a 10 Gbps na rede, contra os poucos Mbps da internet.
Uma imagem de 15 GB que levaria horas baixando da nuvem leva minutos.

### Como usar

Organize a pasta com uma subpasta por imagem:

```
D:\imagens\
    pc114sp-v15\
        boot.wim
        boot.sdi
        Install.swm
        Install2.swm
    dell-3420-v3\
        boot.wim
        Install.swm
```

Abra o **PowerShell como administrador** e rode:

```powershell
cd "C:\Users\gusta\OneDrive\Área de Trabalho\myBoot_win\ferramentas"
.\servidor-local.ps1 -Pasta "D:\imagens" -AbrirFirewall
```

Ele varre a pasta, monta o catálogo sozinho e mostra o endereço, algo como
`http://192.168.1.50:8080`.

No PC que vai ser formatado: botão roxo **"1. Importar minha imagem"** →
**SIM** → digite esse endereço.

Deixe a janela aberta enquanto estiver formatando. `Ctrl+C` encerra.

### Limitações

- Só funciona na mesma rede.
- O PC servidor tem que ficar ligado.
- Wi-Fi fraco atrapalha; cabo de rede é bem melhor para 15 GB.
- Em rede de escola/empresa, o firewall pode bloquear a porta. O
  `-AbrirFirewall` resolve no Windows, mas switch gerenciado com isolamento
  de portas é conversa com quem cuida da rede.

---

## 2. Backblaze B2 — nuvem sem cartão

Para atender em lugares diferentes. **Não pede cartão** para criar a conta.

**Grátis:** 10 GB de armazenamento, sem prazo. Download grátis até 3x o que
você tem guardado por mês (10 GB guardados = 30 GB de download por mês).

**Passando disso:** armazenamento a US$ 6 por TB/mês (15 GB ≈ US$ 0,09/mês) e
download a US$ 0,01 por GB. Cada formatação baixando 15 GB custa uns US$ 0,15.

Na prática: guardar uma imagem de 15 GB custa centavos, mas cada formatação
tem um custinho de download.

### Como usar

1. Conta em <https://www.backblaze.com/sign-up/cloud-storage>
2. **B2 Cloud Storage** → **Create a Bucket** → deixe **Public**
3. **Application Keys** → **Add a New Application Key** com acesso ao bucket
4. Suba com **rclone** (provider `Backblaze B2`) — o passo a passo do rclone
   está no `IMAGENS-R2.md`, muda só o provider e o endpoint
5. A URL pública fica no formato
   `https://f000.backblazeb2.com/file/SEU-BUCKET/`
   — esse é o `urlBase` do `catalogo.json`

---

## 3. Cloudflare R2 — melhor se o volume crescer

**Download não é cobrado, nunca.** É a diferença que pesa: se você formata
muita máquina, o custo fica só no armazenamento (US$ 0,015 por GB/mês, ou uns
US$ 0,23/mês por uma imagem de 15 GB).

O porém: a página oficial diz que dá para começar sem cartão, mas há relatos
de que a ativação do R2 pede cartão mesmo no plano gratuito. Se você mudar de
ideia sobre o cartão, o passo a passo completo está no `IMAGENS-R2.md`.

---

## Resumindo

| | Custo | Serve para | Velocidade |
|---|---|---|---|
| **Rede local** | zero | mesma rede | altíssima |
| **Backblaze B2** | centavos/mês + US$ 0,01 por GB baixado | qualquer lugar | a da internet |
| **Cloudflare R2** | ~US$ 0,23/mês, download grátis | qualquer lugar | a da internet |

Para os seus dois cenários, o arranjo que faz sentido é **rede local no dia a
dia** e **B2 como reserva** para quando estiver fora. As duas coisas convivem:
o servidor local serve o próprio `catalogo.json`, então é só digitar um
endereço ou outro no momento de importar.

---

## Fontes

- [Cloudflare R2 — Pricing](https://developers.cloudflare.com/r2/pricing/)
- [Cloudflare R2 — página do produto](https://www.cloudflare.com/products/r2/)
- [Free — credit card required (Cloudflare Community)](https://community.cloudflare.com/t/free-credit-card-required/399917)
- [Backblaze B2 Cloud Storage — 10 GB grátis](https://freetier.co/directory/products/backblaze-b2-cloud-storage)
- [Backblaze — Low Cost, High Performance S3 Compatible Object Storage](https://www.backblaze.com/cloud-storage)
