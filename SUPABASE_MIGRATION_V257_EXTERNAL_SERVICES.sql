-- V257: External services for customers outside company trips
create table if not exists public.external_services (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  service_type text not null,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  service_date date not null default current_date,
  supplier_cost_amount numeric(18,2) not null check (supplier_cost_amount > 0),
  supplier_cost_currency text not null check (supplier_cost_currency in ('SAR','USD','IQD')),
  customer_amount numeric(18,2) not null check (customer_amount > 0),
  customer_currency text not null check (customer_currency in ('SAR','USD','IQD')),
  fx_rate numeric(18,8) not null default 1 check (fx_rate > 0),
  supplier_iqd_rate numeric(18,8) not null check (supplier_iqd_rate > 0),
  revenue_in_cost_currency numeric(18,2) not null,
  profit_in_cost_currency numeric(18,2) not null,
  supplier_cost_iqd numeric(18,2) not null,
  revenue_iqd numeric(18,2) not null,
  profit_iqd numeric(18,2) not null,
  wallet_tx_id uuid null references public.supplier_wallet_transactions(id) on delete set null,
  notes text null,
  created_by uuid null,
  created_at timestamptz not null default now()
);
create index if not exists external_services_date_idx on public.external_services(service_date, created_at desc);
create index if not exists external_services_supplier_idx on public.external_services(supplier_id);
alter table public.external_services enable row level security;
drop policy if exists external_services_select_auth on public.external_services;
create policy external_services_select_auth on public.external_services for select to authenticated using (true);
drop policy if exists external_services_insert_auth on public.external_services;
create policy external_services_insert_auth on public.external_services for insert to authenticated with check (true);

create or replace function public.record_external_service(
  p_customer_name text,
  p_service_type text,
  p_supplier_id uuid,
  p_service_date date,
  p_supplier_cost_amount numeric,
  p_supplier_cost_currency text,
  p_customer_amount numeric,
  p_customer_currency text,
  p_fx_rate numeric,
  p_supplier_iqd_rate numeric,
  p_revenue_in_cost_currency numeric,
  p_profit_in_cost_currency numeric,
  p_supplier_cost_iqd numeric,
  p_revenue_iqd numeric,
  p_profit_iqd numeric,
  p_notes text,
  p_created_by uuid
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
  v_service_id uuid;
begin
  if p_supplier_cost_amount <= 0 or p_customer_amount <= 0 then
    raise exception 'المبالغ يجب أن تكون أكبر من صفر';
  end if;
  if p_supplier_cost_currency not in ('SAR','USD','IQD') or p_customer_currency not in ('SAR','USD','IQD') then
    raise exception 'عملة غير مدعومة';
  end if;
  insert into public.supplier_wallet_transactions(
    supplier_id, transaction_type, currency, amount, amount_iqd,
    transaction_date, source_currency, source_amount, fx_rate,
    exchange_rate_to_iqd, description, created_by
  ) values (
    p_supplier_id, 'withdrawal', p_supplier_cost_currency, p_supplier_cost_amount, p_supplier_cost_iqd,
    p_service_date, null, null, null,
    p_supplier_iqd_rate,
    'خدمة خارجية: ' || p_service_type || ' — ' || p_customer_name,
    p_created_by
  ) returning id into v_wallet_id;

  insert into public.external_services(
    customer_name, service_type, supplier_id, service_date,
    supplier_cost_amount, supplier_cost_currency, customer_amount, customer_currency,
    fx_rate, supplier_iqd_rate, revenue_in_cost_currency, profit_in_cost_currency,
    supplier_cost_iqd, revenue_iqd, profit_iqd, wallet_tx_id, notes, created_by
  ) values (
    p_customer_name, p_service_type, p_supplier_id, p_service_date,
    p_supplier_cost_amount, p_supplier_cost_currency, p_customer_amount, p_customer_currency,
    p_fx_rate, p_supplier_iqd_rate, p_revenue_in_cost_currency, p_profit_in_cost_currency,
    p_supplier_cost_iqd, p_revenue_iqd, p_profit_iqd, v_wallet_id, p_notes, p_created_by
  ) returning id into v_service_id;
  return v_service_id;
end;
$$;

grant execute on function public.record_external_service(text,text,uuid,date,numeric,text,numeric,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,text,uuid) to authenticated;
