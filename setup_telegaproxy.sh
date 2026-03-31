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

# --- СИСТЕМНЫЕ ПРОВЕРКИ ---
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

# --- PROMO ---
show_promo() {
    clear
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                 COMP_MANIYA Telega Proxy                   ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}Telegram:${NC} $PROMO_LINK"
    echo -e "${RED}YouTube:${NC} https://www.youtube.com/@comp_maniya"

    echo ""
    qrencode -t ANSIUTF8 "$PROMO_LINK"

    echo ""
    read -p "Нажмите enter для настройки..."
}

# --- СПИСОК ПОЛЬЗОВАТЕЛЕЙ ---
list_users() {
    clear
    echo -e "${CYAN}=== АКТИВНЫЕ ПОЛЬЗОВАТЕЛИ ===${NC}"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep mtproto-proxy
    echo ""
}

# --- ВЫБОР ПОЛЬЗОВАТЕЛЯ ---
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

# --- SHOW CONFIG ---
show_config() {
    select_user || return

    SECRET=$(docker inspect "$CONTAINER_NAME" \
        --format='{{range .Config.Cmd}}{{.}} {{end}}' | awk '{print $NF}')

    IP=$(get_ip)

    LINK="tg://proxy?server=$IP&port=$PORT&secret=$SECRET"

    echo ""
    echo -e "${GREEN}=== ПАНЕЛЬ ДАННЫХ ===${NC}"
    echo -e "IP: $IP | Port: $PORT"
    echo -e "Secret: $SECRET"
    echo -e "Link: ${BLUE}$LINK${NC}"

    qrencode -t ANSIUTF8 "$LINK"

    echo ""
    read -p "Нажмите Enter..."
}

# --- УСТАНОВКА ---
menu_install() {
    clear
    echo -e "${CYAN}--- Выберите домен ---${NC}"

    domains=(
        "google.com" "wikipedia.org" "habr.com" "github.com"
        "coursera.org" "udemy.com" "medium.com" "stackoverflow.com"
        "bbc.com" "cnn.com" "reuters.com" "nytimes.com"
    )

    for i in "${!domains[@]}"; do
        printf "${YELLOW}%2d)${NC} %-20s " "$((i+1))" "${domains[$i]}"
        [[ $(( (i+1) % 2 )) -eq 0 ]] && echo ""
    done

    echo ""
    read -p "Ваш выбор: " d_idx
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
    echo -e "Порт: $PORT"
    echo -e "Link: ${BLUE}$LINK${NC}"

    qrencode -t ANSIUTF8 "$LINK"

    read -p "Нажмите Enter..."
}

restart_proxy() {
    select_user || return
    docker restart "$CONTAINER_NAME" >/dev/null
    echo -e "${GREEN}[OK] Перезапущен${NC}"
    read -p "Нажмите Enter..."
}

show_online_users() {
    select_user || return
    ss -tn state established "( dport = :$PORT or sport = :$PORT )"
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
    clear
    read -p "Удалить всё? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    docker ps -a --format '{{.Names}}' | grep '^mtproto-proxy' | while read c; do
        docker stop "$c" >/dev/null 2>&1
        docker rm "$c" >/dev/null 2>&1
    done

    docker rmi nineseconds/mtg:2 >/dev/null 2>&1
    rm -f "$BINARY_PATH"

    echo -e "${GREEN}[SUCCESS] Всё удалено${NC}"
    exit 0
}

show_exit() {
    clear
    echo -e "${MAGENTA}💰 ПОДДЕРЖКА АВТОРА${NC}"
    qrencode -t ANSIUTF8 "$TIP_LINK"
    exit 0
}

# --- START ---
check_root
install_deps
show_promo

while true; do
    clear
    echo -e "${MAGENTA}=== telegaproxy Manager (by comp-maniya) ===${NC}"
    echo -e "1) ${GREEN}Добавить пользователя${NC}"
    echo -e "2) Показать данные подключения"
    echo -e "3) Показать пользователей"
    echo -e "4) Restart пользователя"
    echo -e "5) Online users"
    echo -e "6) Monitoring"
    echo -e "7) ${RED}Удалить пользователя${NC}"
    echo -e "8) ${RED}Удалить всё${NC}"
    echo -e "0) Выход"

    read -p "Пункт: " m_idx

    case $m_idx in
        1) menu_install ;;
        2) show_config ;;
        3) list_users; read -p "Нажмите Enter..." ;;
        4) restart_proxy ;;
        5) show_online_users ;;
        6) proxy_monitoring ;;
        7) remove_proxy ;;
        8) full_uninstall ;;
        0) show_exit ;;
        *) echo "Неверный ввод"; sleep 1 ;;
    esac
done
