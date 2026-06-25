-- Bootstrap recall.reminders schema on the Understood Supabase project.
-- Mirrors Re_Call migrations; seeded_from_template_id is text-only (no FK) until reminder_templates exists.

create schema if not exists recall;

create table if not exists recall.reminders (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null default auth.uid(),
  title                   text not null default '',
  notes                   text not null default '',
  url                     text not null default '',
  image_path              text,
  due_date                date,
  due_time                time,
  urgent                  boolean not null default false,
  repeat_rule             text not null default 'none',
  early_reminder          text not null default 'none',
  list_name               text not null default 'Reminders',
  flag                    boolean not null default false,
  priority                text not null default 'none',
  location_name           text not null default '',
  when_messaging_person   text not null default '',
  kind                    text not null default 'reminder',
  end_time                time,
  when_i_am               text not null default '',
  outcome                 text not null default '',
  effort                  text not null default 'none',
  energy                  text not null default 'none',
  context                 text not null default 'none',
  defer_date              date,
  waiting_on              text not null default '',
  pinned                  boolean not null default false,
  up_next_order           integer,
  seeded_from_template_id text,
  status                  text not null default 'active',
  completed_at            timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  constraint reminders_status_check   check (status in ('active','completed','deleted')),
  constraint reminders_priority_check check (priority in ('none','low','medium','high')),
  constraint reminders_repeat_check   check (repeat_rule in ('none','daily','weekdays','weekly','monthly','yearly')),
  constraint reminders_early_check    check (early_reminder in ('none','5m','10m','30m','1h','1d')),
  constraint reminders_kind_check     check (kind in ('reminder','action','event'))
);

create index if not exists reminders_user_status_idx on recall.reminders (user_id, status, created_at desc);

create or replace function recall.set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql security definer set search_path = recall, public;

drop trigger if exists reminders_set_updated_at on recall.reminders;
create trigger reminders_set_updated_at
  before update on recall.reminders
  for each row execute function recall.set_updated_at();

create table if not exists recall.reminder_tags (
  reminder_id uuid not null references recall.reminders(id) on delete cascade,
  tag         text not null,
  primary key (reminder_id, tag)
);

create table if not exists recall.reminder_subtasks (
  id          uuid primary key default gen_random_uuid(),
  reminder_id uuid not null references recall.reminders(id) on delete cascade,
  title       text not null default '',
  done        boolean not null default false,
  position    integer not null default 0
);

alter table recall.reminders         enable row level security;
alter table recall.reminder_tags     enable row level security;
alter table recall.reminder_subtasks enable row level security;

drop policy if exists reminders_own_rows on recall.reminders;
create policy reminders_own_rows on recall.reminders
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists reminder_tags_own_rows on recall.reminder_tags;
create policy reminder_tags_own_rows on recall.reminder_tags
  for all to authenticated
  using (exists (
    select 1 from recall.reminders r
    where r.id = reminder_id and r.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from recall.reminders r
    where r.id = reminder_id and r.user_id = (select auth.uid())
  ));

drop policy if exists reminder_subtasks_own_rows on recall.reminder_subtasks;
create policy reminder_subtasks_own_rows on recall.reminder_subtasks
  for all to authenticated
  using (exists (
    select 1 from recall.reminders r
    where r.id = reminder_id and r.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from recall.reminders r
    where r.id = reminder_id and r.user_id = (select auth.uid())
  ));

grant usage on schema recall to authenticated, service_role;
grant all on all tables in schema recall to authenticated, service_role;
grant all on all sequences in schema recall to authenticated, service_role;

alter role authenticator set pgrst.db_schemas = 'public, graphql_public, recall';
notify pgrst, 'reload config';
notify pgrst, 'reload schema';

insert into storage.buckets (id, name, public)
values ('reminder-images', 'reminder-images', false)
on conflict (id) do nothing;
