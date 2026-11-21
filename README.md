# Pianomaps — versão com migração de contas, Google e Apple

## O que mudou
- **As contas antigas NÃO são apagadas.** Email, nome de utilizador, descrição e foto de perfil ficam como estão.
  Os pianos, avaliações e locais visitados antigos são copiados para o sistema novo (pianos antigos pendentes passam a pianos normais, vermelhos até 10 contas os confirmarem).
- **Migração de conta antiga:** na primeira vez que uma conta antiga entra, aparece um ecrã a pedir uma **palavra-passe nova** (mínimo 8 caracteres). Só depois se pode usar o site. A palavra-passe antiga continua a servir para entrar nessa primeira vez.
- **Criar conta / entrar com Google e Apple.** Os botões aparecem sozinhos assim que ativares cada um no Supabase (passos abaixo). Quem entrar com Google ou Apple usando o mesmo email de uma conta antiga fica ligado a essa conta.
- Contas novas (email, Google ou Apple) já nascem migradas.

## Passo 1 — Base de dados (obrigatório)
Supabase → **SQL Editor → New query** → cola o conteúdo de `supabase-migracao.sql` → **Run**.
Seguro: não apaga contas. Podes voltar a corrê-lo sem duplicar nada. **Não uses os ficheiros `supabase-1-limpar.sql` / `supabase-2-criar.sql` das versões anteriores** (o primeiro apaga as contas).
As tabelas antigas ficam guardadas como cópia de segurança (fechadas à API); podes apagá-las quando tiveres a certeza de que está tudo bem.

## Passo 2 — Autenticação (Supabase → Authentication)
- **Sign In / Providers → Email → desliga "Confirm email"** (senão o Supabase só envia uns poucos emails por hora).
- **URL Configuration:** *Site URL* e *Redirect URLs* = `https://topsbusinesspt-lab.github.io/pianomaps/`

## Passo 3 — Google (grátis)
1. https://console.cloud.google.com → cria um projeto.
2. **APIs e serviços → Ecrã de consentimento OAuth**: tipo *Externo*, nome *Pianomaps*, o teu email. Em *Domínios autorizados* acrescenta `supabase.co`. No fim **publica a app** (senão só as pessoas da lista de teste conseguem entrar).
3. **Credenciais → Criar credenciais → ID de cliente OAuth → Aplicação Web**:
   - *Origens JavaScript autorizadas:* `https://topsbusinesspt-lab.github.io`
   - *URIs de redirecionamento autorizados:* `https://oonhxwluuiujuugcqgym.supabase.co/auth/v1/callback`
4. Copia o **ID de cliente** e o **Segredo do cliente**.
5. Supabase → **Authentication → Sign In / Providers → Google** → liga → cola os dois → **Save**.
O botão "Continuar com o Google" aparece no site em poucos minutos.

## Passo 4 — Apple (precisa de conta Apple Developer paga, 99 USD/ano)
1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles**.
2. **Identifiers → App IDs**: cria um App ID e ativa *Sign in with Apple*.
3. **Identifiers → Services IDs**: cria um (por exemplo `com.pianomaps.web`), ativa *Sign in with Apple* → **Configure**:
   - *Primary App ID:* o do passo anterior
   - *Domains:* `oonhxwluuiujuugcqgym.supabase.co`
   - *Return URLs:* `https://oonhxwluuiujuugcqgym.supabase.co/auth/v1/callback`
4. **Keys**: cria uma chave com *Sign in with Apple*, descarrega o ficheiro `.p8` (só dá para descarregar uma vez!) e anota o **Key ID**. O **Team ID** está no canto superior direito da página.
5. No computador, na pasta deste projeto, com o Node instalado:
   `node apple-secret.mjs TEAM_ID KEY_ID SERVICES_ID AuthKey_XXXXXXXX.p8`
   Imprime um texto comprido (o "segredo"). **Dura 6 meses**: volta a gerar e a colar antes de expirar.
6. Supabase → **Authentication → Sign In / Providers → Apple** → liga → *Client IDs* = o Services ID, *Secret Key* = o texto do passo 5 → **Save**.

## Passo 5 — Site
Descompacta o zip, entra na pasta e carrega tudo (incluindo `assets` e `icons`) no GitHub: **Add file → Upload files → Commit changes**. Abre o site numa janela anónima.

## Gerir
Sem painel de admin. Apagar um piano ou comentário: Supabase → **Table Editor** → `places` / `place_reviews`. Ver ou apagar contas: **Authentication → Users**.
Os menus do Google, da Apple e do Supabase mudam de vez em quando; se algum nome for diferente, procura o equivalente.
