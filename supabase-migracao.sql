-- PIANOMAPS: MIGRAÇÃO + CRIAÇÃO DAS TABELAS
-- Seguro: NÃO apaga contas. Mantém as contas, nomes de utilizador, fotos de perfil e descrições que já existem
-- e copia os pianos, avaliações e locais visitados antigos para o sistema novo.
-- Podes voltar a correr este ficheiro sempre que quiseres (nada é copiado ou apagado duas vezes).
-- Como usar: Supabase > SQL Editor > New query > cola tudo > Run.

create or replace function public.norm(t text) returns text language sql immutable as
$$ select translate(lower(trim(t)),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc') $$;

-- registo do que já foi migrado (ninguém acede a isto pela API)
create table if not exists public.migration_log(step text primary key, done_at timestamptz not null default now());
alter table public.migration_log enable row level security;

-- ============ 1) tirar regras antigas (versão com admin / votos por dispositivo). As contas e as tabelas ficam. ============
drop view if exists public.place_stats, public.places_public, public.reviews_public cascade;
do $$ begin
  if to_regclass('public.profiles') is not null then
    execute 'drop trigger if exists guard_profile on public.profiles';
  end if;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.guard_profile() cascade;
drop function if exists public.is_admin() cascade;
drop function if exists public.owner_email() cascade;
drop function if exists public.is_owner(text) cascade;
drop function if exists public.delete_my_place(uuid, text) cascade;
drop function if exists public.delete_my_review(uuid, text) cascade;

-- ============ 2) pôr de lado tabelas com estrutura antiga (ficam guardadas como "legacy_...") ============
do $$ begin
  -- versão com votos por dispositivo (sem contas)
  if to_regclass('public.places') is not null and not exists (
       select 1 from information_schema.columns where table_schema='public' and table_name='places' and column_name='user_id') then
    if to_regclass('public.place_votes') is not null then
      execute 'drop trigger if exists block_self_vote on public.place_votes';
      execute 'alter table public.place_votes rename to legacy_votes_device';
    end if;
    if to_regclass('public.place_reviews') is not null then execute 'alter table public.place_reviews rename to legacy_reviews_device'; end if;
    execute 'alter table public.places rename to legacy_places_device';
  end if;
  -- versão com contas e administrador: a tabela "visits" tinha a coluna piano_id
  if to_regclass('public.visits') is not null and exists (
       select 1 from information_schema.columns where table_schema='public' and table_name='visits' and column_name='piano_id') then
    execute 'alter table public.visits rename to legacy_visits';
  end if;
end $$;

-- ============ 3) PERFIS (mantém os que já existem) ============
create table if not exists public.profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null check (char_length(username) between 3 and 30),
  username_key text generated always as (public.norm(username)) stored unique,
  bio text check (char_length(bio) <= 200),
  avatar_url text,
  show_visited boolean not null default true,
  created_at timestamptz not null default now(),
  migrated_at timestamptz                      -- vazio = conta antiga que ainda tem de definir uma palavra-passe nova
);
alter table public.profiles
  add column if not exists bio text,
  add column if not exists avatar_url text,
  add column if not exists show_visited boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists migrated_at timestamptz;

-- perfil automático para contas novas (email, Google ou Apple). As contas novas já nascem "migradas".
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
declare base text; nm text; n int := 0;
begin
  base := left(coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
                        nullif(split_part(coalesce(new.email, ''), '@', 1), ''), 'user'), 24);
  if char_length(base) < 3 then base := base || 'user'; end if;
  nm := base;
  loop
    begin
      insert into profiles(id, username, migrated_at) values (new.id, nm, now());
      exit;
    exception when unique_violation then
      n := n + 1; nm := left(base, 24) || n::text;
      if n > 50 then raise; end if;
    end;
  end loop;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- contas antigas que ficaram sem perfil: criar um (migrated_at fica vazio, vão ter de definir palavra-passe)
