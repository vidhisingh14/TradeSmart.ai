#!/bin/bash

# TradeSmart.AI Quick Start Script
# This script sets up and runs the entire application with Docker

set -e

echo "🚀 TradeSmart.AI Quick Start"
echo "============================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first:"
    echo "   https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first:"
    echo "   https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.docker .env
    echo ""
    echo "⚠️  IMPORTANT: Please edit .env and add your Cerebras API key!"
    echo "   nano .env"
    echo ""
    read -p "Press Enter after you've added your API key..."
fi

# Validate Cerebras API key
CEREBRAS_KEY=$(grep CEREBRAS_API_KEY .env | cut -d '=' -f2)
if [ -z "$CEREBRAS_KEY" ] || [ "$CEREBRAS_KEY" = "your_cerebras_api_key_here" ]; then
    echo "❌ Cerebras API key not set in .env file!"
    echo "   Please edit .env and add your key."
    exit 1
fi

echo "✅ Environment configured"
echo ""

# Build containers
echo "🔨 Building Docker containers..."
docker-compose build --no-cache

echo ""
echo "✅ Containers built successfully"
echo ""

# Start services
echo "🚀 Starting all services..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service health
echo ""
echo "🏥 Checking service health..."

# Check TimescaleDB
if docker exec tradesmart-timescaledb pg_isready &> /dev/null; then
    echo "✅ TimescaleDB is ready"
else
    echo "❌ TimescaleDB is not ready"
fi

# Check Redis
if docker exec tradesmart-redis redis-cli ping &> /dev/null; then
    echo "✅ Redis is ready"
else
    echo "❌ Redis is not ready"
fi

# Check Backend
if curl -s http://localhost:8000/health &> /dev/null; then
    echo "✅ Backend is ready"
else
    echo "⏳ Backend is starting... (this may take 30-60 seconds)"
    sleep 30
    if curl -s http://localhost:8000/health &> /dev/null; then
        echo "✅ Backend is ready"
    else
        echo "❌ Backend failed to start. Check logs with: docker-compose logs backend"
    fi
fi

echo ""
echo "🎉 TradeSmart.AI is running!"
echo ""
echo "📊 Access points:"
echo "   - API: http://localhost:8000"
echo "   - API Docs: http://localhost:8000/docs"
echo "   - Health Check: http://localhost:8000/health"
echo ""
echo "🧪 Test the API:"
echo '   curl -X POST http://localhost:8000/api/strategy/build \'
echo '     -H "Content-Type: application/json" \'
echo "     -d '{\"prompt\": \"Create a swing trading strategy for BTC\", \"symbol\": \"BTC/USD\", \"timeframe\": \"1h\"}'"
echo ""
echo "📋 Useful commands:"
echo "   - View logs: docker-compose logs -f"
echo "   - Stop: docker-compose down"
echo "   - Restart: docker-compose restart"
echo ""
echo "🐛 Troubleshooting:"
echo "   - Check logs: docker-compose logs backend"
echo "   - Check services: docker-compose ps"
echo "   - See DOCKER-DEPLOYMENT.md for more help"
echo ""
