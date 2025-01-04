


-- BUSINESS REQUEST: 1 - City Level Fare & Trip Summary Report

USE trips_db;
SELECT
	city_name,
    COUNT(trip_id) AS total_trips,
    ROUND(AVG(fare_amount/distance_travelled_km),2) AS avg_fare_per_km,
    ROUND(AVG(fare_amount),2) AS avg_fare_per_trip,
    CONCAT(
		ROUND((COUNT(trip_id) * 100) / (SELECT COUNT(trip_id) FROM fact_trips))
	,"%") AS '%_contribution_to_total_trips'
FROM
	fact_trips 
LEFT JOIN dim_city ON fact_trips.city_id = dim_city.city_id
GROUP BY city_name
ORDER BY total_trips DESC;



-- BUSINESS REQUEST: 2 - Monthly City Level Trips Target Performance Report 

WITH city_target AS (
	SELECT
		city_name,
        monthly_target_trips.month,
		month_name,
		COUNT(fact_trips.trip_id) AS actual_trips,
		total_target_trips AS target_trips
	FROM fact_trips 
	LEFT JOIN dim_city ON fact_trips.city_id = dim_city.city_id
	LEFT JOIN dim_date ON fact_trips.date = dim_date.date
	LEFT JOIN targets_db.monthly_target_trips ON monthly_target_trips.month = dim_date.start_of_month 
		AND fact_trips.city_id = monthly_target_trips.city_id
	GROUP BY city_name, month_name, total_target_trips, monthly_target_trips.month
	)
SELECT
	city_name,
	month_name,
	actual_trips,
	target_trips,
	CASE
		WHEN actual_trips > target_trips THEN "Above Target"
		WHEN actual_trips < target_trips THEN "Below Target"
		ELSE "Equal to Target"
	END AS performance_status,
    CONCAT(
			ROUND(((actual_trips - target_trips ) * 100) / (target_trips),2)
            ,"%")
    AS "%_difference"
FROM city_target
ORDER BY city_name, month;



-- BUSINESS REQUEST: 3 - City Level Repeat Passenger Trip Frequency Report

WITH main_table AS (
	WITH passenger_each_city_trip AS(
			SELECT 
				dim_city.city_id,
                city_name,
				trip_count,
				SUM(repeat_passenger_count) AS total_passenger1
			FROM dim_repeat_trip_distribution
            JOIN dim_city 
            ON dim_repeat_trip_distribution.city_id = dim_city.city_id
			GROUP BY dim_city.city_id, trip_count, city_name
		),

	passenger_each_city AS (
			SELECT 
				city_id,
				SUM(repeat_passenger_count) AS total_passenger2
			FROM dim_repeat_trip_distribution
			GROUP BY city_id
		)
        
	SELECT 
		city_name,
		t1.trip_count,
		total_passenger1,
		total_passenger2,
		ROUND((total_passenger1 * 100 / total_passenger2),2) AS p_distribution
	FROM passenger_each_city_trip t1
	JOIN passenger_each_city t2
	ON t1.city_id = t2.city_id
)
    
SELECT
	city_name,
    CONCAT(SUM(CASE WHEN trip_count = '2-Trips' THEN p_distribution ELSE NULL END),'%') AS '2-Trips',
    CONCAT(SUM(CASE WHEN trip_count = '3-Trips' THEN p_distribution ELSE NULL END),'%') AS '3-Trips',
	CONCAT(SUM(CASE WHEN trip_count = '4-Trips' THEN p_distribution ELSE NULL END),'%') AS '4-Trips',
    CONCAT(SUM(CASE WHEN trip_count = '5-Trips' THEN p_distribution ELSE NULL END),'%') AS '5-Trips',
    CONCAT(SUM(CASE WHEN trip_count = '6-Trips' THEN p_distribution ELSE NULL END),'%') AS '6-Trips',
    CONCAT(SUM(CASE WHEN trip_count = '7-Trips' THEN p_distribution ELSE NULL END),'%') AS '7-Trips',
    CONCAT(SUM(CASE WHEN trip_count = '8-Trips' THEN p_distribution ELSE NULL END),'%') AS '8-Trips',
    CONCAT(SUM(CASE WHEN trip_count = '9-Trips' THEN p_distribution ELSE NULL END),'%') AS '9-Trips',
    CONCAT(SUM(CASE WHEN trip_count = '10-Trips' THEN p_distribution ELSE NULL END),'%') AS '10-Trips'
FROM main_table
GROUP BY city_name
ORDER BY city_name DESC;



-- BUSINESS REQUEST: 4 - Identify Cities with Highest and Lowest Total New Passengers

