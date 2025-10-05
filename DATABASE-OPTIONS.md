# 🗄️ Database Options Comparison

## TradeSmart.AI supports 2 database setups:

---

## ✅ **Option A: Supabase (RECOMMENDED)**

### **What is it?**
Managed PostgreSQL + TimescaleDB in the cloud

### **Pros:**
- ✅ **5-minute setup** - Just create account and copy URL
- ✅ **Zero maintenance** - No database container to manage
- ✅ **Automatic backups** - Built-in daily backups
- ✅ **Web dashboard** - Visual SQL editor, table viewer
- ✅ **Free tier** - 500MB database (enough for 50+ stocks)
- ✅ **SSL by default** - Secure connections
- ✅ **Connection pooling** - Better performance (PgBouncer)
- ✅ **Auto-scaling** - Click to upgrade
- ✅ **TimescaleDB included** - Extension pre-enabled

### **Cons:**
- ❌ Free tier has 500MB limit (upgrade to Pro for 8GB)
- ❌ Requires internet connection
- ❌ Data stored in cloud (not local)

### **Perfect for:**
- 🏆 Hackathons (like FutureStack 2025)
- 🚀 MVPs and demos
- 👥 Small teams
- 💡 Rapid prototyping
- ☁️ Cloud deployments

### **Setup:**
```bash
# 1. Create Supabase account (5 min)
https://supabase.com

# 2. Enable TimescaleDB extension
# Dashboard → Database → Extensions → Enable TimescaleDB

# 3. Run SQL schema
# Dashboard → SQL Editor → Run schema from SUPABASE-SETUP.md

# 4. Configure .env
cp .env.supabase .env
# Add your Supabase DATABASE_URL

# 5. Start (lightweight - no DB container)
docker-compose -f docker-compose.supabase.yml up -d
```

**Full guide:** [SUPABASE-SETUP.md](SUPABASE-SETUP.md)

---

## 🐳 **Option B: Self-hosted TimescaleDB**

### **What is it?**
Docker container running PostgreSQL + TimescaleDB locally

### **Pros:**
- ✅ **Full control** - Your server, your rules
- ✅ **Unlimited storage** - Based on your disk space
- ✅ **Works offline** - No internet needed
- ✅ **Data privacy** - Everything stays local
- ✅ **No vendor lock-in** - Standard PostgreSQL

### **Cons:**
- ❌ **Manual setup** - Docker container configuration
- ❌ **Manual backups** - You handle backup strategy
- ❌ **Manual updates** - Update PostgreSQL/TimescaleDB yourself
- ❌ **Resource usage** - Container runs on your machine
- ❌ **DevOps required** - Need to manage database

### **Perfect for:**
- 🏢 Enterprise deployments
- 🔒 Strict data locality requirements
- 💪 DevOps/infrastructure teams
- 🏭 Production systems with dedicated infra

### **Setup:**
```bash
# 1. Configure .env
cp .env.docker .env
# Add your credentials

# 2. Start (includes database container)
docker-compose up -d

# 3. Database auto-initializes with init-db.sql
```

**Full guide:** [DOCKER-DEPLOYMENT.md](DOCKER-DEPLOYMENT.md)

---

## 📊 **Detailed Comparison**

| Feature | Supabase | Self-hosted |
|---------|----------|-------------|
| **Setup Time** | ⚡ 5 minutes | ⏱️ 30+ minutes |
| **Maintenance** | 🎉 Zero | 😰 Manual |
| **Backups** | 🔄 Automatic daily | 📝 You configure |
| **Dashboard** | 💻 Beautiful web UI | 🖥️ CLI only |
| **SSL/Security** | 🔐 Built-in | 🔧 You configure |
| **Scaling** | 📈 Click to upgrade | 🚀 Manual migration |
| **Cost (Startup)** | 💰 Free (500MB) | 💸 Your server costs |
| **Cost (Production)** | 💵 $25/mo (8GB) | 💲 Infrastructure costs |
| **Monitoring** | 📊 Built-in metrics | 📉 You setup |
| **Connection Pooling** | ✅ PgBouncer included | ❌ Manual setup |
| **Point-in-Time Recovery** | ✅ Pro plan | ❌ Configure yourself |
| **Multi-region** | ✅ Choose region | ❌ Single location |

