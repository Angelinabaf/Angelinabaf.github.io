--Creating a cohort1 query to filter on number of sessions
WITH cohort1 AS 
	(SELECT user_id, COUNT (*) AS num_sessions 
	FROM sessions 
	WHERE session_start >='2023-01-04' --filtering on day, after wich we interested in our data 
	GROUP By user_id)

SELECT s.session_id,cohort1.num_sessions,s.user_id,s.trip_id, s.session_start,s.session_end,s.flight_discount,
	   s.hotel_discount,s.flight_discount_amount,s.hotel_discount_amount,s.flight_booked,
	   s.hotel_booked,s.page_clicks,s.cancellation,u.birthdate,u.gender,u.married,u.has_children,
	   u.home_country,u.home_city,u.home_airport,u.home_airport_lat,u.home_airport_lon,u.sign_up_date,
       h.hotel_name,h.nights,h.rooms,h.check_in_time,h.check_out_time,h.hotel_per_room_usd,
       f.origin_airport,f.destination,f.destination_airport,f.seats,f.return_flight_booked,
       f.departure_time,f.return_time,f.checked_bags,f.trip_airline,f.destination_airport_lat,
       f.destination_airport_lon,f.base_fare_usd -- selecting all colloms without duplicates
FROM sessions AS s 
LEFT JOIN cohort1 -- join our cohort1 query to filter on number of sessions
ON s.user_id = cohort1.user_id
LEFT JOIN users AS u -- Join users table
ON s.user_id = u.user_id
LEFT JOIN hotels AS h -- Join hotels table
ON s.trip_id = h.trip_id
LEFT JOIN flights AS f -- Join flflights table
ON s.trip_id = f.trip_id
WHERE session_start >='2023-01-04' AND num_sessions > 7 -- Filtering on date of session and number of sessins
ORDER BY s.user_id