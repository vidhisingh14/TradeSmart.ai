# 🐳 TradeSmart.AI Docker Deployment Guide

Complete guide for deploying TradeSmart.AI using Docker MCP Gateway architecture.

## 📋 Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB+ RAM available
- Cerebras API key ([Get one here](https://cloud.cerebras.ai/))

## 🚀 Quick Start

### 1. Clone and Configure

```bash
# Clone repository
cd TradeSmart.ai

# Create environment file
cp .env.docker .env

# Edit .env and add your Cerebras API key
nano .env  # or use your preferred editor
```

### 2. Start All Services

```bash
# Build and start all containers
docker-compose up -d

# View logs
docker-compose logs -f

# Check service health
docker-compose ps
```

### 3. Verify Deployment

```bash
# Check backend health
curl http://localhost:8000/health

# Test strategy building
curl -X POST http://localhost:8000/api/strategy/build \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Create a swing trading strategy for BTC using RSI",
    "symbol": "BTC/USD",
    "timeframe": "1h"
  }'
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Docker Network                      │
│                 tradesmart-network                   │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐        │
│  │  Redis   │  │TimescaleDB│  │ MCP Server │        │
│  │  Cache   │  │ Database  │  │  Gateway   │        │
│  └────┬─────┘  └─────┬────┘  └──────┬─────┘        │
│       │              │               │              │
│       └──────────────┴───────────────┘              │
│                      │                              │
│               ┌──────▼──────┐                       │
│               │   FastAPI   │                       │
│               │   Backend   │                       │
│               │ (3 AI Agents)│                      │
│               └──────┬──────┘                       │
│                      │                              │
└──────────────────────┼──────────────────────────────┘
                       │
                    Port 8000
                       │
                  ┌────▼────┐
                  │ Frontend │
                  │(Optional)│
                  └─────────┘
```

## 📦 Services

### 1. **TimescaleDB** (Port 5432)
- Time-series database for OHLC data
- Auto-initialized with schema
- 30-day retention policy
- Continuous aggregates for performance

### 2. **Redis** (Port 6379)
- High-performance caching
- Strategy result caching
- Market data caching

### 3. **MCP Server** (Docker MCP Gateway)
- 6 specialized tools:
  - `get_ohlc_data` - Fetch candlestick data
  - `calculate_indicators` - Technical indicators
  - `detect_liquidation_levels` - Support/resistance
  - `create_chart_annotation` - Visual markers
  - `create_liquidation_zone` - Zone rectangles
  - `generate_strategy` - Strategy synthesis

### 4. **FastAPI Backend** (Port 8000)
- 3 AI Agents (Cerebras):
  - Orchestrator (Llama 3.1 70B)
  - Liquidation Agent (Llama 3.1 8B)
  - Indicator Agent (Llama 3.1 8B)
- REST API endpoints
- WebSocket support

## 🔧 Configuration

### Environment Variables

Edit `.env` file:

```bash
# REQUIRED
CEREBRAS_API_KEY=your_key_here

# Database (defaults are fine for local)
TIMESCALE_USER=tradesmart
TIMESCALE_PASSWORD=tradesmart123

# Optional
BINANCE_API_KEY=your_binance_key
BINANCE_API_SECRET=your_binance_secret
```

### Custom Configuration

**Adjust resource limits** in `docker-compose.yml`:

```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

## 🛠️ Management Commands

### Start/Stop Services

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart specific service
docker-compose restart backend

# View logs
docker-compose logs -f backend
docker-compose logs -f mcp-server
```

### Database Management

```bash
# Access database
docker exec -it tradesmart-timescaledb psql -U tradesmart -d tradesmart

# Backup database
docker exec tradesmart-timescaledb pg_dump -U tradesmart tradesmart > backup.sql

# Restore database
docker exec -i tradesmart-timescaledb psql -U tradesmart tradesmart < backup.sql
```

### Debugging

```bash
# Check container status
docker-compose ps

# View container logs
docker-compose logs backend
docker-compose logs mcp-server

# Execute shell in container
docker exec -it tradesmart-backend bash
docker exec -it tradesmart-mcp-server bash

# Test MCP server
docker exec -it tradesmart-mcp-server python -c "from mcp.client import mcp_client; print('MCP OK')"
```

## 📊 Monitoring

### Health Checks

All services have health checks:

```bash
# Backend health
curl http://localhost:8000/health

# Database health
docker exec tradesmart-timescaledb pg_isready

# Redis health
docker exec tradesmart-redis redis-cli ping
```

### Logs

```bash
# View all logs
docker-compose logs -f

# View specific service
docker-compose logs -f backend

# Last 100 lines
docker-compose logs --tail=100 mcp-server
```

## 🚢 Production Deployment

### 1. Cloud Deployment (Railway/Render)

```bash
# Build for production
docker-compose -f docker-compose.prod.yml build

# Push to registry
docker tag tradesmart-backend:latest your-registry/tradesmart-backend
docker push your-registry/tradesmart-backend
```

### 2. Environment-Specific Configs

Create `docker-compose.prod.yml`:

```yaml
version: '3.9'
services:
  backend:
    environment:
      - LOG_LEVEL=warning
      - WORKERS=4
    restart: always
```

Deploy:
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 3. Scaling

```bash
# Scale backend instances
docker-compose up -d --scale backend=3

# Use nginx for load balancing (separate config)
```

## 🔐 Security

### Production Checklist

- [ ] Change default database password
- [ ] Enable SSL/TLS for APIs
- [ ] Restrict CORS origins
- [ ] Use secrets management (Docker secrets/Vault)
- [ ] Enable firewall rules
- [ ] Implement rate limiting
- [ ] Add authentication middleware

### Secrets Management

```bash
# Use Docker secrets (Swarm mode)
echo "your_cerebras_key" | docker secret create cerebras_api_key -

# Reference in compose:
services:
  backend:
    secrets:
      - cerebras_api_key
```

## 🧪 Testing

### Run Tests in Container

```bash
# Unit tests
docker exec tradesmart-backend pytest tests/

# Integration tests
docker exec tradesmart-backend pytest tests/integration/

# Load testing
docker run --network tradesmart-network -v $(pwd):/app locustio/locust \
  -f /app/tests/load_test.py --host http://backend:8000
```

## 📈 Performance Tuning

### Database Optimization

```sql
-- Access database
docker exec -it tradesmart-timescaledb psql -U tradesmart -d tradesmart

-- Check table sizes
SELECT hypertable_name, hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)
FROM timescaledb_information.hypertables;

-- Adjust chunk interval (if needed)
SELECT set_chunk_time_interval('ohlc_data', INTERVAL '1 day');
```

### Redis Tuning

```bash
# Check memory usage
docker exec tradesmart-redis redis-cli INFO memory

# Set max memory
docker exec tradesmart-redis redis-cli CONFIG SET maxmemory 2gb
```

## 🐛 Troubleshooting

### Common Issues

**1. MCP Server not connecting:**
```bash
# Check MCP server logs
docker-compose logs mcp-server

# Restart MCP server
docker-compose restart mcp-server
```

**2. Database connection failed:**
```bash
# Verify database is running
docker-compose ps timescaledb

# Check connection
docker exec tradesmart-timescaledb pg_isready
```

**3. Cerebras API errors:**
```bash
# Verify API key
docker exec tradesmart-backend python -c "from config.settings import settings; print(settings.cerebras_api_key[:10])"
```

**4. Out of memory:**
```bash
# Check container resources
docker stats

# Increase limits in docker-compose.yml
```

## 📚 Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [TimescaleDB Docs](https://docs.timescale.com/)
- [MCP Protocol](https://modelcontextprotocol.io/)
- [Cerebras Cloud](https://cloud.cerebras.ai/)

## 🎯 Hackathon Judges

**Docker MCP Gateway Track Highlights:**

✅ **6 Custom MCP Tools** for trading analysis
✅ **Containerized Architecture** with docker-compose
✅ **Service Mesh** (FastAPI ↔ MCP ↔ Database)
✅ **Health Checks** on all services
✅ **Production-Ready** deployment configuration
✅ **Creative Use Case** - AI trading with visual annotations

See `mcp-gateway.json` for complete MCP configuration.

---

**Need help?** Check the main [README.md](backend/README.md) or create an issue.
