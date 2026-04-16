#!/bin/bash

# Sync tool for llama.cpp server
# Usage: ./sync.sh <command> [args]
#
# Commands:
#   push        - sync local files -> server
#   pull        - sync server -> local files (configs)
#   deploy      - sync + restart container (no build)
#   rebuild     - sync + build + restart container
#   start       - start container
#   stop        - stop container
#   restart     - restart container
#   logs        - show container logs
#   status      - container status
#   health      - check health endpoint
#   ssh         - open SSH to server
#   config      - show current config on server

set -e

# Configuration
SERVER="ag@127.0.0.1"
REMOTE_DIR="~/llama"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# Run a command on the remote server
ssh_exec() {
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SERVER" "$1"
}

# Push local files to server
rsync_push() {
    log_info "Sync: local -> server ($SERVER:$REMOTE_DIR)"

    EXCLUDE=(
        --exclude=".git/"
        --exclude=".env"
        --exclude="*.log"
        --exclude="build/"
    )

    rsync -avz --progress \
        -e "ssh -o StrictHostKeyChecking=no" \
        "${EXCLUDE[@]}" \
        "$LOCAL_DIR/" "$SERVER:$REMOTE_DIR/"

    log_ok "Sync complete"
}

rsync_pull() {
    log_info "Sync: server -> local ($SERVER:$REMOTE_DIR -> local)"

    rsync -avz --progress \
        -e "ssh -o StrictHostKeyChecking=no" \
        --include="configs/" \
        --include="*.env" \
        --include="*.md" \
        --exclude="*" \
        "$SERVER:$REMOTE_DIR/" "$LOCAL_DIR/"

    log_ok "Pull complete"
}

cmd_push() {
    rsync_push
}

cmd_pull() {
    rsync_pull
}

cmd_deploy() {
    rsync_push
    log_info "Restarting container..."
    ssh_exec "cd $REMOTE_DIR && docker compose restart"
    log_ok "Deploy complete"
}

cmd_rebuild() {
    rsync_push
    log_info "Building and restarting container..."
    ssh_exec "cd $REMOTE_DIR && docker compose up -d --build"
    log_ok "Rebuild complete"
}

cmd_start() {
    log_info "Starting container..."
    ssh_exec "cd $REMOTE_DIR && docker compose up -d"
    log_ok "Container started"
}

cmd_stop() {
    log_info "Stopping container..."
    ssh_exec "cd $REMOTE_DIR && docker compose down"
    log_ok "Container stopped"
}

cmd_restart() {
    log_info "Restarting container..."
    ssh_exec "cd $REMOTE_DIR && docker compose restart"
    log_ok "Container restarted"
}

cmd_logs() {
    ssh_exec "cd $REMOTE_DIR && docker compose logs --tail=50 -f"
}

cmd_status() {
    echo -e "${BLUE}=== Container Status ===${NC}"
    ssh_exec "cd $REMOTE_DIR && docker compose ps"
    echo ""
    echo -e "${BLUE}=== GPU Usage ===${NC}"
    ssh_exec "nvidia-smi --query-compute-apps=pid,name,used_memory --format=csv,noheader 2>/dev/null || echo 'No GPU'"
}

cmd_health() {
    echo -e "${BLUE}=== Health Check ===${NC}"
    RESPONSE=$(ssh_exec "curl -s -o /dev/null -w '%{http_code}' http://localhost:8089/health 2>/dev/null || echo 'failed'")
    if [ "$RESPONSE" = "200" ]; then
        log_ok "Server is up (HTTP 200)"
    else
        log_err "Server unavailable (HTTP: $RESPONSE)"
    fi

    echo ""
    echo -e "${BLUE}=== VRAM (GPU) ===${NC}"
    ssh_exec "nvidia-smi --query-gpu=memory.used,memory.total,memory.free --format=csv,noheader 2>/dev/null || echo 'No GPU'"
    echo ""
    echo -e "${BLUE}=== Container RAM ===${NC}"
    ssh_exec "docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}' 2>/dev/null || echo 'No container'"
    echo ""
    echo -e "${BLUE}=== System RAM ===${NC}"
    ssh_exec "free -h | head -2"
    echo ""
    echo -e "${BLUE}=== Swap ===${NC}"
    ssh_exec "free -h | grep -E 'Swap'"
}

cmd_ssh() {
    log_info "Connecting to server..."
    ssh -o StrictHostKeyChecking=no "$SERVER"
}

cmd_config() {
    echo -e "${BLUE}=== Current server config ===${NC}"
    ssh_exec "cd $REMOTE_DIR && cat .env 2>/dev/null || echo 'No .env file found'"
}

# Main
COMMAND="${1:-help}"

case "$COMMAND" in
    push)     cmd_push ;;
    pull)     cmd_pull ;;
    deploy)   cmd_deploy ;;
    rebuild)  cmd_rebuild ;;
    start)    cmd_start ;;
    stop)     cmd_stop ;;
    restart)  cmd_restart ;;
    logs)     cmd_logs ;;
    status)   cmd_status ;;
    health)   cmd_health ;;
    ssh)      cmd_ssh ;;
    config)   cmd_config ;;
    help|--help|-h)
        echo "Llama.cpp Server Sync Tool"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  push     - sync local files -> server"
        echo "  pull     - sync server -> local (configs)"
        echo "  deploy   - sync + restart container"
        echo "  rebuild  - sync + build + restart container"
        echo "  start    - start container"
        echo "  stop     - stop container"
        echo "  restart  - restart container"
        echo "  logs     - show container logs"
        echo "  status   - container and GPU status"
        echo "  health   - check health endpoint"
        echo "  ssh      - open SSH to server"
        echo "  config   - show current config"
        echo ""
        echo "Examples:"
        echo "  $0 push           # sync files"
        echo "  $0 deploy         # sync + restart"
        echo "  $0 rebuild        # sync + build + restart"
        echo "  $0 status         # check status"
        echo "  $0 logs           # show logs"
        ;;
    *)        log_err "Unknown command: $COMMAND"; exit 1 ;;
esac
