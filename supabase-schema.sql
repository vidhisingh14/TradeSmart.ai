-- TradeSmart.AI - Supabase PostgreSQL Schema
-- (Without TimescaleDB - using native PostgreSQL partitioning)

-- Enable useful extensions
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- Better time-based indexes
CREATE EXTENSION IF NOT EXISTS pg_cron;     -- Scheduled tasks

-- OHLC table with NATIVE PostgreSQL partitioning by time
CREATE TABLE IF NOT EXISTS ohlc_data (
    time TIMESTAMPTZ NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    open DECIMAL(20, 8) NOT NULL,
    high DECIMAL(20, 8) NOT NULL,
    low DECIMAL(20, 8) NOT NULL,
    close DECIMAL(20, 8) NOT NULL,
    volume DECIMAL(20, 8) NOT NULL,
    PRIMARY KEY (time, symbol, timeframe)
) PARTITION BY RANGE (time);

-- Create partitions for current and next month (auto-managed)
DO $$
DECLARE
    start_date DATE := DATE_TRUNC('month', CURRENT_DATE);
    partition_name TEXT;
BEGIN
    -- Create partition for current month
    partition_name := 'ohlc_data_' || TO_CHAR(start_date, 'YYYY_MM');
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF ohlc_data FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        start_date,
        start_date + INTERVAL '1 month'
    );

    -- Create partition for next month
    start_date := start_date + INTERVAL '1 month';
    partition_name := 'ohlc_data_' || TO_CHAR(start_date, 'YYYY_MM');
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF ohlc_data FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        start_date,
        start_date + INTERVAL '1 month'
    );

    -- Create partition for month after
    start_date := start_date + INTERVAL '1 month';
    partition_name := 'ohlc_data_' || TO_CHAR(start_date, 'YYYY_MM');
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF ohlc_data FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        start_date,
        start_date + INTERVAL '1 month'
    );
END $$;

-- Create indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_ohlc_symbol_time ON ohlc_data (symbol, time DESC);
CREATE INDEX IF NOT EXISTS idx_ohlc_timeframe ON ohlc_data (timeframe, symbol, time DESC);
CREATE INDEX IF NOT EXISTS idx_ohlc_time_range ON ohlc_data USING GIST (time, symbol);

-- Annotations table for chart annotations
CREATE TABLE IF NOT EXISTS annotations (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,
    annotation_data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for annotations
CREATE INDEX IF NOT EXISTS idx_annotations_symbol ON annotations (symbol);
CREATE INDEX IF NOT EXISTS idx_annotations_created_at ON annotations (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_annotations_data ON annotations USING GIN (annotation_data);

-- Create materialized view for 1h aggregates (optional performance boost)
CREATE MATERIALIZED VIEW IF NOT EXISTS ohlc_1h_summary AS
SELECT
    DATE_TRUNC('hour', time) AS hour,
    symbol,
    timeframe,
    COUNT(*) AS candle_count,
    MIN(low) AS period_low,
    MAX(high) AS period_high,
    FIRST_VALUE(open) OVER (PARTITION BY DATE_TRUNC('hour', time), symbol ORDER BY time) AS period_open,
    LAST_VALUE(close) OVER (PARTITION BY DATE_TRUNC('hour', time), symbol ORDER BY time) AS period_close,
    SUM(volume) AS total_volume
FROM ohlc_data
WHERE time > NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('hour', time), symbol, timeframe, time, open, close
WITH NO DATA;

-- Create index on materialized view
CREATE INDEX IF NOT EXISTS idx_ohlc_summary_hour ON ohlc_1h_summary (hour DESC, symbol);

-- Function to refresh materialized view (call this periodically)
CREATE OR REPLACE FUNCTION refresh_ohlc_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY ohlc_1h_summary;
END;
$$ LANGUAGE plpgsql;

-- Schedule automatic refresh every hour using pg_cron
SELECT cron.schedule(
    'refresh-ohlc-summary',
    '0 * * * *',  -- Every hour
    'SELECT refresh_ohlc_summary();'
);

-- Function to auto-create new partitions (run monthly)
CREATE OR REPLACE FUNCTION create_next_partition()
RETURNS void AS $$
DECLARE
    next_month DATE := DATE_TRUNC('month', CURRENT_DATE + INTERVAL '3 months');
    partition_name TEXT;
BEGIN
    partition_name := 'ohlc_data_' || TO_CHAR(next_month, 'YYYY_MM');

    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF ohlc_data FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        next_month,
        next_month + INTERVAL '1 month'
    );

    RAISE NOTICE 'Created partition: %', partition_name;
END;
$$ LANGUAGE plpgsql;

-- Schedule partition creation (1st of every month)
SELECT cron.schedule(
    'create-monthly-partition',
    '0 0 1 * *',  -- First day of month at midnight
    'SELECT create_next_partition();'
);

-- Function to drop old partitions (data retention)
CREATE OR REPLACE FUNCTION drop_old_partitions()
RETURNS void AS $$
DECLARE
    old_month DATE := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '3 months');
    partition_name TEXT;
BEGIN
    partition_name := 'ohlc_data_' || TO_CHAR(old_month, 'YYYY_MM');

    EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);

    RAISE NOTICE 'Dropped old partition: %', partition_name;
END;
$$ LANGUAGE plpgsql;

-- Schedule old partition cleanup (1st of every month)
SELECT cron.schedule(
    'cleanup-old-partitions',
    '0 1 1 * *',  -- First day of month at 1 AM
    'SELECT drop_old_partitions();'
);

-- Grant necessary permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ TradeSmart.AI database initialized successfully!';
    RAISE NOTICE '✅ PostgreSQL native partitioning: enabled';
    RAISE NOTICE '✅ OHLC table with time-based partitions: created';
    RAISE NOTICE '✅ Annotations table: created';
    RAISE NOTICE '✅ Indexes: created';
    RAISE NOTICE '✅ Automatic partition management: scheduled';
    RAISE NOTICE '✅ Data retention: 3 months (configurable)';
END $$;

-- View current partitions
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE tablename LIKE 'ohlc_data%'
ORDER BY tablename;
