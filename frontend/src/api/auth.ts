import api from "./axios";

export async function login(username: string, password: string) {
  const { data } = await api.post("/api/auth/login/", { username, password });
  localStorage.setItem("access", data.access);
  localStorage.setItem("refresh", data.refresh);
  return data;
}

export async function register(email: string, password: string) {
  const { data } = await api.post("/api/auth/register/", { email, password });
  return data;
}

export async function refreshToken(refresh: string) {
  const { data } = await api.post("/api/auth/refresh/", { refresh });
  localStorage.setItem("access", data.access);
  return data;
}

export function logout() {
  localStorage.clear();
  window.location.href = "/login";
}
