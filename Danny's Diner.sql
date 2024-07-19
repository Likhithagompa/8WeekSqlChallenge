use dannys_diner;

-- What is the total amount each customer spent at the restaurant?

select s.customer_id,  sum(m.price) from
sales s join menu m
on s.product_id = m.product_id
group by s.customer_id;

-- How many days has each customer visited the restaurant?
-- count(distinct order_date), group by cx_id

select customer_id, count(distinct order_date) as no_of_visits
from sales
group by customer_id;

-- What was the first item from the menu purchased by each customer?
-- min(order_date)

select * from sales
where order_date in (select min(order_date) from sales);

select s.customer_id, s.order_date, mn.product_name 
from sales s join menu mn on s.product_id = mn.product_id 
where (customer_id, order_date) in (select customer_id, min(order_date) from sales
					 group by customer_id);

-- What is the most purchased item on the menu and how many times was it purchased by all customers?

select s.product_id, mn.product_name, count(*) as total_sales_per_product 
from sales s join menu mn
group by s.product_id, mn.product_name
order by  count(*) desc
limit 1;


with total_sales (product_id, total_sales_per_product) AS
		(select product_id, count(*) as total_sales_per_product from sales
		group by product_id), 
    maximum_count (max_count) as 
		(select max(total_sales_per_product) as max_count
		from total_sales)
select *
from total_sales ts
join maximum_count mc
on ts.total_sales_per_product >= mc.max_count;

select * 
from (select product_id, count(*) as total_sales_per_product from sales
	group by product_id) total_sales
join (select max(total_sales_per_product) as max_count
	from (select product_id, count(*) as total_sales_per_product from sales
	group by product_id) a) maximum_count
on total_sales.total_sales_per_product >= maximum_count.max_count;



-- Which item was the most popular for each customer?

select customer_id, product_name, total_sales, rnk from
(
select customer_id, product_id, 
count(*) as total_sales, rank() over(partition by customer_id order by count(*) desc) as rnk from sales
group by customer_id, product_id
)x
left join menu mn on x.product_id = mn.product_id
where rnk = 1;

-- Which item was purchased first by the customer after they became a member?
-- order_date > = join_date , rnk/row_no = 1


 select * from 
 (select s.customer_id,  m.join_date, s.order_date, mn.product_name, 
		 rank() over (partition by customer_id order by order_date asc) as rnk
 from sales s join members m
 on s.customer_id = m.customer_id and s.order_date >= m.join_date
	join menu mn on s.product_id = mn.product_id) x
 where rnk = 1;
 
 

-- Which item was purchased just before the customer became a member?

select * from 
(select s.*, m.join_date, mn.product_name, rank() over(partition by s.customer_id order by s.order_date desc) as rnk
from sales s join members m on s.customer_id = m.customer_id AND s.order_date < m.join_date
			 join  menu mn ON s.product_id = mn.product_id) x
	where rnk = 1;
    
-- What is the total items and amount spent for each member before they became a member?

select s.customer_id, count(*) as item_count, sum(mn.price) from 
sales s join members m on s.customer_id = m.customer_id AND s.order_date < m.join_date
		join  menu mn ON s.product_id = mn.product_id
	group by s.customer_id;
    
-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier 
-- how many points would each customer have?

select s.customer_id, 
sum(case  
	when m.product_name = 'sushi' then m.price*20
	else m.price*10
end) as points
from 
sales s left join menu m 
on s.product_id = m.product_id
group by s.customer_id;

-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
-- not just sushi - how many points do customer A and B have at the end of January?

select s.customer_id,
sum(case
	when s.order_date >= m.join_date and s.order_date <= date_add(m.join_date, interval 6 day) then mn.price * 10 * 2
    else mn.price * 10 
end) as points
from sales s
join members m on s.customer_id = m.customer_id 
join menu mn on s.product_id = mn.product_id
where s.order_date <= '2021-01-31'
group by s.customer_id;

-- Recreate the following table output using the available data:

select s.customer_id, s.order_date, mn.product_name, mn.price,
case when s.order_date >= m.join_date then 'Y'
	else 'N'
    end as member
 from sales s
left join members m on s.customer_id = m.customer_id
left join menu mn on s.product_id = mn.product_id;

-- Rank All The Things

select x.customer_id, x.order_date, x.product_name, x.price, x.member, 
case when x.member = 'N' then 'null'
	else rank() over(partition by s.customer_id, x.member order by s.order_date asc) 
    end as ranking 
from 
(select s.customer_id, s.order_date, mn.product_name, mn.price,
case when s.order_date >= m.join_date then 'Y'
	else 'N'
    end as member
from sales s
left join members m on s.customer_id = m.customer_id
left join menu mn on s.product_id = mn.product_id) x













