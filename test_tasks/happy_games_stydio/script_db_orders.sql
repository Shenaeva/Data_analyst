-- PostgreSQL 16
-- Дамп структуры БД:
-- Создание таблицы пользователей
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

-- Создание таблицы заказов
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    total_price NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

-- Создание таблицы деталей заказах
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id),
    product_name VARCHAR(200) NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    quantity INT NOT NULL
);

-- Заполнение таблиц
-- 1 млн пользователей
INSERT INTO users (name, email, created_at)
SELECT 
    'User ' || g,
    'user' || g || '@example.com',
    now() - (g || ' days')::interval
FROM generate_series(1, 1000000) g;

-- 1 млн заказов
INSERT INTO orders (user_id, total_price, created_at)
SELECT 
    (trunc(random() * random() * 50000 + 1))::int,  -- пользователи 1–50 000, но с перекосом
    round((random() * 500)::numeric, 2),           -- сумма заказа
    now() - (g || ' minutes')::interval
FROM generate_series(1, 1000000) g;

-- 1 млн инфо о заказах. Можно было бы задать рандомные значения, но хотелось ограничить ассортимент товаров и чтобы удовлетворялось условие price * quantity == total_price 
WITH item_split AS (
    SELECT 
        o.id AS order_id,
        o.total_price,
        (random() * 9 + 1)::int AS quantity,          -- количество 1–10
        'Product ' || (random() * 29 + 1)::int AS product_name  -- товар из 1–30
    FROM orders o
)
INSERT INTO order_items (order_id, product_name, price, quantity)
SELECT 
    order_id,
    product_name,
    round((total_price / quantity)::numeric, 2) AS price,  -- цена = сумма / qty
    quantity
FROM item_split;

-- Найти общее количество заказов каждого пользователя, который сделал более 10 заказов
select o.user_id, count(*) as total_orders 
from orders o 
join users u on o.user_id = u.id 
group by o.user_id 
having count(*) >10 
order by total_orders desc;

-- Найти средний размер заказа для каждого пользователя за последний месяц
select user_id , round(avg(total_price), 2) as avg_price
from orders o 
where created_at >= now() - interval '1 month'
group by user_id 
order by avg_price desc, user_id; 

-- Найти средний размер заказа за каждый месяц в текущем году и сравнить его с средним размером заказа за соответствующий месяц в прошлом году.
select 
	extract (month from created_at) AS month_at,
	round(avg(case when extract(year from created_at) = 2025 then total_price end), 2) as avg_2025,
	round(avg(case when extract(year from created_at) = 2024 then total_price end), 2) as avg_2024
from orders o
group by extract (month from created_at)
order by month_at;

-- Найти 10 пользователей, у которых наибольшее количество заказов за последний год, и для каждого из них найти средний размер заказа за последний месяц.
with top_users as (
select 
	user_id,
	count(*) as count_orders
from orders o 
where created_at >= current_date - interval '1 year'
group by user_id
order by count_orders desc
limit 10
)
select 
	o.user_id ,
	count(*) filter (where o.created_at >= current_date - interval '1 year') as orders_last_year,
	round(avg(o.total_price) filter (where o.created_at >= current_date - interval '1 month'), 2) as avg_orders_last_month
from top_users tu
join orders o on tu.user_id = o.user_id 
group by o.user_id
order by orders_last_year desc;
