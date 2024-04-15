#########################
#########################
# Create Table Statements
#########################

CREATE TABLE `currency` (
  `id` tinyint(1) unsigned NOT NULL,
  `code` char(3) NOT NULL,
  `name` varchar(30) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
# Sample content
# id, code, name
# 1,  AUD,  Australian Dollar
# ...
# 6,  EUR,  Euro
# ...
# 19, USD,  US Dollar
# 20, ZAR,  South African Rand

insert into currency
select 1,'AUD','Australian Dollar' union all
select 2,'BRL','Brazialian Real' union all
select 3,'CAD','Canadian Dollar' union all
select 4,'CHF','Swiss Franc' union all
select 5,'CNY','Chinese Yuan' union all
select 6,'EUR','Euro' union all
select 7,'GBP','British Pound Sterling' union all
select 8,'HKD','Hong Kong Dollar' union all
select 9,'INR','Indian Rupee' union all
select 10,'JPY','Japanese Yen' union all
select 11,'KRW','South Korean Won' union all
select 12,'MXN','Mexican Peso' union all
select 13,'NOK','Norwegian Krone' union all
select 14,'NZD','New Zealand Dollar' union all
select 15,'RUB','Russian Ruble' union all
select 16,'SEK','Swedish Krona' union all
select 17,'SGD','Singapore Dollar' union all
select 18,'TRY','Turkish Lira' union all
select 19,'USD','US Dollar' union all
select 20,'ZAR','South African Rand'


CREATE TABLE `daily_exchange_rate` (
  `currency_id` tinyint(1) unsigned NOT NULL,
  `exchange_rate` decimal(10,6) unsigned NOT NULL,
  `date` date NOT NULL,
  PRIMARY KEY (`currency_id`,`date`),
  CONSTRAINT `FK_DAILY_EXCHANGE_RATE_CURRENCY_ID` FOREIGN KEY (`currency_id`) REFERENCES `currency` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
# Sample content (rates are pulled in the base of EUR only, other rates are converted dinamically)
# currency_id, exchange_rate, date
# 1,           1.633777,      2018-10-07
# ...
# 6,           1.000000,      2018-10-07
# ...
# 19,          1.152226,      2018-10-07
# 20,          17.083367,     2018-10-07


CREATE TABLE `hourly_exchange_rate` (
  `currency_id` tinyint(1) unsigned NOT NULL,
  `exchange_rate` decimal(10,6) unsigned NOT NULL,
  `date_hour` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`currency_id`,`date_hour`),
  CONSTRAINT `FK_HOURLY_EXCHANGE_RATE_CURRENCY_ID` FOREIGN KEY (`currency_id`) REFERENCES `currency` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
# Sample content (rates are pulled in the base of EUR only, other rates are converted dinamically)
# currency_id, exchange_rate, date_hour
# 1,           1.634485,      2018-10-07 14:00:00
# ...
# 6,           1.000000,      2018-10-07 14:00:00
# ...
# 19,          1.153449,      2018-10-07 14:00:00
# 20,          17.055133,     2018-10-07 14:00:00


CREATE TABLE `transaction_type` (
  `id` tinyint(1) unsigned NOT NULL,
  `description` varchar(45) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `description_UNIQUE` (`description`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
# Content
# id, description
# 3,  Deposit/Wthdrawal
# 2,  Gift
# 1,  Trade

insert into transaction_type
select 1,  'Trade' union all
select 2,  'Gift' union all
select 3,  'Deposit/Wthdrawal'

CREATE TABLE `user` (
  `username` varchar(15) NOT NULL,
  `password` binary(60) NOT NULL,
  `base_currency_id` tinyint(1) unsigned NOT NULL,
  `registration_timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`username`),
  KEY `FK_CURRENCY_ID_idx` (`base_currency_id`),
  CONSTRAINT `FK_USER_CURRENCY_ID` FOREIGN KEY (`base_currency_id`) REFERENCES `currency` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
# Sample content
# username, password, base_currency_id, registration_timestamp
# James,    [BLOB],   19,               2018-09-23 21:27:32    # User with base currency of USD
# Ken,      [BLOB],   10,               2018-08-29 06:49:06    # User with base currency of JPY


CREATE TABLE `ledger` (
  `username` varchar(15) NOT NULL,
  `currency_id` tinyint(1) unsigned NOT NULL,
  `units` decimal(12,2) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `type` tinyint(1) unsigned NOT NULL,
  PRIMARY KEY (`username`,`currency_id`,`timestamp`),
  KEY `FK_LEDGER_CURRENCY_ID_idx` (`currency_id`),
  KEY `FK_LEDGER_TYPE_idx` (`type`),
  CONSTRAINT `FK_LEDGER_TYPE` FOREIGN KEY (`type`) REFERENCES `transaction_type` (`id`),
  CONSTRAINT `FK_LEDGER_CURRENCY_ID` FOREIGN KEY (`currency_id`) REFERENCES `currency` (`id`),
  CONSTRAINT `FK_LEDGER_USERNAME` FOREIGN KEY (`username`) REFERENCES `user` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
# Sample content
# username, currency_id, units,   timestamp,           type
# James,    19,          1000.00, 2018-09-23 21:27:32, 2   # Gift entry for $1000 USD
# James,    1,           136.39,  2018-09-23 21:28:44, 1   # } One transaction of Selling 100 USD
# James,    19,          900.00,  2018-09-23 21:28:44, 1   # } and Buying 136.39 AUD with the new balances of each currencies
# James,    14,          148.58,  2018-09-23 21:30:54, 1   # One transaction will have the same timestamps
# James,    19,          800.00,  2018-09-23 21:30:54, 1   # for two records. Each transaction has it's unique timestamp.



##################
#Stored Procedures
##################

DELIMITER $$
CREATE PROCEDURE `sp_account_allocation_daily`(p_username VARCHAR(15), p_date VARCHAR(10))
BEGIN

    SET @user_base_currency = ( SELECT base_currency_id FROM user WHERE username = p_username );

	SET @from_date = p_date;
	SET @to_date = DATE_ADD(p_date, INTERVAL 1 DAY);

	DROP TEMPORARY TABLE IF EXISTS t1;
    DROP TEMPORARY TABLE IF EXISTS t2;
	
    CREATE TEMPORARY TABLE t1 AS (
		SELECT DATE_ADD(o.date, INTERVAL -1 DAY) AS date, c.code, c.name, r.units, CAST(r.units / e.buy AS DECIMAL(12, 2)) AS value
		FROM (	SELECT d.date, l.currency_id, username, MAX(timestamp) AS max_timestamp
				FROM (	SELECT *
						FROM (	SELECT DISTINCT date
								FROM daily_exchange_rate
									UNION
								SELECT DATE_ADD(MAX(date), INTERVAL 1 DAY)
								FROM daily_exchange_rate
							 ) u
						WHERE date >= @from_date AND date <= @to_date
					 ) d INNER JOIN ledger l ON d.date >= l.timestamp
							WHERE l.username = p_username
				GROUP BY d.date, l.currency_id, username
			 ) o INNER JOIN ledger r ON o.username = r.username AND o.currency_id = r.currency_id AND o.max_timestamp = r.timestamp
				INNER JOIN (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)) AS buy, e1.date
								FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2
								WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date
									AND e1.currency_id = @user_base_currency AND e1.date >= @from_date AND e1.date <= @to_date
										UNION ALL
								SELECT DISTINCT @user_base_currency, 1, date FROM daily_exchange_rate WHERE date >= @from_date AND date <= @to_date
							) e ON DATE_ADD(o.date, INTERVAL -1 DAY) = e.date AND o.currency_id = e.currency_id
			INNER JOIN currency c ON r.currency_id = c.id
    );

	CREATE TEMPORARY TABLE t2 AS ( SELECT date, SUM(value) AS total FROM t1 GROUP BY date );
    
    SELECT t1.*, t2.total, CAST(t1.value / t2.total * 100 AS DECIMAL(14,2)) AS percent
    FROM t1 INNER JOIN t2 ON t1.date = t2.date
    ORDER BY percent DESC, t1.code;
    
END $$


CREATE PROCEDURE `sp_account_balance_daily`(p_username VARCHAR(15), p_date VARCHAR(10), p_days VARCHAR(10))
BEGIN

    SET @user_base_currency = ( SELECT base_currency_id FROM user WHERE username = p_username );

	SET @p_days = CASE WHEN p_days = 'EOMonth' THEN DATEDIFF(LAST_DAY(p_date), p_date) + 1
					   WHEN p_days = 'EOQuarter' THEN DATEDIFF(MAKEDATE(YEAR(p_date), 1) + INTERVAL QUARTER(p_date) QUARTER - INTERVAL 1 DAY, p_date) + 1
                       WHEN p_days = 'EOYear' THEN DATEDIFF(CONCAT(LEFT(p_date, 4), '-12-31'), p_date) + 1
                       ELSE p_days END;


	SET @from_date = CASE WHEN @p_days > 0 THEN p_date WHEN @p_days < 0 THEN DATE_ADD(p_date, INTERVAL @p_days + 1 DAY) END;
	SET @to_date = CASE WHEN @p_days > 0 THEN DATE_ADD(p_date, INTERVAL @p_days DAY) WHEN @p_days < 0 THEN DATE_ADD(p_date, INTERVAL + 1 DAY) END;


	SELECT LEFT(DATE_ADD(o.date, INTERVAL -1 DAY), 10) AS date, SUM(CAST(r.units / e.buy AS DECIMAL(12, 2))) AS total
	FROM (	SELECT d.date, l.currency_id, username, MAX(timestamp) AS max_timestamp
			FROM (	SELECT *
					FROM (	SELECT DISTINCT date
							FROM daily_exchange_rate
								UNION
							SELECT DATE_ADD(MAX(date), INTERVAL 1 DAY)
							FROM daily_exchange_rate
						 ) u
					WHERE date >= @from_date AND date <= @to_date
				 ) d INNER JOIN ledger l ON d.date >= l.timestamp
						WHERE l.username = p_username
			GROUP BY d.date, l.currency_id, username
		 ) o INNER JOIN ledger r ON o.username = r.username AND o.currency_id = r.currency_id AND o.max_timestamp = r.timestamp
			INNER JOIN (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)) AS buy, e1.date
							FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2
							WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date
								AND e1.currency_id = @user_base_currency AND e1.date >= @from_date AND e1.date <= @to_date
									UNION ALL
							SELECT DISTINCT @user_base_currency, 1, date FROM daily_exchange_rate WHERE date >= @from_date AND date <= @to_date
						) e ON DATE_ADD(o.date, INTERVAL -1 DAY) = e.date AND o.currency_id = e.currency_id
	GROUP BY o.date
    ORDER BY o.date;

END $$



CREATE PROCEDURE `sp_account_balance_hourly`(p_username VARCHAR(15), p_date_hour VARCHAR(19), p_hours VARCHAR(10))
BEGIN
	SET @user_base_currency = ( SELECT base_currency_id FROM user WHERE username = p_username );

	SET @from_date_hour = CASE WHEN p_hours > 0 THEN p_date_hour WHEN p_hours < 0 THEN DATE_ADD(p_date_hour, INTERVAL p_hours + 1 HOUR) END;
	SET @to_date_hour = CASE WHEN p_hours > 0 THEN DATE_ADD(p_date_hour, INTERVAL p_hours - 1 HOUR) WHEN p_hours < 0 THEN p_date_hour END;
    
    
	SELECT o.date_hour, SUM(CAST(r.units / e.buy AS DECIMAL(12, 2))) AS total
	FROM (	SELECT h.date_hour, username, currency_id, MAX(timestamp) AS max_timestamp
			FROM (	SELECT *
                    FROM (	SELECT date_hour
							FROM hourly_exchange_rate
								UNION
							SELECT DATE_ADD(MAX(date_hour), INTERVAL 1 HOUR)
							FROM hourly_exchange_rate
								UNION
							SELECT DATE_ADD(MAX(date_hour), INTERVAL 2 HOUR)
							FROM hourly_exchange_rate
						 ) u
					WHERE date_hour >= @from_date_hour AND date_hour <= @to_date_hour
				 ) h INNER JOIN ledger l ON h.date_hour >= l.timestamp
			WHERE l.username = p_username
			GROUP BY h.date_hour, username, currency_id
		 ) o INNER JOIN ledger r ON o.username = r.username AND o.currency_id = r.currency_id AND o.max_timestamp = r.timestamp
		INNER JOIN	(	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)) AS buy, e1.date_hour
						FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
						WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour
							AND e1.currency_id = @user_base_currency AND e1.date_hour >= DATE_ADD(@from_date_hour, INTERVAL -2 HOUR) AND e1.date_hour <= @to_date_hour
								UNION ALL
						SELECT DISTINCT @user_base_currency, 1, date_hour FROM hourly_exchange_rate WHERE date_hour >= DATE_ADD(@from_date_hour, INTERVAL -2 HOUR) AND date_hour <= @to_date_hour
					 ) e ON o.date_hour = DATE_ADD(e.date_hour, INTERVAL 1 HOUR) AND o.currency_id = e.currency_id
	GROUP BY o.date_hour
    ORDER BY o.date_hour;
    
END $$


CREATE PROCEDURE `sp_account_balance_monthly`(p_username VARCHAR(15), p_date VARCHAR(10), p_days VARCHAR(10))
BEGIN

    SET @user_base_currency = ( SELECT base_currency_id FROM user WHERE username = p_username );

	SET @p_days = CASE WHEN p_days = 'EOMonth' THEN DATEDIFF(LAST_DAY(p_date), p_date) + 1
					   WHEN p_days = 'EOQuarter' THEN DATEDIFF(MAKEDATE(YEAR(p_date), 1) + INTERVAL QUARTER(p_date) QUARTER - INTERVAL 1 DAY, p_date) + 1
                       WHEN p_days = 'EOYear' THEN DATEDIFF(CONCAT(LEFT(p_date, 4), '-12-31'), p_date) + 1
                       ELSE p_days END;


	SET @from_date = DATE_ADD(p_date, INTERVAL -1 MONTH);
	SET @to_date = DATE_ADD(p_date, INTERVAL @p_days DAY);

	DROP TEMPORARY TABLE IF EXISTS t1;
	DROP TEMPORARY TABLE IF EXISTS t2;
	DROP TEMPORARY TABLE IF EXISTS t3;
    DROP TEMPORARY TABLE IF EXISTS t4;

    CREATE TEMPORARY TABLE t1 AS (
		SELECT DATE_ADD(o.date, INTERVAL -1 DAY) AS date, SUM(CAST(r.units / e.buy AS DECIMAL(12, 2))) AS total
		FROM (	SELECT d.date, l.currency_id, username, MAX(timestamp) AS max_timestamp
				FROM (	SELECT *
						FROM (	SELECT DISTINCT date
								FROM daily_exchange_rate
									UNION
								SELECT DATE_ADD(MAX(date), INTERVAL 1 DAY)
								FROM daily_exchange_rate
							 ) u
						WHERE date >= @from_date AND date <= @to_date
					 ) d INNER JOIN ledger l ON d.date >= l.timestamp
							WHERE l.username = p_username
				GROUP BY d.date, l.currency_id, username
			 ) o INNER JOIN ledger r ON o.username = r.username AND o.currency_id = r.currency_id AND o.max_timestamp = r.timestamp
				INNER JOIN (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)) AS buy, e1.date
								FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2
								WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date
									AND e1.currency_id = @user_base_currency AND e1.date >= @from_date AND e1.date <= @to_date
										UNION ALL
								SELECT DISTINCT @user_base_currency, 1, date FROM daily_exchange_rate WHERE date >= @from_date AND date <= @to_date
							) e ON DATE_ADD(o.date, INTERVAL -1 DAY) = e.date AND o.currency_id = e.currency_id
		GROUP BY o.date
	 );

    CREATE TEMPORARY TABLE t2 AS ( SELECT * FROM t1 );
	CREATE TEMPORARY TABLE t3 AS ( SELECT * FROM t1 );
    CREATE TEMPORARY TABLE t4 AS ( SELECT * FROM t1 );

	SELECT `date_month`, month, opening_balance, high_balance, low_balance, average_balance, closing_balance,
			closing_balance - prev_closing_balance AS gain_loss, 
            CAST((closing_balance - prev_closing_balance) / prev_closing_balance * 100 AS DECIMAL(12, 2)) AS percent_change
    FROM (
			SELECT LEFT(date, 7) AS 'date_month', LEFT(MONTHNAME(STR_TO_DATE(RIGHT(LEFT(date, 7), 2), '%m')), 3) AS month, 
					( SELECT total FROM t2 WHERE LEFT(date, 7) = LEFT(t1.date, 7) ORDER BY date LIMIT 1 ) AS opening_balance,
					MAX(total) AS high_balance, MIN(total) AS low_balance, CAST(AVG(total) AS DECIMAL(12, 2)) AS average_balance,
					( SELECT total FROM t3 WHERE LEFT(date, 7) = LEFT(t1.date, 7) ORDER BY date DESC LIMIT 1 ) AS closing_balance,
					( SELECT total FROM t4 WHERE LEFT(date, 7) = LEFT(DATE_ADD(t1.date, INTERVAL -1 MONTH), 7) ORDER BY date DESC LIMIT 1 ) AS prev_closing_balance
			FROM t1
			GROUP BY LEFT(date, 7)
		 ) a
	WHERE `date_month` >= LEFT(p_date, 7)
	ORDER BY `date_month`;

END $$


CREATE PROCEDURE `sp_candle_stick`(p_base_code CHAR(3), p_pair_code CHAR(3), p_rates_or_prices VARCHAR(15))
BEGIN

	#returns the date to the daily candlestick daily chart to six digits rather that six decimal precision
	SELECT s.base, s.exchange,                                
			CASE WHEN p_rates_or_prices = 'Rates' THEN o.rate_mid WHEN p_rates_or_prices = 'Prices' THEN o.price_mid END AS open,
            CASE WHEN p_rates_or_prices = 'Rates' THEN s.min_rate_mid WHEN p_rates_or_prices = 'Prices' THEN s.min_price_mid END AS min,
            CASE WHEN p_rates_or_prices = 'Rates' THEN s.max_rate_mid WHEN p_rates_or_prices = 'Prices' THEN s.max_price_mid END AS max,
            CASE WHEN p_rates_or_prices = 'Rates' THEN c.rate_mid WHEN p_rates_or_prices = 'Prices' THEN c.price_mid END AS close,
            s.date            
	FROM (	SELECT base, exchange, LEFT(date_hour, 10) AS date, MIN(rate_mid) AS min_rate_mid, MAX(rate_mid) AS max_rate_mid, MIN(price_mid) AS min_price_mid, MAX(price_mid) AS max_price_mid
			FROM (	SELECT p_base_code AS base, c2.code AS exchange, 
							LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7), 7)) AS rate_mid,
							LEFT( CAST(1 / (1 / e1.exchange_rate * e2.exchange_rate) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7) > 7, ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7), 7)) AS price_mid, 
							e1.date_hour
					FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
					WHERE e1.date_hour = e2.date_hour AND c1.code = p_base_code AND c2.code = p_pair_code
				 ) r
			GROUP BY base, exchange, LEFT(date_hour, 10)
			HAVING COUNT(*) = 24
		 ) s INNER JOIN (	SELECT *
							FROM (	SELECT p_base_code AS base, c2.code AS exchange, 
											LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7), 7)) AS rate_mid,
											LEFT( CAST(1 / (1 / e1.exchange_rate * e2.exchange_rate) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7) > 7, ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7), 7)) AS price_mid, 
											e1.date_hour
									FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
									WHERE e1.date_hour = e2.date_hour AND c1.code = p_base_code AND c2.code = p_pair_code
								 ) r
							WHERE RIGHT(date_hour, 8) = '00:00:00'
						) o ON s.date = LEFT(o.date_hour, 10)
			 INNER JOIN (	SELECT *
							FROM (	SELECT p_base_code AS base, c2.code AS exchange, 
											LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7), 7)) AS rate_mid,
											LEFT( CAST(1 / (1 / e1.exchange_rate * e2.exchange_rate) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7) > 7, ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7), 7)) AS price_mid, 
											e1.date_hour
									FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
									WHERE e1.date_hour = e2.date_hour AND c1.code = p_base_code AND c2.code = p_pair_code
								 ) r
							WHERE RIGHT(date_hour, 8) = '00:00:00'
						) c ON DATE_ADD(s.date, INTERVAL 1 DAY) = LEFT(c.date_hour, 10)
	ORDER BY s.date;


END $$



CREATE PROCEDURE `sp_currency_board`(p_currency_code VARCHAR(15), p_rates_or_prices VARCHAR(10))
BEGIN
	SET @currency_code = ( SELECT id FROM currency WHERE code = p_currency_code );
    SET @latest_trading_hour = ( SELECT MAX(date_hour) FROM hourly_exchange_rate );
	
    SELECT c.id, c.code, c.name,  
			CASE WHEN p_rates_or_prices = 'Rates' THEN u.rate_trend WHEN p_rates_or_prices = 'Prices' THEN u.rate_trend * -1 END AS trend, 
            CASE WHEN p_rates_or_prices = 'Rates' THEN u.rate_buy WHEN p_rates_or_prices = 'Prices' THEN u.price_buy END AS buy, 
            CASE WHEN p_rates_or_prices = 'Rates' THEN u.rate_sell WHEN p_rates_or_prices = 'Prices' THEN u.price_sell END AS sell, 
            u.graph
    FROM (	#Trends and exchange rates, prices for latest currency hourly reading returned to 6 digits, rather than 6 decimal precision regardless of order of magnitude
			SELECT rc.currency_id, CASE WHEN rc.rate_buy > rp.rate_buy THEN 1 WHEN rc.rate_buy < rp.rate_buy THEN -1 ELSE 0 END AS rate_trend, rc.rate_buy, rc.rate_sell,
				   CASE WHEN rc.price_buy > rp.price_buy THEN 1 WHEN rc.price_buy < rp.price_buy THEN -1 ELSE 0 END AS price_trend, rc.price_buy, rc.price_sell, 1 AS graph
			FROM (	SELECT e2.currency_id, 
							LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 1.01)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 1.01)) -7), 7)) AS rate_buy,
							LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate * 0.99 AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 0.99)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 0.99)) -7), 7)) AS rate_sell,
							LEFT( CAST(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01))) -7) > 7, ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01))) -7), 7)) AS price_buy, 
							LEFT( CAST(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99))) -7) > 7, ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99))) -7), 7)) AS price_sell
					FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
					WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour AND e1.currency_id = @currency_code AND e1.date_hour = @latest_trading_hour
				 ) rc #current readings converted to the user's base currency
				 INNER JOIN
				 (	SELECT e2.currency_id, 
							LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 1.01)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 1.01)) -7), 7)) AS rate_buy,
							LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate * 0.99 AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 0.99)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * .009)) -7), 7)) AS rate_sell,
							LEFT( CAST(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01))) -7) > 7, ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01))) -7), 7)) AS price_buy, 
							LEFT( CAST(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99))) -7) > 7, ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99))) -7), 7)) AS price_sell
					FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
					WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour AND e1.currency_id = @currency_code AND e1.date_hour = DATE_ADD(@latest_trading_hour, INTERVAL -1 HOUR)
				 ) rp ON rc.currency_id = rp.currency_id #one hour prior readings for trend comparison
		 ) u INNER JOIN currency c ON u.currency_id = c.id
	ORDER BY u.currency_id;


END $$


CREATE PROCEDURE `sp_currency_pairs_daily`(p_base_code CHAR(3), p_pair_code CHAR(3), p_rates_or_prices VARCHAR(15))
BEGIN

	#returns exchange rates or prices of a currency pair for the entire lenght of the dataset of ten years returned with six digit, rather than six decimal precision, regardless the order of magnitude
	SELECT p_base_code AS base, c2.code AS exchange, 
			CASE WHEN p_rates_or_prices = 'Rates' THEN LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7), 7))
				 WHEN p_rates_or_prices = 'Prices' THEN LEFT( CAST(1 / (1 / e1.exchange_rate * e2.exchange_rate) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7) > 7, ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7), 7)) END mid,
			e1.date
	FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
	WHERE e1.date = e2.date AND c1.code = p_base_code AND c2.code = p_pair_code
    ORDER BY e1.date;

END;



CREATE PROCEDURE `sp_currency_pairs_hourly`(p_base_code CHAR(3), p_pair_code CHAR(3), p_rates_or_prices VARCHAR(15))
BEGIN

	#returns exchange rates or prices of a currency pair for the entire lenght of the dataset of one month returned with six digit, rather than six decimal precision, regardless the order of magnitude
	SELECT p_base_code AS base, c2.code AS exchange, 
			CASE WHEN p_rates_or_prices = 'Rates' THEN LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7), 7))
				 WHEN p_rates_or_prices = 'Prices' THEN LEFT( CAST(1 / (1 / e1.exchange_rate * e2.exchange_rate) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7) > 7, ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7), 7)) END AS mid,
			e1.date_hour
	FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
	WHERE e1.date_hour = e2.date_hour AND c1.code = p_base_code AND c2.code = p_pair_code
    ORDER BY e1.date_hour;

END $$


CREATE PROCEDURE `sp_exchange_daily`(p_base_code CHAR(3))
BEGIN

	#returns exchange rates or prices of all currencies for a specific base for a specific day returned with six digit, rather than six decimal precision, regardless the order of magnitude
	SELECT p_base_code AS base, c2.code AS exchange, 
			LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7), 7)) AS rate_mid,
			LEFT( CAST(1 / (1 / e1.exchange_rate * e2.exchange_rate) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7) > 7, ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7), 7)) AS price_mid, 
			e1.date
	FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
	WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_code
    ORDER BY e1.date;

END $$


CREATE PROCEDURE `sp_exchange_hourly`(p_base_code CHAR(3))
BEGIN

	#returns exchange rates or prices of all currencies for a specific base for a specific hour returned with six digit, rather than six decimal precision, regardless the order of magnitude
	SELECT p_base_code AS base, c2.code AS exchange, 
			LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate)) -7), 7)) AS rate_mid,
			LEFT( CAST(1 / (1 / e1.exchange_rate * e2.exchange_rate) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7) > 7, ABS(FLOOR(LOG10(1 / (1 / e1.exchange_rate * e2.exchange_rate))) -7), 7)) AS price_mid, 
			e1.date_hour
	FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
	WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour AND c1.code = p_base_code
    ORDER BY e1.date_hour;

END $$


CREATE PROCEDURE `sp_gift`(p_username VARCHAR(15), p_amount_in_USD DECIMAL(12, 2))
BEGIN
	
	#This stored procedure increases a user's ledger with the specified USD gift amount equivalent 
    #in the user's base currency according to the current hourly exchange rate. 
    #This is not an external facing Stored Procedure, the user can not initiate this procedure directly only the site can
    SET @user_base_currency = ( SELECT base_currency_id FROM user WHERE username = p_username );
    SET @latest_trading_hour = ( SELECT MAX(date_hour) FROM hourly_exchange_rate );


	IF ( p_amount_in_USD >= 0.01 ) THEN
		INSERT INTO ledger
			SELECT p_username, @user_base_currency,
				   IFNULL(( SELECT units FROM ledger WHERE username = p_username AND currency_id = @user_base_currency 
						AND timestamp = ( SELECT MAX(timestamp) FROM ledger WHERE username = p_username AND currency_id = @user_base_currency ) ), 0) +                
						CAST(1 / e1.exchange_rate * e2.exchange_rate * p_amount_in_USD AS DECIMAL(12, 2)) AS gift,				
					CONCAT(CURDATE(), ' ', CURTIME()) AS timestamp, 2 AS type
			FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
			WHERE e1.date_hour = e2.date_hour AND e1.currency_id = 19 #USD currency code
					AND e2.currency_id = @user_base_currency
					AND e1.date_hour = @latest_trading_hour;
	END IF;

END $$


CREATE PROCEDURE `sp_insert_exchange_rates_daily`(
	p_cur01 INT, p_rate01 DECIMAL(12,6), p_cur02 INT, p_rate02 DECIMAL(12,6),
    p_cur03 INT, p_rate03 DECIMAL(12,6), p_cur04 INT, p_rate04 DECIMAL(12,6), 
    p_cur05 INT, p_rate05 DECIMAL(12,6), p_cur06 INT, p_rate06 DECIMAL(12,6), 
    p_cur07 INT, p_rate07 DECIMAL(12,6), p_cur08 INT, p_rate08 DECIMAL(12,6), 
    p_cur09 INT, p_rate09 DECIMAL(12,6), p_cur10 INT, p_rate10 DECIMAL(12,6), 
    p_cur11 INT, p_rate11 DECIMAL(12,6), p_cur12 INT, p_rate12 DECIMAL(12,6), 
    p_cur13 INT, p_rate13 DECIMAL(12,6), p_cur14 INT, p_rate14 DECIMAL(12,6), 
    p_cur15 INT, p_rate15 DECIMAL(12,6), p_cur16 INT, p_rate16 DECIMAL(12,6), 
    p_cur17 INT, p_rate17 DECIMAL(12,6), p_cur18 INT, p_rate18 DECIMAL(12,6), 
    p_cur19 INT, p_rate19 DECIMAL(12,6), p_cur20 INT, p_rate20 DECIMAL(12,6), yr INT, mo INT, dy INT
)
BEGIN

	#Inserting rows based on currency_id if no rows exist for that day already, so exchange rates can not be changed later for consitency
    #and no future or not yet closed days are allowed
	INSERT INTO daily_exchange_rate 
		SELECT *
        FROM ( SELECT p_cur01, p_rate01, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
			   SELECT p_cur02, p_rate02, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur03, p_rate03, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur04, p_rate04, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur05, p_rate05, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur06, p_rate06, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur07, p_rate07, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur08, p_rate08, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur09, p_rate09, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur10, p_rate10, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur11, p_rate11, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur12, p_rate12, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur13, p_rate13, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur14, p_rate14, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur15, p_rate15, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur16, p_rate16, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur17, p_rate17, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur18, p_rate18, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur19, p_rate19, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) UNION ALL
               SELECT p_cur20, p_rate20, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2))               
             ) c
        WHERE NOT EXISTS ( SELECT * 
						   FROM daily_exchange_rate
						   WHERE date = CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) 
						 );
				#AND p_date < CURDATE();


	#Inserting the same reading as prior day, if reading is missing for one or more currencies from the API response
	INSERT INTO daily_exchange_rate
		SELECT e1.currency_id, e1.exchange_rate, DATE_ADD(e1.date, INTERVAL +1 DAY) AS date
		FROM daily_exchange_rate e1 LEFT OUTER JOIN daily_exchange_rate e2
			ON DATE_ADD(e1.date, INTERVAL +1 DAY) = e2.date
				AND e1.currency_id = e2.currency_id
		WHERE e1.date = DATE_ADD(CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2)) , INTERVAL -1 DAY) 
				#AND p_date < CURDATE()
				AND e2.date IS NULL;


	#Deleting rows older than 10 years due to 5MB database size limit from the free tier of hosting site
	SET SQL_SAFE_UPDATES = 0;
	DELETE FROM daily_exchange_rate
	WHERE date < DATE_ADD(CURDATE(), INTERVAL -5 YEAR);
    
    OPTIMIZE NO_WRITE_TO_BINLOG
    TABLE currency, daily_exchange_rate, hourly_exchange_rate, ledger, user;

   
END $$


CREATE PROCEDURE `sp_insert_exchange_rates_hourly`(
	p_cur01 CHAR(3), p_rate01 DECIMAL(12,6), p_cur02 CHAR(3), p_rate02 DECIMAL(12,6),
    p_cur03 CHAR(3), p_rate03 DECIMAL(12,6), p_cur04 CHAR(3), p_rate04 DECIMAL(12,6), 
    p_cur05 CHAR(3), p_rate05 DECIMAL(12,6), p_cur06 CHAR(3), p_rate06 DECIMAL(12,6), 
    p_cur07 CHAR(3), p_rate07 DECIMAL(12,6), p_cur08 CHAR(3), p_rate08 DECIMAL(12,6), 
    p_cur09 CHAR(3), p_rate09 DECIMAL(12,6), p_cur10 CHAR(3), p_rate10 DECIMAL(12,6), 
    p_cur11 CHAR(3), p_rate11 DECIMAL(12,6), p_cur12 CHAR(3), p_rate12 DECIMAL(12,6), 
    p_cur13 CHAR(3), p_rate13 DECIMAL(12,6), p_cur14 CHAR(3), p_rate14 DECIMAL(12,6), 
    p_cur15 CHAR(3), p_rate15 DECIMAL(12,6), p_cur16 CHAR(3), p_rate16 DECIMAL(12,6), 
    p_cur17 CHAR(3), p_rate17 DECIMAL(12,6), p_cur18 CHAR(3), p_rate18 DECIMAL(12,6), 
    p_cur19 CHAR(3), p_rate19 DECIMAL(12,6), p_cur20 CHAR(3), p_rate20 DECIMAL(12,6), p_date_hour TIMESTAMP
)
BEGIN

	#Inserting rows based on currency_id if no rows exist for that day_hour already, so exchange rates can not be changed later for consitency
    #and no future or not yet closed day_hours are allowed
    INSERT INTO hourly_exchange_rate 
		SELECT c.id, p.exchange_rate, p_date_hour
		FROM currency c INNER JOIN (SELECT p_cur01 AS currency_code, p_rate01 AS exchange_rate UNION SELECT p_cur02, p_rate02
									UNION SELECT p_cur03, p_rate03 UNION SELECT p_cur04, p_rate04 UNION SELECT p_cur05, p_rate05
									UNION SELECT p_cur06, p_rate06 UNION SELECT p_cur07, p_rate07 UNION SELECT p_cur08, p_rate08
									UNION SELECT p_cur09, p_rate09 UNION SELECT p_cur10, p_rate10 UNION SELECT p_cur11, p_rate11
									UNION SELECT p_cur12, p_rate12 UNION SELECT p_cur13, p_rate13 UNION SELECT p_cur14, p_rate14
									UNION SELECT p_cur15, p_rate15 UNION SELECT p_cur16, p_rate16 UNION SELECT p_cur17, p_rate17
									UNION SELECT p_cur18, p_rate18 UNION SELECT p_cur19, p_rate19 UNION SELECT p_cur20, p_rate20) p 
			ON c.code = p.currency_code
		WHERE NOT EXISTS ( SELECT * 
						   FROM hourly_exchange_rate
						   WHERE date_hour = p_date_hour)
				AND p_date_hour <= CONCAT(CURDATE(), ' ', RIGHT(CONCAT('0', HOUR(CURTIME())), 2), ':00:00');


	#Inserting the same reading as prior day_hour, if reading is missing for one or more currencies from the API response
	INSERT INTO hourly_exchange_rate
		SELECT e1.currency_id, e1.exchange_rate, DATE_ADD(e1.date_hour, INTERVAL +1 HOUR) AS date_hour
		FROM hourly_exchange_rate e1 LEFT OUTER JOIN hourly_exchange_rate e2
			ON DATE_ADD(e1.date_hour, INTERVAL +1 HOUR) = e2.date_hour
				AND e1.currency_id = e2.currency_id
		WHERE e1.date_hour = DATE_ADD(p_date_hour, INTERVAL -1 HOUR) 
				AND p_date_hour <= CONCAT(CURDATE(), ' ', RIGHT(CONCAT('0', HOUR(CURTIME())), 2), ':00:00')
				AND e2.date_hour IS NULL;


	#Deleting rows older than 10 years due to 5MB database size limit from the free tier of hosting site
	SET SQL_SAFE_UPDATES = 0;
	DELETE FROM hourly_exchange_rate
	WHERE date_hour < DATE_ADD(CURDATE(), INTERVAL -30 DAY);
    
END $$



CREATE PROCEDURE `sp_insert_exchange_rates_hourly2`(yr INT, mo INT, dy INT, hr INT)
BEGIN
    INSERT INTO hourly_exchange_rate 
		SELECT DISTINCT currency_id, exchange_rate, CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2), ' ', RIGHT(CONCAT('0', hr), 2), ':00:00')
        FROM daily_exchange_rate
		WHERE date = CONCAT(yr, '-', RIGHT(CONCAT('0', mo + 1), 2), '-', RIGHT(CONCAT('0', dy), 2));

END $$


CREATE PROCEDURE `sp_insert_exchange_rates_hourly_insert_missing_readings`()
BEGIN

    #Current day
	INSERT INTO hourly_exchange_rate
		SELECT b.currency_id, b.exchange_Rate, b.date_hour
		FROM (
				SELECT *
				FROM (                       
						SELECT CONCAT(dt.dt, ' ', hr.hr) AS date_hour
						FROM (	SELECT MAX(LEFT(date_hour, 10)) AS dt
								FROM hourly_exchange_rate
							 ) dt CROSS JOIN
							 (
								SELECT '00:00:00' AS hr UNION ALL
								SELECT '01:00:00' AS hr UNION ALL
								SELECT '02:00:00' AS hr UNION ALL
								SELECT '03:00:00' AS hr UNION ALL
								SELECT '04:00:00' AS hr UNION ALL
								SELECT '05:00:00' AS hr UNION ALL
								SELECT '06:00:00' AS hr UNION ALL
								SELECT '07:00:00' AS hr UNION ALL
								SELECT '08:00:00' AS hr UNION ALL
								SELECT '09:00:00' AS hr UNION ALL
								SELECT '10:00:00' AS hr UNION ALL
								SELECT '11:00:00' AS hr UNION ALL
								SELECT '12:00:00' AS hr UNION ALL
								SELECT '13:00:00' AS hr UNION ALL
								SELECT '14:00:00' AS hr UNION ALL
								SELECT '15:00:00' AS hr UNION ALL
								SELECT '16:00:00' AS hr UNION ALL
								SELECT '17:00:00' AS hr UNION ALL
								SELECT '18:00:00' AS hr UNION ALL
								SELECT '19:00:00' AS hr UNION ALL
								SELECT '20:00:00' AS hr UNION ALL
								SELECT '21:00:00' AS hr UNION ALL
								SELECT '22:00:00' AS hr UNION ALL
								SELECT '23:00:00' AS hr
							 ) hr
						WHERE CONCAT(dt.dt, ' ', hr.hr) <= (SELECT MAX(date_hour) AS max_date_hour
															FROM hourly_exchange_rate
														   )
					 ) a CROSS JOIN
					 (
						SELECT DISTINCT currency_id, exchange_rate
						FROM hourly_exchange_rate
						WHERE date_hour = ( SELECT MAX(date_hour)
											FROM hourly_exchange_rate
										  )
					 ) er
			 ) b LEFT OUTER JOIN
			 (
				SELECT date_hour, currency_id, exchange_rate
				FROM hourly_exchange_rate
				WHERE LEFT(date_hour, 10) = (	SELECT MAX(LEFT(date_hour, 10))
												FROM hourly_exchange_rate
											)
			 ) c ON b.date_hour = c.date_hour
					AND b.currency_id = c.currency_id
		WHERE c.date_hour IS NULL;

	#Prior day
	INSERT INTO hourly_exchange_rate
		SELECT b.currency_id, b.exchange_Rate, b.date_hour
		FROM (
				SELECT *
				FROM (                       
						SELECT CONCAT(dt.dt, ' ', hr.hr) AS date_hour
						FROM (	SELECT DATE_ADD(MAX(LEFT(date_hour, 10)), INTERVAL -1 DAY) AS dt
								FROM hourly_exchange_rate
							 ) dt CROSS JOIN
							 (
								SELECT '00:00:00' AS hr UNION ALL
								SELECT '01:00:00' AS hr UNION ALL
								SELECT '02:00:00' AS hr UNION ALL
								SELECT '03:00:00' AS hr UNION ALL
								SELECT '04:00:00' AS hr UNION ALL
								SELECT '05:00:00' AS hr UNION ALL
								SELECT '06:00:00' AS hr UNION ALL
								SELECT '07:00:00' AS hr UNION ALL
								SELECT '08:00:00' AS hr UNION ALL
								SELECT '09:00:00' AS hr UNION ALL
								SELECT '10:00:00' AS hr UNION ALL
								SELECT '11:00:00' AS hr UNION ALL
								SELECT '12:00:00' AS hr UNION ALL
								SELECT '13:00:00' AS hr UNION ALL
								SELECT '14:00:00' AS hr UNION ALL
								SELECT '15:00:00' AS hr UNION ALL
								SELECT '16:00:00' AS hr UNION ALL
								SELECT '17:00:00' AS hr UNION ALL
								SELECT '18:00:00' AS hr UNION ALL
								SELECT '19:00:00' AS hr UNION ALL
								SELECT '20:00:00' AS hr UNION ALL
								SELECT '21:00:00' AS hr UNION ALL
								SELECT '22:00:00' AS hr UNION ALL
								SELECT '23:00:00' AS hr
							 ) hr
					 ) a CROSS JOIN
					 (
						SELECT DISTINCT currency_id, exchange_rate
						FROM hourly_exchange_rate
						WHERE date_hour = ( SELECT MAX(date_hour)
											FROM hourly_exchange_rate
											WHERE LEFT(date_hour, 10) = (	SELECT DATE_ADD(MAX(LEFT(date_hour, 10)), INTERVAL -1 DAY) AS dt
																			FROM hourly_exchange_rate
																		)
										  )
					 ) er
			 ) b LEFT OUTER JOIN
			 (
				SELECT date_hour, currency_id, exchange_rate
				FROM hourly_exchange_rate
				WHERE LEFT(date_hour, 10) = (	SELECT DATE_ADD(MAX(LEFT(date_hour, 10)), INTERVAL -1 DAY)
												FROM hourly_exchange_rate
											)
			 ) c ON b.date_hour = c.date_hour
					AND b.currency_id = c.currency_id
		WHERE c.date_hour IS NULL;

END $$





CREATE PROCEDURE `sp_most_traded_currencies`(p_username VARCHAR(15), p_year_month DATE, p_length VARCHAR(15))
BEGIN

	SET @user_base_currency = ( SELECT base_currency_id FROM user WHERE username = p_username );


	SET @from_date = CONCAT(LEFT(p_year_month, 8), '01');
	SET @to_date = CASE WHEN p_length = 'EOMonth' THEN DATE_ADD(@from_date, INTERVAL DATEDIFF(LAST_DAY(@from_date), @from_date) DAY)
					    WHEN p_length = 'EOQuarter' THEN DATE_ADD(@from_date, INTERVAL DATEDIFF(LAST_DAY(DATE_ADD(@from_date, INTERVAL 2 MONTH)), @from_date) DAY)
                        WHEN p_length = 'EOYear' THEN CONCAT(LEFT(p_year_month, 4), '-12-31')
				   END;


	DROP TEMPORARY TABLE IF EXISTS u1;
    DROP TEMPORARY TABLE IF EXISTS u2;
    DROP TEMPORARY TABLE IF EXISTS q1;
	DROP TEMPORARY TABLE IF EXISTS q2;
	
    CREATE TEMPORARY TABLE u1 AS (
		SELECT * 
		FROM (	SELECT username, currency_id, MAX(units) AS units, MAX(timestamp) AS timestamp, 9 AS type
				FROM (	SELECT l.*
						FROM (	SELECT username, currency_id, MAX(timestamp) AS max_timestamp
								FROM ledger
								WHERE username = p_username AND timestamp < @from_date
								GROUP BY username, currency_id
							 ) g INNER JOIN ledger l ON g.username = g.username AND g.currency_id = l.currency_id AND g.max_timestamp = l.timestamp
							UNION
						SELECT p_username, id, 0, '2000-01-01 00:00:01', 1
						FROM currency
					 ) c
				GROUP BY username, currency_id
					UNION
				SELECT *
				FROM ledger
				WHERE username = p_username AND timestamp >= @from_date AND timestamp <= @to_date 
			) t1
	);
     
	CREATE TEMPORARY TABLE u2 AS ( SELECT * FROM u1 );
	

	CREATE TEMPORARY TABLE q1 AS (
		SELECT *
		FROM (	SELECT o.username, o.currency_id, o.units - r.units AS units, o.timestamp, o.type
				FROM (
						SELECT u1.username, u1.currency_id, u1.units, u1.timestamp, u1.type, MAX(u2.timestamp) AS max_timestamp
						FROM u1	INNER JOIN u2 ON u1.username = u2.username AND u1.currency_id = u2.currency_id AND u1.timestamp > u2.timestamp
						GROUP BY u1.username, u1.currency_id, u1.units, u1.timestamp, u1.type
					 ) o INNER JOIN 
					 (
						SELECT *
						FROM ledger
						WHERE username = p_username AND timestamp <= @to_date
							UNION
						SELECT p_username, id, 0, '2000-01-01 00:00:01', 1
						FROM currency
					 ) r ON o.username = r.username AND o.currency_id = r.currency_id AND o.max_timestamp = r.timestamp
			) t2
	);

	CREATE TEMPORARY TABLE q2 AS ( SELECT * FROM q1 );

   	DROP TEMPORARY TABLE IF EXISTS w1;
	DROP TEMPORARY TABLE IF EXISTS w2;
    
   	CREATE TEMPORARY TABLE w1 AS (
		SELECT *, amount_sold / buy AS value_sold, amount_bought / sell AS value_bought
		FROM (
				SELECT LEFT(q1.timestamp, 10) AS date, 
						CASE WHEN q1.units < 0 THEN q1.units ELSE NULL END AS amount_sold, y1.code AS currency_sold,
						CASE WHEN q2.units > 0 THEN q2.units ELSE NULL END AS amount_bought, y2.code AS currency_bought, 
						s1.buy, s2.sell
				FROM q1 INNER JOIN q2 ON q1.timestamp = q2.timestamp
							AND CASE WHEN q1.type = 1 AND q2.type = 1 THEN q1.units < q2.units ELSE q1.units = q2.units END
					INNER JOIN currency y1 ON q1.currency_id = y1.id
					INNER JOIN currency y2 ON q2.currency_id = y2.id
					LEFT OUTER JOIN 
					(	
						SELECT *
						FROM (
								SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)) AS buy, e1.date
								FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2
								WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date
									AND e1.currency_id = @user_base_currency AND e1.date >= @from_date AND e1.date <= @to_date
										UNION ALL
								SELECT DISTINCT @user_base_currency, 1, date FROM daily_exchange_rate WHERE date >= @from_date AND date <= @to_date
							 ) r INNER JOIN currency c ON r.currency_id = c.id
					) s1 ON LEFT(q1.timestamp, 10) = s1.date AND q1.currency_id = s1.currency_id
					LEFT OUTER JOIN 
					(	
						SELECT *
						FROM (
								SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 0.99 AS DECIMAL(14, 10)) AS sell, e1.date
								FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2
								WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date
									AND e1.currency_id = @user_base_currency AND e1.date >= @from_date AND e1.date <= @to_date
										UNION ALL
								SELECT DISTINCT @user_base_currency, 1, date FROM daily_exchange_rate WHERE date >= @from_date AND date <= @to_date
							 ) r INNER JOIN currency c ON r.currency_id = c.id
					) s2 ON LEFT(q1.timestamp, 10) = s2.date AND q2.currency_id = s2.currency_id
				WHERE q1.type = 1
		 ) n
	 );

	CREATE TEMPORARY TABLE w2 AS ( SELECT * FROM w1 );
    
    SELECT currency_sold, COUNT(currency_sold) AS count_sold, CAST(SUM(amount_sold) AS DECIMAL(14, 2)) AS units_sold, CAST(SUM(value_sold) AS DECIMAL(14, 2)) AS value_sold
    FROM w1 
	GROUP BY currency_sold
    ORDER BY count_sold DESC;

    SELECT currency_bought, COUNT(currency_bought) AS count_bought, CAST(SUM(amount_bought) AS DECIMAL(14, 2)) AS units_bought, CAST(SUM(value_bought) AS DECIMAL(14, 2)) AS value_bought
    FROM w2
	GROUP BY currency_bought
    ORDER BY count_bought DESC;

    SELECT currency_sold, COUNT(currency_sold) AS count_sold, CAST(SUM(amount_sold) AS DECIMAL(14, 2)) AS units_sold, CAST(SUM(value_sold) AS DECIMAL(14, 2)) AS value_sold
    FROM w1 
	GROUP BY currency_sold
    ORDER BY value_sold;

    SELECT currency_bought, COUNT(currency_bought) AS count_bought, CAST(SUM(amount_bought) AS DECIMAL(14, 2)) AS units_bought, CAST(SUM(value_bought) AS DECIMAL(14, 2)) AS value_bought
    FROM w2
	GROUP BY currency_bought
    ORDER BY value_bought DESC;

END $$


CREATE PROCEDURE `sp_past_performance_daily_graph`(p_base_currency_code CHAR(3), p_days_back SMALLINT)
BEGIN

	SET @currency_id = ( SELECT id FROM currency WHERE code = p_base_currency_code );
	SET @ledger_begin_date = DATE_ADD( ( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL (p_days_back - 1) * -1 DAY);


	SELECT c.code AS currency_id, date, total, 
									 CASE WHEN 1 - (1 - total) * 10 < 0 THEN 0 ELSE 1 - (1 - total) * 10 END AS total_amp_ten, 
									 CASE WHEN 1 - (1 - total) * 50 < 0 THEN 0 ELSE 1 - (1 - total) * 50 END AS total_amp_fifty, 
									 CASE WHEN 1 - (1 - total) * 100 < 0 THEN 0 ELSE 1 - (1 - total) * 100 END AS total_amp_hundred
	FROM (	SELECT o.currency_id, o.date, CAST(o.units / e.buy AS DECIMAL(14, 10)) AS total
			FROM (	SELECT l.currency_id, l.units, d.date
					FROM (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1 AS DECIMAL(14, 10)) AS units, @ledger_begin_date AS date
							FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2
							WHERE e1.date = e2.date AND e1.currency_id <> e2.currency_id AND e1.currency_id = @currency_id
									AND e1.date = @ledger_begin_date
						 ) l INNER JOIN ( SELECT DISTINCT date 
										  FROM daily_exchange_rate
										  WHERE date >= @ledger_begin_date
										) d ON l.date <= d.date
				 ) o INNER JOIN (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate AS DECIMAL(14, 10)) AS buy, e1.date
									FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2
									WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND e1.date >= @ledger_begin_date
										AND e1.currency_id = @currency_id
								) e ON o.date = e.date AND o.currency_id = e.currency_id
		 ) s INNER JOIN currency c ON s.currency_id = c.id
	ORDER BY c.code, date;


END $$


CREATE PROCEDURE `sp_past_performance_hourly_graph`(p_base_currency_code CHAR(3), p_hours_back SMALLINT)
BEGIN

	SET @currency_id = ( SELECT id FROM currency WHERE code = p_base_currency_code );
	SET @ledger_begin_date_hour = DATE_ADD( ( SELECT MAX(date_hour) FROM hourly_exchange_rate ), INTERVAL (p_hours_back - 1) * -1 HOUR);


	SELECT c.code AS currency_id, date_hour, total, 
									 CASE WHEN 1 - (1 - total) * 10 < 0 THEN 0 ELSE 1 - (1 - total) * 10 END AS total_amp_ten, 
									 CASE WHEN 1 - (1 - total) * 50 < 0 THEN 0 ELSE 1 - (1 - total) * 50 END AS total_amp_fifty, 
									 CASE WHEN 1 - (1 - total) * 100 < 0 THEN 0 ELSE 1 - (1 - total) * 100 END AS total_amp_hundred
	FROM (	SELECT o.currency_id, o.date_hour, CAST(o.units / e.buy AS DECIMAL(14, 10)) AS total
			FROM (	SELECT l.currency_id, l.units, d.date_hour
					FROM (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1 AS DECIMAL(14, 10)) AS units, @ledger_begin_date_hour AS date_hour
							FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
							WHERE e1.date_hour = e2.date_hour AND e1.currency_id <> e2.currency_id AND e1.currency_id = @currency_id
									AND e1.date_hour = @ledger_begin_date_hour
						 ) l INNER JOIN ( SELECT DISTINCT date_hour 
										  FROM hourly_exchange_rate
										  WHERE date_hour >= @ledger_begin_date_hour
										) d ON l.date_hour <= d.date_hour
				 ) o INNER JOIN (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate AS DECIMAL(14, 10)) AS buy, e1.date_hour
									FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
									WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour AND e1.date_hour >= @ledger_begin_date_hour
										AND e1.currency_id = @currency_id
								) e ON o.date_hour = e.date_hour AND o.currency_id = e.currency_id
		 ) s INNER JOIN currency c ON s.currency_id = c.id
    ORDER BY c.code, date_hour;


END $$


CREATE PROCEDURE `sp_past_performance_statement_graph`(p_base_currency_code CHAR(3), p_date VARCHAR(10), p_days VARCHAR(10))
BEGIN
    
	SET @p_days = CASE WHEN p_days = 'EOMonth' THEN DATEDIFF(LAST_DAY(p_date), p_date) 
					   WHEN p_days = 'EOQuarter' THEN DATEDIFF(MAKEDATE(YEAR(p_date), 1) + INTERVAL QUARTER(p_date) QUARTER - INTERVAL 1 DAY, p_date)
                       WHEN p_days = 'EOYear' THEN DATEDIFF(CONCAT(LEFT(p_date, 4), '-12-31'), p_date)
                       ELSE p_days END;

	SET @from_date = p_date;
	SET @to_date = DATE_ADD(p_date, INTERVAL @p_days DAY);
  
	SELECT c.exchange, CAST((c.rate_mid - d.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff'
    FROM (
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = @to_date
		 ) c INNER JOIN
		 (
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = @from_date
		 ) d ON c.exchange = d.exchange
	ORDER BY diff DESC;
         
END $$


CREATE PROCEDURE `sp_past_performance_table`(p_base_currency_code CHAR(3))
BEGIN
    
	DROP TEMPORARY TABLE IF EXISTS c;
	CREATE TEMPORARY TABLE c AS ( 
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid
			FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour AND c1.code = p_base_currency_code
				AND e1.date_hour = ( SELECT MAX(date_hour) FROM hourly_exchange_rate )
	);
	DROP TEMPORARY TABLE IF EXISTS d1;
	CREATE TEMPORARY TABLE d1 AS ( 
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = DATE_ADD(( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL - 3 DAY)
	);
	DROP TEMPORARY TABLE IF EXISTS d2;
	CREATE TEMPORARY TABLE d2 AS ( 
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = DATE_ADD(( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL - 1 WEEK)
	);
	DROP TEMPORARY TABLE IF EXISTS d3;
	CREATE TEMPORARY TABLE d3 AS ( 
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = DATE_ADD(( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL - 1 MONTH)
	);
	DROP TEMPORARY TABLE IF EXISTS d4;
	CREATE TEMPORARY TABLE d4 AS ( 
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = DATE_ADD(( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL - 3 MONTH)
	);
	DROP TEMPORARY TABLE IF EXISTS d5;
	CREATE TEMPORARY TABLE d5 AS ( 
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = DATE_ADD(( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL - 1 YEAR)
	);
	DROP TEMPORARY TABLE IF EXISTS d6;
	CREATE TEMPORARY TABLE d6 AS ( 
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = ( SELECT MIN(date) FROM daily_exchange_rate )
	);

	SELECT c.exchange, CAST((c.rate_mid - d1.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff3day',
					   CAST((c.rate_mid - d2.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff1week',
                       CAST((c.rate_mid - d3.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff1month',
                       CAST((c.rate_mid - d4.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff3month',
                       CAST((c.rate_mid - d5.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff1year',
                       CAST((c.rate_mid - d6.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diffmax'
    FROM c 
		INNER JOIN d1 
			ON c.exchange = d1.exchange 
		INNER JOIN d2 
			ON c.exchange = d2.exchange 
		INNER JOIN d3 
			ON c.exchange = d3.exchange 
		INNER JOIN d4 
			ON c.exchange = d4.exchange 
		INNER JOIN d5 
			ON c.exchange = d5.exchange 
		INNER JOIN d6 
			ON c.exchange = d6.exchange;

    /*
	SELECT c.exchange, CAST((c.rate_mid - d1.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff3day',
					   CAST((c.rate_mid - d2.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff1week',
                       CAST((c.rate_mid - d3.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff1month',
                       CAST((c.rate_mid - d4.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff3month',
                       CAST((c.rate_mid - d5.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diff1year',
                       CAST((c.rate_mid - d6.rate_mid) / (c.rate_mid / 100) AS DECIMAL(5, 2)) AS 'diffmax'
    FROM (
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid
			FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour AND c1.code = p_base_currency_code
				AND e1.date_hour = ( SELECT MAX(date_hour) FROM hourly_exchange_rate )
		 ) c INNER JOIN
		 (
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = DATE_ADD(( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL - 3 DAY)
		 ) d1 ON c.exchange = d1.exchange INNER JOIN
		 (
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = DATE_ADD(( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL - 1 WEEK)
		 ) d2 ON c.exchange = d2.exchange INNER JOIN
		 (
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = DATE_ADD(( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL - 1 MONTH)
		 ) d3 ON c.exchange = d3.exchange INNER JOIN
		 (
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = DATE_ADD(( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL - 3 MONTH)
		 ) d4 ON c.exchange = d4.exchange INNER JOIN
		 (
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = DATE_ADD(( SELECT MAX(date) FROM daily_exchange_rate ), INTERVAL - 1 YEAR)
		 ) d5 ON c.exchange = d5.exchange INNER JOIN
		 (
			SELECT c2.code AS exchange, 1 / e1.exchange_rate * e2.exchange_rate AS rate_mid	
			FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2 INNER JOIN currency c1 ON e1.currency_id = c1.id INNER JOIN currency c2 ON e2.currency_id = c2.id
			WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date AND c1.code = p_base_currency_code
					AND e1.date = ( SELECT MIN(date) FROM daily_exchange_rate )
		 ) d6 ON c.exchange = d6.exchange;
      */   
         
END $$


CREATE PROCEDURE `sp_statements_monthly_links`(p_username VARCHAR(15))
BEGIN
	
	SELECT DISTINCT CONCAT(LEFT(MONTHNAME(STR_TO_DATE(RIGHT(LEFT(date, 7), 2), '%m')), 3), ' ', LEFT(date, 4)) AS year_month_statement, 
		   CASE WHEN LEFT(date, 4) = LEFT(CURDATE(), 4) THEN NULL ELSE LEFT(date, 4) END AS year,
		   LEFT(date, 7) AS date_ord
	FROM daily_exchange_rate
	WHERE date >= ( SELECT LEFT(MIN(timestamp), 10) FROM ledger WHERE username = p_username ) AND date < CONCAT(LEFT(CURDATE(), 7), '-01')

		UNION ALL

	SELECT DISTINCT LEFT(date, 4), NULL, CONCAT(LEFT(date, 4), '-13')
	FROM daily_exchange_rate
	WHERE date >= ( SELECT LEFT(MIN(timestamp), 10) FROM ledger WHERE username = p_username ) AND date < CONCAT(LEFT(CURDATE(), 4), '-01-01')

	ORDER BY date_ord DESC;

END $$


CREATE PROCEDURE `sp_statements_quarterly_links`(p_username VARCHAR(15))
BEGIN
	
	SELECT DISTINCT CASE WHEN QUARTER(date) = 1 THEN CONCAT(YEAR(date), ' ', QUARTER(date), 'st Quarter') 
						 WHEN QUARTER(date) = 2 THEN CONCAT(YEAR(date), ' ', QUARTER(date), 'nd Quarter')
						 WHEN QUARTER(date) = 3 THEN CONCAT(YEAR(date), ' ', QUARTER(date), 'rd Quarter') 
						 WHEN QUARTER(date) = 4 THEN CONCAT(YEAR(date), ' ', QUARTER(date), 'th Quarter') 
					END AS year_quarter_statement, 
                    CASE WHEN LEFT(date, 4) = LEFT(CURDATE(), 4) THEN NULL ELSE LEFT(date, 4) END AS year,
					CONCAT(YEAR(date),' ', QUARTER(date)) AS date_ord,
                    CASE WHEN QUARTER(date) = 1 THEN CONCAT(YEAR(date), '-01-01') 
						 WHEN QUARTER(date) = 2 THEN CONCAT(YEAR(date), '-04-01')
						 WHEN QUARTER(date) = 3 THEN CONCAT(YEAR(date), '-07-01') 
						 WHEN QUARTER(date) = 4 THEN CONCAT(YEAR(date), '-10-01') 
					END AS date_link
	FROM daily_exchange_rate
	WHERE date >= ( SELECT LEFT(MIN(timestamp), 10) FROM ledger WHERE username = p_username ) AND CONCAT(YEAR(date), QUARTER(date)) < CONCAT(YEAR(CURDATE()), QUARTER(CURDATE()))

		UNION ALL
		
	SELECT DISTINCT LEFT(date, 4) AS year_end_statement, NULL, CONCAT(LEFT(date, 4), ' ', 5), NULL
	FROM daily_exchange_rate
	WHERE date >= ( SELECT LEFT(MIN(timestamp), 10) FROM ledger WHERE username = p_username ) AND date < CONCAT(LEFT(CURDATE(), 4), '-01-01')

	ORDER BY date_ord DESC;

END $$


CREATE PROCEDURE `sp_statements_yearly_links`(p_username VARCHAR(15))
BEGIN
	
	SELECT DISTINCT LEFT(date, 4) AS year_end_statement
	FROM daily_exchange_rate
	WHERE date >= ( SELECT LEFT(MIN(timestamp), 10) FROM ledger WHERE username = p_username ) AND date < CONCAT(LEFT(CURDATE(), 4), '-01-01')
	ORDER BY year_end_statement DESC;

END $$


CREATE PROCEDURE `sp_trade`(p_username VARCHAR(15), p_currency_code_sell CHAR(3), p_units_sell DECIMAL(12, 2), p_currency_code_buy CHAR(3))
BEGIN

	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
	BEGIN
		ROLLBACK; 
	END;

	DECLARE EXIT HANDLER FOR SQLWARNING
	BEGIN
		ROLLBACK;
	END;

	SET @currency_id_sell = (SELECT id FROM currency WHERE code = p_currency_code_sell);
    SET @currency_id_buy = (SELECT id FROM currency WHERE code = p_currency_code_buy);
	SET @ledger_units_sell = ( SELECT IFNULL( ( SELECT units FROM ledger WHERE username = p_username AND currency_id = @currency_id_sell ORDER BY timestamp DESC LIMIT 1 ), 0 ) );
    SET @ledger_units_buy = ( SELECT IFNULL( ( SELECT units FROM ledger WHERE username = p_username AND currency_id = @currency_id_buy ORDER BY timestamp DESC LIMIT 1 ), 0 ) );
	SET @latest_trading_hour = ( SELECT MAX(date_hour) FROM hourly_exchange_rate );
    SET @user_base_currency = ( SELECT base_currency_id FROM user WHERE username = p_username );
	SET @sell_rate = (	SELECT sell_rate
						FROM (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)) AS sell_rate #1.00015
								FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
								WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour 
										AND e1.currency_id = @user_base_currency 
										AND e1.date_hour = @latest_trading_hour 
									UNION ALL
								SELECT @user_base_currency, 1
							 ) s
						WHERE currency_id = @currency_id_sell );
	SET @buy_rate = (	SELECT buy_rate
						FROM (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 0.99 AS DECIMAL(14, 10)) AS buy_rate
								FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
								WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour 
										AND e1.currency_id = @user_base_currency 
										AND e1.date_hour = @latest_trading_hour 
									UNION ALL
								SELECT @user_base_currency, 1
							 ) s
						WHERE currency_id = @currency_id_buy );
    
    START TRANSACTION;
		IF ( SELECT DISTINCT timestamp FROM ledger WHERE timestamp = CONCAT(CURDATE(), ' ', CURTIME()) AND username = p_username ) THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trade limit is one per second per user.';
        ELSE
			IF ( p_units_sell < 0.01 ) THEN
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sell amount minimum is 0.01.';
			ELSE
				IF ( ( p_units_sell / @sell_rate * @buy_rate ) < 0.01 ) THEN
					SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Buy amount minimum is 0.01.';
				ELSE
					INSERT INTO ledger
					VALUES (p_username, @currency_id_sell, CAST(@ledger_units_sell - p_units_sell AS DECIMAL(12, 2)), CONCAT(CURDATE(), ' ', CURTIME()), 1),
						   (p_username, @currency_id_buy, CAST(@ledger_units_buy + ( p_units_sell / @sell_rate * @buy_rate ) AS DECIMAL(12, 2)), CONCAT(CURDATE(), ' ', CURTIME()), 1);
				END IF;
			END IF;
		END IF;
	COMMIT;

END $$


CREATE PROCEDURE `sp_trade_history`(p_username VARCHAR(15), p_year_month DATE, p_length VARCHAR(15), p_sort VARCHAR(15))
BEGIN

	SET @user_base_currency = ( SELECT base_currency_id FROM user WHERE username = p_username );


	SET @from_date = CONCAT(LEFT(p_year_month, 8), '01');
	SET @to_date = CASE WHEN p_length = 'EOMonth' THEN DATE_ADD(@from_date, INTERVAL DATEDIFF(LAST_DAY(@from_date), @from_date) DAY)
					    WHEN p_length = 'EOQuarter' THEN DATE_ADD(@from_date, INTERVAL DATEDIFF(LAST_DAY(DATE_ADD(@from_date, INTERVAL 2 MONTH)), @from_date) DAY)
                        WHEN p_length = 'EOYear' THEN CONCAT(LEFT(p_year_month, 4), '-12-31')
				   END;


	DROP TEMPORARY TABLE IF EXISTS u1;
    DROP TEMPORARY TABLE IF EXISTS u2;
    DROP TEMPORARY TABLE IF EXISTS q1;
	DROP TEMPORARY TABLE IF EXISTS q2;
	
    CREATE TEMPORARY TABLE u1 AS (
		SELECT * 
		FROM (	SELECT username, currency_id, MAX(units) AS units, MAX(timestamp) AS timestamp, 9 AS type
				FROM (	SELECT l.*
						FROM (	SELECT username, currency_id, MAX(timestamp) AS max_timestamp
								FROM ledger
								WHERE username = p_username AND timestamp < @from_date
								GROUP BY username, currency_id
							 ) g INNER JOIN ledger l ON g.username = g.username AND g.currency_id = l.currency_id AND g.max_timestamp = l.timestamp
							UNION
						SELECT p_username, id, 0, '2000-01-01 00:00:01', 1
						FROM currency
					 ) c
				GROUP BY username, currency_id
					UNION
				SELECT *
				FROM ledger
				WHERE username = p_username AND timestamp >= @from_date AND timestamp <= @to_date 
			) t1
	);
     
	CREATE TEMPORARY TABLE u2 AS ( SELECT * FROM u1 );
	

	CREATE TEMPORARY TABLE q1 AS (
		SELECT *
		FROM (	SELECT o.username, o.currency_id, o.units - r.units AS units, o.timestamp, o.type
				FROM (
						SELECT u1.username, u1.currency_id, u1.units, u1.timestamp, u1.type, MAX(u2.timestamp) AS max_timestamp
						FROM u1	INNER JOIN u2 ON u1.username = u2.username AND u1.currency_id = u2.currency_id AND u1.timestamp > u2.timestamp
						GROUP BY u1.username, u1.currency_id, u1.units, u1.timestamp, u1.type
					 ) o INNER JOIN 
					 (
						SELECT *
						FROM ledger
						WHERE username = p_username AND timestamp <= @to_date
							UNION
						SELECT p_username, id, 0, '2000-01-01 00:00:01', 1
						FROM currency
					 ) r ON o.username = r.username AND o.currency_id = r.currency_id AND o.max_timestamp = r.timestamp
			) t2
	);

	CREATE TEMPORARY TABLE q2 AS ( SELECT * FROM q1 );

    
    
	SELECT LEFT(q1.timestamp, 10) AS date, 
			CASE WHEN q1.type = 1 THEN 'Trade' 
				 WHEN q1.type = 2 THEN 'Gift' 
				 WHEN q1.type = 3 AND q1.units > 0 THEN 'Deposit' 
				 WHEN q1.type = 3 AND q1.units < 0 THEN 'Withdrawal' END AS type, 
			CONCAT(CASE WHEN q1.units < 0 THEN q1.units ELSE NULL END, ' ', y1.code) AS units_sold,
			CONCAT(CASE WHEN q2.units > 0 THEN CONCAT('+', q2.units) ELSE NULL END, ' ', y2.code) AS units_bought, 
			s.total AS daily_balance
	FROM q1 INNER JOIN q2 ON q1.timestamp = q2.timestamp
				AND CASE WHEN q1.type = 1 AND q2.type = 1 THEN q1.units < q2.units ELSE q1.units = q2.units END
		INNER JOIN currency y1 ON q1.currency_id = y1.id
		INNER JOIN currency y2 ON q2.currency_id = y2.id
		LEFT OUTER JOIN 
		(	
			SELECT DATE_ADD(o.date, INTERVAL -1 DAY) AS date, SUM(CAST(r.units / e.buy AS DECIMAL(12, 2))) AS total
			FROM (	SELECT d.date, l.currency_id, username, MAX(timestamp) AS max_timestamp
					FROM (	SELECT *
							FROM (	SELECT DISTINCT date
									FROM daily_exchange_rate
										UNION
									SELECT DATE_ADD(MAX(date), INTERVAL 1 DAY)
									FROM daily_exchange_rate
								 ) u
							WHERE date >= @from_date AND date <= @to_date
						 ) d INNER JOIN ledger l ON d.date >= l.timestamp
								WHERE l.username = p_username
					GROUP BY d.date, l.currency_id, username
				 ) o INNER JOIN ledger r ON o.username = r.username AND o.currency_id = r.currency_id AND o.max_timestamp = r.timestamp
					INNER JOIN (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)) AS buy, e1.date
									FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2
									WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date
										AND e1.currency_id = @user_base_currency AND e1.date >= @from_date AND e1.date <= @to_date
											UNION ALL
									SELECT DISTINCT @user_base_currency, 1, date FROM daily_exchange_rate WHERE date >= @from_date AND date <= @to_date
								) e ON DATE_ADD(o.date, INTERVAL -1 DAY) = e.date AND o.currency_id = e.currency_id
			GROUP BY o.date
		) s ON LEFT(q1.timestamp, 10) = s.date
	ORDER BY CASE WHEN p_sort = 'Asc' THEN q1.timestamp END, CASE WHEN p_sort = 'Desc' THEN q1.timestamp END DESC;

END $$


CREATE PROCEDURE `sp_trades_per_month`(p_username VARCHAR(15), p_year_month DATE, p_length VARCHAR(15))
BEGIN

	SET @user_base_currency = ( SELECT base_currency_id FROM user WHERE username = p_username );

	SET @from_date = CONCAT(LEFT(p_year_month, 8), '01');
	SET @to_date = CASE WHEN p_length = 'EOMonth' THEN DATE_ADD(@from_date, INTERVAL DATEDIFF(LAST_DAY(@from_date), @from_date) DAY)
					    WHEN p_length = 'EOQuarter' THEN DATE_ADD(@from_date, INTERVAL DATEDIFF(LAST_DAY(DATE_ADD(@from_date, INTERVAL 2 MONTH)), @from_date) DAY)
                        WHEN p_length = 'EOYear' THEN CONCAT(LEFT(p_year_month, 4), '-12-31')
				   END;


	DROP TEMPORARY TABLE IF EXISTS u1;
    DROP TEMPORARY TABLE IF EXISTS u2;
    DROP TEMPORARY TABLE IF EXISTS q1;
	DROP TEMPORARY TABLE IF EXISTS q2;
	
    CREATE TEMPORARY TABLE u1 AS (
		SELECT * 
		FROM (	SELECT username, currency_id, MAX(units) AS units, MAX(timestamp) AS timestamp, 9 AS type
				FROM (	SELECT l.*
						FROM (	SELECT username, currency_id, MAX(timestamp) AS max_timestamp
								FROM ledger
								WHERE username = p_username AND timestamp < @from_date
								GROUP BY username, currency_id
							 ) g INNER JOIN ledger l ON g.username = g.username AND g.currency_id = l.currency_id AND g.max_timestamp = l.timestamp
							UNION
						SELECT p_username, id, 0, '2000-01-01 00:00:01', 1
						FROM currency
					 ) c
				GROUP BY username, currency_id
					UNION
				SELECT *
				FROM ledger
				WHERE username = p_username AND timestamp >= @from_date AND timestamp <= @to_date 
			) t1
	);
     
	CREATE TEMPORARY TABLE u2 AS ( SELECT * FROM u1 );
	

	CREATE TEMPORARY TABLE q1 AS (
		SELECT *
		FROM (	SELECT o.username, o.currency_id, o.units - r.units AS units, o.timestamp, o.type
				FROM (
						SELECT u1.username, u1.currency_id, u1.units, u1.timestamp, u1.type, MAX(u2.timestamp) AS max_timestamp
						FROM u1	INNER JOIN u2 ON u1.username = u2.username AND u1.currency_id = u2.currency_id AND u1.timestamp > u2.timestamp
						GROUP BY u1.username, u1.currency_id, u1.units, u1.timestamp, u1.type
					 ) o INNER JOIN 
					 (
						SELECT *
						FROM ledger
						WHERE username = p_username AND timestamp <= @to_date
							UNION
						SELECT p_username, id, 0, '2000-01-01 00:00:01', 1
						FROM currency
					 ) r ON o.username = r.username AND o.currency_id = r.currency_id AND o.max_timestamp = r.timestamp
			) t2
	);

	CREATE TEMPORARY TABLE q2 AS ( SELECT * FROM q1 );

   	DROP TEMPORARY TABLE IF EXISTS w1;
   	DROP TEMPORARY TABLE IF EXISTS w2;
   	DROP TEMPORARY TABLE IF EXISTS w3;


   	CREATE TEMPORARY TABLE w1 AS (
		SELECT *, amount_sold / buy AS value_sold, amount_bought / sell AS value_bought
		FROM (
				SELECT LEFT(q1.timestamp, 10) AS date, 
						CASE WHEN q1.units < 0 THEN q1.units ELSE NULL END AS amount_sold, y1.code AS currency_sold,
						CASE WHEN q2.units > 0 THEN q2.units ELSE NULL END AS amount_bought, y2.code AS currency_bought, 
						s1.buy, s2.sell
				FROM q1 INNER JOIN q2 ON q1.timestamp = q2.timestamp
							AND CASE WHEN q1.type = 1 AND q2.type = 1 THEN q1.units < q2.units ELSE q1.units = q2.units END
					INNER JOIN currency y1 ON q1.currency_id = y1.id
					INNER JOIN currency y2 ON q2.currency_id = y2.id
					LEFT OUTER JOIN 
					(	
						SELECT *
						FROM (
								SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)) AS buy, e1.date
								FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2
								WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date
									AND e1.currency_id = @user_base_currency AND e1.date >= @from_date AND e1.date <= @to_date
										UNION ALL
								SELECT DISTINCT @user_base_currency, 1, date FROM daily_exchange_rate WHERE date >= @from_date AND date <= @to_date
							 ) r INNER JOIN currency c ON r.currency_id = c.id
					) s1 ON LEFT(q1.timestamp, 10) = s1.date AND q1.currency_id = s1.currency_id
					LEFT OUTER JOIN 
					(	
						SELECT *
						FROM (
								SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 0.99 AS DECIMAL(14, 10)) AS sell, e1.date
								FROM daily_exchange_rate e1 CROSS JOIN daily_exchange_rate e2
								WHERE e1.currency_id <> e2.currency_id AND e1.date = e2.date
									AND e1.currency_id = @user_base_currency AND e1.date >= @from_date AND e1.date <= @to_date
										UNION ALL
								SELECT DISTINCT @user_base_currency, 1, date FROM daily_exchange_rate WHERE date >= @from_date AND date <= @to_date
							 ) r INNER JOIN currency c ON r.currency_id = c.id
					) s2 ON LEFT(q1.timestamp, 10) = s2.date AND q2.currency_id = s2.currency_id
				WHERE q1.type = 1
		 ) n
	 );

	CREATE TEMPORARY TABLE w2 AS ( SELECT * FROM w1 );
	CREATE TEMPORARY TABLE w3 AS ( SELECT * FROM w1 );    
   
    SELECT COALESCE(d.month, m.month) AS month, IFNULL(number_of_trades, 0) AS number_of_trades, IFNULL(volume_of_trades, 0.00) AS volume_of_trades,
			most_sold_currency, most_bought_currency
    FROM (
			SELECT LEFT(MONTHNAME(STR_TO_DATE(RIGHT(LEFT(date, 7), 2), '%m')), 3) AS month,
					COUNT(date) AS number_of_trades, CAST((SUM(value_sold * -1) + SUM(value_bought)) / 2 AS DECIMAL(12, 2)) AS volume_of_trades,
					( SELECT currency_sold FROM w2 WHERE LEFT(date, 7) = LEFT(w1.date, 7) GROUP BY LEFT(date,7), currency_sold ORDER BY SUM(value_sold) LIMIT 1 ) AS most_sold_currency,
					( SELECT currency_bought FROM w3 WHERE LEFT(date, 7) = LEFT(w1.date, 7) GROUP BY LEFT(date,7), currency_bought ORDER BY SUM(value_bought) DESC LIMIT 1 ) AS most_bought_currency
			FROM w1
			GROUP BY LEFT(date, 7)
		 ) d RIGHT OUTER JOIN ( SELECT 1 AS ord, 'Jan' AS month UNION ALL SELECT 2 AS ord, 'Feb' AS month UNION ALL SELECT 3 AS ord, 'Mar' AS month UNION ALL
							    SELECT 4 AS ord, 'Apr' AS month UNION ALL SELECT 5 AS ord, 'May' AS month UNION ALL SELECT 6 AS ord, 'Jun' AS month UNION ALL
							    SELECT 7 AS ord, 'Jul' AS month UNION ALL SELECT 8 AS ord, 'Aug' AS month UNION ALL SELECT 9 AS ord, 'Sep' AS month UNION ALL
							    SELECT 10 AS ord, 'Oct' AS month UNION ALL SELECT 11 AS ord, 'Nov' AS month UNION ALL SELECT 12 AS ord, 'Dec' AS month
							  ) m ON d.month = m.month
	ORDER BY m.ord;

END $$


CREATE PROCEDURE `sp_trading_board`(p_username VARCHAR(15), p_rates_or_prices VARCHAR(10))
BEGIN
	SET @latest_trading_hour = ( SELECT MAX(date_hour) FROM hourly_exchange_rate );
    SET @user_base_currency = ( SELECT base_currency_id FROM user WHERE username = p_username );

	

    SELECT d.id, d.code, d.name,   			
            CASE WHEN p_rates_or_prices = 'Rates' THEN u.rate_trend WHEN p_rates_or_prices = 'Prices' THEN u.rate_trend * -1 END AS trend, 
            CASE WHEN p_rates_or_prices = 'Rates' THEN u.rate_buy WHEN p_rates_or_prices = 'Prices' THEN u.price_buy END AS buy, 
            CASE WHEN p_rates_or_prices = 'Rates' THEN u.rate_sell WHEN p_rates_or_prices = 'Prices' THEN u.price_sell END AS sell,
            u.graph, CASE WHEN d.units = 0 THEN NULL ELSE d.units END AS units, 
            CASE WHEN d.value_in_base_currency = 0 THEN NULL ELSE d.value_in_base_currency END AS value_in_base_currency
    FROM (	#Trends and exchange rates, prices for latest currency hourly reading returned to 6 digits, rather than 6 decimal precision regardless of order of magnitude
			SELECT rc.currency_id, CASE WHEN rc.rate_buy > rp.rate_buy THEN 1 WHEN rc.rate_buy < rp.rate_buy THEN -1 ELSE 0 END AS rate_trend, rc.rate_buy, rc.rate_sell,
				   CASE WHEN rc.price_buy > rp.price_buy THEN 1 WHEN rc.price_buy < rp.price_buy THEN -1 ELSE 0 END AS price_trend, rc.price_buy, rc.price_sell, 1 AS graph
			FROM (	SELECT e2.currency_id, 
							LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 1.01)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 1.01)) -7), 7)) AS rate_buy,
							LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate * 0.99 AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 0.99)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 0.99)) -7), 7)) AS rate_sell,
							LEFT( CAST(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01))) -7) > 7, ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01))) -7), 7)) AS price_buy, 
							LEFT( CAST(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99))) -7) > 7, ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99))) -7), 7)) AS price_sell
					FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
					WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour AND e1.currency_id = @user_base_currency AND e1.date_hour = @latest_trading_hour
				 ) rc #current readings converted to the user's base currency
				 INNER JOIN
				 (	SELECT e2.currency_id, 
							LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 1.01)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 1.01)) -7), 7)) AS rate_buy,
							LEFT( CAST(1 / e1.exchange_rate * e2.exchange_rate * 0.99 AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 0.99)) -7) > 7, ABS(FLOOR(LOG10(1 / e1.exchange_rate * e2.exchange_rate * 0.99)) -7), 7)) AS rate_sell,
							LEFT( CAST(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01))) -7) > 7, ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 1.01))) -7), 7)) AS price_buy, 
							LEFT( CAST(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99) AS DECIMAL(14, 10)), IF(ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99))) -7) > 7, ABS(FLOOR(LOG10(1 / ((1 / e1.exchange_rate * e2.exchange_rate) * 0.99))) -7), 7)) AS price_sell
					FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
					WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour AND e1.currency_id = @user_base_currency AND e1.date_hour = DATE_ADD(@latest_trading_hour, INTERVAL -1 HOUR)
				 ) rp ON rc.currency_id = rp.currency_id #one hour prior readings for trend comparison
				UNION ALL
			SELECT @user_base_currency, '2', 1.00000, 1.00000, '2', 1.00000, 1.00000, 0
		 ) u INNER JOIN
         (	#Present time currency distribution plus their value in the user's base currency
			SELECT c.id, c.code, c.name, MAX(g.units) AS units, MAX(g.value_in_base_currency) AS value_in_base_currency
			FROM (	SELECT m.currency_id, l.units, CAST(units / buy AS DECIMAL(12, 2)) AS value_in_base_currency
					FROM (	SELECT currency_id, username, MAX(timestamp) AS max_timestamp
							FROM ledger
							WHERE username = p_username
							GROUP BY currency_id, username
						 ) m INNER JOIN ledger l ON m.max_timestamp = l.timestamp AND m.currency_id = l.currency_id AND m.username = l.username
						 INNER JOIN (	SELECT e2.currency_id, CAST(1 / e1.exchange_rate * e2.exchange_rate * 1.01 AS DECIMAL(14, 10)) AS buy
										FROM hourly_exchange_rate e1 CROSS JOIN hourly_exchange_rate e2
										WHERE e1.currency_id <> e2.currency_id AND e1.date_hour = e2.date_hour 
											AND e1.currency_id = @user_base_currency
											AND e1.date_hour = @latest_trading_hour
												UNION ALL
										SELECT @user_base_currency, NULL
									) r ON m.currency_id = r.currency_id
						UNION
					SELECT id, NULL, NULL
					FROM currency
				 ) g INNER JOIN currency c ON g.currency_id = c.id
			GROUP BY c.id, c.code, c.name
		 ) d ON u.currency_id = d.id
	ORDER BY u.currency_id;


END $$

DELIMITER ;




