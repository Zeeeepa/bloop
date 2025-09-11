#!/bin/bash

# Bloop Service Management Script
# Companion script for managing bloop services

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FRONTEND_PORT=3000
BACKEND_PORT=7878
PROJECT_DIR="bloop"

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"
}

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"
}

# Check if we're in the right directory
check_directory() {
    if [ ! -f "package.json" ] || [ ! -d "server" ] || [ ! -d "client" ]; then
        log_error "Not in bloop project directory. Please run from bloop root."
        exit 1
    fi
}

# Get process status
get_process_status() {
    local pid_file=$1
    local service_name=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}$service_name: Running (PID: $pid)${NC}"
            return 0
        else
            echo -e "${RED}$service_name: Stopped (stale PID file)${NC}"
            rm -f "$pid_file"
            return 1
        fi
    else
        echo -e "${RED}$service_name: Stopped${NC}"
        return 1
    fi
}

# Show service status
status() {
    log "Checking bloop service status..."
    echo
    
    get_process_status "backend.pid" "Backend"
    get_process_status "frontend.pid" "Frontend"
    
    echo
    log_info "Port status:"
    if lsof -Pi :$BACKEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "  Backend port $BACKEND_PORT: ${GREEN}In use${NC}"
    else
        echo -e "  Backend port $BACKEND_PORT: ${RED}Available${NC}"
    fi
    
    if lsof -Pi :$FRONTEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "  Frontend port $FRONTEND_PORT: ${GREEN}In use${NC}"
    else
        echo -e "  Frontend port $FRONTEND_PORT: ${RED}Available${NC}"
    fi
    
    echo
    log_info "Health checks:"
    if curl -s "http://127.0.0.1:$BACKEND_PORT/health" > /dev/null 2>&1; then
        echo -e "  Backend health: ${GREEN}OK${NC}"
    else
        echo -e "  Backend health: ${RED}Failed${NC}"
    fi
    
    if curl -s "http://127.0.0.1:$FRONTEND_PORT" > /dev/null 2>&1; then
        echo -e "  Frontend health: ${GREEN}OK${NC}"
    else
        echo -e "  Frontend health: ${RED}Failed${NC}"
    fi
}

# Stop services
stop() {
    log "Stopping bloop services..."
    
    local stopped=false
    
    if [ -f "backend.pid" ]; then
        local pid=$(cat "backend.pid")
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping backend (PID: $pid)..."
            kill "$pid"
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                log_warn "Backend didn't stop gracefully, force killing..."
                kill -9 "$pid"
            fi
            stopped=true
        fi
        rm -f "backend.pid"
    fi
    
    if [ -f "frontend.pid" ]; then
        local pid=$(cat "frontend.pid")
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping frontend (PID: $pid)..."
            kill "$pid"
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                log_warn "Frontend didn't stop gracefully, force killing..."
                kill -9 "$pid"
            fi
            stopped=true
        fi
        rm -f "frontend.pid"
    fi
    
    # Kill any remaining processes on the ports
    if lsof -Pi :$BACKEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log "Killing remaining processes on port $BACKEND_PORT..."
        lsof -ti:$BACKEND_PORT | xargs kill -9 2>/dev/null || true
        stopped=true
    fi
    
    if lsof -Pi :$FRONTEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log "Killing remaining processes on port $FRONTEND_PORT..."
        lsof -ti:$FRONTEND_PORT | xargs kill -9 2>/dev/null || true
        stopped=true
    fi
    
    if [ "$stopped" = true ]; then
        log "Services stopped successfully"
    else
        log_info "No running services found"
    fi
}

# Start services
start() {
    log "Starting bloop services..."
    
    # Check if already running
    if [ -f "backend.pid" ] && kill -0 "$(cat backend.pid)" 2>/dev/null; then
        log_warn "Backend already running"
    else
        # Determine backend type
        if [ -f "server/bleep/target/release/bleep" ]; then
            log "Starting Rust backend..."
            cd server/bleep
            nohup ./target/release/bleep --config-file=../../local_config.json > ../../backend.log 2>&1 &
            echo $! > ../../backend.pid
            cd ../..
            log "Rust backend started"
        elif [ -f "mock-server.js" ]; then
            log "Starting mock server..."
            nohup node mock-server.js > backend.log 2>&1 &
            echo $! > backend.pid
            log "Mock server started"
        else
            log_error "No backend available. Run deployment script first."
            exit 1
        fi
    fi
    
    # Start frontend
    if [ -f "frontend.pid" ] && kill -0 "$(cat frontend.pid)" 2>/dev/null; then
        log_warn "Frontend already running"
    else
        log "Starting frontend..."
        nohup npm run start-web > frontend.log 2>&1 &
        echo $! > frontend.pid
        log "Frontend started"
    fi
    
    sleep 3
    log "Services started successfully"
}

# Restart services
restart() {
    log "Restarting bloop services..."
    stop
    sleep 2
    start
}

# Show logs
logs() {
    local service=${1:-"all"}
    
    case $service in
        backend)
            if [ -f "backend.log" ]; then
                tail -f backend.log
            else
                log_error "Backend log file not found"
            fi
            ;;
        frontend)
            if [ -f "frontend.log" ]; then
                tail -f frontend.log
            else
                log_error "Frontend log file not found"
            fi
            ;;
        deployment)
            if [ -f "bloop_deployment.log" ]; then
                tail -f bloop_deployment.log
            else
                log_error "Deployment log file not found"
            fi
            ;;
        all|*)
            log "Showing all logs (Ctrl+C to exit)..."
            if [ -f "backend.log" ] && [ -f "frontend.log" ]; then
                tail -f backend.log frontend.log
            elif [ -f "backend.log" ]; then
                tail -f backend.log
            elif [ -f "frontend.log" ]; then
                tail -f frontend.log
            else
                log_error "No log files found"
            fi
            ;;
    esac
}

# Show help
help() {
    echo "Bloop Service Management Script"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  start     - Start bloop services"
    echo "  stop      - Stop bloop services"
    echo "  restart   - Restart bloop services"
    echo "  status    - Show service status"
    echo "  logs      - Show service logs"
    echo "  help      - Show this help message"
    echo
    echo "Log options:"
    echo "  logs backend     - Show backend logs only"
    echo "  logs frontend    - Show frontend logs only"
    echo "  logs deployment  - Show deployment logs only"
    echo "  logs all         - Show all logs (default)"
    echo
    echo "Examples:"
    echo "  $0 status        - Check if services are running"
    echo "  $0 restart       - Restart all services"
    echo "  $0 logs backend  - Monitor backend logs"
}

# Main execution
main() {
    check_directory
    
    case "${1:-help}" in
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        logs)
            logs "${2:-all}"
            ;;
        help|--help|-h)
            help
            ;;
        *)
            log_error "Unknown command: $1"
            echo
            help
            exit 1
            ;;
    esac
}

main "$@"

