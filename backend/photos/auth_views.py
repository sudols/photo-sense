from django.contrib.auth.models import User
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").lower().strip()
        password = request.data.get("password", "")

        if not email or not password:
            return Response({"error": "email and password required"}, status=400)

        if User.objects.filter(username=email).exists():
            return Response({"error": "email already registered"}, status=400)

        User.objects.create_user(username=email, email=email, password=password)
        return Response({"message": "account created"}, status=status.HTTP_201_CREATED)
