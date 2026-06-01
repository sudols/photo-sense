from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenRefreshView
from photos.auth_views import RegisterView, TurnstileLoginView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/auth/register/", RegisterView.as_view()),
    path("api/auth/login/", TurnstileLoginView.as_view()),
    path("api/auth/refresh/", TokenRefreshView.as_view()),
    path("api/", include("photos.urls")),
]
