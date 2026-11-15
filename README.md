# Pianomaps (versão sem Supabase)

Site 100% estático: não precisa de base de dados, contas nem configuração. Basta pôr os ficheiros no GitHub Pages.
Tem mapa com ruas e satélite, fotos, avaliações, "visitado", perfil, inglês/português, tema claro/escuro/sistema e instala-se como app.

## Pôr online (GitHub)
1. Descompacta o zip.
2. No GitHub cria um repositório público (por exemplo `pianomaps`).
3. **Add file → Upload files** e arrasta *tudo* o que está dentro da pasta (incluindo as pastas `assets` e `icons`). Commit changes.
4. **Settings → Pages → Deploy from a branch → `main` / root → Save.**
5. Passado um minuto o site está em `https://O-TEU-USER.github.io/O-REPO/`.

Não há mais nada a configurar.

## Como funcionam os pianos
- **Pianos oficiais** estão no ficheiro `pianos.json` do repositório e aparecem para toda a gente (pino preto). Só o dono do repositório os pode alterar.
- **Quem adiciona um piano** guarda-o no próprio dispositivo (pino tracejado, "Só neste dispositivo"). Avaliações, "visitado" e perfil também ficam no dispositivo.
- **Verificação:** no piano, o botão **Enviar para verificação** abre um pedido (Issue) já preenchido no teu repositório.
  Para publicar: abre o `pianos.json` no GitHub (lápis ✏️), cola a linha que vem no pedido dentro dos `[ ]` e confirma o commit.
  A partir daí o piano aparece para todos e a cópia local desaparece sozinha. Para recusar, fecha o pedido.
  Se o piano tiver foto, a pessoa pode arrastá-la para o pedido; para a mostrares no site, mete o ficheiro numa pasta `photos/` e acrescenta `"photo_url": "photos/nome.jpg"` ao piano.
- **Avaliações oficiais** (opcional): podes acrescentar `"reviews":[{"name":"Rita","rating":5,"text":"Lindo","date":"2026-05-01"}]` a um piano no `pianos.json`.
- **Cópia de segurança:** Menu → Cópia de segurança exporta/importa os dados do dispositivo (serve também para os passar para outro telemóvel).

## Exemplo de piano no pianos.json
```json
[
  { "id": "gare-oriente", "name": "Gare do Oriente", "description": "Piano vertical, bem afinado", "lat": 38.7677, "lng": -9.0993, "added_by": "Francisco" }
]
```

## O que esta versão NÃO tem (precisa de servidor)
Contas partilhadas entre pessoas, nomes de utilizador únicos, o menu de admin online e avaliações de todos a aparecerem para todos em tempo real. A verificação é feita por ti, a publicar no `pianos.json`.

## Instalar como app
No Chrome aparece o botão **Instalar app** (e o ícone na barra de endereço). No iPhone: Safari → Partilhar → Adicionar ao ecrã principal.
