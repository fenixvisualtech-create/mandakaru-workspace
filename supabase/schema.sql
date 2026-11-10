-- Mandakaru Workspace 2.1 • Um único administrador com escrita; convidados somente leitura.
-- Modelo para UM estúdio privado; não é multi-tenant.
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 email text not null unique,
 display_name text not null default '',
 created_at timestamptz not null default now()
);
create table if not exists public.members (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 role text not null check(role in ('admin','head','member','viewer')),
 department text not null default 'A definir',
 created_at timestamptz not null default now()
);
-- Esta fase do projeto permite somente UMA conta admin.
create unique index if not exists members_one_admin on public.members ((role)) where role='admin';
create table if not exists public.records (
 id uuid primary key default gen_random_uuid(),
 kind text not null check(kind in ('hardware','task','project')),
 data jsonb not null default '{}',
 updated_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.audit_log (
 id bigint generated always as identity primary key,
 record_id uuid,
 kind text,
 operation text not null,
 actor uuid,
 old_data jsonb,
 new_data jsonb,
 changed_at timestamptz not null default now()
);
create or replace function public.on_auth_user_created() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id,email,display_name) values(new.id,lower(new.email),coalesce(new.raw_user_meta_data->>'display_name',''))
 on conflict(id) do update set email=excluded.email;
 return new;
end;$$;
drop trigger if exists auth_user_to_profile on auth.users;
create trigger auth_user_to_profile after insert on auth.users for each row execute procedure public.on_auth_user_created();
-- Caso existam usuários criados ANTES da instalação do schema:
insert into public.profiles(id,email,display_name)
select id,lower(email),coalesce(raw_user_meta_data->>'display_name','') from auth.users
where email is not null on conflict(id) do nothing;
-- As funções de autorização usam security definer para não recursarem na RLS de members.
create or replace function public.my_role() returns text language sql stable security definer set search_path='' as $$
 select role from public.members where user_id=(select auth.uid()) limit 1
$$;
create or replace function public.is_member() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members where user_id=(select auth.uid()))
$$;
create or replace function public.may_edit() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members where user_id=(select auth.uid()) and role='admin')
$$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members where user_id=(select auth.uid()) and role='admin')
$$;
revoke all on function public.my_role() from public,anon;
revoke all on function public.is_member() from public,anon;
revoke all on function public.may_edit() from public,anon;
revoke all on function public.is_admin() from public,anon;
grant execute on function public.my_role(),public.is_member(),public.may_edit(),public.is_admin() to authenticated;
alter table public.profiles enable row level security;
alter table public.members enable row level security;
alter table public.records enable row level security;
alter table public.audit_log enable row level security;
revoke all on public.profiles,public.members,public.records,public.audit_log from anon,authenticated;
grant select on public.profiles to authenticated;
grant select,insert,update,delete on public.members to authenticated;
grant select,insert,update,delete on public.records to authenticated;
grant select on public.audit_log to authenticated;
drop policy if exists profile_view on public.profiles;
create policy profile_view on public.profiles for select to authenticated using((select public.is_member()) or id=(select auth.uid()));
drop policy if exists member_view on public.members;
create policy member_view on public.members for select to authenticated using((select public.is_member()));
drop policy if exists member_insert on public.members;
create policy member_insert on public.members for insert to authenticated with check((select public.is_admin()));
drop policy if exists member_update on public.members;
create policy member_update on public.members for update to authenticated using((select public.is_admin())) with check((select public.is_admin()));
drop policy if exists member_delete on public.members;
create policy member_delete on public.members for delete to authenticated using((select public.is_admin()) and user_id<>(select auth.uid()));
drop policy if exists record_read on public.records;
create policy record_read on public.records for select to authenticated using((select public.is_member()));
drop policy if exists record_insert on public.records;
create policy record_insert on public.records for insert to authenticated with check((select public.may_edit()) and updated_by=(select auth.uid()));
drop policy if exists record_update on public.records;
create policy record_update on public.records for update to authenticated using((select public.may_edit())) with check((select public.may_edit()) and updated_by=(select auth.uid()));
drop policy if exists record_delete on public.records;
create policy record_delete on public.records for delete to authenticated using((select public.is_admin()));
drop policy if exists audit_read on public.audit_log;
create policy audit_read on public.audit_log for select to authenticated using((select public.is_admin()));
create or replace function public.audit_records() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op = 'DELETE' then
   insert into public.audit_log(record_id,kind,operation,actor,old_data) values(old.id,old.kind,'DELETE',auth.uid(),old.data);
   return old;
 elsif tg_op = 'INSERT' then
   insert into public.audit_log(record_id,kind,operation,actor,new_data) values(new.id,new.kind,'INSERT',auth.uid(),new.data);
 else
   new.updated_at=now();
   insert into public.audit_log(record_id,kind,operation,actor,old_data,new_data) values(new.id,new.kind,'UPDATE',auth.uid(),old.data,new.data);
 end if;
 return new;
