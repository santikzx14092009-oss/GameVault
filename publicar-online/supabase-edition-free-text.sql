alter table public.products
add column if not exists edition text not null default 'Standard';

alter table public.products
drop constraint if exists products_edition_check;

create or replace function public.admin_add_product(
  p_name text,
  p_platform text,
  p_edition text,
  p_category text,
  p_price numeric,
  p_old_price numeric,
  p_stock int,
  p_cover text,
  p_description text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  if not public.is_staff() then
    raise exception 'not admin';
  end if;

  insert into public.products (
    name,
    platform,
    edition,
    category,
    price,
    old_price,
    discount,
    stock,
    cover,
    description,
    active
  )
  values (
    p_name,
    p_platform,
    coalesce(nullif(p_edition,''), 'Standard'),
    p_category,
    p_price,
    p_old_price,
    greatest(0, round((1 - (p_price / nullif(p_old_price, 0))) * 100)::int),
    p_stock,
    p_cover,
    coalesce(p_description, ''),
    true
  )
  returning id into new_id;

  return new_id;
end;
$$;

grant execute on function public.admin_add_product(text,text,text,text,numeric,numeric,int,text,text) to authenticated;

select 'OK - edição livre ativada' as resultado;
