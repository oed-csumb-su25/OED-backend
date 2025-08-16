-- Enable the extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Convert the table to a hypertable
SELECT create_hypertable('metrics', 'time');

-- You can then query the hypertable as a regular table
SELECT * FROM readings WHERE start_timestamp <= now() - interval '1 day'
ORDER BY START_TIMESTAMP;

SELECT * FROM cik_time_vary WHERE start_time <= now() - interval '1 day';
DELETE FROM cik;

SELECT DISTINCT source_id FROM cik WHERE start_time <= now() - interval '1 day';

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'meters';
SELECT cik.*,meters.id,meters.name from cik inner join meters on meters.id = cik.source_id



"Natural Gas Cubic Meters"


SELECT create_hypertable('cik_time_vary', 'start_time');

seLECT set_chunk_time_interval

CREATE TABLE cik_time_vary AS
TABLE cik;
ALTER TABLE cik_time_vary
ADD COLUMN time TIMESTAMPTZ;


UPDATE cik_time_vary
    SET time = start_time AT TIME ZONE 'PDT';

	SELECT create_hypertable('cik_time_vary', 'time',migrate_data => TRUE);

SELECT add_continuous_aggregate_policy(
    'cik_time_vary',
    start_offset => INTERVAL 'your_start_offset',
    end_offset => INTERVAL 'your_end_offset',
    schedule_interval => INTERVAL 'your_schedule_interval'
);



select clock_timestamp() at time zone 'PDT';
select shift_readings('Natural Gas Cubic Meters','PDT')
drop table cik_ht

CREATE TABLE IF NOT EXISTS cik_ht (
	row_index INTEGER,
	column_index INTEGER,
	slope FLOAT,
	intercept FLOAT,
	PRIMARY KEY (row_index, column_index)
);


CREATE TABLE cik_ht (
   time        TIMESTAMPTZ       NOT NULL,
   location    TEXT              NOT NULL,
   device      TEXT              NOT NULL,
   temperature DOUBLE PRECISION  NULL,
   humidity    DOUBLE PRECISION  NULL
) WITH (
   tsdb.hypertable,
   tsdb.partition_column='time',
   tsdb.chunk_interval='1 hour'
);





EXPLAIN CREATE MATERIALIZED VIEW IF NOT EXISTS meter_hourly_readings_unit_cont
AS
WITH base_hourly AS (
	SELECT
		r.meter_id,
		CASE
		WHEN u.unit_represent = 'quantity'::unit_represent_type THEN
			(
			SUM(
				(r.reading * 3600 / EXTRACT(EPOCH FROM (r.end_timestamp - r.start_timestamp))) *
				EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			) /
			SUM(
				EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			)
			)
		WHEN u.unit_represent IN ('flow'::unit_represent_type, 'raw'::unit_represent_type) THEN
			(
			SUM(
				(r.reading * 3600 / u.sec_in_rate) *
				EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			) /
			SUM(
				EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			)
			)
		END AS reading_rate,

		CASE
		WHEN u.unit_represent = 'quantity'::unit_represent_type THEN
			MAX(
			(
				(r.reading * 3600 / EXTRACT(EPOCH FROM (r.end_timestamp - r.start_timestamp))) *
				EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			) /
			EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			)
		WHEN u.unit_represent IN ('flow'::unit_represent_type, 'raw'::unit_represent_type) THEN
			MAX(
			(
				(r.reading * 3600 / u.sec_in_rate) *
				EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			) /
			EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			)
		END AS max_rate,

		CASE
		WHEN u.unit_represent = 'quantity'::unit_represent_type THEN
			MIN(
			(
				(r.reading * 3600 / EXTRACT(EPOCH FROM (r.end_timestamp - r.start_timestamp))) *
				EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			) /
			EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			)
		WHEN u.unit_represent IN ('flow'::unit_represent_type, 'raw'::unit_represent_type) THEN
			MIN(
			(
				(r.reading * 3600 / u.sec_in_rate) *
				EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			) /
			EXTRACT(EPOCH FROM LEAST(r.end_timestamp, gen.interval_start + INTERVAL '1 hour') - GREATEST(r.start_timestamp, gen.interval_start))
			)
		END AS min_rate,

		tsrange(gen.interval_start, gen.interval_start + INTERVAL '1 hour', '()') AS time_interval

	FROM readings r
	INNER JOIN meters m ON r.meter_id = m.id
	INNER JOIN units u ON m.unit_id = u.id
	CROSS JOIN LATERAL generate_series(
		date_trunc('hour', r.start_timestamp),
		date_trunc_up('hour', r.end_timestamp) - INTERVAL '1 hour',
		INTERVAL '1 hour'
	) gen(interval_start)
	GROUP BY r.meter_id, gen.interval_start, u.unit_represent
)
SELECT
  	bh.meter_id,
	(
		bh.reading_rate * SUM(
		(EXTRACT(EPOCH FROM (
			upper(tsrange(c.start_time, c.end_time, '()') * tsrange(lower(bh.time_interval), upper(bh.time_interval), '[]'))
			-
			lower(tsrange(c.start_time, c.end_time, '()') * tsrange(lower(bh.time_interval), upper(bh.time_interval), '[]'))
		)) / 3600)
		* c.slope + c.intercept)
	) AS reading_rate,
	(
		bh.min_rate * SUM(
		(EXTRACT(EPOCH FROM (
			upper(tsrange(c.start_time, c.end_time, '()') * tsrange(lower(bh.time_interval), upper(bh.time_interval), '[]'))
			-
			lower(tsrange(c.start_time, c.end_time, '()') * tsrange(lower(bh.time_interval), upper(bh.time_interval), '[]'))
		)) / 3600)
		* c.slope + c.intercept)
	) AS min_rate,
  	(
		bh.max_rate * SUM(
		(EXTRACT(EPOCH FROM (
			upper(tsrange(c.start_time, c.end_time, '()') * tsrange(lower(bh.time_interval), upper(bh.time_interval), '[]'))
			-
			lower(tsrange(c.start_time, c.end_time, '()') * tsrange(lower(bh.time_interval), upper(bh.time_interval), '[]'))
		)) / 3600)
		* c.slope + c.intercept)
	) AS max_rate,
  	bh.time_interval,
  	c.destination_id AS graphic_unit_id

FROM base_hourly bh
INNER JOIN meters m ON m.id = bh.meter_id
INNER JOIN units u ON m.unit_id = u.id
INNER JOIN cik c ON c.source_id = m.unit_id AND tsrange(c.start_time, c.end_time, '()') && bh.time_interval
GROUP BY bh.meter_id, bh.time_interval, c.destination_id, bh.reading_rate, bh.min_rate, bh.max_rate
ORDER BY bh.meter_id, c.destination_id, bh.time_interval;

CREATE INDEX if not exists idx_meter_hourly_ordering ON meter_hourly_readings_unit (meter_id, graphic_unit_id, lower(time_interval)); -- Used by the line/3d/compare functions.

meter_hourly_readings_unit
timescaledb.chunk_interval


select meter_line_readings_unit('{10}', 1 , '-infinity', 'infinity', 'hourly', 200, 200);
