# Pianomaps

Pianos públicos em todo o mundo. Qualquer pessoa adiciona um piano e ele aparece logo no mapa para toda a gente.

## Como funciona
- Um piano novo aparece para todos os dispositivos com o pino **vermelho** (ainda não confirmado).
- Quem clicar no pino vê a informação e a pergunta **"Isto é verdade?"** (Sim / Não).
- Quando **10 pessoas diferentes** respondem **Sim**, o pino fica **verde** e a pergunta desaparece.
- Respostas "Não" não contam para confirmar. Quem adicionou o piano não o pode confirmar. Cada dispositivo só responde uma vez por piano.
- Cada piano tem fotos, avaliações e comentários partilhados por todos.
- O perfil (nome, foto, descrição) e a lista de locais visitados ficam guardados no próprio dispositivo.
- Inglês / Português, tema claro / escuro / sistema, e instala-se como app no Chrome.

## Pôr online (uma vez)
1. **Supabase:** abre o projeto → **SQL Editor** → **New query** → cola o conteúdo de `supabase.sql` → **Run**. (O `config.js` já tem o teu URL e a tua chave.)
2. **GitHub:** descompacta o zip, entra na pasta e carrega todos os ficheiros e pastas no repositório (**Add file → Upload files**). Se já existirem ficheiros antigos com o mesmo nome, são substituídos. Podes apagar o `pianos.json`, se existir.
3. **Settings → Pages → Deploy from a branch → `main` / root → Save.**

## Gerir pianos (admin)
Não há login. Para apagar um piano ou comentário mal feito, vai ao Supabase → **Table Editor** → tabelas `places`, `place_reviews` ou `place_votes` e apaga a linha.

## Limites a ter em conta
Não há contas, por isso "10 pessoas diferentes" significa 10 dispositivos/navegadores diferentes. Alguém determinado pode contornar isto (por exemplo, limpar os dados do navegador e votar de novo). Para uso normal chega; se aparecer spam, é preciso passar para contas com login.
