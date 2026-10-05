-- V282: بيانات الرحلة الجوية وستيكر الحقيبة
alter table public.programs
  add column if not exists flight_number text,
  add column if not exists departure_airport text,
  add column if not exists arrival_airport text;
