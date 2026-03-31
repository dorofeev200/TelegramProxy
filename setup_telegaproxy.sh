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
    if [ "$EUID" -ne 0 ]; then echo -e "${RED}Ошибка: запустите через sudo!${NC}"; exit 1; fi
}

install_deps() {
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
    fi
    if ! command -v qrencode &> /dev/null; then
        apt-get update && apt-get install -y qrencode || yum install -y qrencode
    fi
    cp "$0" "$BINARY_PATH" && chmod +x "$BINARY_PATH"
}

get_ip() {
    local ip
    ip=$(curl -s -4 --max-time 5 https://api.ipify.org || curl -s -4 --max-time 5 https://icanhazip.com || echo "0.0.0.0")
    echo "$ip" | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1
}

# --- 1) ПРОМО ПРИ ЗАПУСКЕ ---
show_promo() {
    clear
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                 COMP_MANIYA Telega Proxy                     ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}Telegram:${NC} https://t.me/computerchik"
    echo -e "${RED}YouTube:${NC} https://www.youtube.com/@comp_maniya"

    echo ""
    echo -e "${YELLOW}QR Telegram:${NC}"
    qrencode -t ANSIUTF8 "https://t.me/computerchik"

    echo ""
    echo -e "${YELLOW}QR YouTube:${NC}"
    qrencode -t ANSIUTF8 "https://www.youtube.com/@comp_maniya"

    echo ""
    read -p "Нажмите enter для настройки каскадного скрипта..."
}

# --- ПАНЕЛЬ ДАННЫХ ---
show_config() {
    if ! docker ps | grep -q "mtproto-proxy"; then echo -e "${RED}Прокси не найден!${NC}"; return; fi
    SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Cmd}}{{.}} {{end}}' | awk '{print $NF}')
    IP=$(get_ip)
    PORT=$(docker inspect mtproto-proxy --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' 2>/dev/null)
    PORT=${PORT:-443}
    LINK="tg://proxy?server=$IP&port=$PORT&secret=$SECRET"

    echo -e "\n${GREEN}=== ПАНЕЛЬ ДАННЫХ (RU) ===${NC}"
    echo -e "IP: $IP | Port: $PORT"
    echo -e "Secret: $SECRET"
    echo -e "Link: ${BLUE}$LINK${NC}"
    qrencode -t ANSIUTF8 "$LINK"
}

# --- УСТАНОВКА (MULTI USER) ---
menu_install() {
    clear
    echo -e "${CYAN}--- Выберите домен для маскировки (Fake TLS) ---${NC}"

    domains=(
        "google.com" "wikipedia.org" "habr.com" "github.com"
        "coursera.org" "udemy.com" "medium.com" "stackoverflow.com"
        "bbc.com" "cnn.com" "reuters.com" "nytimes.com"
        "lenta.ru" "rbc.ru" "ria.ru" "kommersant.ru"
        "stepik.org" "duolingo.com" "khanacademy.org" "ted.com"
    )

    for i in "${!domains[@]}"; do
        printf "${YELLOW}%2d)${NC} %-20s " "$((i+1))" "${domains[$i]}"
        [[ $(( (i+1) % 2 )) -eq 0 ]] && echo ""
    done

    echo ""
    read -p "Ваш выбор [1-20]: " d_idx
    DOMAIN=${domains[$((d_idx-1))]}
    DOMAIN=${DOMAIN:-google.com}

    echo ""
    echo -e "${CYAN}--- Выберите порт ---${NC}"
    echo -e "1) 443"
    echo -e "2) 8443"
    echo -e "3) Свой порт"

    read -p "Выбор: " p_choice

    case $p_choice in
        2) PORT=8443 ;;
        3) read -p "Введите свой порт: " PORT ;;
        *) PORT=443 ;;
    esac

    CONTAINER_NAME="mtproto-proxy-$PORT"

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}[ERROR] Пользователь на порту ${PORT} уже существует!${NC}"
        read -p "Нажмите Enter..."
        return
    fi

    echo ""
    echo -e "${YELLOW}[*] Создание пользователя на порту ${PORT}...${NC}"

    SECRET=$(docker run --rm nineseconds/mtg:2 generate-secret --hex "$DOMAIN")

    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart always \
        -p "$PORT":"$PORT" \
        nineseconds/mtg:2 simple-run \
        -n 1.1.1.1 \
        -i prefer-ipv4 \
        0.0.0.0:"$PORT" \
        "$SECRET" > /dev/null

    IP=$(get_ip)
    LINK="tg://proxy?server=$IP&port=$PORT&secret=$SECRET"

    clear
    echo -e "${GREEN}[SUCCESS] Пользователь создан.${NC}"
    echo ""
    echo -e "Контейнер: ${CYAN}${CONTAINER_NAME}${NC}"
    echo -e "Порт: ${CYAN}${PORT}${NC}"
    echo -e "Secret: ${CYAN}${SECRET}${NC}"
    echo -e "Link: ${BLUE}${LINK}${NC}"
    echo ""

    qrencode -t ANSIUTF8 "$LINK"

    read -p "Нажмите Enter..."
}

