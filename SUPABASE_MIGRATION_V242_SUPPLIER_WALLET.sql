-- V242: Supplier wallet / multi-currency ledger
create table if not exists public.supplier_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  transaction_type text not null check (transaction_type in ('deposit','withdrawal')),
  currency text not null check (currency in ('SAR','USD','IQD')),
  amount numeric(18,2) not null check (amount > 0),
  transaction_date date not null default current_date,
  program_id uuid null references public.programs(id) on delete set null,
  expense_id uuid null references public.expenses(id) on delete set null,
  source_currency text null check (source_currency is null or source_currency in ('SAR','USD','IQD')),
  source_amount numeric(18,2) null check (source_amount is null or source_amount > 0),
  fx_rate numeric(18,8) null check (fx_rate is null or fx_rate > 0),
  description text null,
  notes text null,
  created_by uuid null,
  created_at timestamptz not null default now()
);
create index if not exists supplier_wallet_transactions_supplier_idx on public.supplier_wallet_transactions(supplier_id, currency, transaction_date);
create index if not exists supplier_wallet_transactions_program_idx on public.supplier_wallet_transactions(program_id);
create index if not exists supplier_wallet_transactions_expense_idx on public.supplier_wallet_transactions(expense_id);
alter table public.supplier_wallet_transactions enable row level security;

-- Policies follow the platform's authenticated-admin pattern; adjust only if your existing RLS differs.
drop policy if exists supplier_wallet_select_auth on public.supplier_wallet_transactions;
create policy supplier_wallet_select_auth on public.supplier_wallet_transactions for select to authenticated using (true);
drop policy if exists supplier_wallet_insert_auth on public.supplier_wallet_transactions;
create policy supplier_wallet_insert_auth on public.supplier_wallet_transactions for insert to authenticated with check (true);
drop policy if exists supplier_wallet_update_auth on public.supplier_wallet_transactions;
create policy supplier_wallet_update_auth on public.supplier_wallet_transactions for update to authenticated using (true) with check (true);
