-- V281: حفظ عملة سعر الرحلة/الباقة للحجوزات والدفعات
alter table public.bookings
  add column if not exists currency text not null default 'IQD';

alter table public.payments
  add column if not exists currency text not null default 'IQD';

update public.bookings set currency='IQD' where currency is null;
update public.payments set currency='IQD' where currency is null;