# --- ВЫХОД ---
show_exit() {
    clear
    show_config
    echo -e "\n${MAGENTA}💰 ПОДДЕРЖКА АВТОРА (CloudTips)${NC}"
    qrencode -t ANSIUTF8 "$TIP_LINK"
    echo -e "Донат: $TIP_LINK"
    echo -e "https://www.youtube.com/@comp_maniya"
    exit 0
}

# --- УДАЛЕНИЕ ВСЕХ ПРОКСИ И СКРИПТА ---
full_uninstall() {
    clear
    echo -e "${RED}╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}║       FULL PRO UNINSTALL             ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════╝${NC}"
    echo ""

    read -p "Удалить ВСЕХ пользователей и скрипт? (y/n): " confirm
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')

    [[ "$confirm" != "y" ]] && return

    docker ps -a --format '{{.Names}}' | grep '^mtproto-proxy-' | while read c; do
        docker stop "$c" >/dev/null 2>&1
        docker rm "$c" >/dev/null 2>&1
    done

    docker rmi nineseconds/mtg:2 >/dev/null 2>&1
    rm -f "$BINARY_PATH"

    echo -e "${GREEN}[SUCCESS] Всё удалено.${NC}"
    exit 0
}

# --- ВЫБОР ПОЛЬЗОВАТЕЛЯ ПО ПОРТУ ---
select_proxy() {
    read -p "Введите порт пользователя: " PORT
    CONTAINER_NAME="mtproto-proxy-$PORT"

    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}Пользователь не найден.${NC}"
        return 1
    fi

    return 0
}

# --- RESTART ---
restart_proxy() {
    clear
    echo -e "${CYAN}--- Restart пользователя ---${NC}"

    select_proxy || { read -p "Enter..."; return; }

    docker restart "$CONTAINER_NAME" >/dev/null 2>&1

    echo -e "${GREEN}[OK] Перезапущен ${CONTAINER_NAME}${NC}"
    read -p "Нажмите Enter..."
}

# --- ONLINE USERS ---
show_online_users() {
    clear
    echo -e "${CYAN}--- ONLINE USERS ---${NC}"

    select_proxy || { read -p "Enter..."; return; }

    PORT=$(docker inspect "$CONTAINER_NAME" \
        --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}')

    ss -tn state established "( dport = :$PORT or sport = :$PORT )"

    echo ""
    echo -e "${GREEN}Всего:${NC} $(ss -tn state established "( dport = :$PORT or sport = :$PORT )" | tail -n +2 | wc -l)"

    read -p "Нажмите Enter..."
}

# --- STATS ---
proxy_monitoring() {
    clear
    echo -e "${CYAN}--- MONITORING ---${NC}"

    select_proxy || { read -p "Enter..."; return; }

    docker stats "$CONTAINER_NAME" --no-stream

    read -p "Нажмите Enter..."
}

# --- TOP CLIENTS ---
top_clients() {
    clear
    echo -e "${CYAN}--- TOP CLIENTS ---${NC}"

    select_proxy || { read -p "Enter..."; return; }

    PORT=$(docker inspect "$CONTAINER_NAME" \
        --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}')

    ss -tn state established "( dport = :$PORT or sport = :$PORT )" \
        | awk 'NR>1 {print $5}' \
        | cut -d: -f1 \
        | sort | uniq -c | sort -nr

    read -p "Нажмите Enter..."
}

# --- REMOVE USER ---
remove_proxy_by_port() {
    clear
    echo -e "${CYAN}--- REMOVE USER ---${NC}"

    select_proxy || { read -p "Enter..."; return; }

    docker stop "$CONTAINER_NAME" >/dev/null 2>&1
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1

    echo -e "${GREEN}[OK] Удалён ${CONTAINER_NAME}${NC}"
    read -p "Нажмите Enter..."
}

# --- LIST USERS ---
list_all_users() {
    clear
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep mtproto-proxy
    read -p "Нажмите Enter..."
}

# --- MAIN LOOP ---
while true; do
    clear
    echo -e "${MAGENTA}=== TELEGAPROXY PRO MANAGER ===${NC}"
    echo "1) Добавить пользователя"
    echo "2) Показать всех пользователей"
    echo "3) Restart пользователя"
    echo "4) Online users"
    echo "5) Monitoring"
    echo "6) Top clients"
    echo "7) Удалить пользователя"
    echo "8) Заблокировать IP"
    echo "9) Full uninstall"
    echo "0) Exit"

    read -p "Пункт: " m_idx

    case $m_idx in
        1) menu_install ;;
        2) list_all_users ;;
        3) restart_proxy ;;
        4) show_online_users ;;
        5) proxy_monitoring ;;
        6) top_clients ;;
        7) remove_proxy_by_port ;;
        8) block_client_ip ;;
        9) full_uninstall ;;
        0) show_exit ;;
        *) echo "Ошибка"; sleep 1 ;;
    esac
done
