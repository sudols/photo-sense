import api from "./axios";
import type { Photo } from "./types";

export async function listPhotos(): Promise<Photo[]> {
  const { data } = await api.get("/api/photos/");
  return data;
}

export async function getPhoto(id: string): Promise<Photo> {
  const { data } = await api.get(`/api/photos/${id}/`);
  return data;
}

export async function uploadPhoto(file: File): Promise<Photo> {
  const formData = new FormData();
  formData.append("file", file);
  const { data } = await api.post("/api/photos/upload/", formData, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return data;
}

export async function deletePhoto(id: string): Promise<void> {
  await api.delete(`/api/photos/${id}/`);
}

export async function searchPhotos(query: string): Promise<Photo[]> {
  const { data } = await api.get("/api/photos/search/", {
    params: { q: query },
  });
  return data;
}
