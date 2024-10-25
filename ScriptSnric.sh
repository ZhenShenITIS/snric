#!/bin/bash

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
    check_docker
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
check_docker
build_base_image

rebuild_base_image(){
  local image_name="sonaric-node"

  # Проверяем, существует ли образ
  image_id=$(docker images -q "$image_name")

  if [ -n "$image_id" ]; then
      echo "Образ $image_name существует. Удаляем его..."
      docker rmi -f "$image_id"
  else
      echo "Образ $image_name не найден. Создаем новый образ..."
  fi

  # Вызываем функцию для сборки образа
  build_base_image
}

install_new_node286() {
    echo "Установка нового узла Sonaric..."

    if [ -n "$1" ]; then
        # Если переданы параметры, используем их
        proxy_details="$1"
    else
        # Запрос данных у пользователя
        read -p "Введите данные прокси и ключ из дискорда (IP:Port:Login:Pass:Key): " proxy_details
    fi

    # Парсинг данных прокси
    proxy_ip=$(echo $proxy_details | cut -d':' -f1)
    proxy_port=$(echo $proxy_details | cut -d':' -f2)
    proxy_username=$(echo $proxy_details | cut -d':' -f3)
    proxy_password=$(echo $proxy_details | cut -d':' -f4)
    key=$(echo $proxy_details | cut -d':' -f5)

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
        --memory="286m" \
        --cpus="1.0" \
        --name "$node_name" \
        --hostname VPS \
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
      " | tee -a "$node_dir/$node_name.log"
    docker exec -it "$node_name" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZhenShenITIS/snricinstall/refs/heads/main/install.sh)" | tee -a "$node_dir/$node_name.log"
    docker exec -it "$node_name" sonaric node-register $key | tee -a "$node_dir/$node_name.txt"
}

install_new_node512() {
    echo "Установка нового узла Sonaric..."

    if [ -n "$1" ]; then
        # Если переданы параметры, используем их
        proxy_details="$1"
    else
        # Запрос данных у пользователя
        read -p "Введите данные прокси и ключ из дискорда (IP:Port:Login:Pass:Key): " proxy_details
    fi

    # Парсинг данных прокси
    proxy_ip=$(echo $proxy_details | cut -d':' -f1)
    proxy_port=$(echo $proxy_details | cut -d':' -f2)
    proxy_username=$(echo $proxy_details | cut -d':' -f3)
    proxy_password=$(echo $proxy_details | cut -d':' -f4)
    key=$(echo $proxy_details | cut -d':' -f5)

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
        --memory="512m" \
        --cpus="2.0" \
        --name "$node_name" \
        --hostname VPS \
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
      " | tee -a "$node_dir/$node_name.log"
    docker exec -it "$node_name" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZhenShenITIS/snricinstall/refs/heads/main/install.sh)" | tee -a "$node_dir/$node_name.log"
    docker exec -it "$node_name" sonaric node-register $key | tee -a "$node_dir/$node_name.txt"
}

install_new_nodenolimits() {
    echo "Установка нового узла Sonaric..."

    if [ -n "$1" ]; then
        # Если переданы параметры, используем их
        proxy_details="$1"
    else
        # Запрос данных у пользователя
        read -p "Введите данные прокси и ключ из дискорда (IP:Port:Login:Pass:Key): " proxy_details
    fi
    # Парсинг данных прокси
    proxy_ip=$(echo $proxy_details | cut -d':' -f1)
    proxy_port=$(echo $proxy_details | cut -d':' -f2)
    proxy_username=$(echo $proxy_details | cut -d':' -f3)
    proxy_password=$(echo $proxy_details | cut -d':' -f4)
    key=$(echo $proxy_details | cut -d':' -f5)

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
        --hostname VPS \
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
      " | tee -a "$node_dir/$node_name.log"
    docker exec -it "$node_name" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZhenShenITIS/snricinstall/refs/heads/main/install.sh)" | tee -a "$node_dir/$node_name.log"
    docker exec -it "$node_name" sonaric node-register $key | tee -a "$node_dir/$node_name.txt"
}

