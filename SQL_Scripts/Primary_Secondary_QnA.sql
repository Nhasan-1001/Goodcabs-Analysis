-- 1. Top 3 and Bottom 3 cities by total trips over the entire analysis period.
use trips_db;
with city_trip as (
select 
	fact_trips.city_id,
    city_name,
	count(trip_id) total_trip
from fact_trips 
left join dim_city on fact_trips.city_id = dim_city.city_id
group by city_id
),
top_bottom as (
select
	city_id, city_name, total_trip,
    row_number() over(order by total_trip desc) as top_rank,
    row_number() over(order by total_trip asc) as bottom_rank
from city_trip
)
select city_id, city_name, total_trip, concat('top- ',top_rank) as rank_category from top_bottom where top_rank <= 3
union all
select city_id, city_name, total_trip, concat('bottom- ', bottom_rank) as rank_category from top_bottom where bottom_rank <= 3;

-- --------------------------------------------------------------------------------------------------------------------------------------------------

-- 2. Average fare per trip by city.
use trips_db;

-- Calculate the average fare per trip for each city and compare it with the city's average trip distance. 

with city_trip_fact as (
	select fact_trips.*, dim_city.city_name
    from fact_trips
    left join dim_city on fact_trips.city_id = dim_city.city_id
),
city_avg_fare as (
	select
		city_name,
		round(avg(fare_amount),2) as avg_fare_per_trip
	from city_trip_fact
	group by city_name
),
city_avg_distance as(
	select
		city_name,
		round(avg(distance_travelled_km),2) as avg_trip_distance_km
	from city_trip_fact
	group by city_name
)
select
	city_avg_distance.city_name,
	avg_fare_per_trip,
	avg_trip_distance_km
from city_avg_distance 
join city_avg_fare
on city_avg_distance.city_name = city_avg_fare.city_name;

-- Identify the cities with the highest and lowest average fare per trip to assess pricing efficiency accross locations.

with avg_fare_distance as (
	with city_trip_fact as (
		select fact_trips.*, dim_city.city_name
		from fact_trips
		left join dim_city on fact_trips.city_id = dim_city.city_id
    ),
	city_avg_fare as (
		select
			city_name,
			round(avg(fare_amount),2) as avg_fare_per_trip
		from city_trip_fact
		group by city_name
	),
	city_avg_distance as(
		select
			city_name,
			round(avg(distance_travelled_km),2) as avg_trip_distance_km
		from city_trip_fact
		group by city_name
	)
	select
		city_avg_distance.city_name,
		avg_fare_per_trip,
		avg_trip_distance_km,
		row_number() over(order by avg_fare_per_trip desc) as desc_rank, -- Highest Fare: desc_rank = 1
		row_number() over(order by avg_fare_per_trip asc) as asc_rank -- Lowest Fare: asc_rank = 1
	from city_avg_distance 
	join city_avg_fare
	on city_avg_distance.city_name = city_avg_fare.city_name
)
select city_name, avg_fare_per_trip, 'Highest Fare' as fare_category from avg_fare_distance where desc_rank = 1
union all 
select city_name, avg_fare_per_trip, 'Lowest Fare' as fare_category from avg_fare_distance where asc_rank = 1;

-- --------------------------------------------------------------------------------------------------------------------------------------------------

-- 3. Average Ratings by City and Passenger Type

-- Average Passenger Rating, Driver Rating based on each City, segmented by Passenger Type
with city_trip_fact as (
	select fact_trips.*, dim_city.city_name
    from fact_trips
    left join dim_city on fact_trips.city_id = dim_city.city_id
)
select
	city_name,
    passenger_type,
    round(avg(passenger_rating),2) as avg_passenger_rating,
    round(avg(driver_rating),2) as avg_driver_rating
from city_trip_fact
group by city_name, passenger_type;

-- Cities with Highest and Lowest Average Ratings

with city_trip_fact as (
	select fact_trips.*, dim_city.city_name
    from fact_trips
    left join dim_city on fact_trips.city_id = dim_city.city_id
),
rating_ranking as (
	select
	city_name,
    round(avg(passenger_rating),2) as avg_passenger_rating,
    round(avg(driver_rating),2) as avg_driver_rating,
    row_number() over(order by avg(passenger_rating) desc) as p_desc_rank, -- Highest Passenger Rank: p_desc_rank = 1
    row_number() over(order by avg(passenger_rating) asc) as p_asc_rank, -- Lowest Passenger Rank: p_asc_rank = 1
	row_number() over(order by avg(driver_rating) desc) as d_desc_rank, -- Highest Driver Rank: d_desc_rank = 1
    row_number() over(order by avg(driver_rating) asc) as d_asc_rank -- Lowest Driver Rank: d_asc_rank = 1
from city_trip_fact
group by city_name
)
select city_name, avg_passenger_rating, 'Highest Passenger Rating' as rating_category from rating_ranking where p_desc_rank = 1
union all 
select city_name, avg_passenger_rating, 'Lowest Passenger Rating' as rating_category from rating_ranking where p_asc_rank = 1;

