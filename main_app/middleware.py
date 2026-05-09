from django.utils.deprecation import MiddlewareMixin
from django.urls import reverse
from django.shortcuts import redirect
from django.db.utils import OperationalError, ProgrammingError


class LoginCheckMiddleWare(MiddlewareMixin):
    def process_view(self, request, view_func, view_args, view_kwargs):
        modulename = view_func.__module__
        metrics_allowed = request.path.startswith("/metrics")
        auth_allowed_paths = {
            reverse("login_page"),
            reverse("user_login"),
            reverse("user_logout"),
        }

        try:
            user = request.user
            user_type = str(getattr(user, "user_type", ""))
        except (OperationalError, ProgrammingError):
            # Let auth pages load even when DB tables are not initialized yet.
            if (
                metrics_allowed
                or request.path in auth_allowed_paths
                or modulename.startswith("django.contrib.auth")
                or request.path.startswith("/admin/")
            ):
                return None
            return redirect(reverse("login_page"))

        if user.is_authenticated:
            if user_type == "1":
                if modulename == "main_app.student_views":
                    return redirect(reverse("admin_home"))
            elif user_type == "2":
                if modulename in {"main_app.student_views", "main_app.hod_views"}:
                    return redirect(reverse("staff_home"))
            elif user_type == "3":
                if modulename in {"main_app.hod_views", "main_app.staff_views"}:
                    return redirect(reverse("student_home"))
            else:
                return redirect(reverse("login_page"))
        else:
            if (
                metrics_allowed
                or request.path in auth_allowed_paths
                or modulename.startswith("django.contrib.auth")
                or request.path.startswith("/admin/")
            ):
                return None
            return redirect(reverse("login_page"))
