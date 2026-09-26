-- V282: Shared trip expense allocation
create table if not exists public.finance_transaction_programs (
  id uuid primary key default gen_random_uuid(),
  finance_transaction_id uuid not null references public.finance_transactions(id) on delete cascade,
  program_id uuid not null references public.programs(id) on delete cascade,
  allocated_amount numeric(14,2) not null check (allocated_amount >= 0),
  allocated_amount_iqd numeric(14,2),
  created_at timestamptz not null default now(),
  constraint finance_transaction_programs_unique unique (finance_transaction_id, program_id)
);

create index if not exists idx_finance_transaction_programs_tx
  on public.finance_transaction_programs(finance_transaction_id);
create index if not exists idx_finance_transaction_programs_program
  on public.finance_transaction_programs(program_id);

insert into public.finance_transaction_programs
  (finance_transaction_id, program_id, allocated_amount, allocated_amount_iqd)
select
  ft.id,
  ft.program_id,
  ft.amount,
  case when ft.currency='IQD' then ft.amount else null end
from public.finance_transactions ft
where ft.program_id is not null
  and not exists (
    select 1 from public.finance_transaction_programs x
    where x.finance_transaction_id=ft.id and x.program_id=ft.program_id
  );

alter table public.finance_transaction_programs enable row level security;

grant select, insert, update, delete on public.finance_transaction_programs to authenticated;

drop policy if exists "finance_transaction_programs_select" on public.finance_transaction_programs;
drop policy if exists "finance_transaction_programs_insert" on public.finance_transaction_programs;
drop policy if exists "finance_transaction_programs_update" on public.finance_transaction_programs;
drop policy if exists "finance_transaction_programs_delete" on public.finance_transaction_programs;

create policy "finance_transaction_programs_select"
on public.finance_transaction_programs for select to authenticated
using (
  exists (select 1 from public.admin_users a where a.user_id=auth.uid())
  or exists (select 1 from public.staff_profiles s where s.user_id=auth.uid() and s.active=true)
);

create policy "finance_transaction_programs_insert"
on public.finance_transaction_programs for insert to authenticated
with check (
  exists (select 1 from public.admin_users a where a.user_id=auth.uid())
  or exists (select 1 from public.staff_profiles s where s.user_id=auth.uid() and s.active=true)
);

create policy "finance_transaction_programs_update"
on public.finance_transaction_programs for update to authenticated
using (
  exists (select 1 from public.admin_users a where a.user_id=auth.uid())
  or exists (select 1 from public.staff_profiles s where s.user_id=auth.uid() and s.active=true)
)
with check (
  exists (select 1 from public.admin_users a where a.user_id=auth.uid())
  or exists (select 1 from public.staff_profiles s where s.user_id=auth.uid() and s.active=true)
);

create policy "finance_transaction_programs_delete"
on public.finance_transaction_programs for delete to authenticated
using (
  exists (select 1 from public.admin_users a where a.user_id=auth.uid())
  or exists (select 1 from public.staff_profiles s where s.user_id=auth.uid() and s.active=true)
);