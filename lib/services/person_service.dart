import 'dart:convert';
import '../models/person.dart';
import 'api_client.dart';

class PersonService {
  /// List all persons for the current user.
  /// Does NOT include photos (lightweight for grid view).
  static Future<List<Person>> listPersons() async {
    final response = await ApiClient.get('/persons/');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => Person.fromJson(j)).toList();
    }
    throw Exception('Failed to load persons (${response.statusCode})');
  }

  /// Get a single person with their photos included.
  static Future<Person> getPerson(String id) async {
    final response = await ApiClient.get('/persons/$id/');
    if (response.statusCode == 200) {
      return Person.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load person (${response.statusCode})');
  }

  /// Rename a person and mark as named.
  static Future<Person> renamePerson(String id, String name) async {
    final response = await ApiClient.patch('/persons/$id/', {
      'name': name,
      'is_unnamed': false,
    });
    if (response.statusCode == 200) {
      return Person.fromJson(jsonDecode(response.body));
    }
    throw Exception('Rename failed (${response.statusCode})');
  }

  /// Merge source person into target.
  /// Backend handles: combine face_ids, re-link PhotoPersons, delete source.
  static Future<void> mergePerson(String sourceId, String targetId) async {
    final response = await ApiClient.post('/persons/$sourceId/merge/', {
      'merge_into_id': targetId,
    });
    if (response.statusCode == 200) return;
    throw Exception('Merge failed (${response.statusCode})');
  }

  /// Delete a person.
  static Future<void> deletePerson(String id) async {
    final response = await ApiClient.delete('/persons/$id/');
    if (response.statusCode == 204) return;
    throw Exception('Delete failed (${response.statusCode})');
  }
}
