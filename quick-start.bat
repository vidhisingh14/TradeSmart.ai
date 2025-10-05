@echo off
REM TradeSmart.AI Quick Start Script for Windows
REM This script sets up and runs the entire application with Docker

echo ========================================
echo  TradeSmart.AI Quick Start
echo ========================================
echo.

REM Check if Docker is installed
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not installed. Please install Docker Desktop:
    echo https://docs.docker.com/desktop/install/windows-install/
    exit /b 1
)

REM Check if Docker Compose is installed
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker Compose is not installed.
    exit /b 1
)

echo ✓ Docker and Docker Compose are installed
echo.

REM Check if .env file exists
if not exist .env (
    echo Creating .env file from template...
    copy .env.docker .env
    echo.
    echo WARNING: Please edit .env and add your Cerebras API key!
    echo    Open .env in a text editor
    echo.
    pause
)

echo ✓ Environment configured
echo.

REM Build containers
echo Building Docker containers...
docker-compose build --no-cache

echo.
echo ✓ Containers built successfully
echo.

REM Start services
echo Starting all services...
docker-compose up -d

echo.
echo Waiting for services to be ready...
timeout /t 10 /nobreak >nul

REM Check service health
echo.
echo Checking service health...

docker exec tradesmart-timescaledb pg_isready >nul 2>&1
if errorlevel 1 (
    echo ✗ TimescaleDB is not ready
) else (
    echo ✓ TimescaleDB is ready
)

docker exec tradesmart-redis redis-cli ping >nul 2>&1
if errorlevel 1 (
    echo ✗ Redis is not ready
) else (
    echo ✓ Redis is ready
)

curl -s http://localhost:8000/health >nul 2>&1
if errorlevel 1 (
    echo Backend is starting... (this may take 30-60 seconds^)
    timeout /t 30 /nobreak >nul
    curl -s http://localhost:8000/health >nul 2>&1
    if errorlevel 1 (
        echo ✗ Backend failed to start. Check logs with: docker-compose logs backend
    ) else (
        echo ✓ Backend is ready
    )
) else (
    echo ✓ Backend is ready
)

echo.
echo ========================================
echo  TradeSmart.AI is running!
echo ========================================
echo.
echo Access points:
echo    - API: http://localhost:8000
echo    - API Docs: http://localhost:8000/docs
echo    - Health Check: http://localhost:8000/health
echo.
echo Test the API:
echo    curl -X POST http://localhost:8000/api/strategy/build ^
echo      -H "Content-Type: application/json" ^
echo      -d "{\"prompt\": \"Create a swing trading strategy for BTC\", \"symbol\": \"BTC/USD\", \"timeframe\": \"1h\"}"
echo.
echo Useful commands:
echo    - View logs: docker-compose logs -f
echo    - Stop: docker-compose down
echo    - Restart: docker-compose restart
echo.
echo See DOCKER-DEPLOYMENT.md for more help
echo.
pause