---

## 🎯 **Recommendations by Use Case**

### **🏆 Hackathons (FutureStack 2025)**
**Use:** ✅ **Supabase**
- Fast setup for demo
- No infrastructure worries
- Free tier is enough
- Focus on code, not DevOps

### **🚀 MVP / Startup**
**Use:** ✅ **Supabase**
- Quick time-to-market
- Scale as you grow
- Professional infrastructure
- Pay only when needed

### **👨‍💻 Learning / Side Projects**
**Use:** Either works
- Supabase: If you want it "just to work"
- Self-hosted: If learning DevOps

### **🏢 Enterprise / Production**
**Use:** Depends on requirements
- Supabase: If you want managed solution
- Self-hosted: If strict compliance/control needed

### **🔒 Data Locality Requirements**
**Use:** 🐳 **Self-hosted**
- Data must stay in specific country
- Compliance regulations
- Air-gapped environments

---

## 🚀 **Quick Start Commands**

### **Supabase Setup:**
```bash
# 1. Setup (see SUPABASE-SETUP.md)
# Create account → Enable TimescaleDB → Get connection URL

# 2. Configure
cp .env.supabase .env
nano .env  # Add DATABASE_URL

# 3. Start (lightweight)
docker-compose -f docker-compose.supabase.yml up -d

# 4. Seed data
docker exec tradesmart-backend python seed_data.py
```

### **Self-hosted Setup:**
```bash
# 1. Configure
cp .env.docker .env
nano .env  # Add credentials

# 2. Start (includes database)
docker-compose up -d

# 3. Database auto-initialized

# 4. Seed data
docker exec tradesmart-backend python seed_data.py
```

---

## 💡 **Migration Between Options**

### **Supabase → Self-hosted:**
```bash
# 1. Dump from Supabase
pg_dump "postgresql://postgres.xxx@db.xxx.supabase.co:5432/postgres" > backup.sql

# 2. Import to local
docker exec -i tradesmart-timescaledb psql -U tradesmart tradesmart < backup.sql
```

### **Self-hosted → Supabase:**
```bash
# 1. Dump from local
docker exec tradesmart-timescaledb pg_dump -U tradesmart tradesmart > backup.sql

# 2. Import to Supabase
psql "postgresql://postgres.xxx@db.xxx.supabase.co:5432/postgres" < backup.sql
```

---

## 🏁 **Final Verdict**

### **For TradeSmart.AI Hackathon:**

```
┌────────────────────────────────────────┐
│   USE SUPABASE! 🎯                     │
│                                        │
│   Reasons:                             │
│   ✅ 5-minute setup                    │
│   ✅ Zero maintenance                  │
│   ✅ Focus on AI/features              │
│   ✅ Free tier sufficient              │
│   ✅ Impress judges with speed         │
│   ✅ Production-ready if you win!      │
└────────────────────────────────────────┘
```

### **When to Use Self-hosted:**
- You're a DevOps engineer
- You have infrastructure team
- Enterprise compliance requirements
- Specific data locality needs

---

## 📚 **Resources**

- [Supabase Setup Guide](SUPABASE-SETUP.md)
- [Docker Deployment Guide](DOCKER-DEPLOYMENT.md)
- [Data Flow Architecture](DATA-FLOW.md)
- [Supabase Docs](https://supabase.com/docs)
- [TimescaleDB Docs](https://docs.timescale.com)

---

**🎊 Bottom Line: For hackathons and MVPs, Supabase is a no-brainer!**
