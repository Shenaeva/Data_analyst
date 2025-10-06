-- 1. Вывести все товары, в наименовании которых содержится «самокат» (без учета регистра), и срок годности которых не превышает 7 суток.		
-- Данные на выходе – наименование товара, срок годности	
select name, shelf_life 
from product p 
where lower(name) like lower('%самокат%') and shelf_life <= 7;

-- 2. Посчитать количество работающих складов на текущую дату по каждому городу. Вывести только те города, у которых количество складов более 50.		
-- Данные на выходе - город, количество складов

select city, count(*) as cnt_warecouse
from warehouses w 
where date_close is null 
group by city 
having count(*) > 50

-- 3. Посчитать количество позиций (SKU), которые продавались в июне 2020 года в среднем на 1 складе, данные вывести в разрезе городов.					
-- Данные на выходе - город, количество складов, количество товаров с продажами на 1 склад

select 
	city, 
	count(distinct ol.warehouse_id) as cnt_warecouse, 
	round(count(distinct ol.product_id)::numeric / count(distinct w.warehouse_id), 2) as avg_sku_per_warehouse
from warehouses w 
join order_line ol on w.warehouse_id = ol.warehouse_id 
where to_date(date, 'YYYY/MM') = '2020/06'
group by w.city 

-- 4. Посчитать количество заказов и количество клиентов в разрезе месяцев за 2021 год по компании в целом и по каждому из городов.
-- Данные на выходе – город/компания, месяц, количество заказов, количество клиентов
select 
	w.city,
	EXTRACT(MONTH FROM o.date) as month_2021,
	count(o.order_id) as cnt_orders,
	count(o.user_id) as cnt_users
from order_line ol 
join orders o on ol.order_id = o.order_id 
join warehouses w on w.warehouse_id = ol.warehouse_id 
where EXTRACT(year FROM o.date) = 2021
group by w.city, extract(month from o.date)

-- 5. Посчитать средний заказ в рублях по каждому складу за последние 14 дней, при этом вывести в алфавитном порядке наименования только тех складов, где средний заказ выше, чем средний заказ по городу.						
-- Данные на выходе – наименование склада, город, средний заказ по складу, средний заказ по городу						

with t_warehouse as (
	select
	warehouse_id,
	round(avg(o.paid_amount),2) as avg_order_by_warehouse
	from warehouses w 
	join orders o on w.warehouse_id = o.warehouse_id  
	group by warehouse_id
	having o.date >= now() - interval '14 days'
	
), t_city as (
	select
	city,
	round(avg(o.paid_amount),2) as avg_order_by_city
	from warehouses w 
	join orders o on w.warehouse_id = o.warehouse_id  
	group by w.city 
	having o.date >= now() - interval '14 days'
	)
select 
	w.name, 
	w.city,
	avg_order_by_warehouse,
	avg_order_by_city
from warehouses w 
join t_warehouse tw on w.warehouse_id = tw.warehouse_id
join t_city tc on w.city = tc.city
where avg_order_by_warehouse > avg_order_by_city
order by w.name;

-- 6. Рассчитать % потерь (от суммы продаж, учитывая все статьи) и долю потерь в общей сумме потерь по компании в целом 
-- за последние 4 недели по каждой группе товаров 2 уровня.
-- Данные на выходе – группа товаров 1 уровня, группа товаров 2 уровня, % потерь от продаж, доля потерь

with sales as (
    select 
        p.group1,
        p.group2,
        sum(ol.paid_amount) as total_sales
    from order_line ol
    join product p on p.product_id = ol.product_id
    where ol.date >= now() - interval '4 weeks'
    group by p.group1, p.group2
),
loss as (
    select 
        p.group1,
        p.group2,
        sum(l.amount) as total_loss
    from lost l
    join product p on p.product_id = l.product_id
    where l.date >= now() - interval '4 weeks'
    group by p.group1, p.group2
)
select 
    s.group1,
    s.group2,
    round(coalesce(l.total_loss,0) / nullif(s.total_sales,0) * 100, 2) as percent_loss_from_sales,
    round(coalesce(l.total_loss,0) / nullif(sum(l.total_loss) over(),0) * 100, 2) as share_in_total_loss
from sales s
left join loss l 
    on s.group1 = l.group1 and s.group2 = l.group2;

--7. Построить рейтинги товаров за май 2021 года по всем складам в Москве. Строим отдельно 2 рейтинга - 
-- рейтинг по сумме продаж на 1 склад в рамках группы товаров 1 уровня и рейтинг по сумме потерь на 
-- 1 склад в рамках группы товаров 1 уровня. В итоге выводим топ-10 товаров по потерям и продажам в 
-- каждой группе.
   
-- Данные на выходе – группа товаров 1 уровня, наименование товара, сумма продаж на 1 склад, рейтинг 
-- по продажам, сумма потерь на 1 склад, рейтинг по потерям
WITH sales AS (
    SELECT 
        p.group1,
        p.name,
        SUM(ol.paid_amount) / COUNT(DISTINCT w.warehouse_id) AS sales_per_warehouse,
        RANK() OVER (
            PARTITION BY p.group1 
            ORDER BY SUM(ol.paid_amount) / COUNT(DISTINCT w.warehouse_id) DESC
        ) AS rank_sales
    FROM order_line ol
    JOIN product p ON p.product_id = ol.product_id
    JOIN warehouses w ON w.warehouse_id = ol.warehouse_id
    WHERE w.city = 'Москва'
      AND ol.date >= '2021-05-01' 
      AND ol.date < '2021-06-01'
    GROUP BY p.group1, p.name
),
loss AS (
    SELECT 
        p.group1,
        p.name,
        SUM(l.amount) / COUNT(DISTINCT w.warehouse_id) AS loss_per_warehouse,
        RANK() OVER (
            PARTITION BY p.group1 
            ORDER BY SUM(l.amount) / COUNT(DISTINCT w.warehouse_id) DESC
        ) AS rank_loss
    FROM lost l
    JOIN product p ON p.product_id = l.product_id
    JOIN warehouses w ON w.warehouse_id = l.warehouse_id
    WHERE w.city = 'Москва'
      AND l.date >= '2021-05-01' 
      AND l.date < '2021-06-01'
    GROUP BY p.group1, p.name
)
SELECT 
    COALESCE(s.group1, l.group1) AS group1,
    COALESCE(s.name, l.name) AS product_name,
    s.sales_per_warehouse,
    s.rank_sales,
    l.loss_per_warehouse,
    l.rank_loss
FROM sales s
FULL JOIN loss l 
    ON s.group1 = l.group1 AND s.name = l.name
WHERE (s.rank_sales <= 10 OR l.rank_loss <= 10)
ORDER BY group1, COALESCE(rank_sales, rank_loss);
