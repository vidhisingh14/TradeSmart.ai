# 📊 TradeSmart.AI - Complete Data Flow Architecture

## 🗄️ **TimescaleDB: PostgreSQL + Time-Series Extension**

### **What is TimescaleDB?**

```
TimescaleDB = PostgreSQL 15 + Time-Series Extension
                      ↓
            Perfect for OHLC Data
                      ↓
            Auto-partitioning by time
                      ↓
            10-100x faster queries
```

**Why TimescaleDB for Trading?**
- ✅ **Hypertables** - Automatic data partitioning by time
- ✅ **Continuous Aggregates** - Pre-computed 1h/1d summaries
- ✅ **Retention Policies** - Auto-delete old data
- ✅ **Compression** - Reduces storage by 90%
- ✅ **Time-bucketing** - Lightning-fast time-range queries

---

## 📥 **Data Ingestion Flow - NSE India**

### **Complete Data Pipeline**

```
┌─────────────────────────────────────────────────────┐
│                   DATA SOURCES                       │
│  (Yahoo Finance API - Free for NSE India)           │
│                                                      │
│  Nifty 50 Stocks:                                   │
│  - RELIANCE, TCS, INFY, HDFCBANK, etc.             │
│  - Real-time prices                                 │
│  - Historical OHLC data                             │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────┐
│           NSE FETCHER (nse_fetcher.py)              │
│                                                      │
│  1. Fetch from Yahoo Finance API                    │
│     - Symbol: RELIANCE.NS, TCS.NS, etc.            │
│     - Interval: 1m, 5m, 15m, 30m, 1h, 1d           │
│     - Period: 1d, 5d, 1mo, 3mo, 1y, max            │
│                                                      │
│  2. Parse JSON Response                             │
│     - Extract timestamps                            │
│     - Extract OHLC values                           │
│     - Extract volume                                │
│                                                      │
│  3. Transform to Standard Format                    │
│     {                                               │
│       'time': datetime,                             │
│       'open': float,                                │
│       'high': float,                                │
│       'low': float,                                 │
│       'close': float,                               │
│       'volume': float                               │
│     }                                               │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────┐
│        OHLC REPOSITORY (ohlc_repository.py)         │
│                                                      │
│  Insert into TimescaleDB:                           │
│                                                      │
│  INSERT INTO ohlc_data (                            │
│    time, symbol, timeframe,                         │
│    open, high, low, close, volume                   │
│  ) VALUES (...) ON CONFLICT DO UPDATE              │
│                                                      │
│  ✅ Upsert logic (no duplicates)                    │
│  ✅ Batch insert (fast)                             │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────┐
│         TIMESCALEDB (PostgreSQL + Extension)        │
│                                                      │
│  Table: ohlc_data (Hypertable)                      │
│  ├── time (TIMESTAMPTZ) - Partition key            │
│  ├── symbol (VARCHAR)                               │
│  ├── timeframe (VARCHAR)                            │
│  ├── open, high, low, close (DECIMAL)              │
│  └── volume (DECIMAL)                               │
│                                                      │
│  Features:                                          │
│  ✅ Auto-partitioned by time (chunks)               │
│  ✅ Retention: 30 days (auto-delete)                │
│  ✅ Continuous aggregates (1h view)                 │
│  ✅ Compressed old data (90% savings)               │
└──────────────────────────────────────────────────────┘
```

---

## ⏰ **Automated Data Updates - Scheduler**

### **Data Scheduler Flow**

```
┌─────────────────────────────────────────────────────┐
│        DATA SCHEDULER (data_scheduler.py)           │
│        (APScheduler - Background Tasks)             │
└──────────────────┬──────────────────────────────────┘
                   │
        ┌──────────┼──────────┐
        ↓          ↓          ↓
   [STARTUP]  [HOURLY]   [DAILY]
        │          │          │
        ↓          ↓          ↓

┌─────────────────────────────────────────────────────┐
│  STARTUP (Once on server start):                    │
│                                                      │
│  1. Fetch Nifty 50 stock list                       │
│  2. Get top 10 stocks                               │
│  3. Fetch 10 days of 1h data                        │
│  4. Store in TimescaleDB                            │
│                                                      │
│  Result: Database ready with initial data           │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  HOURLY (Mon-Fri, 9:00-15:00 IST):                 │
│                                                      │
│  Cron: 0 9-15 * * 1-5 (Every hour during market)   │
│                                                      │
│  1. Check market hours (9:15 AM - 3:30 PM)         │
│  2. Fetch latest 1h candle for all stocks          │
│  3. Update TimescaleDB                              │
│                                                      │
│  Result: Real-time hourly updates                   │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  DAILY (Mon-Fri, 15:45 IST):                       │
│                                                      │
│  Cron: 45 15 * * 1-5 (After market close)          │
│                                                      │
│  1. Fetch daily candle for all stocks              │
│  2. Fetch last 30 days for completeness            │
│  3. Store in TimescaleDB                            │
│                                                      │
│  Result: Complete daily data archive                │
└─────────────────────────────────────────────────────┘
```