do $$ declare u record; base text; nm text; n int;
begin
  for u in select id, email, raw_user_meta_data from auth.users x where not exists (select 1 from public.profiles p where p.id = x.id) loop
    base := left(coalesce(nullif(trim(u.raw_user_meta_data->>'name'), ''), nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
                          nullif(split_part(coalesce(u.email, ''), '@', 1), ''), 'user'), 24);
    if char_length(base) < 3 then base := base || 'user'; end if;
    nm := base; n := 0;
    loop
      begin
        insert into public.profiles(id, username) values (u.id, nm);
        exit;
      exception when unique_violation then
        n := n + 1; nm := left(base, 24) || n::text;
        if n > 50 then raise; end if;
      end;
    end loop;
  end loop;
end $$;

-- ============ 4) PIANOS, VOTOS, AVALIAÇÕES, VISITADOS (sistema novo) ============
create table if not exists public.places(
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null default auth.uid(),
  name text not null check (char_length(name) between 1 and 80),
  description text check (char_length(description) <= 300),
  photo_url text,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  created_at timestamptz not null default now()
);
create table if not exists public.place_votes(
  place_id uuid not null references public.places(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  yes boolean not null,
  created_at timestamptz not null default now(),
  primary key (place_id, user_id)
);
create table if not exists public.place_reviews(
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  rating int not null check (rating between 1 and 5),
  text text check (char_length(text) <= 400),
  created_at timestamptz not null default now(),
  unique (place_id, user_id)
);
create table if not exists public.visits(
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  place_id uuid not null references public.places(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, place_id)
);

create or replace function public.block_self_vote() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from places where id = new.place_id and user_id = new.user_id) then
    raise exception 'own_piano';
  end if;
  return new;
end $$;
drop trigger if exists block_self_vote on public.place_votes;
create trigger block_self_vote before insert on public.place_votes for each row execute function public.block_self_vote();

create or replace view public.place_stats as
  select p.id as place_id,
         count(v.*) filter (where v.yes)::int as yes,
         count(v.*) filter (where not v.yes)::int as no
  from public.places p left join public.place_votes v on v.place_id = p.id group by p.id;

-- ============ 5) COPIAR OS DADOS ANTIGOS (uma só vez) ============
do $$ begin
  -- pianos da versão com contas (aprovados e pendentes: passam a ser pianos normais, vermelhos até 10 contas confirmarem)
  if to_regclass('public.pianos') is not null and not exists (select 1 from public.migration_log where step = 'v1_pianos') then
    insert into public.places(id, user_id, name, description, photo_url, lat, lng, created_at)
      select p.id, (select u.id from auth.users u where u.id = p.user_id), p.name, p.description, p.photo_url, p.lat, p.lng, p.created_at
      from public.pianos p on conflict (id) do nothing;
    insert into public.migration_log(step) values ('v1_pianos');
  end if;
  if to_regclass('public.reviews') is not null and not exists (select 1 from public.migration_log where step = 'v1_reviews') then
    insert into public.place_reviews(id, place_id, user_id, rating, text, created_at)
      select r.id, r.piano_id, r.user_id, r.rating, r.text, r.created_at from public.reviews r
      where exists (select 1 from public.places p where p.id = r.piano_id) and exists (select 1 from auth.users u where u.id = r.user_id)
      on conflict do nothing;
    insert into public.migration_log(step) values ('v1_reviews');
  end if;
  if to_regclass('public.legacy_visits') is not null and not exists (select 1 from public.migration_log where step = 'v1_visits') then
    insert into public.visits(user_id, place_id, created_at)
      select v.user_id, v.piano_id, v.created_at from public.legacy_visits v
      where exists (select 1 from public.places p where p.id = v.piano_id) and exists (select 1 from auth.users u where u.id = v.user_id)
      on conflict do nothing;
    insert into public.migration_log(step) values ('v1_visits');
  end if;
  -- pianos da versão sem contas (votos por dispositivo): ficam sem dono
  if to_regclass('public.legacy_places_device') is not null and not exists (select 1 from public.migration_log where step = 'v2_places') then
    insert into public.places(id, name, description, photo_url, lat, lng, created_at)
      select id, name, description, photo_url, lat, lng, created_at from public.legacy_places_device on conflict (id) do nothing;
    insert into public.migration_log(step) values ('v2_places');
  end if;
