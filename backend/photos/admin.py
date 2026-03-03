from django.contrib import admin
from .models import Photo, Person, PhotoPerson


@admin.register(Photo)
class PhotoAdmin(admin.ModelAdmin):
    list_display = ("id", "owner", "s3_key", "faces_count", "analyzed_at", "created_at")
    list_filter = ("owner", "analyzed_at")
    search_fields = ("s3_key",)
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(Person)
class PersonAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "owner", "face_id", "is_unnamed", "created_at")
    list_filter = ("owner", "is_unnamed")
    search_fields = ("name",)
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(PhotoPerson)
class PhotoPersonAdmin(admin.ModelAdmin):
    list_display = ("id", "photo", "person", "owner", "created_at")
    list_filter = ("owner",)
    readonly_fields = ("id", "created_at")
