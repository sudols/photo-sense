// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'Photo.dart';
import 'Person.dart';
import 'PhotoPerson.dart';

export 'Photo.dart';
export 'Person.dart';
export 'PhotoPerson.dart';

class ModelProvider implements amplify_core.ModelProviderInterface {
  @override
  String version = "1";

  @override
  List<amplify_core.ModelSchema> modelSchemas = [
    Photo.schema,
    Person.schema,
    PhotoPerson.schema,
  ];

  @override
  List<amplify_core.ModelSchema> customTypeSchemas = [];

  static final ModelProvider _instance = ModelProvider();
  static ModelProvider get instance => _instance;

  amplify_core.ModelType getModelTypeByModelName(String modelName) {
    switch (modelName) {
      case "Photo":
        return Photo.classType;
      case "Person":
        return Person.classType;
      case "PhotoPerson":
        return PhotoPerson.classType;
      default:
        throw Exception("Failed to find model in model provider for model name: " + modelName);
    }
  }
}

// Alias for backward compatibility with Amplify codegen
class AmplifyModelProvider extends ModelProvider {
  static final AmplifyModelProvider _instance = AmplifyModelProvider._();
  AmplifyModelProvider._();
  static AmplifyModelProvider get instance => _instance;
}
