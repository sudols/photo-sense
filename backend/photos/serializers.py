from rest_framework import serializers
from .models import Photo, Person, PhotoPerson
from .storage import get_presigned_url


class PhotoSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model = Photo
        fields = [
            "id",
            "s3_key",
            "url",
            "face_ids",
            "detected_text",
            "detected_faces",
            "faces_count",
            "analyzed_at",
            "created_at",
        ]

    def get_url(self, obj):
        return get_presigned_url(obj.s3_key)


class PersonSerializer(serializers.ModelSerializer):
    thumbnail_url = serializers.SerializerMethodField()
    photos = serializers.SerializerMethodField()

    class Meta:
        model = Person
        fields = [
            "id",
            "name",
            "face_id",
            "face_ids",
            "bounding_box",
            "thumbnail_s3_key",
            "thumbnail_url",
            "is_unnamed",
            "created_at",
            "photos",
        ]

    def get_thumbnail_url(self, obj):
        if obj.thumbnail_s3_key:
            return get_presigned_url(obj.thumbnail_s3_key)
        return None

    def get_photos(self, obj):
        # Only included on detail view to avoid N+1 on list
        if self.context.get("include_photos"):
            photos = Photo.objects.filter(photo_persons__person=obj)
            return PhotoSerializer(photos, many=True, context=self.context).data
        return None
