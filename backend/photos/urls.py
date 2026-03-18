from django.urls import path
from .views import (
    PhotoUploadView,
    PhotoListView,
    PhotoDetailView,
    PhotoSearchView,
    PersonListView,
    PersonDetailView,
    PersonMergeView,
)

urlpatterns = [
    # Photo endpoints
    path("photos/upload/", PhotoUploadView.as_view()),
    path("photos/search/", PhotoSearchView.as_view()),
    path("photos/", PhotoListView.as_view()),
    path("photos/<uuid:pk>/", PhotoDetailView.as_view()),
    # Person endpoints
    path("persons/", PersonListView.as_view()),
    path("persons/<uuid:pk>/", PersonDetailView.as_view()),
    path("persons/<uuid:pk>/merge/", PersonMergeView.as_view()),
]
