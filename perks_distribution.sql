-- filter for required time frame and session amount 
WITH cohort1 AS
            (SELECT user_id, COUNT (*) AS num_sessions 
			 FROM sessions 
			 WHERE session_start >='2023-01-04' --filtering on day, after wich we interested in our data 
			 GROUP By user_id), 

-- define users age, average amount spent to calculate scores later
calculation AS (SELECT s.user_id, EXTRACT(YEAR FROM AGE(u.birthdate)) AS age, 
                       AVG(((base_fare_usd*seats) + 
                       (hotel_per_room_usd*rooms*nights))) as avg_amount_spent
                FROM sessions s
                LEFT JOIN users AS u
				ON s.user_id = u.user_id
				LEFT JOIN hotels AS h
				ON s.trip_id = h.trip_id
				LEFT join flights AS f
				ON s.trip_id = f.trip_id
                GROUP BY s.user_id,u.birthdate), 

-- join all data needed to calculate scores
main AS (SELECT s.user_id, s.trip_id, s.flight_discount, s.hotel_discount,
         		s.flight_booked,s.hotel_booked,s.cancellation,
				cal.avg_amount_spent,cal.age,
				u.birthdate,u.has_children,u.home_airport_lat,u.home_airport_lon,
      			h.nights,h.rooms,
         		f.checked_bags,f.destination_airport_lat,f.destination_airport_lon
        FROM sessions AS s
        LEFT JOIN calculation AS cal ON s.user_id = cal.user_id -- join calculation query for futue score calculation
       	LEFT JOIN cohort1 ON s.user_id = cohort1.user_id -- join our cohort1 query to filter on number of sessions
		LEFT JOIN users AS u ON s.user_id = u.user_id -- Join users table
		LEFT JOIN hotels AS h ON s.trip_id = h.trip_id -- Join hotels table
		LEFT JOIN flights AS f ON s.trip_id = f.trip_id -- Join flflights table
		WHERE session_start >='2023-01-04' AND num_sessions > 7 -- Filtering on date of session and number of sessins
		ORDER BY s.user_id),

--calculating scores for each perk
score_table AS (SELECT user_id, 
                        ROUND(SUM((CASE WHEN rooms >= 2 THEN 0.5 ELSE 0 END) +
                                  (CASE WHEN has_children = true THEN 0.3 ELSE 0 END) +
                                  (CASE WHEN age >=56  THEN 0.2 ELSE 0 END))/COUNT(*),2) AS score_free_hotel_meals,
			            ROUND(SUM((CASE WHEN checked_bags >= 2 THEN 0.7 ELSE 0 END) +
                                  (CASE WHEN (haversine_distance(home_airport_lat,home_airport_lon, 
                                             destination_airport_lat, destination_airport_lon)*6371)> 1000 THEN 0.3 
                                   ELSE 0 END))/COUNT(*),2) AS score_free_checked_bag,
			            ROUND(SUM((CASE WHEN cancellation = true THEN 0.5 ELSE 0 END) +
                                  (CASE WHEN flight_booked = true and hotel_booked = true THEN 0.5 
                                   ELSE 0 END))/COUNT(*),2) AS score_no_cancellation_fee,
			            ROUND(SUM((CASE WHEN nights <2 THEN 0.5 ELSE 0 END) +
                                  (CASE WHEN flight_booked = true and hotel_booked = true THEN 0.5 
                                   ELSE 0 END))/COUNT(*),2) AS score_1_night_free_with_flight,
                        ROUND(SUM((CASE WHEN avg_amount_spent>1000 THEN 0.5 ELSE 0 END) +
                                  (CASE WHEN flight_discount = true or hotel_discount = true THEN 0.5 
                                   ELSE 0 END))/COUNT(*),2) AS score_exclusive_discount
                FROM main
                GROUP BY user_id), 

--rank each perk per user based on perk score
ranked_table AS (SELECT user_id,
                        score_free_hotel_meals,
                        RANK() OVER (ORDER BY score_free_hotel_meals DESC) AS rank_free_hotel_meals,
                        score_free_checked_bag,
                        RANK() OVER (ORDER BY score_free_checked_bag DESC) AS rank_free_checked_bag,
		                score_no_cancellation_fee,
                        RANK() OVER (ORDER BY score_no_cancellation_fee DESC) AS rank_no_cancellation_fee,
		                score_1_night_free_with_flight,
                        RANK() OVER (ORDER BY score_1_night_free_with_flight DESC) AS rank_1_night_free_with_flight,
		                score_exclusive_discount,
		                RANK() OVER (ORDER BY score_exclusive_discount DESC) AS rank_exclusive_discount
                FROM score_table)

-- define most attractive perk per user    
SELECT user_id,
	   score_free_hotel_meals, rank_free_hotel_meals,
       score_free_checked_bag, rank_free_checked_bag, 
       score_no_cancellation_fee, rank_no_cancellation_fee,
       score_1_night_free_with_flight, rank_1_night_free_with_flight, 
       score_exclusive_discount, rank_exclusive_discount,
    CASE
        WHEN rank_free_hotel_meals < rank_free_checked_bag 
		    AND rank_free_hotel_meals < rank_no_cancellation_fee
            AND rank_free_hotel_meals < rank_1_night_free_with_flight
            AND rank_free_hotel_meals < rank_exclusive_discount
        THEN 'Free Hotel Meals'
        WHEN rank_free_checked_bag < rank_free_hotel_meals
			AND  rank_free_checked_bag < rank_no_cancellation_fee
			AND  rank_free_checked_bag < rank_1_night_free_with_flight
            AND rank_free_checked_bag < rank_exclusive_discount
  		THEN 'Free Checked Bag'
		WHEN rank_no_cancellation_fee < rank_free_hotel_meals
            AND rank_no_cancellation_fee < rank_free_checked_bag
            AND rank_no_cancellation_fee < rank_1_night_free_with_flight
            AND rank_no_cancellation_fee < rank_exclusive_discount
        THEN 'No Cancellation Fee'
        WHEN rank_1_night_free_with_flight < rank_free_hotel_meals
            AND rank_1_night_free_with_flight < rank_free_checked_bag
            AND rank_1_night_free_with_flight < rank_no_cancellation_fee
            AND rank_1_night_free_with_flight < rank_exclusive_discount
        THEN '1 Night Free With Hotel'
        WHEN rank_exclusive_discount < rank_free_hotel_meals
            AND rank_exclusive_discount < rank_free_checked_bag
            AND rank_exclusive_discount < rank_no_cancellation_fee
            AND rank_exclusive_discount < rank_1_night_free_with_flight
        THEN 'Exclusive Discount'
        ELSE 'No Preferred Perk' -- Handle cases where no perk is top-ranked
        END AS top_perk
FROM
    ranked_table
    ORDER BY user_id