-- --------------------------------------------------------------------------------------------------------------------------------------------------

-- 4. Peak and Low Demand Months by City
with city_trip_fact as (
	select fact_trips.*, dim_city.city_name
    from fact_trips
    left join dim_city on fact_trips.city_id = dim_city.city_id
),
ranking as (
	select
	city_name,
    month,
    total_trip,
    row_number() over(partition by city_name order by total_trip desc) as desc_rank, -- Highest Total Trips: desc_rank = 1
    row_number() over(partition by city_name order by total_trip asc) as asc_rank -- Lowest Total Trips: asc_rank = 1
from (
		select 
			city_name,
			monthname(date) as 'month',
			count(trip_id) as total_trip
		from city_trip_fact
		group by city_name,month
) as city_trip_month
),
low_months as (
-- Low demand months for each city
select city_name, month, total_trip from ranking where asc_rank = 1
),
high_months as (
-- Peak demand months for each city
select city_name, month, total_trip from ranking where desc_rank = 1
)
select 
	high_months.city_name, high_months.month as peak_months, high_months.total_trip as peak_trips, 
    low_months.month as low_months, low_months.total_trip as low_trips
from high_months join low_months on high_months.city_name = low_months.city_name;


-- --------------------------------------------------------------------------------------------------------------------------------------------------

-- 5. Weekend Vs. Weekday Trip Demand by City

with trip_date_type as (
	with trip_table as (
		select 
			trip_id, ft.date as date, ft.city_id as city_id, 
			dc.city_name as city_name,
			dd.month_name as month_name, dd.day_type as date_type
		from fact_trips ft 
		left join dim_city dc on ft.city_id = dc.city_id
		left join dim_date dd on ft.date = dd.date
	)
	select
		city_name, date_type, count(trip_id) as total_trip,
        lag(count(trip_id)) over(partition by city_name order by count(trip_id)) as prev_rec
	from trip_table
	where date between "2024-01-01" and "2024-06-30"
	group by city_name, date_type
),
city_wise_demand as (
select 
	city_name,
    date_type,
    total_trip,
    case 
		when total_trip > prev_rec then "Most Demand"
        else "Least Demand"
	end as demand_category
from trip_date_type
)
select 
	city_name, date_type, total_trip, demand_category
from city_wise_demand 
where demand_category = "Most Demand";


-- --------------------------------------------------------------------------------------------------------------------------------------------------


-- 6. Repeat Passenger Frequency and City Contribution Analysis

with main_table as (
		with cte as (
		select 
			trip_id, ft.date as dates, ft.city_id, passenger_type, distance_travelled_km, fare_amount, passenger_rating, driver_rating, city_name,famous_for
		from fact_trips ft
		left join dim_city dc
		on ft.city_id = dc.city_id
	)
		select
			city_name, famous_for,
			count(trip_id) as frequency_of_trips
		from cte
		where passenger_type = 'repeated'
		group by city_name, famous_for
)
select *
from main_table
order by frequency_of_trips desc; -- Insight: Most of the Tourism-Focused cities are at the behind of the Business-Focused cities, by higher trip frequencies of the repeated passengers. 


-- --------------------------------------------------------------------------------------------------------------------------------------------------

-- 7. Monthly Target Achievement Analysis for Key Metrics

-- Monthly total trips achieved Vs. Monthly trips target, by city and month
with cte as (
	with t1 as (
		select 
			ft.*, city_name, month_name, start_of_month
		from fact_trips ft
		left join dim_city dc on ft.city_id = dc.city_id
		left join dim_date dd on ft.date = dd.date
	),
	t2 as (
	select * from targets_db.monthly_target_trips
	)
	select t1.*, t2.total_target_trips
	from t1 left join t2 
	on t1.start_of_month = t2.month and t1.city_id = t2.city_id
)
select 
	city_name,
    month_name,
    count(trip_id) as monthly_trips_achieved,
    total_target_trips as monthly_trips_target
from cte
group by city_name, month_name, total_target_trips;

-- New Passengers Vs. Average Passengers target ratings by Cities

with cte as (
	with t1 as (
		select 
			ft.*, city_name, month_name, start_of_month
		from fact_trips ft
		left join dim_city dc on ft.city_id = dc.city_id
		left join dim_date dd on ft.date = dd.date
	),
	t2 as (
	select * from targets_db.city_target_passenger_rating
	)
	select t1.city_id, city_name, date, passenger_type, passenger_rating 
    , t2.target_avg_passenger_rating
	from t1 left join t2 
	on t1.city_id = t2.city_id
)

select
	city_name,
    round(avg(passenger_rating),2) as avg_rating_achieved,
    target_avg_passenger_rating as avg_target_rating
from cte
where passenger_type = 'new'
group by city_name, avg_target_rating
order by avg_rating_achieved desc; -- Insight: In each city New Passenger's average rating meets with average rating target

-- Target Analysis 




