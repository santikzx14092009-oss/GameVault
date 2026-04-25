drop policy if exists "orders staff delete" on orders;
create policy "orders staff delete" on orders
for delete using (public.is_staff());

drop policy if exists "order items staff delete" on order_items;
create policy "order items staff delete" on order_items
for delete using (public.is_staff());
