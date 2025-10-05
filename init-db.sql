-- TradeSmart.AI Database Initialization
-- TimescaleDB Schema for OHLC data and annotations

-- Create TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- OHLC table for candlestick data
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
);

-- Convert to hypertable (TimescaleDB feature)
SELECT create_hypertable('ohlc_data', 'time', if_not_exists => TRUE);

-- Create index for fast queries
CREATE INDEX IF NOT EXISTS idx_ohlc_symbol_time ON ohlc_data (symbol, time DESC);
CREATE INDEX IF NOT EXISTS idx_ohlc_timeframe ON ohlc_data (timeframe, symbol, time DESC);

-- Retention policy: auto-delete data older than 30 days (adjust as needed)
SELECT add_retention_policy('ohlc_data', INTERVAL '30 days', if_not_exists => TRUE);

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

-- Continuous aggregate for 1h OHLC (optional performance optimization)
CREATE MATERIALIZED VIEW IF NOT EXISTS ohlc_1h_recent
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    symbol,
    first(open, time) AS open,
    max(high) AS high,
    min(low) AS low,
    last(close, time) AS close,
    sum(volume) AS volume
FROM ohlc_data
WHERE time > NOW() - INTERVAL '30 days'
GROUP BY bucket, symbol
WITH NO DATA;

-- Add continuous aggregate policy to refresh every hour
SELECT add_continuous_aggregate_policy('ohlc_1h_recent',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE);

-- Sample data insertion (for testing)
-- Uncomment to insert sample BTC/USD data
/*
INSERT INTO ohlc_data (time, symbol, timeframe, open, high, low, close, volume) VALUES
    (NOW() - INTERVAL '1 hour', 'BTC/USD', '1h', 65000.00, 65500.00, 64800.00, 65200.00, 1500.50),
    (NOW() - INTERVAL '2 hours', 'BTC/USD', '1h', 64800.00, 65200.00, 64600.00, 65000.00, 1400.25),
    (NOW() - INTERVAL '3 hours', 'BTC/USD', '1h', 65200.00, 65400.00, 64800.00, 64800.00, 1600.75)
ON CONFLICT (time, symbol, timeframe) DO NOTHING;
*/

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO tradesmart;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO tradesmart;

-- Confirmation message
DO $$
BEGIN
    RAISE NOTICE 'TradeSmart.AI database initialized successfully!';
    RAISE NOTICE 'TimescaleDB extension: enabled';
    RAISE NOTICE 'OHLC hypertable: created';
    RAISE NOTICE 'Annotations table: created';
    RAISE NOTICE 'Indexes: created';
    RAISE NOTICE 'Retention policy: 30 days';
END $$;
