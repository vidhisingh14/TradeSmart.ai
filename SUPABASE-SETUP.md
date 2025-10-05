# 🚀 Supabase Setup Guide - Easy Database Management

> **Recommended Approach:** Use Supabase instead of self-hosted TimescaleDB for easier management!

## 🎯 Why Supabase?

### **Benefits Over Self-Hosted TimescaleDB**

| Feature | Supabase | Self-Hosted TimescaleDB |
|---------|----------|-------------------------|
| **Setup Time** | 5 minutes | 30+ minutes |
| **Management** | Zero maintenance | Manual updates/backups |
| **TimescaleDB Support** | ✅ Built-in extension | ✅ Requires config |
| **Backups** | ✅ Automatic | ❌ Manual setup |
| **Scaling** | ✅ Click to upgrade | ❌ Complex migration |
| **Dashboard** | ✅ Visual SQL editor | ❌ CLI only |
| **SSL/Security** | ✅ Built-in | ❌ Manual config |
| **Free Tier** | ✅ 500MB database | ❌ Your server costs |
| **Connection Pooling** | ✅ PgBouncer included | ❌ Manual setup |

**Verdict:** Supabase is **10x easier** for hackathons and MVPs! 🏆

---

## 📋 Quick Setup (5 Minutes)

### **Step 1: Create Supabase Project**