end $$;

-- as tabelas antigas ficam guardadas como cópia de segurança, mas fechadas à API
do $$ declare t text; begin
  foreach t in array array['pianos','reviews','legacy_visits','legacy_places_device','legacy_votes_device','legacy_reviews_device'] loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I enable row level security', t);
      execute format('revoke all on table public.%I from anon, authenticated', t);
    end if;
  end loop;
end $$;

-- ============ 6) SEGURANÇA ============
alter table public.profiles      enable row level security;
alter table public.places        enable row level security;
alter table public.place_votes   enable row level security;
alter table public.place_reviews enable row level security;
alter table public.visits        enable row level security;

drop policy if exists "profiles read"       on public.profiles;
drop policy if exists "profiles insert own" on public.profiles;
drop policy if exists "profiles update own" on public.profiles;
drop policy if exists "profiles insert"     on public.profiles;
drop policy if exists "profiles update"     on public.profiles;
create policy "profiles read"   on public.profiles for select using (true);
create policy "profiles insert" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "places read"   on public.places;
drop policy if exists "places insert" on public.places;
drop policy if exists "places delete" on public.places;
create policy "places read"   on public.places for select using (true);
create policy "places insert" on public.places for insert to authenticated with check (user_id = auth.uid());
create policy "places delete" on public.places for delete to authenticated using (user_id = auth.uid());

drop policy if exists "votes read own" on public.place_votes;
drop policy if exists "votes insert"   on public.place_votes;
create policy "votes read own" on public.place_votes for select to authenticated using (user_id = auth.uid());
create policy "votes insert"   on public.place_votes for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "reviews read"   on public.place_reviews;
drop policy if exists "reviews insert" on public.place_reviews;
drop policy if exists "reviews update" on public.place_reviews;
drop policy if exists "reviews delete" on public.place_reviews;
create policy "reviews read"   on public.place_reviews for select using (true);
create policy "reviews insert" on public.place_reviews for insert to authenticated with check (user_id = auth.uid());
create policy "reviews update" on public.place_reviews for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "reviews delete" on public.place_reviews for delete to authenticated using (user_id = auth.uid());

drop policy if exists "visits read"   on public.visits;
drop policy if exists "visits insert" on public.visits;
drop policy if exists "visits delete" on public.visits;
create policy "visits read"   on public.visits for select using (
  user_id = auth.uid() or exists (select 1 from public.profiles p where p.id = visits.user_id and p.show_visited));
create policy "visits insert" on public.visits for insert to authenticated with check (user_id = auth.uid());
create policy "visits delete" on public.visits for delete to authenticated using (user_id = auth.uid());

grant usage on schema public to anon, authenticated;
grant select on public.profiles, public.places, public.place_reviews, public.visits, public.place_stats to anon, authenticated;
grant insert, update on public.profiles to authenticated;
grant insert, delete on public.places, public.visits to authenticated;
revoke all on public.place_votes from anon;
grant select, insert on public.place_votes to authenticated;
grant insert, update, delete on public.place_reviews to authenticated;

-- ============ 7) FOTOS ============
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('photos', 'photos', true, 2097152, array['image/jpeg'])
  on conflict (id) do update set public = true, file_size_limit = 2097152, allowed_mime_types = array['image/jpeg'];
drop policy if exists "photos read"       on storage.objects;
drop policy if exists "photos upload"     on storage.objects;
drop policy if exists "photos delete"     on storage.objects;
drop policy if exists "photos anon read"  on storage.objects;
drop policy if exists "photos anon upload" on storage.objects;
drop policy if exists "photos upload own" on storage.objects;
drop policy if exists "photos delete own" on storage.objects;
create policy "photos read"       on storage.objects for select using (bucket_id = 'photos');
create policy "photos upload own" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "photos delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