WITH main_table AS (
	WITH new_passengers AS (
			SELECT 
				city_name,
				count(passenger_type) AS total_new_passengers,
				RANK() OVER(ORDER BY count(passenger_type) DESC) AS rnk_desc,
				RANK() OVER(ORDER BY count(passenger_type) ASC) AS rnk_asc
			FROM fact_trips
			LEFT JOIN dim_city 
			ON fact_trips.city_id = dim_city.city_id
			WHERE passenger_type = 'new'
			GROUP BY city_name
		)
	SELECT 
		city_name,
		total_new_passengers,
		CASE 
			WHEN rnk_desc <= 3 THEN 'Top 3'
			WHEN rnk_asc <= 3 THEN 'Bottom 3'
		END AS city_category
	FROM new_passengers
	)
SELECT * FROM main_table
WHERE city_category IN ('Top 3', 'Bottom 3')
ORDER BY total_new_passengers DESC;



-- BUSINESS REQUEST: 5 - Month with Highest Revenue for Each City

WITH top_revenue AS (
		WITH temp1 AS (
				SELECT 
					city_name,
					month_name,
					SUM(fare_amount) AS revenue,
					ROW_NUMBER() OVER(PARTITION BY city_name ORDER BY SUM(fare_amount) DESC) AS rn_dsc
				FROM fact_trips
				LEFT JOIN dim_city ON fact_trips.city_id = dim_city.city_id
				LEFT JOIN dim_date ON fact_trips.date = dim_date.date
				GROUP BY city_name, month_name
				)
		 SELECT * 
		 FROM temp1 
		 WHERE rn_dsc = 1
		),
total_revenue AS (
		WITH temp2 AS (
				SELECT 
					city_name,
					month_name,
					SUM(fare_amount) AS revenue,
					ROW_NUMBER() OVER(PARTITION BY city_name ORDER BY SUM(fare_amount) DESC) AS rn_dsc
				FROM fact_trips
				LEFT JOIN dim_city ON fact_trips.city_id = dim_city.city_id
				LEFT JOIN dim_date ON fact_trips.date = dim_date.date
				GROUP BY city_name, month_name
				)
				SELECT 
					city_name,
					SUM(revenue) AS total_rev
				FROM temp2
				GROUP BY city_name
        )

	SELECT 
		top_revenue.city_name,
        top_revenue.month_name,
        top_revenue.revenue,
        CONCAT(ROUND((top_revenue.revenue * 100 / total_rev),2),'%') AS percentage_distribution
	FROM top_revenue
	JOIN total_revenue 
	ON top_revenue.city_name = total_revenue.city_name;



-- BUSINESS REQUEST: 6 - Repeat Passenger Rate Analysis

WITH total_pass AS (
	SELECT 
		fact_trips.city_id,
		city_name,
		month_name,
		COUNT(*) AS total_passengers
	FROM fact_trips
	LEFT JOIN dim_city ON fact_trips.city_id = dim_city.city_id
	LEFT JOIN dim_date ON fact_trips.date = dim_date.date
	GROUP BY fact_trips.city_id, city_name, month_name
	),
	
repeat_pass AS (
	SELECT 
		city_id,
		month_name,
		COUNT(*) AS repeat_passengers
	FROM fact_trips
	LEFT JOIN dim_date ON fact_trips.date = dim_date.date
	WHERE passenger_type = 'repeated'
	GROUP BY city_id, month_name
	),
	
monthly_repeat_ AS (
	SELECT 
		city_name,
		total_pass.month_name,
		total_passengers,
		repeat_passengers,
		CONCAT((ROUND((repeat_passengers * 100 / total_passengers),2)),'%') AS monthly_repeat_passenger_rate
	FROM total_pass 
	JOIN repeat_pass 
	ON total_pass.city_id = repeat_pass.city_id 
	AND total_pass.month_name = repeat_pass.month_name
	),
	
overall_pass AS (    
	SELECT
		city_name,
		SUM(total_passengers) AS overall_total_passenger,
		SUM(repeat_passengers) AS overall_repat_passenger,
		CONCAT((ROUND((SUM(repeat_passengers) * 100 / SUM(total_passengers)),2)),'%') AS city_repeat_passenger_rate
	FROM total_pass 
	JOIN repeat_pass 
	ON total_pass.city_id = repeat_pass.city_id 
	AND total_pass.month_name = repeat_pass.month_name
	GROUP BY city_name
	)

SELECT 
	monthly_repeat_.city_name,
    monthly_repeat_.month_name AS 'month',
    monthly_repeat_.total_passengers,
    monthly_repeat_.repeat_passengers,
    monthly_repeat_.monthly_repeat_passenger_rate,
    overall_pass.city_repeat_passenger_rate
FROM  monthly_repeat_
JOIN overall_pass
ON monthly_repeat_.city_name = overall_pass.city_name;



--                                                        ---------- *********** ----------
		
