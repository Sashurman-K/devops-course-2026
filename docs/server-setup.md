# Конфигурация сервера devops-vm

## 1. Параметры ВМ

- Гипервизор: VirtualBox.
- ОС: Ubuntu Server.
- RAM: 2048 мб.
- Число виртуальных процессоров: 2.
- Размер диска: 25 гб.

## 2. Сетевые интерфейсы

- enp0s3: NAT, IPv4 10.0.2.15/24.
- Шлюз по умолчанию: 10.0.2.2 через enp0s3.
- enp0s8: Host-only, IPv4 192.168.56.101/24.
- NAT обеспечивает выход в Интернет.
- Host-only используется для доступа из Windows к серверу.

## 3. Проброс портов


Подключение через Host-only:
192.168.56.101:2222.

## 4. Учётные записи

- student: UID 1000, группы student, adm, cdrom, sudo,
  dip, plugdev, users, lxd.
- devops: UID 1001, группы devops, sudo, users.
- Обе учётные записи входят в группу sudo.
- По SSH разрешён вход только пользователю devops.
- Аутентификация devops по SSH выполняется по ключу.
- На клиенте Windows используется ключ ~/.ssh/devops_vm.

## 5. Защита SSH

Файл настроек: /etc/ssh/sshd_config.d/99-hardening.conf.

- Port 2222
- PermitRootLogin no
- PasswordAuthentication no
- PubkeyAuthentication yes
- MaxAuthTries 3
- AllowUsers devops

Проверка синтаксиса: sudo sshd -t.
Проверка действующих параметров: sudo sshd -T.

В файле hosts Windows задано:
192.168.56.101 devops.local

Полное имя сервера: devops-vm.devops.local.

## 6. Правила межсетевого экрана

- UFW активен.
- Входящие соединения по умолчанию: deny.
- Исходящие соединения по умолчанию: allow.
- Маршрутизируемый трафик: disabled.
- 80/tcp: ALLOW IN.
- 443/tcp: ALLOW IN.
- 2222/tcp: LIMIT IN.
- Правила настроены для IPv4 и IPv6.
- Журналирование включено, уровень medium.


## 7. Снимки состояния

- 01-clean-install — 30.10.2026, 11:28.
  Исходное состояние после установки ОС.
- 02-keys-configured — 30.10.2026, 11:44.
  Состояние после настройки SSH-ключей.
- 03-ssh-hardened — 30.10.2026, 16:16.
  Состояние после усиления защиты SSH.
## 8. Веб-сервер

### Установка и конфигурация

- Пакет: nginx.
- Конфигурация сайта: /etc/nginx/sites-available/devops-site.
- Активирующая ссылка: /etc/nginx/sites-enabled/devops-site.
- Стандартный сайт отключён: ссылка sites-enabled/default удалена.
- HTTP, порт 80: перенаправление 301 на HTTPS.
- HTTPS, порт 443: публикация сайта devops.local.
- Разрешённые версии TLS: TLSv1.2 и TLSv1.3.

Установка:
sudo apt update && sudo apt install -y nginx

Применение конфигурации:
sudo nginx -t && sudo systemctl reload nginx

### Файлы сайта

- Каталог: /var/www/devops-site.
- Владелец и группа: devops:devops.
- Права каталогов: 755.
- Права файлов: 644.
- Главная страница: index.html.
- Страница ошибки: 404.html.
- www-data может читать файлы, но не изменять их.

### Сертификат и ключ

- Сертификат: /etc/ssl/certs/devops.crt.
- Владелец сертификата: root, права 644.
- Закрытый ключ: /etc/ssl/private/devops.key.
- Владелец ключа: root, права 600.
- Сертификат самоподписанный, срок действия — 365 дней.
- SAN: DNS:devops.local.

Команда формирования:

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key \
  -out /etc/ssl/certs/devops.crt \
  -subj "/CN=devops.local" \
  -addext "subjectAltName=DNS:devops.local"
```

### Журналы и доставка

- Запросы HTTPS: /var/log/nginx/devops-site.access.log.
- Ошибки сайта: /var/log/nginx/devops-site.error.log.
- Сценарий доставки: scripts/deploy.sh, запускается из WSL.
- Источник: каталог site/ в репозитории.
- Доставка: rsync через SSH, с --delete и --chmod=D755,F644.
- После доставки проверяется HTTPS с сертификатом ~/devops.crt.
- Снимок состояния после настройки HTTPS: 04-nginx-https.

## 9. Контейнеризация

### Установка Docker

Docker Engine установлен из официального APT-репозитория:
https://download.docker.com/linux/ubuntu

Пакеты:
docker-ce, docker-ce-cli, containerd.io,
docker-buildx-plugin, docker-compose-plugin.

Версия Docker Engine: 29.9.2.
Версия Docker Compose: 5.6.1.

Пользователь devops добавлен в группу docker:
sudo usermod -aG docker devops

После добавления выполнен повторный вход по SSH.
Членство в группе docker фактически предоставляет права root.

### Проект и секреты

Проект на сервере: /home/devops/app.
Конфигурация: /home/devops/app/docker-compose.yml.
Секреты: /home/devops/app/.env, владелец devops, права 600.
Файл .env исключён из Git и контекста сборки.
В репозитории хранится только шаблон .env.example.

Доставка из WSL:
rsync -avz --delete --exclude=.env app/ devops:app/

Сборка и запуск на сервере:
cd ~/app
docker compose up -d --build --wait

### Сервисы, сеть и данные

- app: образ devops-app:1.0, процесс от пользователя app.
- db: образ postgres:16-alpine.
- Приложение подключается к БД по имени db.
- Сеть проекта: app_backend, тип bridge.
- Порт приложения: только 127.0.0.1:5000.
- Порт PostgreSQL 5432 наружу не опубликован.
- Именованный том: app_db_data.
- docker compose down сохраняет данные.
- docker compose down -v удаляет том и данные.
- Запуск приложения ожидает состояния healthy у БД.

### Обратный прокси

Конфигурация: /etc/nginx/sites-available/devops-site.
В HTTPS-блок добавлено:

```nginx
location /app/ {
    proxy_pass http://127.0.0.1:5000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Статический сайт по адресу / сохранён.
Приложение доступно по https://devops.local/app/.
Проверка здоровья: https://devops.local/app/health.

Применение конфигурации:
sudo nginx -t && sudo systemctl reload nginx

Снимок состояния: 05-docker-compose.
