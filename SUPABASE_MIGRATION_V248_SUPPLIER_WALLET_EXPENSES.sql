-- V248: Link supplier-wallet withdrawals to expenses, with multi-trip/general allocation
-- Safe: adds columns only; does not drop or recreate existing wallet table.
alter table public.supplier_wallet_transactions
  add column if not exists expense_recorded boolean not null default false,
  add column if not exists expense_mode text null,
  add column if not exists expense_category text null,
  add column if not exists expense_description text null,
  add column if not exists expense_fx_to_iqd numeric(18,8) null,
  add column if not exists expense_amount_iqd numeric(18,2) null,
  add column if not exists expense_allocations jsonb null;

create index if not exists supplier_wallet_expense_idx
  on public.supplier_wallet_transactions(expense_recorded, transaction_date);

-- Allowed modes are enforced at the application layer to remain compatible with existing rows.
