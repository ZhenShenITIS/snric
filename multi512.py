#512
import pexpect

# Путь к вашему Bash-скрипту
bash_script = './ScriptSnric.sh'

# Читаем данные из файла data.txt
with open('data.txt', 'r', encoding='utf-8') as file:
    lines = [line.strip() for line in file if line.strip()]

# Запускаем Bash-скрипт с указанием кодировки
child = pexpect.spawn(bash_script, encoding='utf-8')

# Включаем логирование (опционально)
child.logfile = open('pexpect_log.txt', 'w', encoding='utf-8')

for proxy_data in lines:
    try:
        # Ожидаем появления меню
        child.expect('Введите номер действия: ')
        # Выбираем опцию 2 (Установить новую ноду с ограничениями 1CPU, 286Mb)
        child.sendline('3')

        # Ожидаем запроса данных прокси
        child.expect('Введите данные прокси и ключ из дискорда \\(IP:Port:Login:Pass:Key\\):')
        # Вводим данные прокси из файла
        child.sendline(proxy_data)

        # Ожидаем завершения установки ноды
        child.expect('запущен', timeout=30)

        # Ожидаем появления 'Success' или '403' или 'Proxy CONNECT aborted'
        index = child.expect(['Success', '403', 'Proxy CONNECT aborted'], timeout=600)
        if index == 0:
            print("Нода успешно запущена с данными", proxy_data, " с ограничениями 1/0.512")
            print ("Перехожу к установке следующей ноды...")
        elif index == 1:
            print("Ошибка установки ноды с данными", proxy_data, "- получен код 403")
            print ("Перехожу к установке следующей ноды...")
        elif index == 2:
            print("Ошибка установки ноды с данными", proxy_data, " - ошибка прокси")
            print ("Перехожу к установке следующей ноды...")

        # Ожидаем возвращения к меню для следующей установки
        child.expect('ZhenShen9', timeout=30)
    except pexpect.EOF:
        print("Неожиданное завершение Bash-скрипта.")
        break
    except pexpect.TIMEOUT:
        print("Таймаут при ожидании вывода. Проверьте лог-файл.")
        break

# После установки всех нод отправляем команду выхода и закрываем соединение
child.sendline('0')
child.close()