install_nodes_from_file_286() {
    echo "Установка новых узлов Sonaric из файла с ограничениями 1CPU, 286Mb..."

    input_file=/root/snric/data.txt

    if [ ! -f "$input_file" ]; then
        echo "Файл $input_file не найден!"
        exit 1
    fi

    while IFS= read -r proxy_details || [ -n "$proxy_details" ]; do
        # Проверяем, что строка не пустая
        if [ -n "$proxy_details" ]; then
            install_new_node286 "$proxy_details"
        fi
    done < "$input_file"
}

install_nodes_from_file_512() {
    echo "Установка новых узлов Sonaric из файла с ограничениями 2CPU, 512Mb..."

    input_file=/root/snric/data.txt

    if [ ! -f "$input_file" ]; then
        echo "Файл $input_file не найден!"
        exit 1
    fi

    while IFS= read -r proxy_details || [ -n "$proxy_details" ]; do
        if [ -n "$proxy_details" ]; then
            install_new_node512 "$proxy_details"
        fi
    done < "$input_file"
}

install_nodes_from_file_nolimits() {
    echo "Установка новых узлов Sonaric из файла без ограничений..."

    input_file=/root/snric/data.txt

    if [ ! -f "$input_file" ]; then
        echo "Файл $input_file не найден!"
        exit 1
    fi

    while IFS= read -r proxy_details || [ -n "$proxy_details" ]; do
        if [ -n "$proxy_details" ]; then
            install_new_nodenolimits "$proxy_details"
        fi
    done < "$input_file"
}

# Функция для обновления всех узлов
update_all_nodes() {
    echo "Обновление всех узлов Sonaric..."
    for container in $(docker ps -a --filter "name=node" --format "{{.Names}}"); do
        echo "Обновление $container..."
        docker exec -it "$node_name" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZhenShenITIS/snricinstall/refs/heads/main/install.sh)"
    done
    echo "Все узлы успешно обновлены."
}

# Функция для установки задачи cron для обновления узлов раз в сутки
setup_daily_update() {
    echo "Настройка ежедневного обновления всех узлов..."

    # Проверяем, есть ли cron на системе, и устанавливаем его, если его нет
    if ! command -v crontab &> /dev/null; then
        echo "cron не установлен. Устанавливаю cron..."
        apt-get update && apt-get install -y cron
        systemctl enable cron
        systemctl start cron
    fi
    chmod 777 /root/snric/update.sh
    # Создаем временный файл для новой cron задачи
    (crontab -l 2>/dev/null; echo "0 2 * * * /root/snric/update.sh") | crontab -

    echo "Задача cron установлена: обновление всех узлов каждый день в 02:00."
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

# Функция для создания контейнеров с прокси и ключами из файла
create_containers_from_file() {
    input_file=/root/snric/data.txt

    if [ ! -f "$input_file" ]; then
        echo "Файл $input_file не найден!"
        exit 1
    fi

    while IFS=: read -r proxy_ip proxy_port proxy_username proxy_password node_key; do
        echo "Создаю контейнер для прокси $proxy_ip:$proxy_port..."

        # Создание директории для нового узла
        node_num=$(ls -l $base_dir | grep -c ^d)
        node_name="node$((node_num + 1))"
        node_dir="$base_dir/$node_name"
        mkdir -p "$node_dir"

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
            --memory="286m" \
            --name "$node_name" \
            --hostname vps \
            sonaric-node

        if [ $? -eq 0 ]; then
            echo "Контейнер $node_name успешно запущен"

            # Установка Sonaric внутри контейнера
            docker exec "$node_name" bash -c "
                set -e
                export DEBIAN_FRONTEND=noninteractive
                export HTTP_PROXY=\"http://$proxy_username:$proxy_password@$proxy_ip:$proxy_port\"
                export HTTPS_PROXY=\"http://$proxy_username:$proxy_password@$proxy_ip:$proxy_port\"

                # Обновление списка пакетов
                apt-get update

                # Установка необходимых пакетов
                apt-get install -y apt-transport-https ca-certificates curl gnupg gnupg2 dirmngr
            " | tee -a "$node_dir/$node_name.log"
            docker exec -it "$node_name" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZhenShenITIS/snricinstall/refs/heads/main/install.sh)" | tee -a "$node_dir/$node_name.log"
            docker exec -it "$node_name" sonaric node-register $node_key | tee -a "$node_dir/$node_name.txt"

            # Проверка успешной регистрации
            file_content=$(cat "$node_dir/$node_name.txt")
            if [ "$file_content" == "✔ Success" ]; then
                echo "Нода $node_name успешно зарегистрирована"
            else
                echo "Ошибка регистрации ноды $node_name"
            fi
        else
            echo "Ошибка при запуске контейнера $node_name"
        fi
    done < "$input_file"
}

