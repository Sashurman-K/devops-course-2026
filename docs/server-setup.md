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

## 7. Снимки состояния

- 01-clean-install — 30.10.2026, 11:28.
  Исходное состояние после установки ОС.
- 02-keys-configured — 30.10.2026, 11:44.
  Состояние после настройки SSH-ключей.
- 03-ssh-hardened — 30.10.2026, 16:16.
  Состояние после усиления защиты SSH.