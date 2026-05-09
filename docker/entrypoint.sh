#!/bin/sh
set -e

if [ -n "${PROMETHEUS_MULTIPROC_DIR:-}" ]; then
    mkdir -p "${PROMETHEUS_MULTIPROC_DIR}"
    rm -rf "${PROMETHEUS_MULTIPROC_DIR:?}/"*
fi

python manage.py migrate --noinput
python manage.py collectstatic --clear --noinput

exec gunicorn college_management_system.wsgi:application \
    --bind 0.0.0.0:8000 \
    --config docker/gunicorn.conf.py \
    --workers "${GUNICORN_WORKERS:-3}" \
    --timeout "${GUNICORN_TIMEOUT:-120}"
