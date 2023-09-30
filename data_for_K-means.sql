--Creating a cohort1 query to filter on number of sessions
WITH cohort1 AS 
	(SELECT user_id, COUNT (*) AS num_sessions 
	FROM sessions 
	WHERE session_start >='2023-01-04' --filtering on day, after wich we interested in our data 
	GROUP By user_id), 

-- selecting needed colums from user table, converting birthdate to age, calculating rates and averages
cohort2 AS (SELECT s.user_id,count(s.trip_id) as num_trips,num_sessions,EXTRACT(YEAR FROM AGE(u.birthdate)) AS age,gender,married,has_children,
            	AVG(DATE_PART('second', session_end - session_start)) as avg_session,
                CASE WHEN COUNT(s.trip_id) > 0 THEN (SUM(CASE WHEN flight_booked is TRUE AND hotel_booked IS TRUE THEN 1 ELSE 0 END)::FLOAT /
		   					SUM(CASE WHEN flight_booked IS TRUE OR hotel_booked IS TRUE THEN 1 ELSE 0 END)) ELSE NULL END AS booking_rate,
                CASE WHEN COUNT(s.trip_id) > 0 THEN (SUM(CASE WHEN cancellation is TRUE THEN 1 ELSE 0 END)::FLOAT /
		   					SUM(CASE WHEN flight_booked IS TRUE OR hotel_booked IS TRUE THEN 1 ELSE 0 END)) ELSE NULL END AS cancellation_rate,
                SUM(CASE WHEN s.flight_discount THEN 1 ELSE 0 END) :: FLOAT / COUNT(*) AS discount_flight_proportion,
                ROUND(AVG(s.flight_discount_amount), 2) AS average_flight_discount,
				SUM(s.flight_discount_amount*f.base_fare_usd) / 
                    SUM(haversine_distance(home_airport_lat, home_airport_lon, destination_airport_lat, destination_airport_lon)) AS ADS,
				SUM(CASE WHEN s.hotel_discount THEN 1 ELSE 0 END) :: FLOAT / COUNT(*) AS discount_hotel_proportion,
                ROUND(AVG(s.hotel_discount_amount), 2) AS average_hotel_discount,
				CASE WHEN SUM(h.nights) > 0 THEN (SUM(h.hotel_per_room_usd * h.rooms * s.hotel_discount_amount)/SUM(h.nights)) 
                     ELSE NULL END AS ADS_night,
				SUM(haversine_distance(home_airport_lat, home_airport_lon, destination_airport_lat, destination_airport_lon))/ COUNT(*) as avg_distance_traveled,
				SUM(h.nights)::FLOAT / COUNT(*) as avg_night,
				SUM(h.rooms)::FLOAT / COUNT(*) as avg_rooms,			
                SUM(f.checked_bags)::FLOAT / COUNT(*) as avg_bags,
                AVG((base_fare_usd + (hotel_per_room_usd*rooms))) as avg_amount_spent      
            FROM sessions AS s
       	    LEFT JOIN cohort1 ON s.user_id = cohort1.user_id -- join our cohort1 query to filter on number of sessions
			LEFT JOIN users AS u ON s.user_id = u.user_id -- Join users table
			LEFT JOIN hotels AS h ON s.trip_id = h.trip_id -- Join hotels table
			LEFT JOIN flights AS f ON s.trip_id = f.trip_id -- Join flflights table
			WHERE session_start >='2023-01-04' AND num_sessions > 7 -- Filtering on date of session and number of sessins
            GROUP BY s.user_id,u.birthdate,u.gender,u.married,u.has_children,num_sessions
            ORDER BY s.user_id)

-- selecting user info columns, calculating indexses 
SELECT user_id,num_trips,num_sessions,age,gender,married,has_children,
	--(num_sessions / MAX(num_sessions) OVER())::FLOAT * (avg_session / MAX(avg_session) OVER()) AS session_intencity_index,
	discount_flight_proportion * average_flight_discount * (ADS - MIN(ADS) OVER()) / (MAX(ADS) OVER() - MIN(ADS) OVER()) AS bargain_hunter_index,
	discount_hotel_proportion * average_hotel_discount * (ADS_night - MIN(ADS_night) OVER()) / (MAX(ADS_night) OVER() - MIN(ADS_night) OVER()) AS hotel_hunter_index,
    (booking_rate - MIN(booking_rate) OVER()) / (MAX(booking_rate) OVER() - MIN(booking_rate) OVER()) AS booking_scaled,
    (cancellation_rate - MIN(cancellation_rate) OVER()) / (MAX(cancellation_rate) OVER() - MIN(cancellation_rate) OVER()) AS cancellation_rate_scaled,
	(avg_distance_traveled - MIN(avg_distance_traveled) OVER()) / (MAX(avg_distance_traveled) OVER() - MIN(avg_distance_traveled) OVER()) AS avg_distance_traveled_scaled,
	(avg_night - MIN(avg_night) OVER()) / (MAX(avg_night) OVER() - MIN(avg_night) OVER()) AS avg_night_scaled,
	(avg_rooms - MIN(avg_rooms) OVER()) / (MAX(avg_rooms) OVER() - MIN(avg_rooms) OVER()) AS avg_rooms_scaled,
	(avg_bags - MIN(avg_bags) OVER()) / (MAX(avg_bags) OVER() - MIN(avg_bags) OVER()) AS avg_bags_scaled,
	(avg_amount_spent - MIN(avg_amount_spent) OVER()) / (MAX(avg_amount_spent) OVER() - MIN(avg_amount_spent) OVER()) AS avg_amount_spent_scaled
FROM cohort2			 


