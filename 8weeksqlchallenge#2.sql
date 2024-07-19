-- A. Pizza Metrics

SELECT 
    COUNT(*)
FROM
    customer_orders;

-- How many unique customer orders were made?
SELECT 
    COUNT(DISTINCT order_id) AS TotalOrders
FROM
    customer_orders;

-- How many successful orders were delivered by each runner?
SELECT 
    runner_id, COUNT(order_id) AS no_of_deliveries
FROM
    runner_orders
WHERE
    cancellation IS NULL
GROUP BY 1;

-- How many of each type of pizza was delivered?
SELECT 
    pizza_name, COUNT(*) AS no_of_pizzas_ordered
FROM
    customer_orders c
        JOIN
    runner_orders r ON c.order_id = r.order_id
        JOIN
    pizza_names p ON p.pizza_id = c.pizza_id
WHERE
    r.cancellation IS NULL
GROUP BY pizza_name;

-- How many Vegetarian and Meatlovers were ordered by each customer?
SELECT 
    c.customer_id,
    p.pizza_name,
    COUNT(*) AS no_of_pizzas_ordered
FROM
    customer_orders c
        JOIN
    runner_orders r ON c.order_id = r.order_id
        JOIN
    pizza_names p ON p.pizza_id = c.pizza_id
WHERE
    r.cancellation IS NULL
GROUP BY c.customer_id , p.pizza_name;

-- What was the maximum number of pizzas delivered in a single order?
SELECT 
    c.order_id, COUNT(*) AS max_no_of_pizzas_delivered
FROM
    customer_orders c
        JOIN
    runner_orders r ON c.order_id = r.order_id
WHERE
    r.cancellation IS NULL
GROUP BY 1
ORDER BY max_no_of_pizzas_delivered DESC
LIMIT 1;

-- For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT 
    customer_id,
    COUNT(CASE
        WHEN exclusions IS NULL AND extras IS NULL THEN 1
    END) AS NoChange,
    COUNT(CASE
        WHEN
            exclusions IS NOT NULL
                OR extras IS NOT NULL
        THEN
            1
    END) AS AtleastOneChange
FROM
    customer_orders c
        JOIN
    runner_orders r ON c.order_id = r.order_id
WHERE
    r.cancellation IS NULL
GROUP BY 1;

-- How many pizzas were delivered that had both exclusions and extras?
SELECT 
    COUNT(c.order_id) AS BothExclusionExtra
FROM
    customer_orders c
        JOIN
    runner_orders r ON c.order_id = r.order_id
WHERE
    r.cancellation IS NULL
        AND (exclusions IS NOT NULL
        AND extras IS NOT NULL);

-- What was the total volume of pizzas ordered for each hour of the day?
SELECT 
    EXTRACT(HOUR FROM order_time) AS HourOfDay,
    COUNT(*) AS TotalPizzasOrdered
FROM
    customer_orders
GROUP BY 1
ORDER BY 1;
 
-- What was the volume of orders for each day of the week?
SELECT 
    DAYNAME(order_time) AS DayOfWeek,
    COUNT(*) AS TotalPizzasOrdered
FROM
    customer_orders
GROUP BY 1
ORDER BY TotalPizzasOrdered DESC;

-- B. Runner and Customer Experience

SELECT 
    FLOOR((TO_DAYS(registration_date) - TO_DAYS('2021-01-01')) / 7) + 1 AS week_number,
    COUNT(*) AS runners_signed_up
FROM
    runners
WHERE
    registration_date >= '2021-01-01'
GROUP BY week_number
ORDER BY week_number;
    
-- What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT 
    r.runner_id,
    CONCAT(ROUND(AVG(TIME_TO_SEC(TIMEDIFF(r.pickup_time, c.order_time)) / 60)),
            ' mins') AS avg_time
FROM
    (SELECT DISTINCT
        order_id, order_time
    FROM
        pizza_runner.customer_orders) c
        JOIN
    pizza_runner.runner_orders r ON c.order_id = r.order_id
WHERE
    r.cancellation IS NULL
GROUP BY r.runner_id;

-- Is there any relationship between the number of pizzas and how long the order takes to prepare?
with avg_time_taken as
(
select c.order_id, count(*) as no_of_pizzas, 
	    (AVG(TIME_TO_SEC(TIMEDIFF(r.pickup_time, c.order_time)) / 60)) AS avg_time
FROM 
    customer_orders c
JOIN 
    pizza_runner.runner_orders r
ON 
    c.order_id = r.order_id
WHERE 
    r.cancellation IS NULL
GROUP BY 
    1
)
select  no_of_pizzas, round(avg( avg_time),2)
from avg_time_taken
group by no_of_pizzas;

