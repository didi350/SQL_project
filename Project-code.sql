-- Question 1: Getting familiar with the database

/* Before we begin querying data, we first need to explore which tables are available by checking the metadata.
This can be done by using information_schema.tables. */

SELECT table_schema, table_name, table_type AS type
  FROM information_schema.tables
 WHERE table_schema = 'public' -- information_schema, pg_catalog
   AND table_type IN ('BASE TABLE', 'VIEW');

-- We can also check the columns each table contains by using the query below.
SELECT table_name, column_name, data_type
  FROM information_schema.columns
 WHERE table_name = 'customer'; -- update the table name here
------------------------------------------------------------------------------------------------------------------------

-- Question 2: Categorizing with the CASE WHEN statement

/* The purpose for this exercise is to separate the discontinued products from the rest and calculate their remaining 
quantity and their value. These products are considered excess inventory (also known as dead or obsolete inventory), 
and won't be sold anymore.
-> The total value of discontinued products still in stock is $5,477.6, and the remaining quantity is 157 units in stock
(with different quantities per unit, as provided in the text column with the same name (quantity_per_unit)).
By looking at the output, you'll notice that the categories (used for the grouping) with discontinued products are not
fully discontinued. The same categories still have other products that are still being sold, and whose value is much higher.
We can further group by the unique products per category to get more details and better visibility. */

/* Renaming columns:
Given the products table and the order_details table both have columns named unit_price with different values and context, we 
should keep both and rename them (instead of droppping one of them or merging them). Renaming needs to come before creating 
potential views that join these tables; this will avoid merging the columns through the USING clause as mistaken duplicates.
We only need to rename them once. After that, we should leave the ALTER/RENAME code in comments. Running it for a second time 
wouldn't work anyway, given it can't find the columns by their old names anymore. */

-- Use this code once
-- ALTER TABLE products
-- RENAME COLUMN unit_price TO unit_price_products;

-- Use this code once
-- ALTER TABLE order_details
-- RENAME COLUMN unit_price TO unit_price_orders;

SELECT CASE WHEN p.discontinued = 1 
			THEN 'discontinued'
			END as discontinued_yn,
	   c.category_name AS category_product, -- p.product_name,
	   -- p.quantity_per_unit, -- this is just text and can only be used for grouping, but can't be aggregated itself
	   ROUND(SUM(p.unit_price_products::numeric * p.units_in_stock), 2) AS value_excess_inventory,
	   SUM(p.units_in_stock) AS units_in_stock_total,
	   COUNT(DISTINCT p.product_name) AS products_unique_per_category
  FROM products AS p
  JOIN categories AS c USING(category_id)
 GROUP BY discontinued_yn, c.category_name --, p.product_name
 ORDER BY discontinued_yn, value_excess_inventory DESC
------------------------------------------------------------------------------------------------------------------------

-- Question 3: Multiple JOINS with the USING clause

/* Create an overview of the revenue grouped by a column in the format "country, city". 
Which "country, city" has the least sales?
-> The answer is United States, Tallahassee. */

SELECT CONCAT(country, ', ', city) AS country_city,
       SUM(amount) AS revenue
  FROM customer AS c
  LEFT JOIN address AS a USING(address_id)
  LEFT JOIN city AS ci USING(city_id)
  LEFT JOIN country AS co USING(country_id)
 INNER JOIN payment AS p USING(customer_id)
 GROUP BY country_city
 ORDER BY revenue
 LIMIT 5;

/* The USING clause improves the code readability when the column shared between the tables has the same name in both.
Furthermore, it ensures that this common column will return only once, aka there won't be duplicates in the resulting 
joined table. This is especially important for views, since they don't allow columns with the same exact name even if 
they come from different tables.
An alternative to USING is simply renaming the columns, like the unit_price from the products vs order_details tables. 
But this should probably be avoided when the columns serve as primary and foreign keys in the respective tables. */
------------------------------------------------------------------------------------------------------------------------

-- Bonus: Why use Left and Inner Joins?

/* With the customer table, Left joins are used because we want to keep all customers, but we don't need all addresses, 
cities and countries - including those not related to any customer. Regarding the payment table, it should ideally 
be joined with an Inner or Right join (given the ordering), even though Full join will give the same results in this 
case. This could be because it would be odd to have payments not related to any customer, as payments must be made by 
somebody. The opposite, having customers not related to a payment, could be considered odd too, but it’s not impossible. 
The company could categorize as a customer someone who uses the service/product but doesn't necessarily pay, e.g. 
multiple users of a Netflix account. Or it could have customers who are invoiced, but haven't paid yet.
Since we're interested in the revenue, we care more about including all the payments and not necessarily including 
all the customers, hence the Inner (or Right) join. */
------------------------------------------------------------------------------------------------------------------------

