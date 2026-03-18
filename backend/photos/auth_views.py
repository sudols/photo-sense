import json
from django.contrib.auth.models import User
from django.http import JsonResponse
from django.views import View
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator


@method_decorator(csrf_exempt, name="dispatch")
class RegisterView(View):
    """User registration endpoint."""

    def post(self, request):
        try:
            data = json.loads(request.body) if request.body else {}
        except json.JSONDecodeError:
            return JsonResponse({"error": "Invalid JSON"}, status=400)

        email = data.get("email", "").lower().strip()
        password = data.get("password", "")

        if not email or not password:
            return JsonResponse({"error": "email and password required"}, status=400)

        if User.objects.filter(username=email).exists():
            return JsonResponse({"error": "email already registered"}, status=400)

        User.objects.create_user(username=email, email=email, password=password)
        return JsonResponse({"message": "account created"}, status=201)
