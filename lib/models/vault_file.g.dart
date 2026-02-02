// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_file.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetVaultFileCollection on Isar {
  IsarCollection<VaultFile> get vaultFiles => this.collection();
}

const VaultFileSchema = CollectionSchema(
  name: r'VaultFile',
  id: 4510497847748537902,
  properties: {
    r'byteSize': PropertySchema(
      id: 0,
      name: r'byteSize',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'ivBase64': PropertySchema(
      id: 2,
      name: r'ivBase64',
      type: IsarType.string,
    ),
    r'mimeType': PropertySchema(
      id: 3,
      name: r'mimeType',
      type: IsarType.string,
    ),
    r'originalName': PropertySchema(
      id: 4,
      name: r'originalName',
      type: IsarType.string,
    ),
    r'parentFolderId': PropertySchema(
      id: 5,
      name: r'parentFolderId',
      type: IsarType.long,
    ),
    r'storedBlobName': PropertySchema(
      id: 6,
      name: r'storedBlobName',
      type: IsarType.string,
    )
  },
  estimateSize: _vaultFileEstimateSize,
  serialize: _vaultFileSerialize,
  deserialize: _vaultFileDeserialize,
  deserializeProp: _vaultFileDeserializeProp,
  idName: r'id',
  indexes: {
    r'parentFolderId': IndexSchema(
      id: -8947968903566032810,
      name: r'parentFolderId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'parentFolderId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _vaultFileGetId,
  getLinks: _vaultFileGetLinks,
  attach: _vaultFileAttach,
  version: '3.1.0+1',
);

int _vaultFileEstimateSize(
  VaultFile object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.ivBase64.length * 3;
  {
    final value = object.mimeType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.originalName.length * 3;
  bytesCount += 3 + object.storedBlobName.length * 3;
  return bytesCount;
}

void _vaultFileSerialize(
  VaultFile object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.byteSize);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.ivBase64);
  writer.writeString(offsets[3], object.mimeType);
  writer.writeString(offsets[4], object.originalName);
  writer.writeLong(offsets[5], object.parentFolderId);
  writer.writeString(offsets[6], object.storedBlobName);
}

VaultFile _vaultFileDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = VaultFile();
  object.byteSize = reader.readLong(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.id = id;
  object.ivBase64 = reader.readString(offsets[2]);
  object.mimeType = reader.readStringOrNull(offsets[3]);
  object.originalName = reader.readString(offsets[4]);
  object.parentFolderId = reader.readLongOrNull(offsets[5]);
  object.storedBlobName = reader.readString(offsets[6]);
  return object;
}

P _vaultFileDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _vaultFileGetId(VaultFile object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _vaultFileGetLinks(VaultFile object) {
  return [];
}

void _vaultFileAttach(IsarCollection<dynamic> col, Id id, VaultFile object) {
  object.id = id;
}

extension VaultFileQueryWhereSort
    on QueryBuilder<VaultFile, VaultFile, QWhere> {
  QueryBuilder<VaultFile, VaultFile, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhere> anyParentFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'parentFolderId'),
      );
    });
  }
}