-- What was the average distance travelled for each customer?
SELECT 
    c.customer_id, AVG(r.distance) AS avg_distance_km
FROM
    customer_orders c
        JOIN
    runner_orders r ON c.order_id = r.order_id
WHERE
    r.cancellation IS NULL
GROUP BY 1;

-- What was the difference between the longest and shortest delivery times for all orders?
SELECT 
    MAX(duration) - MIN(duration) AS diff
FROM
    runner_orders
WHERE
    cancellation IS NULL;

-- What was the average speed for each runner for each delivery and do you notice any trend for these values?
-- d = s*t
WITH avg_speed_per_delivery AS (
    SELECT 
        r.order_id,
        r.runner_id,
        (r.distance / (r.duration / 60)) AS speed_kmph
    FROM 
        pizza_runner.runner_orders r
    JOIN 
        pizza_runner.customer_orders c
    ON 
        r.order_id = c.order_id
    WHERE 
        r.cancellation IS NULL
)
SELECT 
    order_id,
    runner_id,
    ROUND(AVG(speed_kmph), 2) AS avg_speed_kmph
FROM 
    avg_speed_per_delivery
GROUP BY 
    order_id, runner_id
ORDER BY 
    runner_id;
    
-- What is the successful delivery percentage for each runner?
WITH total_orders AS (
    SELECT 
        runner_id, 
        COUNT(*) AS total_deliveries
    FROM 
        pizza_runner.runner_orders
    GROUP BY 
        runner_id
),
successful_orders AS (
    SELECT 
        runner_id, 
        COUNT(*) AS successful_deliveries
    FROM 
        pizza_runner.runner_orders
    WHERE 
        cancellation IS NULL
    GROUP BY 
        runner_id
)
SELECT 
    t.runner_id, 
    successful_deliveries,
    total_deliveries,
    ROUND((successful_deliveries / total_deliveries) * 100, 2) AS success_percentage
FROM 
    total_orders t
JOIN 
    successful_orders s
ON 
    t.runner_id = s.runner_id
ORDER BY 
    t.runner_id;

-- C. Ingredient Optimisation

-- What are the standard ingredients for each pizza?
WITH RECURSIVE split_toppings AS (
    SELECT 
        pizza_id,
        SUBSTRING_INDEX(toppings, ',', 1) AS toppingId,
        SUBSTRING(toppings, LENGTH(SUBSTRING_INDEX(toppings, ',', 1)) + 2) AS remaining_toppings
    FROM 
        pizza_recipes
    WHERE 
        toppings IS NOT NULL
    UNION ALL
    SELECT 
        pizza_id,
        SUBSTRING_INDEX(remaining_toppings, ',', 1),
        SUBSTRING(remaining_toppings, LENGTH(SUBSTRING_INDEX(remaining_toppings, ',', 1)) + 2)
    FROM 
        split_toppings
    WHERE 
        remaining_toppings <> ''
)
SELECT 
    st.pizza_id,
    GROUP_CONCAT(ti.topping_name ORDER BY ti.topping_name SEPARATOR ', ') AS toppings
FROM 
    split_toppings st
JOIN 
    pizza_toppings ti
ON 
    st.toppingId = ti.topping_id
GROUP BY 
    st.pizza_id;
    
-- What was the most commonly added extra?
WITH RECURSIVE split_extras AS (
    SELECT 
        order_id,
        SUBSTRING_INDEX(SUBSTRING_INDEX(extras, ',', 1), ',', -1) AS extra_id,
        SUBSTRING(extras, LENGTH(SUBSTRING_INDEX(extras, ',', 1)) + 2) AS remaining_extras
    FROM 
        customer_orders
    WHERE 
        extras IS NOT NULL AND extras <> ''
    UNION ALL
    SELECT 
        order_id,
        SUBSTRING_INDEX(SUBSTRING_INDEX(remaining_extras, ',', 1), ',', -1),
        SUBSTRING(remaining_extras, LENGTH(SUBSTRING_INDEX(remaining_extras, ',', 1)) + 2)
    FROM 
        split_extras
    WHERE 
        remaining_extras <> ''
)
SELECT 
    te.topping_name,
    COUNT(se.extra_id) AS count
