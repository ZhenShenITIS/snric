#!/bin/bash
#Test change
#test
#testtest81298712
# Базовая директория для всех узлов
base_dir=/root/sonaric_nodes

# Функция для проверки и установки Docker, если он не установлен
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker не установлен. Устанавливаю Docker..."
        apt-get update && apt-get install -y docker.io
    fi
}

# Функция для создания базового Docker-образа с поддержкой systemd
build_base_image() {
    if ! docker images | grep -q sonaric-node; then
        echo "Создание базового Docker-образа для Sonaric..."
        cat > Dockerfile.sonaric <<EOF
FROM ubuntu:22.04

ENV container=docker

RUN apt-get update && \
    apt-get install -y --no-install-recommends \\
        systemd systemd-sysv \\
        wget curl gnupg gnupg2 dirmngr \\
        apt-utils ca-certificates apt-transport-https && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*

VOLUME [ "/sys/fs/cgroup" ]
STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
EOF
        docker build -t sonaric-node -f Dockerfile.sonaric .
        rm Dockerfile.sonaric
    fi
}

# Функция для установки нового узла
install_new_node() {
    echo "Установка нового узла Sonaric..."

    # Запрос данных у пользователя
    read -p "Введите данные прокси (IP:Port:Login:Pass): " proxy_details

    # Парсинг данных прокси
    proxy_ip=$(echo $proxy_details | cut -d':' -f1)
    proxy_port=$(echo $proxy_details | cut -d':' -f2)
    proxy_username=$(echo $proxy_details | cut -d':' -f3)
    proxy_password=$(echo $proxy_details | cut -d':' -f4)

    # Создание корневой директории, если не существует
    mkdir -p "$base_dir"

    # Определение следующего узла
    node_num=$(ls -l $base_dir | grep -c ^d)
    node_name="node$((node_num + 1))"
    node_dir="$base_dir/$node_name"
    mkdir "$node_dir"

    # Сохранение данных прокси
    echo "HTTP_PROXY=http://$proxy_username:$proxy_password@$proxy_ip:$proxy_port" > "$node_dir/proxy.conf"
    echo "HTTPS_PROXY=http://$proxy_username:$proxy_password@$proxy_ip:$proxy_port" >> "$node_dir/proxy.conf"

    # Запуск контейнера
    docker run -d --privileged \
        --cgroupns=host \
        --security-opt seccomp=unconfined \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        -v /dev/urandom:/dev/urandom \
        -v /dev/random:/dev/random \
        -e container=docker \
        -e HTTP_PROXY="http://$proxy_username:$proxy_password@$proxy_ip:$proxy_port" \
        -e HTTPS_PROXY="http://$proxy_username:$proxy_password@$proxy_ip:$proxy_port" \
        --name "$node_name" \
        --hostname "$node_name" \
        sonaric-node

    if [ $? -eq 0 ]; then
        echo "Контейнер $node_name успешно запущен" | tee -a "$node_dir/$node_name.log"
    else
        echo "Ошибка при запуске контейнера $node_name"
        return 1
    fi

    # Установка Sonaric внутри контейнера
    echo "Установка Sonaric в контейнере $node_name..."
    docker exec "$node_name" bash -c "
        set -e
        export DEBIAN_FRONTEND=noninteractive
        export HTTP_PROXY=\"http://$proxy_username:$proxy_password@$proxy_ip:$proxy_port\"
        export HTTPS_PROXY=\"http://$proxy_username:$proxy_password@$proxy_ip:$proxy_port\"

        # Обновление списка пакетов
        apt-get update

        # Установка необходимых пакетов
        apt-get install -y apt-transport-https ca-certificates curl gnupg gnupg2 dirmngr

        # Добавление ключа репозитория
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL \"https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg\" | gpg --dearmor -o /etc/apt/keyrings/sonaric.gpg
        chmod a+r /etc/apt/keyrings/sonaric.gpg

        # Добавление репозитория Sonaric
        echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/sonaric.gpg] https://us-central1-apt.pkg.dev/projects/sonaric-platform sonaric-releases-apt main\" > /etc/apt/sources.list.d/sonaric.list

        # Обновление списка пакетов
        apt-get update

        # Установка Sonaric
        apt-get install -y sonaric

        # Запуск службы sonaricd
        systemctl enable sonaricd
        systemctl start sonaricd

        # Ожидание запуска Sonaric
        for i in {1..20}; do
            sonaric version && break || sleep 2
        done
    " | tee -a "$node_dir/$node_name.log"

    # Получение информации об узле
    node_info=$(docker exec "$node_name" sonaric node-info 2>/dev/null)
    if [ -z "$node_info" ]; then
        echo "Ошибка при получении информации узла $node_name"
    else
        node_id=$(echo "$node_info" | grep 'Node ID' | awk '{print $3}')
        node_version=$(echo "$node_info" | grep 'Version' | awk '{print $2}')
        echo "Узел $node_name установлен с ID $node_id и версией $node_version" | tee -a "$node_dir/$node_name.log"
    fi
}

# Функция для обновления всех узлов
update_all_nodes() {
    echo "Обновление всех узлов Sonaric..."
    for container in $(docker ps -a --filter "name=node" --format "{{.Names}}"); do
        echo "Обновление $container..."
        docker exec "$container" bash -c "
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y sonaricd sonaric
            systemctl restart sonaricd
        " | tee -a "$base_dir/$container/$container.log"
    done
    echo "Все узлы успешно обновлены."
}

# Функция для перезапуска всех узлов
restart_all_nodes() {
    echo "Перезапуск всех узлов Sonaric..."
    for container in $(docker ps -a --filter "name=node" --format "{{.Names}}"); do
        echo "Перезапуск $container..."
        docker exec "$container" systemctl restart sonaricd
    done
    echo "Все узлы успешно перезапущены."
}

# Функция для получения информации со всех узлов
get_node_info() {
    echo "Сбор информации со всех узлов..."
    for container in $(docker ps --filter "name=node" --format "{{.Names}}"); do
        node_info=$(docker exec "$container" sonaric node-info 2>/dev/null)
        if [ -z "$node_info" ]; then
            echo "Не удалось получить информацию узла $container"
        else
            node_id=$(echo "$node_info" | grep 'Node ID' | awk '{print $3}')
            node_version=$(echo "$node_info" | grep 'Version' | awk '{print $2}')
            echo "$node_id $node_version"
        fi
    done
}

# Главное меню
check_docker
build_base_image

echo "Выберите действие:"
echo "1. Установить новый узел"
echo "2. Обновить все узлы"
echo "3. Перезапустить все узлы"
echo "4. Получить информацию со всех узлов"
read -p "Введите номер действия (1, 2, 3 или 4): " action

case $action in
    1)
        install_new_node
        ;;
    2)
        update_all_nodes
        ;;
    3)
        restart_all_nodes
        ;;
    4)
        get_node_info
        ;;
    *)
        echo "Неверный выбор. Скрипт завершён."
        exit 1
        ;;
esac