end;$$;
drop trigger if exists audit_records_trigger on public.records;
create trigger audit_records_trigger before insert or update or delete on public.records for each row execute procedure public.audit_records();
-- IMPORTANTE: depois do PRIMEIRO cadastro/login, habilite o administrador no SQL Editor:
-- insert into public.members(user_id,role,department)
-- select id,'admin','Direção geral e criativa' from public.profiles
-- where email='SEU-EMAIL@EXEMPLO.COM'
-- on conflict(user_id) do update set role='admin',department='Direção geral e criativa';
-- Nunca compartilhe a service_role key nem execute o SQL com e-mail fictício.

-- Extensões e permissões do Workspace 3.0:
-- Mandakaru Workspace 3.0 — MIGRAÇÃO SEM APAGAR REGISTROS DO 2.1
-- Rode UMA vez no Supabase SQL Editor, como dono do projeto.
-- Não contém e-mails, senhas nem chaves secretas.

-- Cadastro individual: cada usuário pode atualizar SOMENTE o próprio nome.
revoke update on public.profiles from authenticated;
grant update(display_name) on public.profiles to authenticated;
drop policy if exists profile_view on public.profiles;
create policy profile_view on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or (select public.is_admin())
  or (
    (select public.is_member())
    and exists (select 1 from public.members m where m.user_id = profiles.id)
  )
);
drop policy if exists profile_update_self on public.profiles;
create policy profile_update_self on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Ninguém pode promover a si mesmo ou outra pessoa a admin por API.
-- O ADMIN é definido UMA vez, manualmente, no SQL Editor pelo proprietário.
drop policy if exists member_insert on public.members;
create policy member_insert on public.members for insert to authenticated
with check ((select public.is_admin()) and role in ('viewer','member','head'));
drop policy if exists member_update on public.members;
create policy member_update on public.members for update to authenticated
using ((select public.is_admin()) and role <> 'admin')
with check ((select public.is_admin()) and role in ('viewer','member','head'));

-- Estado de execução separado das definições-base de cada tarefa.
create table if not exists public.task_progress (
  task_id uuid not null references public.records(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('pendente','andamento','concluido')),
  note text not null default '' check (char_length(note) <= 2000),
  updated_at timestamptz not null default now(),
  primary key(task_id,user_id)
);
create index if not exists task_progress_user_idx on public.task_progress(user_id);

-- Proteção da atribuição: o usuário só pode registrar andamento em tarefas dele.
create or replace function public.is_my_assigned_task(task uuid, actor uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select (select auth.uid())=actor
  and exists (
    select 1 from public.members m where m.user_id=actor
  )
  and exists (
    select 1 from public.records r where r.id=task and r.kind='task'
      and r.data->>'assignee_id'=actor::text
  );
$$;
revoke all on function public.is_my_assigned_task(uuid,uuid) from public,anon;
grant execute on function public.is_my_assigned_task(uuid,uuid) to authenticated;

alter table public.task_progress enable row level security;
revoke all on public.task_progress from public,anon,authenticated;
grant select,insert,update on public.task_progress to authenticated;
drop policy if exists progress_view on public.task_progress;
create policy progress_view on public.task_progress for select to authenticated
using ((select public.is_member()));
drop policy if exists progress_insert_self on public.task_progress;
create policy progress_insert_self on public.task_progress for insert to authenticated
with check ((select public.is_my_assigned_task(task_id,user_id)));
drop policy if exists progress_update_self on public.task_progress;
create policy progress_update_self on public.task_progress for update to authenticated
using ((select public.is_my_assigned_task(task_id,user_id)))
with check ((select public.is_my_assigned_task(task_id,user_id)));

-- Histórico de alterações de progresso. Nenhuma gravação direta pela API.
create table if not exists public.task_progress_events (
  id bigint generated always as identity primary key,
  task_id uuid,
  user_id uuid,
  status text not null,
  note text not null default '',
  recorded_at timestamptz not null default now()
);
alter table public.task_progress_events enable row level security;
revoke all on public.task_progress_events from public,anon,authenticated;
grant select on public.task_progress_events to authenticated;
drop policy if exists progress_events_view on public.task_progress_events;
create policy progress_events_view on public.task_progress_events for select to authenticated
using ((select public.is_member()));

create or replace function public.log_progress_change() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op = 'INSERT' or
    (new.status,new.note) is distinct from (old.status,old.note) then
    insert into public.task_progress_events(task_id,user_id,status,note)
    values (new.task_id,new.user_id,new.status,new.note);
  end if;
  new.updated_at := now();
  return new;
end; $$;
drop trigger if exists progress_write on public.task_progress;
create trigger progress_write before insert or update on public.task_progress
for each row execute function public.log_progress_change();

-- Fin da migração: os dados de public.records permanecem intactos.
