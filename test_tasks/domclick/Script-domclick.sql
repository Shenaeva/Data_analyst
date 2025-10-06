-- 1. Название страны, в которой находится город "Казань".
select c.name as Страна
from countries c 
join regions r on c.id = r.countryid 
join cities c2 on r.id = c2.regionid 
where c2."name" = 'Казань';

-- 2. Количество городов в московской области
select count(*) as Кол-во
from cities c 
join regions r on r.id = c.regionid 
where r."name" = 'Московская область';

-- 3. Количество уборок снега проведенных с начала декабря 2020 по конец февраля 2021.
select count(*) as Кол-во
from events e 
join types t  on t.id = e.typeid 
where t.name = 'Уборка снега' and e.date between '1/12/2020' and '28/02/2021'

-- 4. Вывести городское население каждого региона.
select 
	r.name as регион,
	sum(c.population) as население
from regions r 
join cities c on r.id = c.regionid 
group by r.name 

-- 5.Посчитать кол-во уборок снега в Москве за последние 3 года
select count(*) as Кол-во
from events e 
join cities c on e.cityid = c.id 
join types t on t.id = e.typeid 
where 
	t.name = 'Уборка снега' 
	and c.name = 'Москва' 
	and e.date >= now() - interval '3 years'

-- 6. Посчитать средние траты на каждый тип события за последние 5 лет в Санкт-Птеребурге
select 
	t."name" as Тип,
	avg(e.costs) as Стоимость
from events e 
join cities c on e.cityid = c.id 
join types t on t.id = e.typeid 
where c.name = 'Санкт-Петербург' and e.date >= now() - interval '5 years'
group by t.name

-- 7. Посчитать среднее время между одинаковыми событиями для каждого города
select 
	c.name as Город,
	t.name as Тип,
	round(avg(extract(epoch from (e.date - lag(e.date) over(partition by c.id, e.id order by e.date)))/ 86400), 2) as Время
from cities c 
join events e on c.id = e.cityid 
join types t  on e.typeid = t.id 
group by c.name, t.name
order by c.name, t.name,

-- 8. Посчитать среднюю стоимость трат по каждому типу события на 1 человека в год, для каждого региона
select 
	r.name as Регион,
	t.name as Тип,
	round((sum(e.costs)/sum(c.population)), 2) as "Стоимость на человека в год"
from regions r 
join cities c on r.id = c.regionid 
join events e on c.id = e.cityid 
join types t on t.id = e.typeid 
where to_date(e.date, 'DD/MM/YYYY') >= now() - interval '1 year'
group by r.name, t.name