FROM 
    split_extras se
JOIN 
    pizza_toppings te
ON 
    se.extra_id = te.topping_id
GROUP BY 
    te.topping_name
ORDER BY 
    count DESC;

-- What was the most common exclusion?
with recursive split_exclusions as 
(
SELECT 
    order_id,
    SUBSTRING_INDEX(SUBSTRING_INDEX(exclusions, ',', 1),
            ',',
            - 1) AS exclusion_id,
    SUBSTRING(exclusions,
        LENGTH(SUBSTRING_INDEX(exclusions, ',', 1)) + 2) AS remaining_exclusions
 FROM 
        customer_orders
    WHERE 
        exclusions IS NOT NULL AND exclusions <> ''
    UNION ALL
    SELECT 
        order_id,
        SUBSTRING_INDEX(SUBSTRING_INDEX(remaining_exclusions, ',', 1), ',', -1),
        SUBSTRING(remaining_exclusions, LENGTH(SUBSTRING_INDEX(remaining_exclusions, ',', 1)) + 2)
    FROM 
        split_exclusions
    WHERE 
        remaining_exclusions <> ''
)
SELECT 
    te.topping_name,
    COUNT(se.exclusion_id) AS count
FROM 
    split_exclusions se
JOIN 
    pizza_toppings te
ON 
    se.exclusion_id = te.topping_id
GROUP BY 
    te.topping_name
ORDER BY 
    count DESC;

-- D. Pricing and Ratings

-- If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes 
-- how much money has Pizza Runner made so far if there are no delivery fees?
with pizza_prices as
(
select 
     case when pn.pizza_name = "Meatlovers" then 12 else 10 end as price	 
from customer_orders c
join pizza_names pn
on c.pizza_id = pn.pizza_id
join runner_orders r
on c.order_id = r.order_id
where r.cancellation is null
)
select concat("$",sum(price)) as TotalRevenue
from pizza_prices;

-- The Pizza Runner team now wants to add an additional ratings system that allows customers to 
-- rate their runner, how would you design an additional table for this new dataset - generate a schema for 
-- this new table and 
-- insert your own data for ratings for each successful customer order between 1 to 5.
DROP TABLE IF EXISTS ratings;
CREATE TABLE ratings (
    order_id INT,
    rating INT
);
Insert into ratings
(order_id, rating)
values (1,3),
	   (2,3),
       (3,5),
       (4,1),
       (5,5),
       (7,4),
       (8,5),
       (10,5);
       
SELECT 
    *
FROM
    ratings;

-- Using your newly generated table - can you join all of the information together 
-- to form a table which has the following information for successful deliveries?
-- customer_id
-- order_id
-- runner_id
-- rating
-- order_time
-- pickup_time
-- Time between order and pickup
-- Delivery duration
-- Average speed
-- Total number of pizzas
SELECT 
    customer_id,
    c.order_id,
    r.runner_id,
    ra.rating,
    c.order_time,
    r.pickup_time,
    CONCAT(ROUND((TIME_TO_SEC(TIMEDIFF(r.pickup_time, c.order_time)) / 60)),
            ' mins') AS time_bw_pickup_order,
    r.duration,
    ROUND(r.distance / (r.duration / 60)) AS speed_kmph,
    COUNT(c.order_id) AS pizza_count
FROM
    customer_orders c
        JOIN
    runner_orders r ON c.order_id = r.order_id
        JOIN
    ratings ra ON r.order_id = ra.order_id
WHERE
    r.cancellation IS NULL
GROUP BY customer_id , c.order_id , r.runner_id , ra.rating , c.order_time , r.pickup_time , time_bw_pickup_order , r.duration , speed_kmph
ORDER BY c.customer_id;

-- If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each 
-- runner is paid $0.30 per kilometre 
-- traveled - how much money does Pizza Runner have left over after these deliveries?
with pizza_prices as 
(
select *, case when pizza_id = 1 then 12 else 10 end as pizza_price from customer_orders
)
SELECT 
    SUM(pizza_price) AS revenue,
    (SUM(distance) * 0.3) AS total_cost,
    SUM(pizza_price) - (SUM(distance) * 0.3) AS revenue
FROM runner_orders r 
JOIN pizza_prices pp ON r.order_id =pp.order_id
WHERE r.cancellation is NULL;
