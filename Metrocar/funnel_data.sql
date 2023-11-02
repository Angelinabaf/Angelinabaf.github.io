WITH 
totals AS (
    SELECT 
  		COUNT(DISTINCT ad.app_download_key) AS total_user_downloads,
  		COUNT(DISTINCT su.user_id) AS total_users_signed_up,
        COUNT(DISTINCT rr.user_id) AS total_users_ride_requested,
  		COUNT(DISTINCT rr.ride_id) AS total_ride_requested,
  		COUNT(DISTINCT CASE WHEN rr.accept_ts IS NOT NULL THEN rr.user_id END) AS total_users_ride_accepted,
  		COUNT(DISTINCT CASE WHEN rr.accept_ts IS NOT NULL THEN rr.ride_id END) AS total_ride_accepted,
  		COUNT(DISTINCT CASE WHEN rr.dropoff_ts IS NOT NULL THEN rr.user_id END) AS total_users_ride_completed,
  		COUNT(DISTINCT CASE WHEN rr.dropoff_ts IS NOT NULL THEN rr.ride_id END) AS total_ride_completed,
  		COUNT(DISTINCT CASE WHEN tr.charge_status = 'Approved' THEN rr.user_id END) AS total_users_payment_completed,
  		COUNT(DISTINCT CASE WHEN tr.charge_status = 'Approved' THEN rr.ride_id END) AS total_ride_payment_completed,
  		COUNT(DISTINCT rw.user_id) AS total_users_reviews,
 		COUNT(DISTINCT rw.ride_id) AS total_ride_reviews,
  		ad.platform as platform, su.age_range as age_range , CAST(ad.download_ts AS DATE)  AS download_dt
    FROM app_downloads AS ad
	LEFT JOIN signups AS su ON 
  		ad.app_download_key = su.session_id
	LEFT JOIN ride_requests AS rr ON 
  		su.user_id = rr.user_id
	LEFT JOIN transactions AS tr ON 
  		tr.ride_id = rr.ride_id
	LEFT JOIN reviews AS rw ON 
  		rw.user_id = su.user_id
  	GROUP BY platform,age_range, download_dt
),
funnel_stages AS (
  	SELECT
        0 AS funnel_step,
        'downloads' AS funnel_name,
  		platform, age_range, download_dt, 
        total_user_downloads AS user_count,
  		0 as ride_count
    FROM totals
  
  	UNION
  
    SELECT
        1 AS funnel_step,
        'signups' AS funnel_name, 
  		platform, age_range, download_dt,
        total_users_signed_up AS user_count,
  		0 as ride_count
    FROM totals

    UNION

    SELECT
        2 AS funnel_step,
        'ride_requested' AS funnel_name, 
  		platform, age_range, download_dt,
        total_users_ride_requested AS user_count,
  		total_ride_requested as ride_count
    FROM totals
  	
 	UNION

    SELECT
        3 AS funnel_step,
        'ride_accepted' AS funnel_name,
  		platform, age_range, download_dt,
        total_users_ride_accepted AS user_count,
  		total_ride_accepted as ride_count
    FROM totals
  
  	UNION

    SELECT
        4 AS funnel_step,
        'ride_completed' AS funnel_name, 
  		platform, age_range,download_dt,
        total_users_ride_completed AS user_count,
  		total_ride_completed as ride_count
    FROM totals
  	
  	UNION

    SELECT
        5 AS funnel_step,
        'payment' AS funnel_name,
  		platform, age_range, download_dt,
        total_users_payment_completed AS user_count,
  		total_ride_payment_completed as ride_count
    FROM totals
  
  	UNION

    SELECT
        6 AS funnel_step,
        'review' AS funnel_name,
  		platform, age_range, download_dt,
        total_users_reviews AS user_count,
  		total_ride_reviews as ride_count
    FROM totals
)
SELECT *
FROM funnel_stages
ORDER BY funnel_step;