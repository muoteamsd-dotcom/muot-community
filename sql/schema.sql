-- MUO Community — Supabase schema. شغّله في SQL Editor.
create extension if not exists pgcrypto;
create type content_status as enum ('draft','published','archived');

-- حقول مشتركة: id, title, slug, status, created_at, updated_at, published_at
create table news_categories (id uuid primary key default gen_random_uuid(), name text unique not null);
insert into news_categories(name) values ('أخبار'),('إعلانات'),('أنشطة'),('تغطيات');

create table news_articles (
  id uuid primary key default gen_random_uuid(), title text not null, slug text unique,
  excerpt text, body text, category text, cover_url text,
  status content_status not null default 'draft',
  created_at timestamptz default now(), updated_at timestamptz default now(), published_at timestamptz);

create table official_podcast_programs (
  id uuid primary key default gen_random_uuid(), title text not null, slug text unique,
  description text, presenter text, cover_url text,
  status content_status not null default 'draft',
  created_at timestamptz default now(), updated_at timestamptz default now(), published_at timestamptz);
create table official_podcast_seasons (
  id uuid primary key default gen_random_uuid(), program_id uuid references official_podcast_programs on delete cascade,
  number int not null, title text);
create table official_podcast_episodes (
  id uuid primary key default gen_random_uuid(), program_id uuid references official_podcast_programs on delete cascade,
  season_id uuid references official_podcast_seasons on delete set null,
  title text not null, slug text, description text, audio_url text, cover_url text, duration int,
  status content_status not null default 'draft',
  created_at timestamptz default now(), updated_at timestamptz default now(), published_at timestamptz);

create table magazine_issues (
  id uuid primary key default gen_random_uuid(), title text not null, slug text unique,
  number int, description text, cover_url text, pdf_url text,
  status content_status not null default 'draft',
  created_at timestamptz default now(), updated_at timestamptz default now(), published_at timestamptz);
create table magazine_articles (
  id uuid primary key default gen_random_uuid(), issue_id uuid references magazine_issues on delete cascade,
  title text not null, slug text, body text, category text, cover_url text,
  status content_status not null default 'draft',
  created_at timestamptz default now(), updated_at timestamptz default now(), published_at timestamptz);

create table community_podcast_programs (
  id uuid primary key default gen_random_uuid(), title text not null, slug text unique,
  description text, presenter text, producer text, category text, cover_url text,
  status content_status not null default 'draft',
  created_at timestamptz default now(), updated_at timestamptz default now(), published_at timestamptz);
create table community_podcast_episodes (
  id uuid primary key default gen_random_uuid(), program_id uuid references community_podcast_programs on delete cascade,
  title text not null, slug text, description text, audio_url text, cover_url text, duration int,
  status content_status not null default 'draft',
  created_at timestamptz default now(), updated_at timestamptz default now(), published_at timestamptz);

create table media_assets (
  id uuid primary key default gen_random_uuid(), path text not null, url text not null,
  kind text, created_at timestamptz default now());
create table platform_settings (key text primary key, value jsonb);

-- ===== الأمان: القراءة العامة للمنشور فقط، والكتابة للأدمن فقط =====
-- أنشئ مستخدم الأدمن من Authentication > Users، وعطّل التسجيل العام (Sign ups) من Authentication > Providers.
-- ثم ضع بريده هنا:
create table admin_emails (email text primary key);
insert into admin_emails values ('PUT-ADMIN-EMAIL-HERE');
create function is_admin() returns boolean language sql stable security definer as $$
  select exists (select 1 from admin_emails where email = auth.jwt()->>'email') $$;

do $$ declare t text; begin
  foreach t in array array['news_articles','official_podcast_programs','official_podcast_episodes',
    'magazine_issues','magazine_articles','community_podcast_programs','community_podcast_episodes'] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy "public read published" on %I for select using (status = ''published'' or is_admin())', t);
    execute format('create policy "admin write" on %I for all using (is_admin()) with check (is_admin())', t);
  end loop;
  foreach t in array array['news_categories','official_podcast_seasons','platform_settings','media_assets'] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy "public read" on %I for select using (true)', t);
    execute format('create policy "admin write" on %I for all using (is_admin()) with check (is_admin())', t);
  end loop;
end $$;
alter table admin_emails enable row level security; -- بلا سياسات: لا أحد يقرأها من الواجهة

-- ===== التخزين =====
insert into storage.buckets (id, name, public) values ('media','media',true) on conflict do nothing;
create policy "media public read" on storage.objects for select using (bucket_id = 'media');
create policy "media admin insert" on storage.objects for insert with check (bucket_id = 'media' and is_admin());
create policy "media admin update" on storage.objects for update using (bucket_id = 'media' and is_admin());
create policy "media admin delete" on storage.objects for delete using (bucket_id = 'media' and is_admin());
