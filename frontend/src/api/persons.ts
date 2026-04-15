import api from "./axios";
import type { Person } from "./types";

export async function listPersons(): Promise<Person[]> {
  const { data } = await api.get("/api/persons/");
  return data;
}

export async function getPerson(id: string): Promise<Person> {
  const { data } = await api.get(`/api/persons/${id}/`);
  return data;
}

export async function renamePerson(id: string, name: string): Promise<Person> {
  const { data } = await api.patch(`/api/persons/${id}/`, {
    name,
    is_unnamed: false,
  });
  return data;
}

export async function deletePerson(id: string): Promise<void> {
  await api.delete(`/api/persons/${id}/`);
}

export async function mergePerson(
  fromId: string,
  intoId: string
): Promise<Person> {
  const { data } = await api.post(`/api/persons/${fromId}/merge/`, {
    merge_into_id: intoId,
  });
  return data;
}
