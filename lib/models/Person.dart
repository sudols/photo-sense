// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'ModelProvider.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

class Person extends amplify_core.Model {
  static const classType = const _PersonModelType();
  final String id;
  final String? _name;
  final String? _faceId;
  final List<String>? _faceIds;
  final String? _thumbnailS3Key;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;

  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;

  PersonModelIdentifier get modelIdentifier {
    return PersonModelIdentifier(id: id);
  }

  String get name {
    try {
      return _name!;
    } catch (e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion: amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString());
    }
  }

  String? get faceId => _faceId;
  List<String>? get faceIds => _faceIds;
  String? get thumbnailS3Key => _thumbnailS3Key;
  amplify_core.TemporalDateTime? get createdAt => _createdAt;
  amplify_core.TemporalDateTime? get updatedAt => _updatedAt;

  const Person._internal({required this.id, required name, faceId, faceIds, thumbnailS3Key, createdAt, updatedAt})
      : _name = name,
        _faceId = faceId,
        _faceIds = faceIds,
        _thumbnailS3Key = thumbnailS3Key,
        _createdAt = createdAt,
        _updatedAt = updatedAt;

  factory Person({String? id, required String name, String? faceId, List<String>? faceIds, String? thumbnailS3Key}) {
    return Person._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      name: name,
      faceId: faceId,
      faceIds: faceIds != null ? List<String>.unmodifiable(faceIds) : faceIds,
      thumbnailS3Key: thumbnailS3Key,
    );
  }

  bool equals(Object other) => this == other;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Person &&
        id == other.id &&
        _name == other._name &&
        _faceId == other._faceId &&
        _faceIds == other._faceIds &&
        _thumbnailS3Key == other._thumbnailS3Key;
  }

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.write("Person {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("name=" + "$_name" + ", ");
    buffer.write("faceId=" + "$_faceId" + ", ");
    buffer.write("faceIds=" + (_faceIds != null ? _faceIds.toString() : "null") + ", ");
    buffer.write("thumbnailS3Key=" + "$_thumbnailS3Key" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    return buffer.toString();
  }

  Person copyWith({String? name, String? faceId, List<String>? faceIds, String? thumbnailS3Key}) {
    return Person._internal(
      id: id,
      name: name ?? this.name,
      faceId: faceId ?? this.faceId,
      faceIds: faceIds ?? this.faceIds,
      thumbnailS3Key: thumbnailS3Key ?? this.thumbnailS3Key,
    );
  }

  Person.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        _name = json['name'],
        _faceId = json['faceId'],
        _faceIds = json['faceIds']?.cast<String>(),
        _thumbnailS3Key = json['thumbnailS3Key'],
        _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
        _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': _name,
        'faceId': _faceId,
        'faceIds': _faceIds,
        'thumbnailS3Key': _thumbnailS3Key,
        'createdAt': _createdAt?.format(),
        'updatedAt': _updatedAt?.format(),
      };

  Map<String, Object?> toMap() => {
        'id': id,
        'name': _name,
        'faceId': _faceId,
        'faceIds': _faceIds,
        'thumbnailS3Key': _thumbnailS3Key,
        'createdAt': _createdAt,
        'updatedAt': _updatedAt,
      };

  static final amplify_core.QueryModelIdentifier<PersonModelIdentifier> MODEL_IDENTIFIER =
      amplify_core.QueryModelIdentifier<PersonModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final NAME = amplify_core.QueryField(fieldName: "name");
  static final FACEID = amplify_core.QueryField(fieldName: "faceId");
  static final FACEIDS = amplify_core.QueryField(fieldName: "faceIds");
  static final THUMBNAILS3KEY = amplify_core.QueryField(fieldName: "thumbnailS3Key");

  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Person";
    modelSchemaDefinition.pluralName = "People";

    modelSchemaDefinition.authRules = [
      amplify_core.AuthRule(
          authStrategy: amplify_core.AuthStrategy.OWNER,
          ownerField: "owner",
          identityClaim: "cognito:username",
          provider: amplify_core.AuthRuleProvider.USERPOOLS,
          operations: const [
            amplify_core.ModelOperation.CREATE,
            amplify_core.ModelOperation.UPDATE,
            amplify_core.ModelOperation.DELETE,
            amplify_core.ModelOperation.READ
          ])
    ];

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
        key: Person.NAME, isRequired: true, ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
        key: Person.FACEID, isRequired: false, ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
        key: Person.FACEIDS, isRequired: false, isArray: true, ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
        key: Person.THUMBNAILS3KEY,
        isRequired: false,
        ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
        fieldName: 'createdAt', isRequired: false, isReadOnly: true, ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
        fieldName: 'updatedAt', isRequired: false, isReadOnly: true, ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)));
  });
}

class _PersonModelType extends amplify_core.ModelType<Person> {
  const _PersonModelType();

  @override
  Person fromJson(Map<String, dynamic> jsonData) => Person.fromJson(jsonData);

  @override
  String modelName() => 'Person';
}

class PersonModelIdentifier implements amplify_core.ModelIdentifier<Person> {
  final String id;

  const PersonModelIdentifier({required this.id});

  @override
  Map<String, dynamic> serializeAsMap() => {'id': id};

  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap().entries.map((entry) => {entry.key: entry.value}).toList();

  @override
  String serializeAsString() => serializeAsMap().values.join('#');

  @override
  String toString() => 'PersonModelIdentifier(id: $id)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PersonModelIdentifier && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