1. Go to [supabase.com](https://supabase.com)
2. Click "Start your project"
3. Sign in with GitHub
4. Create new project:
   - **Name:** `tradesmart-ai`
   - **Database Password:** (save this!)
   - **Region:** Choose closest to India (Singapore or Mumbai if available)
   - **Plan:** Free tier (500MB - enough for 50+ stocks)

### **Step 2: Enable TimescaleDB Extension**

1. Go to **Database** → **Extensions** in Supabase dashboard
2. Search for "timescaledb"
3. Click "Enable" ✅

![Enable TimescaleDB](https://supabase.com/docs/img/timescaledb-extension.png)

### **Step 3: Run Database Schema**

1. Go to **SQL Editor** in Supabase dashboard
2. Create new query
3. Copy and paste this schema:

```sql
-- Enable TimescaleDB extension
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

-- Create indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_ohlc_symbol_time ON ohlc_data (symbol, time DESC);
CREATE INDEX IF NOT EXISTS idx_ohlc_timeframe ON ohlc_data (timeframe, symbol, time DESC);

-- Retention policy: auto-delete data older than 30 days
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

-- Continuous aggregate for 1h OHLC (performance optimization)
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

-- Add continuous aggregate policy (refresh hourly)
SELECT add_continuous_aggregate_policy('ohlc_1h_recent',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE);
```

4. Click "Run" ✅

### **Step 4: Get Connection Details**

1. Go to **Settings** → **Database** in Supabase
2. Copy these values:

```
Host: db.<project-id>.supabase.co
Database: postgres
Port: 5432
User: postgres
Password: <your-password>
```

3. **Connection String** (pooler - recommended):
```
postgresql://postgres.xxxx:password@aws-0-ap-south-1.pooler.supabase.com:6543/postgres
```

---

## ⚙️ Configure TradeSmart.AI

### **Update .env File**

Replace TimescaleDB config with Supabase:

```bash
# Supabase PostgreSQL (Recommended)
DATABASE_URL=postgresql://postgres.xxxx:password@aws-0-ap-south-1.pooler.supabase.com:6543/postgres
TIMESCALE_HOST=db.<project-id>.supabase.co
TIMESCALE_PORT=6543  # Use pooler port for better performance
TIMESCALE_DB=postgres
TIMESCALE_USER=postgres
TIMESCALE_PASSWORD=your_supabase_password

# Redis (Keep Upstash or local)
REDIS_URL=redis://localhost:6379

# Cerebras API
CEREBRAS_API_KEY=your_cerebras_api_key
```

### **Using Supabase Connection Pooler (Recommended)**

For better performance, use **pooler** port:

```bash
# Pooler (6543) - Recommended for high traffic
DATABASE_URL=postgresql://postgres.xxxx:password@aws-0-ap-south-1.pooler.supabase.com:6543/postgres
TIMESCALE_PORT=6543

# Direct (5432) - For migrations/admin tasks
# DATABASE_URL=postgresql://postgres.xxxx:password@db.xxxx.supabase.co:5432/postgres
# TIMESCALE_PORT=5432
```

---

## 🐳 Updated Docker Setup (Optional)

### **Option A: Supabase Only (Recommended)**

Remove TimescaleDB from docker-compose, keep only:

```yaml
version: '3.9'

services:
  # Redis - Caching layer
  redis:
    image: redis:7-alpine
    container_name: tradesmart-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - tradesmart-network
    command: redis-server --appendonly yes

  # MCP Server
  mcp-server:
    build:
      context: ./backend
      dockerfile: Dockerfile.mcp
    container_name: tradesmart-mcp-server
    environment:
      - CEREBRAS_API_KEY=${CEREBRAS_API_KEY}
      - DATABASE_URL=${DATABASE_URL}  # Supabase URL
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
    networks:
      - tradesmart-network

  # Backend
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: tradesmart-backend
    environment:
      - CEREBRAS_API_KEY=${CEREBRAS_API_KEY}
      - DATABASE_URL=${DATABASE_URL}  # Supabase URL
      - REDIS_URL=redis://redis:6379
      - FRONTEND_URL=${FRONTEND_URL:-http://localhost:3000}
    ports:
      - "8000:8000"
    depends_on:
      - redis
      - mcp-server
    networks:
      - tradesmart-network

networks:
  tradesalemart-network:
    driver: bridge

volumes:
  redis_data:
```

### **Option B: Hybrid (Supabase + Local Redis)**

Even simpler - no database container:

```yaml
version: '3.9'

services:
  # Backend only (connects to Supabase)
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: tradesmart-backend
    environment:
      - CEREBRAS_API_KEY=${CEREBRAS_API_KEY}
      - DATABASE_URL=${DATABASE_URL}  # Supabase
      - REDIS_URL=${REDIS_URL}        # Upstash or local
    ports:
      - "8000:8000"
```

---

## ✅ Verify Setup

### **Test Database Connection**

```bash
# Install psql (if not installed)
# Mac: brew install postgresql
# Ubuntu: sudo apt-get install postgresql-client
# Windows: Download from postgresql.org

# Connect to Supabase
psql "postgresql://postgres.xxxx:password@db.xxxx.supabase.co:5432/postgres"

# Test query
SELECT * FROM ohlc_data LIMIT 1;
```

### **Test from Python**

```python
import asyncpg
import asyncio

async def test_connection():
    conn = await asyncpg.connect(
        "postgresql://postgres.xxxx:password@db.xxxx.supabase.co:6543/postgres"
    )

    # Test query
    result = await conn.fetch("SELECT NOW()")
    print(f"✅ Connected! Server time: {result[0]['now']}")

    await conn.close()

asyncio.run(test_connection())
```

---

## 📊 Supabase Dashboard Features

### **1. SQL Editor**
- Visual query builder
- Save queries
- Export results as CSV
- Real-time query execution

### **2. Table Editor**
- View/edit data visually
- Filter and sort
- Bulk operations
- Export to JSON/CSV

### **3. Database Backups**
- Daily automatic backups
- Point-in-time recovery (paid plans)
- Download backups

### **4. Logs & Monitoring**
- Query performance
- Connection stats
- Error logs
- Real-time metrics

### **5. API Auto-Generation**
- RESTful API (optional)
- GraphQL API (optional)
- Real-time subscriptions

---

## 🚀 Seed Data to Supabase

```bash
# Run seed script (uses Supabase connection from .env)
python backend/seed_data.py

# Choose number of stocks:
# 1. Top 10 (Quick)
# 2. Top 20 (Medium)
# 3. Top 50 (Full)
```

---

## 💡 Pro Tips

### **1. Use Connection Pooler**
```bash
# Pooler URL (6543) - Better for apps
postgresql://postgres.xxxx:password@aws-0-ap-south-1.pooler.supabase.com:6543/postgres

# Direct URL (5432) - For migrations
postgresql://postgres.xxxx:password@db.xxxx.supabase.co:5432/postgres
```

### **2. Monitor Usage**
- Dashboard → Settings → Usage
- Track database size
- Monitor API requests
- Check bandwidth

### **3. Enable Row Level Security (Optional)**
```sql
-- Add RLS for security (if exposing API)
ALTER TABLE ohlc_data ENABLE ROW LEVEL SECURITY;

-- Create policy (example: read-only for all)
CREATE POLICY "Allow read access" ON ohlc_data
    FOR SELECT USING (true);
```

### **4. Upgrade to Pro (If Needed)**
Free tier limits:
- 500MB database
- 2GB bandwidth/month
- 50,000 monthly active users

Pro tier ($25/month):
- 8GB database
- 250GB bandwidth
- Unlimited users
- Point-in-time recovery

---

## 🎯 Quick Start Commands

```bash
# 1. Update .env with Supabase credentials
cp .env.docker .env
nano .env  # Add Supabase DATABASE_URL

# 2. Seed database
python backend/seed_data.py

# 3. Start backend
docker-compose up -d

# 4. Test API
curl http://localhost:8000/health
```

---

## 🔄 Migration from Local TimescaleDB

Already using local TimescaleDB? Migrate easily:

```bash
# 1. Dump local database
docker exec tradesmart-timescaledb pg_dump -U tradesmart tradesmart > backup.sql

# 2. Import to Supabase
psql "postgresql://postgres.xxxx:password@db.xxxx.supabase.co:5432/postgres" < backup.sql

# 3. Update .env
# Change DATABASE_URL to Supabase URL

# 4. Restart backend
docker-compose restart backend
```

---

## 🏆 Supabase vs Self-Hosted - Final Verdict

**Use Supabase if:**
- ✅ You want easy management
- ✅ Building MVP/hackathon project
- ✅ Need automatic backups
- ✅ Want zero DevOps
- ✅ Cloud deployment

**Use Self-Hosted if:**
- ❌ Need 100% control
- ❌ Have strict data locality requirements
- ❌ Already have infrastructure team

**For TradeSmart.AI Hackathon:** **Supabase is PERFECT!** 🎯

---

## 📚 Resources

- [Supabase Documentation](https://supabase.com/docs)
- [TimescaleDB in Supabase](https://supabase.com/docs/guides/database/extensions/timescaledb)
- [Connection Pooling](https://supabase.com/docs/guides/database/connecting-to-postgres#connection-pooler)
- [Supabase Dashboard](https://app.supabase.com)

---

**🎉 Your database is now managed by Supabase - Zero maintenance required!**