---

## 🔄 **On-Demand Data Fetching**

### **When User Requests New Stock**

```
User → POST /api/strategy/build
        {
          "symbol": "WIPRO",
          "timeframe": "1h"
        }
              ↓
    ┌─────────────────┐
    │ Check Database  │
    │ for WIPRO 1h    │
    └────────┬────────┘
             │
      ┌──────┴──────┐
      │ Data Exists? │
      └──────┬──────┘
             │
    ┌────────┴────────┐
    │ NO              │ YES
    ↓                 ↓
┌─────────────┐   ┌──────────────┐
│ Fetch Data  │   │ Use Cached   │
│ from Yahoo  │   │ from DB      │
│             │   │              │
│ Store in DB │   │ Return Data  │
└─────────────┘   └──────────────┘
```

---

## 📊 **Database Schema Details**

### **Table: ohlc_data (Hypertable)**

```sql
CREATE TABLE ohlc_data (
    time TIMESTAMPTZ NOT NULL,        -- 2024-01-15 10:00:00+00
    symbol VARCHAR(20) NOT NULL,      -- RELIANCE, TCS, INFY
    timeframe VARCHAR(10) NOT NULL,   -- 1h, 1d, 15m
    open DECIMAL(20, 8) NOT NULL,     -- 2458.50
    high DECIMAL(20, 8) NOT NULL,     -- 2465.75
    low DECIMAL(20, 8) NOT NULL,      -- 2455.00
    close DECIMAL(20, 8) NOT NULL,    -- 2462.30
    volume DECIMAL(20, 8) NOT NULL,   -- 1500000
    PRIMARY KEY (time, symbol, timeframe)
);

-- Convert to hypertable (TimescaleDB magic!)
SELECT create_hypertable('ohlc_data', 'time');

-- Auto-delete data older than 30 days
SELECT add_retention_policy('ohlc_data', INTERVAL '30 days');
```

### **Table: annotations**

```sql
CREATE TABLE annotations (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,      -- RELIANCE
    annotation_data JSONB NOT NULL,   -- {type, coordinates, style, label}
    created_at TIMESTAMPTZ NOT NULL   -- 2024-01-15 14:30:00+00
);
```

---

## 🚀 **How to Seed Database (First Time)**

### **Option 1: Manual Seed Script**

```bash
# Navigate to backend
cd backend

# Run seed script
python seed_data.py

# Choose:
# 1. Top 10 stocks (~2 min)
# 2. Top 20 stocks (~5 min)
# 3. All 50 stocks (~10 min)
```

### **Option 2: Automatic (On Server Start)**

```bash
# Just start the server
docker-compose up -d

# Data scheduler runs automatically:
# ✅ Fetches initial data on startup
# ✅ Updates hourly during market hours
# ✅ Daily updates at market close
```

---

## 📈 **Stock Data Coverage**

### **Nifty 50 Stocks (Top Indian Companies)**

```python
# Included in NSEFetcher
nifty50_stocks = [
    "RELIANCE",    # Reliance Industries
    "TCS",         # Tata Consultancy Services
    "HDFCBANK",    # HDFC Bank
    "INFY",        # Infosys
    "ICICIBANK",   # ICICI Bank
    "HINDUNILVR",  # Hindustan Unilever
    "BHARTIARTL",  # Bharti Airtel
    "ITC",         # ITC Limited
    "SBIN",        # State Bank of India
    "KOTAKBANK",   # Kotak Mahindra Bank
    # ... and 40 more
]
```

**Yahoo Finance Format:**
- NSE: `RELIANCE.NS`
- BSE: `RELIANCE.BO`

---

## 🔍 **Data Query Flow (When AI Needs Data)**

