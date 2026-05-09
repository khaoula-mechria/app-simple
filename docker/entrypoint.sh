#!/bin/sh
set -e

python manage.py migrate --noinput
python manage.py collectstatic --clear --noinput

exec gunicorn college_management_system.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers "${GUNICORN_WORKERS:-3}" \
    --timeout "${GUNICORN_TIMEOUT:-120}"
