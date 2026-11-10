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
