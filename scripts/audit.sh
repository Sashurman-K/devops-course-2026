#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  [OK]   $desc"
        ((PASS++))
    else
        echo "  [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" \
    "$(sudo sshd -T | awk '/^permitrootlogin /{print $2}')"

check "Парольная аутентификация отключена" "no" \
    "$(sudo sshd -T | awk '/^passwordauthentication /{print $2}')"

# TODO 1: порт SSH отличается от 22
PORT="$(sudo sshd -T | awk '/^port /{print $2}')"
if [[ "$PORT" =~ ^[0-9]+$ ]] && ((PORT != 22)); then
    check "Порт SSH отличается от 22" "yes" "yes"
else
    check "Порт SSH отличается от 22" "yes" "no"
fi

# TODO 2: MaxAuthTries равен 3
check "MaxAuthTries равен 3" "3" \
    "$(sudo sshd -T | awk '/^maxauthtries /{print $2}')"

echo "[2] Межсетевой экран"
UFW_STATUS="$(sudo env LC_ALL=C ufw status verbose)"

check "Межсетевой экран активен" "active" \
    "$(awk '/^Status:/{print $2}' <<< "$UFW_STATUS")"

# TODO 3: входящий трафик по умолчанию запрещён
check "Входящая политика — deny" "deny" \
    "$(sed -n 's/^Default: \([^ ]*\) (incoming).*/\1/p' <<< "$UFW_STATUS")"

echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {printf "    %s (uid=%s)\n",$1,$3}' /etc/passwd
echo "[4] Веб-сервер"

check "Nginx активен" "active" "$(systemctl is-active nginx)"

if sudo nginx -t >/dev/null 2>&1; then
    check "Конфигурация Nginx корректна" "0" "0"
else
    check "Конфигурация Nginx корректна" "0" "1"
fi

# По умолчанию проверяем, что сертификат действует ещё 30 дней.
CERT_MIN_SECONDS="${AUDIT_CERT_MIN_SECONDS:-2592000}"

if openssl x509 -in /etc/ssl/certs/devops.crt \
    -checkend "$CERT_MIN_SECONDS" -noout >/dev/null 2>&1; then
    check "Срок действия сертификата достаточен" "yes" "yes"
else
    check "Срок действия сертификата достаточен" "yes" "no"
fi

if WRITABLE="$(find /var/www/devops-site -perm -o+w)" &&
    [[ -z "$WRITABLE" ]] &&
    [[ "$(sudo stat -c '%a' /etc/ssl/private/devops.key)" == "600" ]]; then
    check "Нет общей записи, права ключа 600" "yes" "yes"
else
    check "Нет общей записи, права ключа 600" "yes" "no"
fi

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
