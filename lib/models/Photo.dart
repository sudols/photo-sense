// NOTE: This file is generated and may not follow lint rules defined in your app

// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, dead_codepublic_member_api_docs, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'ModelProvider.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:collection/collection.dart';


/** This is an auto generated class representing the Photo type in your schema. */
class Photo extends amplify_core.Model {
  static const classType = const _PhotoModelType();
  final String id;
  final String? _s3Key;
  final List<String>? _faceIds;
  final List<String>? _detectedFaces;
  final List<String>? _detectedText;
  final int? _facesCount;
  final amplify_core.TemporalDateTime? _analyzedAt;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  PhotoModelIdentifier get modelIdentifier {
      return PhotoModelIdentifier(
        id: id
      );
  }
  
  String get s3Key {
    try {
      return _s3Key!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  List<String>? get faceIds {
    return _faceIds;
  }
  
  List<String>? get detectedFaces {
    return _detectedFaces;
  }
  
  List<String>? get detectedText {
    return _detectedText;
  }
  
  int? get facesCount {
    return _facesCount;
  }
  
  amplify_core.TemporalDateTime? get analyzedAt {
    return _analyzedAt;
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const Photo._internal({required this.id, required s3Key, faceIds, detectedFaces, detectedText, facesCount, analyzedAt, createdAt, updatedAt}): _s3Key = s3Key, _faceIds = faceIds, _detectedFaces = detectedFaces, _detectedText = detectedText, _facesCount = facesCount, _analyzedAt = analyzedAt, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory Photo({String? id, required String s3Key, List<String>? faceIds, List<String>? detectedFaces, List<String>? detectedText, int? facesCount, amplify_core.TemporalDateTime? analyzedAt}) {
    return Photo._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      s3Key: s3Key,
      faceIds: faceIds != null ? List<String>.unmodifiable(faceIds) : faceIds,
      detectedFaces: detectedFaces != null ? List<String>.unmodifiable(detectedFaces) : detectedFaces,
      detectedText: detectedText != null ? List<String>.unmodifiable(detectedText) : detectedText,
      facesCount: facesCount,
      analyzedAt: analyzedAt);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Photo &&
      id == other.id &&
      _s3Key == other._s3Key &&
      DeepCollectionEquality().equals(_faceIds, other._faceIds) &&
      DeepCollectionEquality().equals(_detectedFaces, other._detectedFaces) &&
      DeepCollectionEquality().equals(_detectedText, other._detectedText) &&
      _facesCount == other._facesCount &&
      _analyzedAt == other._analyzedAt;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Photo {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("s3Key=" + "$_s3Key" + ", ");
    buffer.write("faceIds=" + (_faceIds != null ? _faceIds.toString() : "null") + ", ");
    buffer.write("detectedFaces=" + (_detectedFaces != null ? _detectedFaces.toString() : "null") + ", ");
    buffer.write("detectedText=" + (_detectedText != null ? _detectedText.toString() : "null") + ", ");
    buffer.write("facesCount=" + (_facesCount != null ? _facesCount.toString() : "null") + ", ");
    buffer.write("analyzedAt=" + (_analyzedAt != null ? _analyzedAt!.format() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Photo copyWith({String? s3Key, List<String>? faceIds, List<String>? detectedFaces, List<String>? detectedText, int? facesCount, amplify_core.TemporalDateTime? analyzedAt}) {
    return Photo._internal(
      id: id,
      s3Key: s3Key ?? this.s3Key,
      faceIds: faceIds ?? this.faceIds,
      detectedFaces: detectedFaces ?? this.detectedFaces,
      detectedText: detectedText ?? this.detectedText,
      facesCount: facesCount ?? this.facesCount,
      analyzedAt: analyzedAt ?? this.analyzedAt);
  }
  
  Photo.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _s3Key = json['s3Key'],
      _faceIds = json['faceIds']?.cast<String>(),
      _detectedFaces = json['detectedFaces']?.cast<String>(),
      _detectedText = json['detectedText']?.cast<String>(),
      _facesCount = (json['facesCount'] as num?)?.toInt(),
      _analyzedAt = json['analyzedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['analyzedAt']) : null,
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 's3Key': _s3Key, 'faceIds': _faceIds, 'detectedFaces': _detectedFaces, 'detectedText': _detectedText, 'facesCount': _facesCount, 'analyzedAt': _analyzedAt?.format(), 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    's3Key': _s3Key,
    'faceIds': _faceIds,
    'detectedFaces': _detectedFaces,
    'detectedText': _detectedText,
    'facesCount': _facesCount,
    'analyzedAt': _analyzedAt,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<PhotoModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<PhotoModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final S3KEY = amplify_core.QueryField(fieldName: "s3Key");
  static final FACEIDS = amplify_core.QueryField(fieldName: "faceIds");
  static final DETECTEDFACES = amplify_core.QueryField(fieldName: "detectedFaces");
  static final DETECTEDTEXT = amplify_core.QueryField(fieldName: "detectedText");
  static final FACESCOUNT = amplify_core.QueryField(fieldName: "facesCount");
  static final ANALYZEDAT = amplify_core.QueryField(fieldName: "analyzedAt");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Photo";
    modelSchemaDefinition.pluralName = "Photos";
    
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
      key: Photo.S3KEY,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Photo.FACEIDS,
      isRequired: false,
      isArray: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.collection, ofModelName: amplify_core.ModelFieldTypeEnum.string.name)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Photo.DETECTEDFACES,
      isRequired: false,
      isArray: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.collection, ofModelName: amplify_core.ModelFieldTypeEnum.string.name)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Photo.DETECTEDTEXT,
      isRequired: false,
      isArray: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.collection, ofModelName: amplify_core.ModelFieldTypeEnum.string.name)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Photo.FACESCOUNT,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Photo.ANALYZEDAT,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'createdAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
  });
}

class _PhotoModelType extends amplify_core.ModelType<Photo> {
  const _PhotoModelType();
  
  @override
  Photo fromJson(Map<String, dynamic> jsonData) {
    return Photo.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Photo';
  }
}

class PhotoModelIdentifier implements amplify_core.ModelIdentifier<Photo> {
  final String id;

  const PhotoModelIdentifier({
    required this.id});
  
  @override
  Map<String, dynamic> serializeAsMap() => (<String, dynamic>{
    'id': id
  });
  
  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap()
    .entries
    .map((entry) => (<String, dynamic>{ entry.key: entry.value }))
    .toList();
  
  @override
  String serializeAsString() => serializeAsMap().values.join('#');
  
  @override
  String toString() => 'PhotoModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is PhotoModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}
