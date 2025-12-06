-- Question 1: Case When

/* Write a query that gives an overview of how many films have replacement costs in the following cost ranges:
i)   low: 9.99 - 19.99 (the answer is 514)
ii)  medium: 20.00 - 24.99 (the answer is 250)
iii) high: 25.00 - 29.99 (the answer is 236) */

SELECT COUNT(*) AS number_films,
	   CASE WHEN replacement_cost <= 19.99 THEN 'low'
     		WHEN replacement_cost <= 24.99 THEN 'medium'
    		ELSE 'high' END AS cost_category
  FROM film
 GROUP BY cost_category
 ORDER BY number_films DESC;
-------------------------------------------------------------------------------------------------------------

-- Question 2: Join and Concatenate

/* Create an overview of the actors' first and last names and in how many movies they appear in. 
Which actor is part of most movies?
-> The actor that shows up on top of the list changes, Susan Davis or Gina Degeneres, depending whether we group 
actors just by name, or by name and ID as well. The code for capitalizing names was taken from the following source:
https://www.geeksforgeeks.org/sql/how-to-capitalize-first-letter-in-sql. */

-- Solution 1: Grouping just by name
SELECT first_name || ' ' || last_name AS name,
       COUNT(film_id) AS number_films
  FROM actor AS a
 INNER JOIN film_actor AS fa
	ON a.actor_id = fa.actor_id
 GROUP BY name
 ORDER BY number_films DESC;

-- Solution 2: Grouping by both name and ID
SELECT a.actor_id, 
       first_name || ' ' || last_name AS name,
       COUNT(film_id) AS number_films
  FROM actor AS a
 INNER JOIN film_actor AS fa
    ON a.actor_id = fa.actor_id
 GROUP BY name, a.actor_id
 ORDER BY number_films DESC;
-------------------------------------------------------------------------------------------------------------

-- Bonus: Finding Susan

/* E.g. Susan Davis shows up twice, with IDs 101 and 110. One of the IDs could be a mistake, especially given it has 
the same digits reordered, which might imply mistyping. But it could also be an entirely different person. 
The best way to confirm would be to reach out to the source/collector of the data. In the absence of that possibility, 
the data is grouped in 2 different ways, as demonstrated previously. 
When querying the 2 different solutions, you might notice that Susan shows up at the top of the list when treated as 
the same person, but not when treated separately. */

SELECT a.actor_id, 
       first_name || ' ' || last_name AS name,
       COUNT(film_id) AS number_movies
  FROM actor AS a
 INNER JOIN film_actor AS fa
    ON a.actor_id = fa.actor_id
 WHERE first_name || ' ' || last_name ILIKE 'Susan Davis'
 GROUP BY a.actor_id, name
 ORDER BY number_movies DESC;
-------------------------------------------------------------------------------------------------------------

-- Question 3: Multiple Joins with the USING clause

/* Create an overview of the revenue grouped by a column in the format "country, city". 
Which "country, city" has the least sales?
-> The answer is United States, Tallahassee. */

SELECT country || ', ' || city AS country_city,
       SUM(amount) AS revenue
  FROM customer AS c
  LEFT JOIN address AS a USING(address_id)
  LEFT JOIN city AS ci USING(city_id)
  LEFT JOIN country AS co USING(country_id)
 INNER JOIN payment AS p USING(customer_id)
 GROUP BY country_city
 ORDER BY revenue
 LIMIT 5;
-------------------------------------------------------------------------------------------------------------

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
-------------------------------------------------------------------------------------------------------------

-- Question 4: Uncorrelated Subquery in the FROM clause

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
 ORDER BY 1 DESC;
-------------------------------------------------------------------------------------------------------------

-- Question 5: Window Functions, CTE and running total

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
            ROUND(SUM(unit_price::numeric * quantity), 2) AS revenue_sales -- the ::numeric cast makes the ROUND formula work
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
-------------------------------------------------------------------------------------------------------------
