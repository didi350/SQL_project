-------------------------------------------------------------------------------------------

-- Question 1: Case When

/* Write a query that gives an overview of how many films have replacements costs in the following cost ranges:
i)   low: 9.99 - 19.99
ii)  medium: 20.00 - 24.99
iii) high: 25.00 - 29.99
*/

SELECT 
COUNT(*),
CASE 
     WHEN replacement_cost <= 19.99 THEN 'low'
     WHEN replacement_cost <= 24.99 THEN 'medium'
     ELSE 'high'
     END as cost_category
FROM film
GROUP BY cost_category
ORDER BY Count(*) DESC

-------------------------------------------------------------------------------------------


-- Question 2: Join & Concatenate

/* Create an overview of the actors' first and last names and in how many movies they appear in. 
Which actor is part of most movies?
-> The actor that shows up on top of the list changes, depending whether we group actors just by name, or by name and ID as well. 
*/

-- Solution 1: Grouping just by name
SELECT 
     first_name || ' ' || last_name as name,
     COUNT(film_id) as number_movies
FROM actor a
INNER JOIN film_actor fa
     ON a.actor_id = fa.actor_id
GROUP BY name
ORDER BY number_movies DESC

-- Solution 2: Grouping by both name and ID
SELECT
     a.actor_id, 
     first_name || ' ' || last_name as name,
     COUNT(film_id) as number_movies
FROM actor a
INNER JOIN film_actor fa
     ON a.actor_id = fa.actor_id
GROUP BY name, a.actor_id
ORDER BY number_movies DESC

-- Extra: Finding Susan
/* E.g. Susan Davis shows up twice, with IDs 101 and 110. 
One of the IDs could be a mistake, especially since it has the same digits reordered, making it easy to mistype.
But it could also be a different person. 
The best way to confirm would be to reach out to the source/collector of the data. 
In the absence of that possibility, the data is grouped in 2 different ways, as demonstrated above.
When querying the 2 different solutions, it can be noticed that Susan shows up at the top of the list when treated as the same person, but not when treated separately.
*/
-- Code to find Susan
SELECT
     a.actor_id, 
     first_name || ' ' || last_name as name,
     COUNT(film_id) as number_movies
FROM actor a
INNER JOIN film_actor fa
     ON a.actor_id = fa.actor_id
WHERE first_name || ' ' || last_name ILIKE 'Susan Davis'
GROUP BY a.actor_id, name
ORDER BY number_movies DESC

-------------------------------------------------------------------------------------------


-- Question 3: Multiple Joins

/* Create an overview of the revenue grouped by a column in the format "country, city". 
Which "country, city" has the least sales?
*/

SELECT
     country || ', ' || city as country_city,
     SUM(amount) as revenue
FROM customer c
LEFT JOIN address a
     On a.address_id = c.address_id
LEFT JOIN city ci
     On ci.city_id = a.city_id
LEFT JOIN country co
     On co.country_id = ci.country_id
INNER JOIN payment p
     On p.customer_id = c.customer_id
GROUP BY country_city
ORDER BY revenue ASC
LIMIT 5

-------------------------------------------------------------------------------------------


-- Question 4: Uncorrelated Subquery & Extract

/* Create a query that shows average daily revenue by the day of the week. 
What is the average daily revenue of all Sundays?
*/

SELECT
     EXTRACT(ISODoW from date) as day_of_week,
     ROUND(AVG(total_per_day),2) as avg_daily_revenue
FROM
     (SELECT
          DATE(payment_date),
          SUM(amount) as total_per_day
     FROM payment
     GROUP BY DATE(payment_date))
GROUP BY day_of_week
ORDER BY 1 DESC

-- Notes
-- We need to use "Date(payment_date)" bc the "payment_date" includes timezones and groups by timezones.
-- "total_per_day" is the sum for the "Date(payment_date)", aka not yet by weekday.

-------------------------------------------------------------------------------------------