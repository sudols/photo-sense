from django.urls import path
from rest_framework.routers import DefaultRouter
from .views import PhotoViewSet, PersonViewSet, PhotoUploadView

router = DefaultRouter()
router.register("photos", PhotoViewSet, basename="photo")
router.register("persons", PersonViewSet, basename="person")

urlpatterns = [
    path("photos/upload/", PhotoUploadView.as_view()),  # must be before router
] + router.urls
