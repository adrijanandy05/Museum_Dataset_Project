--Identify the museums which are open on both Sunday and Monday. Display museum name, city.
with sunday_monday_open AS(
  SELECT DISTINCT museum_hours.museum_id
  FROM museum_hours
  WHERE museum_hours.day='Sunday'
  INTERSECT
  SELECT DISTINCT museum_hours.museum_id
  FROM museum_hours
  WHERE museum_hours.day='Monday')
SELECT DISTINCT t1.name, t1.city
FROM museum t1
JOIN sunday_monday_open t2
on t1.museum_id=t2.museum_id


--Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
WITH max_duration as(
  SELECT museum_id,day,
  to_timestamp(close, 'HH:MI PM')-to_timestamp(open,'HH:MI AM') as duration,
  max(to_timestamp(close, 'HH:MI PM')-to_timestamp(open,'HH:MI AM'))
  OVER() as max_duration
  FROM museum_hours
)
SELECT t2.name, t2.state, t1.duration as hours_open, t1.day
FROM max_duration t1
JOIN museum t2
ON t1.museum_id=t2.museum_id
WHERE t1.duration=t1.max_duration


--Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.
with country_count as(
  SELECT country,
  COUNT(1) as country_count,
  rank() OVER(ORDER by count(1) DESC) as rnk
  FROM museum
  GROUP by 1
),
city_count AS(
  SELECT city,
  COUNT(1) as city_count,
  rank() OVER(ORDER by count(1) DESC) as rnk
  FROM museum
  GROUP by 1
)
SELECT string_agg(DISTINCT t1.country,',') as country,
string_agg(t2.city,',') as city
FROM country_count t1
CROSS join city_count t2
WHERE t1.rnk=1 and t2.rnk=1;


-- Fetch all the paintings which are not displayed on any museums?
SELECT * FROM work WHERE museum_id is NULL
SELECT * FROM work WHERE museum_id='30'

--Are there museums without any paintings?
SELECT t1.*
FROM museum t1
JOIN work t2
on t1.museum_id not in (SELECT museum_id FROM work)

--How many paintings have an asking price of more than their regular price?
SELECT * FROM product_size WHERE sale_price>regular_price

-- Identify the paintings whose asking price is less than 50% of its regular price
SELECT * FROM product_size WHERE sale_price<(0.5*regular_price)

--Which canva size costs the most?
with cte1 as(
  SELECT t1.size_id, t1.sale_price,t2.label,
  rank() over(order by t1.sale_price desc) as rnk
  FROM product_size t1
  JOIN canvas_size t2 
  on t1.size_id=t2.size_id)
SELECT size_id,sale_price,label
FROM cte1
WHERE rnk=1

--Delete duplicate records from work, product_size, subject and image_link tables
DELETE FROM subject WHERE work_id NOT in(
SELECT MIN(work_id) FROM subject GROUP by work_id)

DELETE FROM product_size WHERE work_id NOT in(
SELECT MIN(work_id) FROM product_size GROUP by work_id)

DELETE FROM work WHERE work_id NOT in(
SELECT MIN(work_id) FROM work GROUP by work_id)

--Identify the museums with invalid city information in the given dataset
select * from museum 
	where city ~ '^[0-9]'
    
--Fetch the top 10 most famous painting subject
SELECT subject, no_of_records FROM(
  SELECT subject, COUNT(*) as no_of_records, 
  RANK() OVER(order by count(*) desc) as rnk 
  FROM subject 
  GROUP by subject)
WHERE rnk<=10

-- Identify the museums which are open on both Sunday and Monday. Display museum name, city
with cte as(
  SELECT museum_id FROM(
    SELECT museum_id,day,
    ROW_NUMBER() over(PARTITION by museum_id) as rnk 
    FROM museum_hours
    WHERE day='Sunday' OR day='Monday')
  WHERE rnk=2)
SELECT t2.museum_id,t1.name,t1.city
FROM museum t1
JOIN cte t2
ON t1.museum_id=t2.museum_id

--How many museums are open every single day?
SELECT COUNT(*) FROM(
SELECT *,
ROW_NUMBER() over(PARTITION by museum_id) as rnk 
FROM museum_hours)
WHERE rnk=7

--Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
SELECT museum_id FROM(
  SELECT museum_id,COUNT(museum_id),
  rank() over(order by count(museum_id) desc) as rnk 
  FROM work 
  GROUP by museum_id)
WHERE rnk<=5

--Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)
SELECT artist_id FROM(
  SELECT artist_id,COUNT(artist_id),
  rank() over(order by count(artist_id) desc) as rnk 
  FROM work 
  GROUP by artist_id)
WHERE rnk<=5

--Display the 3 least popular canva sizes

