#286
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
        child.sendline('2')

        # Ожидаем запроса данных прокси
        child.expect('Введите данные прокси и ключ из дискорда \\(IP:Port:Login:Pass:Key\\):')
        # Вводим данные прокси из файла
        child.sendline(proxy_data)

        # Ожидаем завершения установки ноды
        child.expect('запущен', timeout=30)

        child.expect('Success', timeout=300)
        print ("Нода успешно запущена с данными ", proxy_data, " и ограничениями 0.5/0.286")


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




