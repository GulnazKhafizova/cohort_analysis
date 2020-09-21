Кейс 10

--переводим ip-адрес в десятичный формат для удобства дальнейших вычислений
with a as
(select id,
    substring(last_sign_in_ip, '^(\d+)\.\d+\.\d+\.\d+$')::bigint * pow(256, 3)+
	substring(last_sign_in_ip, '^\d+\.(\d+)\.\d+\.\d+$')::bigint * pow(256, 2)+
    substring(last_sign_in_ip, '^\d+\.\d+\.(\d+)\.\d+$')::bigint * pow(256, 1)+
	substring(last_sign_in_ip, '^\d+\.\d+\.\d+\.(\d+)$')::bigint * pow(256, 0) as ip
from case10.users),
  
--выделяем диапазоны ip принадлежащие России  
b as 
(select *
from case10.ip2location_db1
where country_code = 'RU'),

--находим пользователей из России по указанному адресу
address_rus as 
(select 
    u.id
from case10.users u 
    join case10.addresses ad on u.id = ad.addressable_id
    join case10.cities c on ad.city_id = c.id
    join case10.regions r on c.region_id = r.id
    join case10.countries coun  on r.country_id = coun.id
where coun.name = 'Russia'),

--находим пользователей из России по указанному телефону
phone_rus as
(select 
    id
from case10.users
where substring(phone::text from 1 for 2) in ('73', '74', '78', '79')),

--находим пользователей из России по ip последнего входа
ip_rus as 
(select id
from a
where exists
    (select * 
    from b 
    where a.ip between b.ip_from and b.ip_to)),

--объединяем все три признака для пользователей из России
id_rus as
(select * from address_rus
union 
select * from phone_rus
union 
select * from ip_rus),


--находим количество пользователей из России для каждого месяца регистрации
reg_from_ru as
(select 
    date_trunc('month',u.created_at) as mn,
    count(*) qty 
from case10.users u 
where exists(select * from id_rus where id_rus.id = u.id)
group by 1),

--создаем когорты и определяем конверсию для пользователей из России
cohorts_russia as
(select
    date_trunc('month',u.created_at) as reg_mn,
    reg_from_ru.qty,
    date_trunc('month',car.purchased_at) as purch_mn,
    count(distinct car.id) as cart,
    count(distinct car.id)::numeric/reg_from_ru.qty as conversion 
from case10.users u 
    join reg_from_ru on reg_from_ru.mn = date_trunc('month',u.created_at)
    join case10.carts car on u.id = car.user_id and car.state = 'successful'
where exists(select * from id_rus where id_rus.id = u.id)
group by 1, 2, 3
order by 1, 3),

--находим количество пользователей не из России для каждого месяца регистрации
reg_from_other as 
(select 
    date_trunc('month',u.created_at) as mn,
    count(*) qty 
from case10.users u 
where not exists(select * from id_rus where id_rus.id = u.id)
group by 1),

--создаем когорты и определяем конверсию для пользователей не из России
cohorts_other as
(select
    date_trunc('month',u.created_at) as reg_mn,
    reg_from_other.qty,
    date_trunc('month',car.purchased_at) as purch_mn,
    count(distinct car.id) as cart,
    count(distinct car.id)::numeric/reg_from_other.qty as conversion 
from case10.users u 
    join reg_from_other on reg_from_other.mn = date_trunc('month',u.created_at)
    join case10.carts car on u.id = car.user_id and car.state = 'successful'
where not exists (select * from id_rus where id_rus.id = u.id)
group by 1, 2, 3
order by 1, 3)

Выводы: Платящих пользователей из России больше чем платящих пользователей не из России примерно в 50 раз (6180/115).
Суммарная конверсия (раскрываемость) по данным 2018 года значительно выше относительно данных 2017 года. Усредненный рост раскрываемости по данным январь-июнь 2018г. составляет 1.15. 
