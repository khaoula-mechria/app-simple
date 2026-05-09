# College ERP

College ERP is a Django application for managing students, staff, courses, attendance, results, leave requests, notifications, and dashboards for a college environment.

## Stack

- Backend: Django 3.1.1
- Frontend: Django templates, Bootstrap, AdminLTE
- Database: PostgreSQL in Docker, SQLite fallback for local non-Docker usage
- Web server: Gunicorn + Nginx

## Features

- Multi-role authentication
- Admin, staff, and student dashboards
- Student and staff management
- Course and subject management
- Attendance tracking
- Result management
- Leave and feedback workflows
- Notifications

## Project Structure

```text
college_management_system/   Django project settings
main_app/                    Main application
docker/                      Nginx config and container entrypoint
scripts/                     Helper scripts for docker run mode
Dockerfile                   Backend image build
docker-compose.yml           Full application stack
```

## Prerequisites

- Git
- Docker Desktop
- Docker Compose
- Python 3.9+ if you want to run without Docker

## Quick Start With Docker Compose

1. Clone the repository:

```bash
git clone https://github.com/khaoula-mechria/app-simple.git
cd app-simple
```

2. Create the environment file:

```bash
cp .env.example .env
```

Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

3. Start the full application:

```bash
docker compose up --build -d
```

4. Check the containers:

```bash
docker compose ps
```

5. Open the application:

```text
http://localhost:8081
```

6. Create the Django admin user:

```bash
docker compose exec backend python manage.py createsuperuser
```

7. Open Django admin:

```text
http://localhost:8081/admin/
```

## Useful Docker Compose Commands

Start:

```bash
docker compose up --build -d
```

Stop:

```bash
docker compose down
```

View backend logs:

```bash
docker compose logs -f backend
```

View frontend logs:

```bash
docker compose logs -f frontend
```

Restart from a clean static build:

```bash
docker compose down
docker volume rm college-erp_static_volume college-erp_media_volume
docker compose up --build -d
```

## Run With docker run

If you specifically want `docker run` instead of `docker compose`, use the helper script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-app-docker.ps1
```

This starts:

- PostgreSQL
- Django backend
- Nginx frontend

Stop those containers with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stop-app-docker.ps1
```

Note: Docker Desktop groups containers into one application when you use `docker compose`. With `docker run`, containers are shown separately.

## Local Development Without Docker

1. Create and activate a virtual environment.
2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Run migrations:

```bash
python manage.py migrate
```

4. Create a superuser:

```bash
python manage.py createsuperuser
```

5. Start the development server:

```bash
python manage.py runserver
```

6. Open:

```text
http://127.0.0.1:8000
```

## Environment Variables

The project uses `.env.example` as the template. Main variables:

- `DJANGO_DEBUG`
- `SECRET_KEY`
- `ALLOWED_HOSTS`
- `CSRF_TRUSTED_ORIGINS`
- `FRONTEND_PORT`
- `DATABASE_URL`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `STATICFILES_STORAGE`
- `EMAIL_HOST`
- `EMAIL_PORT`
- `EMAIL_HOST_USER`
- `EMAIL_HOST_PASSWORD`

## Default Access URLs

- Application: `http://localhost:8081`
- Admin: `http://localhost:8081/admin/`

## Troubleshooting

Port already allocated:

- Change `FRONTEND_PORT` in `.env`
- Restart with `docker compose up --build -d`

Backend container exits immediately:

- Check logs:

```bash
docker compose logs --tail=50 backend
```

Superuser email cannot be blank:

- This project uses email as the login field
- Use a real value such as `admin@example.com`

## Verification

The Docker stack was validated with:

```bash
docker compose up --build -d
docker compose ps
docker compose exec backend python manage.py createsuperuser
```

The `docker run` alternative was also validated with the helper scripts in `scripts/`.

## License

This project is distributed under the MIT License. See [LICENSE](LICENSE).
