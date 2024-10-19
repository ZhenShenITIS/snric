for container in $(docker ps -a --filter "name=node" --format "{{.Names}}"); do
    echo "Обновление $container..."
    docker exec -it "$node_name" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ZhenShenITIS/snricinstall/refs/heads/main/install.sh)"
done