# Главное меню

show_header() {
  echo ""
  echo ""
  echo "███████╗██████╗░███████╗███╗░░░███╗  ░██████╗░█████╗░███╗░░██╗░█████╗░██████╗░██╗░█████╗░"
  echo "██╔════╝██╔══██╗██╔════╝████╗░████║  ██╔════╝██╔══██╗████╗░██║██╔══██╗██╔══██╗██║██╔══██╗"
  echo "█████╗░░██████╦╝█████╗░░██╔████╔██║  ╚█████╗░██║░░██║██╔██╗██║███████║██████╔╝██║██║░░╚═╝"
  echo "██╔══╝░░██╔══██╗██╔══╝░░██║╚██╔╝██║  ░╚═══██╗██║░░██║██║╚████║██╔══██║██╔══██╗██║██║░░██╗"
  echo "███████╗██████╦╝███████╗██║░╚═╝░██║  ██████╔╝╚█████╔╝██║░╚███║██║░░██║██║░░██║██║╚█████╔╝"
  echo "╚══════╝╚═════╝░╚══════╝╚═╝░░░░░╚═╝  ╚═════╝░░╚════╝░╚═╝░░╚══╝╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░╚════╝░"
  echo "========================================================================================="
  echo "                           b.y. @ZhenShen9 and Begunki Uzlov                             "
  echo "                                        v.2.0                                            "
  echo "========================================================================================="
  echo ""
}

show_menu(){
  echo "Выберите действие:"
  echo "1. Пересоздать Docker-образ"
  echo "2. Установить новую ноду с ограничениями 1CPU, 286Mb"
  echo "3. Установить новую ноду с ограничениями 2CPU, 512Mb"
  echo "4. Установить новую ноду без ограничений"
  echo "5. Мульти-установка 1/0.286"
  echo "6. Мульти-установка 2/0.512"
  echo "7. Мульти-установка без ограничений"
  echo "8. Обновить все ноды"
  echo "9. Задать автоматическое ежедневное обновление всех нод"
  echo "10. Перезапустить все ноды"
  echo "0. Выход"
  echo -n "Введите номер действия: "
}
# Основной цикл меню
main_menu() {
    while true; do
        show_header
        show_menu
        read action
        case $action in
                1)
                    rebuild_base_image
                    ;;
                2)
                    install_new_node286
                    ;;
                3)
                    install_new_node512
                    ;;
                4)
                    install_new_nodenolimits
                    ;;
                5)
                    install_nodes_from_file_286
                    ;;
                6)
                    install_nodes_from_file_512
                    ;;
                7)
                    install_nodes_from_file_nolimits
                    ;;
                8)
                    update_all_nodes
                    ;;
                9)
                    setup_daily_update
                    ;;
                10)
                    restart_all_nodes
                    ;;
                *)
                    echo "Скрипт завершён."
                    exit 1
                    ;;
                0)
                    exit 0
                    ;;
        esac
    done
}

# Запуск основного меню
main_menu