extension VaultFileQueryWhere
    on QueryBuilder<VaultFile, VaultFile, QWhereClause> {
  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause> parentFolderIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'parentFolderId',
        value: [null],
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause>
      parentFolderIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'parentFolderId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause> parentFolderIdEqualTo(
      int? parentFolderId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'parentFolderId',
        value: [parentFolderId],
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause>
      parentFolderIdNotEqualTo(int? parentFolderId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'parentFolderId',
              lower: [],
              upper: [parentFolderId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'parentFolderId',
              lower: [parentFolderId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'parentFolderId',
              lower: [parentFolderId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'parentFolderId',
              lower: [],
              upper: [parentFolderId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause>
      parentFolderIdGreaterThan(
    int? parentFolderId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'parentFolderId',
        lower: [parentFolderId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause> parentFolderIdLessThan(
    int? parentFolderId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'parentFolderId',
        lower: [],
        upper: [parentFolderId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterWhereClause> parentFolderIdBetween(
    int? lowerParentFolderId,
    int? upperParentFolderId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'parentFolderId',
        lower: [lowerParentFolderId],
        includeLower: includeLower,
        upper: [upperParentFolderId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension VaultFileQueryFilter
    on QueryBuilder<VaultFile, VaultFile, QFilterCondition> {
  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> byteSizeEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'byteSize',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> byteSizeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'byteSize',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> byteSizeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'byteSize',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> byteSizeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'byteSize',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> ivBase64EqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ivBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> ivBase64GreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ivBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> ivBase64LessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ivBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> ivBase64Between(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ivBase64',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> ivBase64StartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ivBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> ivBase64EndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ivBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> ivBase64Contains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ivBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> ivBase64Matches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ivBase64',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> ivBase64IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ivBase64',
        value: '',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      ivBase64IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ivBase64',
        value: '',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> mimeTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'mimeType',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      mimeTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'mimeType',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> mimeTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> mimeTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> mimeTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> mimeTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mimeType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> mimeTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> mimeTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> mimeTypeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mimeType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> mimeTypeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mimeType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> mimeTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mimeType',
        value: '',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      mimeTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mimeType',
        value: '',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> originalNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originalName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      originalNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'originalName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      originalNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'originalName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> originalNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'originalName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      originalNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'originalName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      originalNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'originalName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      originalNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'originalName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition> originalNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'originalName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      originalNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originalName',
        value: '',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      originalNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'originalName',
        value: '',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      parentFolderIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'parentFolderId',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      parentFolderIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'parentFolderId',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      parentFolderIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parentFolderId',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      parentFolderIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'parentFolderId',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      parentFolderIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'parentFolderId',
        value: value,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      parentFolderIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'parentFolderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      storedBlobNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storedBlobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      storedBlobNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'storedBlobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      storedBlobNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'storedBlobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      storedBlobNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'storedBlobName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      storedBlobNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'storedBlobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      storedBlobNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'storedBlobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      storedBlobNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'storedBlobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      storedBlobNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'storedBlobName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      storedBlobNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storedBlobName',
        value: '',
      ));
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterFilterCondition>
      storedBlobNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'storedBlobName',
        value: '',
      ));
    });
  }
}

extension VaultFileQueryObject
    on QueryBuilder<VaultFile, VaultFile, QFilterCondition> {}

extension VaultFileQueryLinks
    on QueryBuilder<VaultFile, VaultFile, QFilterCondition> {}

extension VaultFileQuerySortBy on QueryBuilder<VaultFile, VaultFile, QSortBy> {
  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byteSize', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByByteSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byteSize', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByIvBase64() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ivBase64', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByIvBase64Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ivBase64', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByMimeType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mimeType', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByMimeTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mimeType', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByOriginalName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalName', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByOriginalNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalName', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByParentFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentFolderId', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByParentFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentFolderId', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByStoredBlobName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storedBlobName', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> sortByStoredBlobNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storedBlobName', Sort.desc);
    });
  }
}

extension VaultFileQuerySortThenBy
    on QueryBuilder<VaultFile, VaultFile, QSortThenBy> {
  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byteSize', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByByteSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byteSize', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByIvBase64() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ivBase64', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByIvBase64Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ivBase64', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByMimeType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mimeType', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByMimeTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mimeType', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByOriginalName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalName', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByOriginalNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalName', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByParentFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentFolderId', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByParentFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentFolderId', Sort.desc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByStoredBlobName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storedBlobName', Sort.asc);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QAfterSortBy> thenByStoredBlobNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storedBlobName', Sort.desc);
    });
  }
}

extension VaultFileQueryWhereDistinct
    on QueryBuilder<VaultFile, VaultFile, QDistinct> {
  QueryBuilder<VaultFile, VaultFile, QDistinct> distinctByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'byteSize');
    });
  }

  QueryBuilder<VaultFile, VaultFile, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<VaultFile, VaultFile, QDistinct> distinctByIvBase64(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ivBase64', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QDistinct> distinctByMimeType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mimeType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QDistinct> distinctByOriginalName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originalName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<VaultFile, VaultFile, QDistinct> distinctByParentFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parentFolderId');
    });
  }

  QueryBuilder<VaultFile, VaultFile, QDistinct> distinctByStoredBlobName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'storedBlobName',
          caseSensitive: caseSensitive);
    });
  }
}

extension VaultFileQueryProperty
    on QueryBuilder<VaultFile, VaultFile, QQueryProperty> {
  QueryBuilder<VaultFile, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<VaultFile, int, QQueryOperations> byteSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'byteSize');
    });
  }

  QueryBuilder<VaultFile, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<VaultFile, String, QQueryOperations> ivBase64Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ivBase64');
    });
  }

  QueryBuilder<VaultFile, String?, QQueryOperations> mimeTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mimeType');
    });
  }

  QueryBuilder<VaultFile, String, QQueryOperations> originalNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originalName');
    });
  }

  QueryBuilder<VaultFile, int?, QQueryOperations> parentFolderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parentFolderId');
    });
  }

  QueryBuilder<VaultFile, String, QQueryOperations> storedBlobNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'storedBlobName');
    });
  }
}
