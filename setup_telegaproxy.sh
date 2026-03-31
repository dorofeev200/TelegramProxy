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

# --- ПОЛНОЕ УДАЛЕНИЕ СКРИПТА ---
full_uninstall() {
    clear
    echo -e "${RED}╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}║     ПОЛНОЕ УДАЛЕНИЕ TELEGAPROXY      ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════╝${NC}"
    echo ""

    echo "Будет удалено:"
    echo "- Docker контейнер mtproto-proxy"
    echo "- команда $ALIAS_NAME"
    echo "- launcher $BINARY_PATH"
    echo ""

    read -p "Удалить полностью? (y/n): " confirm
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')

    if [[ "$confirm" != "y" ]]; then
        echo -e "${YELLOW}Удаление отменено.${NC}"
        read -p "Нажмите Enter..."
        return
    fi

    echo -e "${YELLOW}[*] Остановка контейнера...${NC}"
    docker stop mtproto-proxy >/dev/null 2>&1
    docker rm mtproto-proxy >/dev/null 2>&1

    echo -e "${YELLOW}[*] Удаление Docker image...${NC}"
    docker rmi nineseconds/mtg:2 >/dev/null 2>&1

    echo -e "${YELLOW}[*] Удаление launcher...${NC}"
    rm -f "$BINARY_PATH"

    echo ""
    echo -e "${GREEN}[SUCCESS] Скрипт полностью удалён.${NC}"
    echo -e "${GREEN}[SUCCESS] Перезапустите терминал.${NC}"

    exit 0
}

# --- 6) ПЕРЕЗАПУСК ПРОКСИ ---
restart_proxy() {
    clear
    echo -e "${CYAN}--- Перезапуск прокси ---${NC}"

    if ! docker ps -a | grep -q "mtproto-proxy"; then
        echo -e "${RED}Прокси контейнер не найден!${NC}"
        read -p "Нажмите Enter..."
        return
    fi

    docker restart mtproto-proxy >/dev/null 2>&1

    echo -e "${GREEN}[OK] Прокси успешно перезапущен.${NC}"
    read -p "Нажмите Enter..."
}

# --- 7) ONLINE ПОЛЬЗОВАТЕЛИ ---
show_online_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        ONLINE ПОЛЬЗОВАТЕЛИ           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""

    if ! docker ps | grep -q "mtproto-proxy"; then
        echo -e "${RED}Прокси не запущен.${NC}"
        read -p "Нажмите Enter..."
        return
    fi

    PORT=$(docker inspect mtproto-proxy \
        --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' 2>/dev/null)

    PORT=${PORT:-443}

    echo -e "${YELLOW}Порт:${NC} $PORT"
    echo ""

    ss -tn state established "( dport = :$PORT or sport = :$PORT )"

    echo ""
    echo -e "${GREEN}Всего подключений:${NC} $(ss -tn state established "( dport = :$PORT or sport = :$PORT )" | tail -n +2 | wc -l)"
    echo ""

    read -p "Нажмите Enter..."
}

# --- 8) МОНИТОРИНГ ТРАФИКА ---
proxy_monitoring() {
    clear
    echo -e "${CYAN}--- Мониторинг нагрузки прокси ---${NC}"

    docker stats mtproto-proxy --no-stream

    echo ""
    read -p "Нажмите Enter..."
}

# --- 9) ОБНОВЛЕНИЕ DOCKER IMAGE ---
update_proxy_image() {
    clear
    echo -e "${CYAN}--- Обновление MTProto Proxy ---${NC}"

    docker pull nineseconds/mtg:2

    echo ""
    echo -e "${GREEN}[OK] Docker image обновлён.${NC}"
    read -p "Нажмите Enter..."
}

# --- ТОП КЛИЕНТОВ ПО ТРАФИКУ ---
top_clients() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        ТОП КЛИЕНТОВ ПО IP            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""

    PORT=$(docker inspect mtproto-proxy \
        --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' 2>/dev/null)

    PORT=${PORT:-443}

    ss -tn state established "( dport = :$PORT or sport = :$PORT )" \
        | awk 'NR>1 {print $5}' \
        | cut -d: -f1 \
        | sort \
        | uniq -c \
        | sort -nr

    echo ""
    read -p "Нажмите Enter..."
}

# --- БЛОКИРОВКА IP ---
block_client_ip() {
    clear
    echo -e "${CYAN}--- Блокировка IP клиента ---${NC}"

    read -p "Введите IP для блокировки: " CLIENT_IP

    iptables -I INPUT -s "$CLIENT_IP" -j DROP

    echo -e "${GREEN}[OK] IP ${CLIENT_IP} заблокирован.${NC}"

    read -p "Нажмите Enter..."
}

# --- СТАРТ СКРИПТА ---
check_root
install_deps
show_promo # Промо теперь только один раз при старте

while true; do
    echo -e "\n${MAGENTA}=== telegaproxy Manager (by comp-maniya) ===${NC}"
    echo -e "1) ${GREEN}Установить / Обновить прокси${NC}"
    echo -e "2) Показать данные подключения${NC}"
    echo -e "3) ${YELLOW}Показать PROMO снова${NC}"
    echo -e "4) ${RED}Удалить только прокси${NC}"
    echo -e "5) ${RED}Удалить скрипт полностью${NC}"
    echo -e "6) ${CYAN}Перезапустить прокси${NC}"
    echo -e "7) ${CYAN}ONLINE пользователи${NC}"
    echo -e "8) ${CYAN}Мониторинг нагрузки${NC}"
    echo -e "9) ${CYAN}Обновить Docker image${NC}"
    echo -e "10) Топ клиентов по IP"
    echo -e "11) Заблокировать IP"
    echo -e "0) Выход${NC}"
    read -p "Пункт: " m_idx
    case $m_idx in
        1) menu_install ;;
        2) clear; show_config; read -p "Нажмите Enter..." ;;
        3) show_promo ;;
        4) docker stop mtproto-proxy >/dev/null 2>&1; docker rm mtproto-proxy >/dev/null 2>&1; echo "Прокси удалён" ;;
        5) full_uninstall ;;
        6) restart_proxy ;;
        7) show_online_users ;;
        8) proxy_monitoring ;;
        9) update_proxy_image ;;
        10) top_clients ;;
        11) block_client_ip ;;
        0) show_exit ;;
        *) echo "Неверный ввод" ;;
    esac
done
