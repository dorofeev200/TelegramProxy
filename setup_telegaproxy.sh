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

# --- УСТАНОВКА ---
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
    
    read -p "Ваш выбор [1-20]: " d_idx
    DOMAIN=${domains[$((d_idx-1))]}
    DOMAIN=${DOMAIN:-google.com}

    echo -e "\n${CYAN}--- Выберите порт ---${NC}"
    echo -e "1) 443 (Рекомендуется)"
    echo -e "2) 8443"
    echo -e "3) Свой порт"
    read -p "Выбор: " p_choice
    case $p_choice in
        2) PORT=8443 ;;
        3) read -p "Введите свой порт: " PORT ;;
        *) PORT=443 ;;
    esac

    echo -e "${YELLOW}[*] Настройка прокси...${NC}"
    SECRET=$(docker run --rm nineseconds/mtg:2 generate-secret --hex "$DOMAIN")
    docker stop mtproto-proxy &>/dev/null && docker rm mtproto-proxy &>/dev/null
    
    docker run -d --name mtproto-proxy --restart always -p "$PORT":"$PORT" \
        nineseconds/mtg:2 simple-run -n 1.1.1.1 -i prefer-ipv4 0.0.0.0:"$PORT" "$SECRET" > /dev/null
    
    clear
    show_config
    read -p "Установка завершена. Нажмите Enter..."
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
    echo -e "0) Выход${NC}"
    read -p "Пункт: " m_idx
    case $m_idx in
        1) menu_install ;;
        2) clear; show_config; read -p "Нажмите Enter..." ;;
        3) show_promo ;;
        4) docker stop mtproto-proxy >/dev/null 2>&1; docker rm mtproto-proxy >/dev/null 2>&1; echo "Прокси удалён" ;;
        5) full_uninstall ;;
        0) show_exit ;;
        *) echo "Неверный ввод" ;;
    esac
done