```
AI Agent needs data
        ↓
┌─────────────────────┐
│ MCP Tool:           │
│ get_ohlc_data       │
└──────┬──────────────┘
       ↓
┌─────────────────────┐
│ OHLCRepository      │
│ .get_ohlc_data()    │
└──────┬──────────────┘
       ↓
┌─────────────────────┐
│ TimescaleDB Query:  │
│                     │
│ SELECT * FROM       │
│ ohlc_data WHERE     │
│ symbol = 'RELIANCE' │
│ AND timeframe='1h'  │
│ ORDER BY time DESC  │
│ LIMIT 240           │
└──────┬──────────────┘
       ↓
┌─────────────────────┐
│ Return OHLC data    │
│ to AI agent         │
│                     │
│ Agent analyzes      │
│ & builds strategy   │
└─────────────────────┘
```

---

## ⚡ **Performance Optimizations**

### **1. Redis Caching**
```
First Request:
User → API → TimescaleDB → Redis (cache) → User
           (slow - 100ms)

Subsequent Requests:
User → API → Redis → User
           (fast - <10ms)
```

### **2. Continuous Aggregates**
```sql
-- Pre-computed 1h view (instant queries)
CREATE MATERIALIZED VIEW ohlc_1h_recent AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    symbol,
    first(open, time) AS open,
    max(high) AS high,
    min(low) AS low,
    last(close, time) AS close,
    sum(volume) AS volume
FROM ohlc_data
GROUP BY bucket, symbol;
```

### **3. Data Retention**
```sql
-- Auto-delete old data (saves storage)
SELECT add_retention_policy(
    'ohlc_data',
    INTERVAL '30 days'
);

-- Result: Only 30 days kept, older data auto-deleted
```

---

## 🛠️ **Quick Start Commands**

### **Seed Database**
```bash
# Option 1: Interactive
python backend/seed_data.py

# Option 2: Automatic
docker-compose up -d
# (Scheduler runs initial fetch)
```

### **Check Data**
```bash
# Access database
docker exec -it tradesmart-timescaledb psql -U tradesmart -d tradesmart

# Query data
SELECT symbol, COUNT(*) as candles
FROM ohlc_data
GROUP BY symbol;

# Check latest prices
SELECT symbol, time, close
FROM ohlc_data
ORDER BY time DESC
LIMIT 10;
```

### **Monitor Scheduler**
```bash
# View logs
docker-compose logs -f backend

# You'll see:
# ✅ Data scheduler started (NSE India)
# ⏰ Fetching hourly updates...
# ✅ Hourly update complete
```

---

## 📚 **Data Sources Explained**

### **Yahoo Finance API (Free)**
- **URL:** `https://query1.finance.yahoo.com/v8/finance/chart/`
- **Symbols:** NSE stocks with `.NS` suffix
- **Data:** Real-time prices, historical OHLC
- **Rate Limits:** ~2000 requests/hour (generous)
- **Cost:** FREE ✅

**Example Request:**
```
GET https://query1.finance.yahoo.com/v8/finance/chart/RELIANCE.NS?interval=1h&period=10d

Response:
{
  "chart": {
    "result": [{
      "timestamp": [1705320000, 1705323600, ...],
      "indicators": {
        "quote": [{
          "open": [2458.50, 2462.30, ...],
          "high": [2465.75, 2470.00, ...],
          "low": [2455.00, 2460.50, ...],
          "close": [2462.30, 2468.75, ...],
          "volume": [1500000, 1600000, ...]
        }]
      }
    }]
  }
}
```

---

## 🎯 **Summary**

### **Data Flow in 4 Steps:**

1. **🌐 Yahoo Finance** → Provides free NSE stock data
2. **📥 NSE Fetcher** → Downloads and transforms OHLC data
3. **🗄️ TimescaleDB** → Stores in hypertable (PostgreSQL)
4. **🤖 AI Agents** → Query via MCP tools for analysis

### **Key Features:**
- ✅ **Automatic Updates** - Scheduler runs hourly
- ✅ **No Manual Work** - Everything automated
- ✅ **Real NSE Data** - Live Indian stock prices
- ✅ **Time-Series Optimized** - 10-100x faster queries
- ✅ **Free Forever** - Yahoo Finance API is free

---

**Your database is now a professional-grade time-series database with automatic NSE India stock data! 🚀**
