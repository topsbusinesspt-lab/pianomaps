-- Pianomaps: shared pianos, confirmation votes and reviews. No accounts needed.
-- Run once: Supabase > SQL Editor > New query > paste everything > Run.

-- ============ TABLES (anonymous: each device has a random id) ============
create table if not exists places(
  id uuid primary key,
  name text not null check (char_length(name) between 1 and 80),
  description text check (char_length(description) <= 300),
  photo_url text,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  creator text not null check (char_length(creator) between 8 and 64),
  author text check (char_length(author) <= 30),
  created_at timestamptz not null default now()
);
create table if not exists place_votes(
  place_id uuid not null references places(id) on delete cascade,
  voter text not null check (char_length(voter) between 8 and 64),
  yes boolean not null,
  created_at timestamptz not null default now(),
  primary key (place_id, voter)                 -- one vote per device per piano
);
create table if not exists place_reviews(
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references places(id) on delete cascade,
  voter text not null check (char_length(voter) between 8 and 64),
  author text check (char_length(author) <= 30),
  rating int not null check (rating between 1 and 5),
  text text check (char_length(text) <= 400),
  created_at timestamptz not null default now(),
  unique (place_id, voter)
);

-- the person who added a piano cannot confirm it
create or replace function public.block_self_vote() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from places where id = new.place_id and creator = new.voter) then
    raise exception 'own_piano';
  end if;
  return new;
end $$;
drop trigger if exists block_self_vote on place_votes;
create trigger block_self_vote before insert on place_votes for each row execute function public.block_self_vote();

-- ============ SECURITY ============
-- Nobody can read the base tables directly (that would expose device ids). Everyone reads the views below.
alter table places        enable row level security;
alter table place_votes   enable row level security;
alter table place_reviews enable row level security;
drop policy if exists "add piano"  on places;        create policy "add piano"  on places        for insert to anon, authenticated with check (true);
drop policy if exists "add vote"   on place_votes;   create policy "add vote"   on place_votes   for insert to anon, authenticated with check (true);
drop policy if exists "add review" on place_reviews; create policy "add review" on place_reviews for insert to anon, authenticated with check (true);

create or replace view public.places_public as
  select id, name, description, photo_url, lat, lng, author, created_at from places;
create or replace view public.place_stats as
  select p.id as place_id,
         count(v.*) filter (where v.yes) as yes,
         count(v.*) filter (where not v.yes) as no
  from places p left join place_votes v on v.place_id = p.id group by p.id;
create or replace view public.reviews_public as
  select id, place_id, author, rating, text, created_at from place_reviews;

grant usage on schema public to anon, authenticated;
grant select on public.places_public, public.place_stats, public.reviews_public to anon, authenticated;
grant insert on places, place_votes, place_reviews to anon, authenticated;

-- people can delete their own piano / review from the device that created it
create or replace function public.delete_my_place(p_id uuid, p_voter text) returns void language sql security definer set search_path = public as
$$ delete from places where id = p_id and creator = p_voter $$;
create or replace function public.delete_my_review(p_place uuid, p_voter text) returns void language sql security definer set search_path = public as
$$ delete from place_reviews where place_id = p_place and voter = p_voter $$;
grant execute on function public.delete_my_place(uuid, text), public.delete_my_review(uuid, text) to anon, authenticated;

-- ============ PHOTOS ============
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('photos', 'photos', true, 2097152, array['image/jpeg'])
  on conflict (id) do update set public = true, file_size_limit = 2097152, allowed_mime_types = array['image/jpeg'];
drop policy if exists "photos anon read"   on storage.objects;
drop policy if exists "photos anon upload" on storage.objects;
create policy "photos anon read"   on storage.objects for select using (bucket_id = 'photos');
create policy "photos anon upload" on storage.objects for insert to anon, authenticated with check (bucket_id = 'photos');
