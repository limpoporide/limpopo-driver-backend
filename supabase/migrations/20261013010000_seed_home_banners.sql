alter table public.banners
add column if not exists display_order integer not null default 0;

with banner_data (title, content, image_url, display_order) as (
  values
    (
      'Victoria Island',
      'Old Ikoyi, Banana Island, Bourdillon Road. The estate roads and main corridors, day and night.',
      'https://res.cloudinary.com/wsdzvmmw/image/upload/v1791896370/banner1.jpg',
      0
    ),
    (
      'Lekki',
      'Fast pickups for your next trip.',
      'https://res.cloudinary.com/wsdzvmmw/image/upload/v1791896370/banner2.jpg',
      1
    ),
    (
      'Ikoyi',
      'Move in comfort with Limpopo rides.',
      'https://res.cloudinary.com/wsdzvmmw/image/upload/v1791896370/banner3.jpg',
      2
    )
), updated_banners as (
  update public.banners as existing
  set content = banner_data.content,
      image_url = banner_data.image_url,
      display_order = banner_data.display_order
  from banner_data
  where existing.title = banner_data.title
  returning existing.title
)
insert into public.banners (title, content, image_url, display_order)
select
  banner_data.title,
  banner_data.content,
  banner_data.image_url,
  banner_data.display_order
from banner_data
where not exists (
  select 1
  from public.banners as existing
  where existing.title = banner_data.title
)
order by banner_data.display_order;