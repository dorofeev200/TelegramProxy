#!/bin/bash

# --- КОНФИГУРАЦИЯ ---
ALIAS_NAME="telegaproxy"
BINARY_PATH="/usr/local/bin/telegaproxy"
TIP_LINK="https://pay.cloudtips.ru/p/4a618628"
PROMO_LINK="https://t.me/computerchik"

# --- ЦВЕТА ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Ошибка: запустите через sudo!${NC}"
        exit 1
    fi
}

install_deps() {
    if ! command -v docker >/dev/null 2>&1; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
    fi

    if ! command -v qrencode >/dev/null 2>&1; then
        apt-get update && apt-get install -y qrencode
    fi

    cp "$0" "$BINARY_PATH"
    chmod +x "$BINARY_PATH"
}

get_ip() {
    curl -s -4 https://api.ipify.org
}

show_promo() {
    clear
    echo -e "${MAGENTA}╔════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         COMP_MANIYA Telega Proxy           ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Telegram:${NC} $PROMO_LINK"
    echo ""
    qrencode -t ANSIUTF8 "$PROMO_LINK"
    read -p "Нажмите Enter..."
}

list_users() {
    clear
    echo -e "${CYAN}--- Список пользователей ---${NC}"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep mtproto-proxy
    read -p "Нажмите Enter..."
}

select_user() {
    list_users
    read -p "Введите порт пользователя: " PORT
    CONTAINER_NAME="mtproto-proxy-$PORT"

    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}Пользователь не найден!${NC}"
        read -p "Нажмите Enter..."
        return 1
    fi
    return 0
}

menu_install() {
    clear
    echo -e "${CYAN}--- Выберите домен для маскировки ---${NC}"

    domains=("google.com" "github.com" "bbc.com" "stackoverflow.com")

    for i in "${!domains[@]}"; do
        printf "${YELLOW}%2d)${NC} %-20s\n" "$((i+1))" "${domains[$i]}"
    done

    read -p "Ваш выбор [1-4]: " d_idx
    DOMAIN=${domains[$((d_idx-1))]}
    DOMAIN=${DOMAIN:-google.com}

    echo ""
    read -p "Введите порт: " PORT

    CONTAINER_NAME="mtproto-proxy-$PORT"

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}Порт уже используется!${NC}"
        read -p "Нажмите Enter..."
        return
    fi

    SECRET=$(docker run --rm nineseconds/mtg:2 generate-secret --hex "$DOMAIN")

    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart always \
        -p "$PORT":"$PORT" \
        nineseconds/mtg:2 simple-run \
        -n 1.1.1.1 \
        -i prefer-ipv4 \
        0.0.0.0:"$PORT" \
        "$SECRET" >/dev/null

    IP=$(get_ip)
    LINK="tg://proxy?server=$IP&port=$PORT&secret=$SECRET"

    clear
    echo -e "${GREEN}[SUCCESS] Пользователь создан${NC}"
    echo "Порт: $PORT"
    echo "Link: $LINK"
    qrencode -t ANSIUTF8 "$LINK"

    read -p "Нажмите Enter..."
}

show_online_users() {
    select_user || return

    PORT=$(docker inspect "$CONTAINER_NAME" \
        --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}')

    clear
    ss -tn state established "( dport = :$PORT or sport = :$PORT )"

    read -p "Нажмите Enter..."
}

restart_proxy() {
    select_user || return
    docker restart "$CONTAINER_NAME" >/dev/null
    echo -e "${GREEN}[OK] Перезапущен${NC}"
    read -p "Нажмите Enter..."
}

proxy_monitoring() {
    select_user || return
    docker stats "$CONTAINER_NAME" --no-stream
    read -p "Нажмите Enter..."
}

remove_proxy() {
    select_user || return
    docker stop "$CONTAINER_NAME" >/dev/null
    docker rm "$CONTAINER_NAME" >/dev/null
    echo -e "${GREEN}[OK] Удалён${NC}"
    read -p "Нажмите Enter..."
}

full_uninstall() {
    docker ps -a --format '{{.Names}}' | grep '^mtproto-proxy' | while read c; do
        docker stop "$c" >/dev/null 2>&1
        docker rm "$c" >/dev/null 2>&1
    done

    docker rmi nineseconds/mtg:2 >/dev/null 2>&1
    rm -f "$BINARY_PATH"

    echo -e "${GREEN}[SUCCESS] Всё удалено${NC}"
    exit 0
}

check_root
install_deps
show_promo

while true; do
    clear
    echo -e "${MAGENTA}=== telegaproxy Manager (by comp-maniya) ===${NC}"
    echo -e "1) ${GREEN}Добавить пользователя${NC}"
    echo -e "2) Показать пользователей"
    echo -e "3) Restart пользователя"
    echo -e "4) Online users"
    echo -e "5) Monitoring"
    echo -e "6) ${RED}Удалить пользователя${NC}"
    echo -e "7) ${RED}Удалить всё${NC}"
    echo -e "0) Выход"

    read -p "Пункт: " m_idx

    case $m_idx in
        1) menu_install ;;
        2) list_users ;;
        3) restart_proxy ;;
        4) show_online_users ;;
        5) proxy_monitoring ;;
        6) remove_proxy ;;
        7) full_uninstall ;;
        0) exit 0 ;;
        *) echo "Неверный ввод"; sleep 1 ;;
    esac
done
