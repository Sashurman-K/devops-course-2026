#!/usr/bin/env bash
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_DIR}/site/"

DRY_RUN=false
case "$#" in
    0) ;;
    1)
        if [[ "$1" == "--dry-run" ]]; then
            DRY_RUN=true
        else
            echo "Использование: $0 [--dry-run]" >&2
            exit 1
        fi
        ;;
    *)
        echo "Использование: $0 [--dry-run]" >&2
        exit 1
        ;;
esac

if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: отсутствует site/index.html" >&2
    exit 1
fi

if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
    echo "Ошибка: есть незафиксированные изменения" >&2
    exit 1
fi

if [[ "$DRY_RUN" == false && ! -r "$CA_CERT" ]]; then
    echo "Ошибка: недоступен сертификат $CA_CERT" >&2
    exit 1
fi

COMMIT="$(git -C "$REPO_DIR" rev-parse --short HEAD)"
OPTIONS=(-avz --delete --chmod=D755,F644)

if [[ "$DRY_RUN" == true ]]; then
    OPTIONS+=(--dry-run)
fi

if ! rsync "${OPTIONS[@]}" \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    "$LOCAL_DIR" "${REMOTE}:${REMOTE_DIR}/"; then
    echo "Ошибка доставки файлов" >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "Пробный запуск завершён. Коммит: $COMMIT"
    exit 0
fi

if ! curl --fail --silent --show-error \
    --connect-timeout 5 --max-time 15 \
    --cacert "$CA_CERT" --output /dev/null "$SITE_URL"; then
    echo "Ошибка: проверка HTTPS не пройдена" >&2
    exit 1
fi

echo "Деплой успешен. Коммит: $COMMIT"