select label,ranking,no_of_paintings
	from (
		select cs.size_id,cs.label,count(1) as no_of_paintings
		, dense_rank() over(order by count(1) ) as ranking
		from work w
		join product_size ps on ps.work_id=w.work_id
		join canvas_size cs on cs.size_id = ps.size_id
		group by cs.size_id,cs.label) x
	where x.ranking<=3;

-- Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
with cte1 as(
  SELECT museum_id,day,
  cast(open as time) as open_time,cast(close as time) as close_time,
  (cast(close as time)-cast(open as time)) as duration
  FROM museum_hours
  order by 5 desc),
  cte2 as(
    SELECT max(duration) as max_duration
    FROM cte1)
SELECT t1.name,t1.state,t2.day,t2.duration
FROM museum t1
join cte1 t2
ON t1.museum_id=t2.museum_id
JOIN cte2 t3
ON t2.duration=t3.max_duration

--Which museum has the most no of most popular painting style?
with style_cte as(
  SELECT DISTINCT style,museum_id, count(work_id) as no_of_works,
  rank() over(order by count(work_id) desc) as rnk
  FROM work
  where style is not NULL
  and museum_id is not NULL
  GROUP by 1,2
  order by 4)
SELECT t2.name,style,no_of_works
FROM style_cte t1
JOIN museum t2
on t1.museum_id=t2.museum_id
where rnk=1

--Identify the artists whose paintings are displayed in multiple countries
with cte1 as(
  SELECT DISTINCT t2.country,t3.full_name
  FROM work t1
  JOIN museum t2
  on t1.museum_id=t2.museum_id
  join artist t3
  on t1.artist_id=t3.artist_id
  WHERE t1.museum_id is not NULL)
SELECT full_name,count(country) as no_of_countries
FROM cte1
GROUP by 1
having count(country)>1
order by 2 desc;

--Which country has the 5th highest no of paintings
with cte1 as(
  SELECT t1.country,COUNT(t2.work_id) as no_of_paintings,
  RANK() over(order by COUNT(t2.work_id) desc) as rnk
  FROM museum t1
  JOIN work t2
  on t1.museum_id=t2.museum_id
  and t2.museum_id is not NULL
  GROUP by 1)
SELECT country,no_of_paintings
FROM cte1
WHERE rnk=5

--Which are the 3 most popular and 3 least popular painting styles?
SELECT style,
case when rnk<=3 then 'Most Popular' else 'Least Popular' END as remarks from(
SELECT style, count(1) as no_of_works,
rank() OVER(order by count(1) desc) as rnk,
count(1) over() as no_of_records
FROM work WHERE style is not NULL GROUP by 1)
where rnk<=3
or rnk>no_of_records-3

--Which artist has the most no of Portraits paintings outside USA?. Display artist name, no of paintings and the artist nationality
with cte1 as(
  SELECT artist.full_name,artist.nationality,count(work.work_id) as no_of_paintings,
  rank() over(order by count(work.work_id) desc) as rnk
  FROM artist
  join work
  ON artist.artist_id=work.artist_id
  JOIN museum
  on work.museum_id=museum.museum_id
  JOIN subject 
  on work.work_id=subject.work_id
  WHERE subject.subject='Portraits'
  and museum.country<>'USA'
  GROUP by 1,2)
SELECT full_name,nationality,no_of_paintings
FROM cte1
WHERE rnk=1

--Identify the artist and the museum where the most expensive and least expensive
--painting is placed. Display the artist name, sale_price, painting name, museum
--name, museum city and canvas label
with cte as(
  SELECT *,
  rank() over(order by sale_price desc) as rnk1,
  rank() over(order by sale_price) as rnk2
  FROM product_size)
SELECT t3.full_name as artist_name,t1.name as painting_name,cte.sale_price,
t2.name as museum_name,t2.city as museum_city,t4.label as canvas_label
FROM cte
join work t1
on cte.work_id=t1.work_id
join museum t2
ON t1.museum_id=t2.museum_id
JOIN artist t3
ON t1.artist_id=t3.artist_id
JOIN canvas_size t4
on cte.size_id=t4.size_id
where rnk1=1 or rnk2=1

--Display the country and the city with most no of museums. Output 2 seperate
--columns to mention the city and country. If there are multiple value, seperate them
--with comma.

with country_cte as(
  SELECT country,count(museum_id) as no_of_museums,
  rank() over(order by count(museum_id) desc) as rnk
  FROM museum 
  GROUP by 1),
  city_cte as(
    SELECT city,count(museum_id) as no_of_museums,
    rank() over(order by count(museum_id) desc) as rnk
    FROM museum
    GROUP by 1)
SELECT string_agg(distinct t1.country,', ') as country, string_agg(t2.city,', ') as city
FROM country_cte t1
cross join city_cte t2
where t1.rnk=1 and t2.rnk=1