-- Question 4: GROUP BY versions with different results

/* Create an overview of the actors' first and last names and in how many movies they appear in. 
Which actor is part of most movies?
-> The actor that shows up on top of the list changes, Susan Davis or Gina Degeneres, depending whether we group actors 
just by name, or both by their name and their actor ID. We'll investigate why just below this code. */

SELECT CONCAT(first_name, ' ', last_name) AS full_name,
	   -- a.actor_id, -- the different version
       COUNT(film_id) AS number_films
  FROM actor AS a
 INNER JOIN film_actor AS fa USING (actor_id)
 GROUP BY full_name --, a.actor_id -- the different version
 ORDER BY number_films DESC;

/* The reason why (Finding Susan):
The actor Susan Davis shows up twice, with IDs 101 and 110. One of the IDs could be a mistake, especially given it has 
the same digits reordered, which might imply mistyping. But it could also be an entirely different person. 
The best way to confirm would be to reach out to the source/collector of the data. In the absence of that possibility, 
the data is grouped in 2 different ways, as demonstrated beforehand. 
When querying with and without grouping by actor ID, Susan shows up at the top of the list when treated as the same person, 
but not when treated separately. This goes to show how important the small details are. */

SELECT a.actor_id, 
       CONCAT(first_name, ' ', last_name) AS name,
       COUNT(film_id) AS number_movies
  FROM actor AS a
 INNER JOIN film_actor AS fa
    ON a.actor_id = fa.actor_id
 WHERE CONCAT(first_name, ' ', last_name) ILIKE 'Susan Davis'
 GROUP BY a.actor_id, name
 ORDER BY number_movies DESC;
------------------------------------------------------------------------------------------------------------------------

-- Question 5: Uncorrelated Subquery in the FROM clause

/* Create a query that shows average daily revenue by the day of the week. 
What is the average daily revenue of all Sundays?
-> The answer is $1,410.65. */

SELECT EXTRACT(ISODoW FROM date) AS day_of_week,
       ROUND(AVG(total_per_day), 2) AS avg_daily_revenue
  FROM (SELECT DATE(payment_date), -- the DATE function is used to exclude timezones and avoid grouping by timezones
			   SUM(amount) AS total_per_day -- this sums by "DATE(payment_date)", but not yet by weekday
     	  FROM payment
     	 GROUP BY DATE(payment_date)) AS revenue_per_date
 GROUP BY day_of_week
 ORDER BY day_of_week;
------------------------------------------------------------------------------------------------------------------------

-- Question 6: CTE, Window Function and running total

/* The management team is interested in the monthly sales performance (i.e. revenue), and wants to identify trends to 
support strategic decision-making. This can be done by aggregating the sales data and calculating a running total of 
the sales revenue by month. This will provide the management team with a clear depiction of sales trends and help identify
periods of high or low sales activity. We can additionally include the ship_country or some other field to get more details.

The DATE_TRUNC function is used to truncate the order_date to the nearest month. EXTRACT(MONTH FROM order_date) works 
too, but doesn't fit in this case because we need both the year and the month.
It would make sense to include percentage growth by using the LAG() or LEAD() window functions, but for the purposes 
of this demonstration, we'll keep just the running total. The former might require creating more complex code. */

WITH monthly_revenue AS (
     SELECT -- ship_country,
            DATE_TRUNC('MONTH', order_date)::date AS month_year, -- the ::date cast is used to remove the timestamps
            ROUND(SUM(unit_price_orders::numeric * quantity), 2) AS revenue_sales -- the ::numeric cast is needed for ROUND to work
       FROM orders AS o
      INNER JOIN order_details AS od
      USING(order_id) -- instead of the ON clause, given the column has the same name in both tables
      GROUP BY month_year -- , ship_country
)

SELECT month_year, revenue_sales, -- ship_country,
       SUM(revenue_sales) OVER (-- PARTITION BY ship_country -- if more details are needed
	   					  ORDER BY month_year
           				  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
						 ) AS revenue_running_total
  FROM monthly_revenue
 ORDER BY month_year;
------------------------------------------------------------------------------------------------------------------------
