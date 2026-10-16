-- ============================================================
-- Types
-- ============================================================

create type public.shelf_kind as enum ('want_to_read', 'currently_reading', 'read', 'custom');

-- ============================================================
-- Tables
-- ============================================================

-- One row per user: preferences.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  theme text not null default 'system' check (theme in ('system', 'light', 'dark')),
  created_at timestamptz not null default now()
);

-- Default shelves (want_to_read, currently_reading, read) plus the user's custom ones.
create table public.shelves (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 50),
  kind public.shelf_kind not null default 'custom',
  position int not null,
  created_at timestamptz not null default now(),
  unique (id, user_id)
);

-- Each user's copy of a book: edition details + their own data.
create table public.library_books (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  shelf_id uuid not null,
  ol_work_key text,

  -- Edition details (display only; identity comes from ol_work_key)
  title text not null,
  authors text[] not null default '{}',
  cover_url text,
  isbn_10 text,
  isbn_13 text,
  publisher text,
  description text,
  page_count int check (page_count > 0),
  published_year int,
  genres text[] not null default '{}',

  -- The user's data
  rating smallint check (rating between 1 and 5),
  notes text,
  started_on date,
  finished_on date,

  -- Current progress (kept in sync from progress_updates by a trigger)
  current_page int check (current_page >= 0),
  progress_percent numeric(5,2) check (progress_percent between 0 and 100),
  progress_updated_at timestamptz,

  created_at timestamptz not null default now(),

  unique (user_id, ol_work_key),
  unique (id, user_id),
  foreign key (shelf_id, user_id) references public.shelves (id, user_id) on delete restrict,
  check (finished_on >= started_on)
);

-- Append-only log of reading positions.
create table public.progress_updates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  library_book_id uuid not null,
  page int check (page >= 0),
  percent numeric(5,2) not null check (percent between 0 and 100),
  created_at timestamptz not null default now(),

  foreign key (library_book_id, user_id) references public.library_books (id, user_id) on delete cascade
);

-- One reading goal per user per year.
create table public.reading_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  year int not null,
  target int not null check (target > 0),
  created_at timestamptz not null default now(),

  unique (user_id, year)
);

-- ============================================================
-- Indexes
-- ============================================================

-- Only one shelf of each default kind per user; any number of custom shelves.
create unique index shelves_one_default_per_kind on public.shelves (user_id, kind) where kind <> 'custom';
-- No two shelves with the same name, ignoring case.
create unique index shelves_unique_name on public.shelves (user_id, lower(name));

create index library_books_user_shelf on public.library_books (user_id, shelf_id);
create index library_books_user_finished on public.library_books (user_id, finished_on);
create index progress_updates_book_time on public.progress_updates (library_book_id, created_at);
create index progress_updates_user_time on public.progress_updates (user_id, created_at);

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.profiles enable row level security;
alter table public.shelves enable row level security;
alter table public.library_books enable row level security;
alter table public.progress_updates enable row level security;
alter table public.reading_goals enable row level security;

create policy "Users can view their own profile" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "Users can update their own profile" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "Users can view their own shelves" on public.shelves
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can create custom shelves" on public.shelves
  for insert to authenticated with check ((select auth.uid()) = user_id and kind = 'custom');
create policy "Users can update their own shelves" on public.shelves
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users can delete their own custom shelves" on public.shelves
  for delete to authenticated using ((select auth.uid()) = user_id and kind = 'custom');

create policy "Users can view their own books" on public.library_books
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can add their own books" on public.library_books
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update their own books" on public.library_books
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users can delete their own books" on public.library_books
  for delete to authenticated using ((select auth.uid()) = user_id);

create policy "Users can view their own progress" on public.progress_updates
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can log their own progress" on public.progress_updates
  for insert to authenticated with check ((select auth.uid()) = user_id);

create policy "Users can view their own goals" on public.reading_goals
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can create their own goals" on public.reading_goals
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update their own goals" on public.reading_goals
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users can delete their own goals" on public.reading_goals
  for delete to authenticated using ((select auth.uid()) = user_id);

-- ============================================================
-- Functions and triggers
-- ============================================================

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id);
  insert into public.shelves (user_id, name, kind, position) values
    (new.id, 'Want to Read', 'want_to_read', 0),
    (new.id, 'Currently Reading', 'currently_reading', 1),
    (new.id, 'Read', 'read', 2);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.sync_progress()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  update public.library_books
  set current_page = new.page,
      progress_percent = new.percent,
      progress_updated_at = new.created_at
  where id = new.library_book_id;
  return new;
end;
$$;

create trigger progress_updates_sync
  after insert on public.progress_updates
  for each row execute function public.sync_progress();

create function public.set_reading_dates()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  new_kind public.shelf_kind;
begin
  select kind into new_kind from public.shelves where id = new.shelf_id;
  if new_kind = 'currently_reading' and new.started_on is null then
    new.started_on := current_date;
  elsif new_kind = 'read' and new.finished_on is null then
    new.finished_on := current_date;
  end if;
  return new;
end;
$$;

create trigger library_books_set_reading_dates
  before update of shelf_id on public.library_books
  for each row
  when (old.shelf_id is distinct from new.shelf_id)
  execute function public.set_reading_dates();

create function public.protect_default_shelves()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.kind is distinct from old.kind then
    raise exception 'A shelf''s kind cannot be changed';
  end if;
  if old.kind <> 'custom' and new.name is distinct from old.name then
    raise exception 'Default shelves cannot be renamed';
  end if;
  return new;
end;
$$;

create trigger shelves_protect_defaults
  before update on public.shelves
  for each row execute function public.protect_default_shelves();

create function public.delete_shelf(target_shelf_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  shelf public.shelves;
begin
  select * into shelf from public.shelves where id = target_shelf_id;

  if not found then
    raise exception 'Shelf not found';
  end if;
  if shelf.kind <> 'custom' then
    raise exception 'Default shelves cannot be deleted';
  end if;

  update public.library_books b
  set shelf_id = (
    select s.id
    from public.shelves s
    where s.user_id = shelf.user_id
      and s.kind = case
        when b.finished_on is not null then 'read'::public.shelf_kind
        when b.started_on is not null then 'currently_reading'::public.shelf_kind
        else 'want_to_read'::public.shelf_kind
      end
  )
  where b.shelf_id = target_shelf_id;

  delete from public.shelves where id = target_shelf_id;
end;
$$;
