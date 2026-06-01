import json
import urllib.request
import urllib.parse
from django.conf import settings
from django.contrib.auth.models import User
from django.http import JsonResponse
from django.views import View
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from rest_framework_simplejwt.views import TokenObtainPairView


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
        turnstile_token = data.get("turnstileToken", "")

        if not email or not password:
            return JsonResponse({"error": "email and password required"}, status=400)

        if not turnstile_token:
            return JsonResponse({"error": "CAPTCHA verification required"}, status=400)

        # Verify Turnstile
        verify_url = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
        verify_data = urllib.parse.urlencode({
            "secret": settings.TURNSTILE_SECRET_KEY,
            "response": turnstile_token
        }).encode("utf-8")

        try:
            req = urllib.request.Request(verify_url, data=verify_data)
            with urllib.request.urlopen(req, timeout=5) as response:
                verify_result = json.loads(response.read().decode("utf-8"))
                if not verify_result.get("success"):
                    return JsonResponse({"error": "CAPTCHA verification failed. Are you a bot?"}, status=403)
        except Exception:
            return JsonResponse({"error": "CAPTCHA service unavailable"}, status=500)

        if User.objects.filter(username=email).exists():
            return JsonResponse({"error": "email already registered"}, status=400)

        User.objects.create_user(username=email, email=email, password=password)
        return JsonResponse({"message": "account created"}, status=201)

class TurnstileLoginView(TokenObtainPairView):
    """Secure login endpoint with Turnstile verification."""

    def post(self, request, *args, **kwargs):
        turnstile_token = request.data.get("turnstileToken", "")
        
        if not turnstile_token:
            return JsonResponse({"error": "CAPTCHA verification required"}, status=400)

        # Verify Turnstile
        verify_url = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
        verify_data = urllib.parse.urlencode({
            "secret": settings.TURNSTILE_SECRET_KEY,
            "response": turnstile_token
        }).encode("utf-8")

        try:
            req = urllib.request.Request(verify_url, data=verify_data)
            with urllib.request.urlopen(req, timeout=5) as response:
                verify_result = json.loads(response.read().decode("utf-8"))
                if not verify_result.get("success"):
                    return JsonResponse({"error": "CAPTCHA verification failed. Are you a bot?"}, status=403)
        except Exception:
            return JsonResponse({"error": "CAPTCHA service unavailable"}, status=500)

        # If turnstile is valid, proceed with standard JWT login
        return super().post(request, *args, **kwargs)
