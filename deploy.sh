#!/bin/bash
#
# Простая и безопасная схема деплоя на 94.250.252.236:8000
# Usage: ./deploy.sh <ssh_user>
# Например: ./deploy.sh root

set -euo pipefail

# ----------------------------------------
# Получаем нашего SSH-юзера из аргумента
# ----------------------------------------
if [ $# -ne 1 ]; then
  echo "Usage: $0 <ssh_user>"
  exit 1
fi
REMOTE_USER="$1"

# ----------------------------------------
# Константы (менять здесь не нужно)
# ----------------------------------------
REMOTE_HOST="94.250.252.236"
REMOTE_APP_DIR="/home/${REMOTE_USER}/app"   # куда клонируем код
IMAGE_NAME="namaz-app"
CONTAINER_NAME="namaz-app"

# ----------------------------------------
# Шаг 1: чистим сервер
# ----------------------------------------
echo ">>> Подключаемся к ${REMOTE_USER}@${REMOTE_HOST} и чистим прошлые артефакты…"
ssh "${REMOTE_USER}@${REMOTE_HOST}" bash <<EOF
  set -euo pipefail

  echo " - Убиваем все слушатели порта 8000 (uvicorn и др.)"
  if lsof -iTCP:8000 -sTCP:LISTEN &>/dev/null; then
    pkill -f uvicorn || true
  fi

  echo " - Удаляем папку ${REMOTE_APP_DIR}"
  rm -rf "${REMOTE_APP_DIR}"

  echo " - Создаём заново папку ${REMOTE_APP_DIR}"
  mkdir -p "${REMOTE_APP_DIR}"
EOF

# ----------------------------------------
# Шаг 2: копируем код
# ----------------------------------------
echo ">>> Копируем локальные файлы в ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APP_DIR}…"
# rsync надёжнее scp, автоматически пропустит .git
rsync -av --exclude='.git' ./ "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_APP_DIR}/"

# ----------------------------------------
# Шаг 3: билдим Docker и запускаем контейнер
# ----------------------------------------
echo ">>> Собираем Docker-образ и запускаем контейнер…"
ssh "${REMOTE_USER}@${REMOTE_HOST}" bash <<EOF
  set -euo pipefail
  cd "${REMOTE_APP_DIR}"

  echo " - Собираем образ ${IMAGE_NAME}"
  docker build -t "${IMAGE_NAME}" .

  echo " - Если старый контейнер ${CONTAINER_NAME} есть — удаляем"
  if docker ps -a --format '{{.Names}}' | grep -x "${CONTAINER_NAME}" &>/dev/null; then
    docker rm -f "${CONTAINER_NAME}"
  fi

  echo " - Запускаем новый контейнер на порту 8000"
  docker run -d --name "${CONTAINER_NAME}" -p 8000:8000 "${IMAGE_NAME}"

  echo ">>> Деплой завершён! Приложение на http://${REMOTE_HOST}:8000"
EOF
