// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'ModelProvider.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

class PhotoPerson extends amplify_core.Model {
  static const classType = const _PhotoPersonModelType();
  final String id;
  final String? _photoId;
  final String? _personId;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;

  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;

  PhotoPersonModelIdentifier get modelIdentifier {
    return PhotoPersonModelIdentifier(id: id);
  }

  String get photoId {
    try {
      return _photoId!;
    } catch (e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion: amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString());
    }
  }

  String get personId {
    try {
      return _personId!;
    } catch (e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion: amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString());
    }
  }

  amplify_core.TemporalDateTime? get createdAt => _createdAt;
  amplify_core.TemporalDateTime? get updatedAt => _updatedAt;

  const PhotoPerson._internal({required this.id, required photoId, required personId, createdAt, updatedAt})
      : _photoId = photoId,
        _personId = personId,
        _createdAt = createdAt,
        _updatedAt = updatedAt;

  factory PhotoPerson({String? id, required String photoId, required String personId}) {
    return PhotoPerson._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      photoId: photoId,
      personId: personId,
    );
  }

  bool equals(Object other) => this == other;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PhotoPerson && id == other.id && _photoId == other._photoId && _personId == other._personId;
  }

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.write("PhotoPerson {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("photoId=" + "$_photoId" + ", ");
    buffer.write("personId=" + "$_personId" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    return buffer.toString();
  }

  PhotoPerson copyWith({String? photoId, String? personId}) {
    return PhotoPerson._internal(
      id: id,
      photoId: photoId ?? this.photoId,
      personId: personId ?? this.personId,
    );
  }

  PhotoPerson.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        _photoId = json['photoId'],
        _personId = json['personId'],
        _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
        _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'photoId': _photoId,
        'personId': _personId,
        'createdAt': _createdAt?.format(),
        'updatedAt': _updatedAt?.format(),
      };

  Map<String, Object?> toMap() => {
        'id': id,
        'photoId': _photoId,
        'personId': _personId,
        'createdAt': _createdAt,
        'updatedAt': _updatedAt,
      };

  static final amplify_core.QueryModelIdentifier<PhotoPersonModelIdentifier> MODEL_IDENTIFIER =
      amplify_core.QueryModelIdentifier<PhotoPersonModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final PHOTOID = amplify_core.QueryField(fieldName: "photoId");
  static final PERSONID = amplify_core.QueryField(fieldName: "personId");

  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "PhotoPerson";
    modelSchemaDefinition.pluralName = "PhotoPeople";

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
        key: PhotoPerson.PHOTOID, isRequired: true, ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
        key: PhotoPerson.PERSONID, isRequired: true, ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
        fieldName: 'createdAt', isRequired: false, isReadOnly: true, ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
        fieldName: 'updatedAt', isRequired: false, isReadOnly: true, ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)));
  });
}

class _PhotoPersonModelType extends amplify_core.ModelType<PhotoPerson> {
  const _PhotoPersonModelType();

  @override
  PhotoPerson fromJson(Map<String, dynamic> jsonData) => PhotoPerson.fromJson(jsonData);

  @override
  String modelName() => 'PhotoPerson';
}

class PhotoPersonModelIdentifier implements amplify_core.ModelIdentifier<PhotoPerson> {
  final String id;

  const PhotoPersonModelIdentifier({required this.id});

  @override
  Map<String, dynamic> serializeAsMap() => {'id': id};

  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap().entries.map((entry) => {entry.key: entry.value}).toList();

  @override
  String serializeAsString() => serializeAsMap().values.join('#');

  @override
  String toString() => 'PhotoPersonModelIdentifier(id: $id)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhotoPersonModelIdentifier && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
