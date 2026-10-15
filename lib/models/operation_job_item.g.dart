// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_job_item.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetOperationJobItemCollection on Isar {
  IsarCollection<OperationJobItem> get operationJobItems => this.collection();
}

const OperationJobItemSchema = CollectionSchema(
  name: r'OperationJobItem',
  id: 4071966786488884479,
  properties: {
    r'blobId': PropertySchema(
      id: 0,
      name: r'blobId',
      type: IsarType.string,
    ),
    r'failureReason': PropertySchema(
      id: 1,
      name: r'failureReason',
      type: IsarType.string,
    ),
    r'jobId': PropertySchema(
      id: 2,
      name: r'jobId',
      type: IsarType.long,
    ),
    r'partialBlobPath': PropertySchema(
      id: 3,
      name: r'partialBlobPath',
      type: IsarType.string,
    ),
    r'sourcePath': PropertySchema(
      id: 4,
      name: r'sourcePath',
      type: IsarType.string,
    ),
    r'sourceSizeBytes': PropertySchema(
      id: 5,
      name: r'sourceSizeBytes',
      type: IsarType.long,
    ),
    r'state': PropertySchema(
      id: 6,
      name: r'state',
      type: IsarType.byte,
      enumMap: _OperationJobItemstateEnumValueMap,
    )
  },
  estimateSize: _operationJobItemEstimateSize,
  serialize: _operationJobItemSerialize,
  deserialize: _operationJobItemDeserialize,
  deserializeProp: _operationJobItemDeserializeProp,
  idName: r'id',
  indexes: {
    r'jobId': IndexSchema(
      id: 7916160552736803877,
      name: r'jobId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'jobId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _operationJobItemGetId,
  getLinks: _operationJobItemGetLinks,
  attach: _operationJobItemAttach,
  version: '3.1.0+1',
);

int _operationJobItemEstimateSize(
  OperationJobItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.blobId.length * 3;
  {
    final value = object.failureReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.partialBlobPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sourcePath.length * 3;
  return bytesCount;
}

void _operationJobItemSerialize(
  OperationJobItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.blobId);
  writer.writeString(offsets[1], object.failureReason);
  writer.writeLong(offsets[2], object.jobId);
  writer.writeString(offsets[3], object.partialBlobPath);
  writer.writeString(offsets[4], object.sourcePath);
  writer.writeLong(offsets[5], object.sourceSizeBytes);
  writer.writeByte(offsets[6], object.state.index);
}

OperationJobItem _operationJobItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = OperationJobItem();
  object.blobId = reader.readString(offsets[0]);
  object.failureReason = reader.readStringOrNull(offsets[1]);
  object.id = id;
  object.jobId = reader.readLong(offsets[2]);
  object.partialBlobPath = reader.readStringOrNull(offsets[3]);
  object.sourcePath = reader.readString(offsets[4]);
  object.sourceSizeBytes = reader.readLong(offsets[5]);
  object.state =
      _OperationJobItemstateValueEnumMap[reader.readByteOrNull(offsets[6])] ??
          JobItemState.pending;
  return object;
}

P _operationJobItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (_OperationJobItemstateValueEnumMap[
              reader.readByteOrNull(offset)] ??
          JobItemState.pending) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _OperationJobItemstateEnumValueMap = {
  'pending': 0,
  'running': 1,
  'completed': 2,
  'failed': 3,
  'skipped': 4,
};
const _OperationJobItemstateValueEnumMap = {
  0: JobItemState.pending,
  1: JobItemState.running,
  2: JobItemState.completed,
  3: JobItemState.failed,
  4: JobItemState.skipped,
};

Id _operationJobItemGetId(OperationJobItem object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _operationJobItemGetLinks(OperationJobItem object) {
  return [];
}

void _operationJobItemAttach(
    IsarCollection<dynamic> col, Id id, OperationJobItem object) {
  object.id = id;
}

extension OperationJobItemQueryWhereSort
    on QueryBuilder<OperationJobItem, OperationJobItem, QWhere> {
  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhere> anyJobId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'jobId'),
      );
    });
  }
}

extension OperationJobItemQueryWhere
    on QueryBuilder<OperationJobItem, OperationJobItem, QWhereClause> {
  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhereClause>
      idNotEqualTo(Id id) {
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

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhereClause> idBetween(
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

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhereClause>
      jobIdEqualTo(int jobId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobId',
        value: [jobId],
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhereClause>
      jobIdNotEqualTo(int jobId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobId',
              lower: [],
              upper: [jobId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobId',
              lower: [jobId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobId',
              lower: [jobId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobId',
              lower: [],
              upper: [jobId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhereClause>
      jobIdGreaterThan(
    int jobId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobId',
        lower: [jobId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhereClause>
      jobIdLessThan(
    int jobId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobId',
        lower: [],
        upper: [jobId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterWhereClause>
      jobIdBetween(
    int lowerJobId,
    int upperJobId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobId',
        lower: [lowerJobId],
        includeLower: includeLower,
        upper: [upperJobId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension OperationJobItemQueryFilter
    on QueryBuilder<OperationJobItem, OperationJobItem, QFilterCondition> {
  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      blobIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'blobId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      blobIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'blobId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      blobIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'blobId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      blobIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'blobId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      blobIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'blobId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      blobIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'blobId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      blobIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'blobId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      blobIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'blobId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      blobIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'blobId',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      blobIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'blobId',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'failureReason',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'failureReason',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'failureReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'failureReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'failureReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'failureReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'failureReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'failureReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'failureReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'failureReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'failureReason',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      failureReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'failureReason',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      idGreaterThan(
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

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      idLessThan(
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

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      jobIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobId',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      jobIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'jobId',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      jobIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'jobId',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      jobIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'jobId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'partialBlobPath',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'partialBlobPath',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'partialBlobPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'partialBlobPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'partialBlobPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'partialBlobPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'partialBlobPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'partialBlobPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'partialBlobPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'partialBlobPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'partialBlobPath',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      partialBlobPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'partialBlobPath',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourcePathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourcePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourcePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourcePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourcePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourcePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourcePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourcePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourcePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourcePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourcePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourcePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourcePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourcePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourcePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourcePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourcePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourcePath',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourcePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourcePath',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourceSizeBytesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceSizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourceSizeBytesGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceSizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourceSizeBytesLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceSizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      sourceSizeBytesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceSizeBytes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      stateEqualTo(JobItemState value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'state',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      stateGreaterThan(
    JobItemState value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'state',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      stateLessThan(
    JobItemState value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'state',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterFilterCondition>
      stateBetween(
    JobItemState lower,
    JobItemState upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'state',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension OperationJobItemQueryObject
    on QueryBuilder<OperationJobItem, OperationJobItem, QFilterCondition> {}

extension OperationJobItemQueryLinks
    on QueryBuilder<OperationJobItem, OperationJobItem, QFilterCondition> {}

extension OperationJobItemQuerySortBy
    on QueryBuilder<OperationJobItem, OperationJobItem, QSortBy> {
  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortByBlobId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blobId', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortByBlobIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blobId', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortByFailureReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureReason', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortByFailureReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureReason', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy> sortByJobId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobId', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortByJobIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobId', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortByPartialBlobPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'partialBlobPath', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortByPartialBlobPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'partialBlobPath', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortBySourcePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourcePath', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortBySourcePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourcePath', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortBySourceSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSizeBytes', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortBySourceSizeBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSizeBytes', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy> sortByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      sortByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }
}

extension OperationJobItemQuerySortThenBy
    on QueryBuilder<OperationJobItem, OperationJobItem, QSortThenBy> {
  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenByBlobId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blobId', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenByBlobIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blobId', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenByFailureReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureReason', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenByFailureReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureReason', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy> thenByJobId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobId', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenByJobIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobId', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenByPartialBlobPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'partialBlobPath', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenByPartialBlobPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'partialBlobPath', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenBySourcePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourcePath', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenBySourcePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourcePath', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenBySourceSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSizeBytes', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenBySourceSizeBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSizeBytes', Sort.desc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy> thenByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QAfterSortBy>
      thenByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }
}

extension OperationJobItemQueryWhereDistinct
    on QueryBuilder<OperationJobItem, OperationJobItem, QDistinct> {
  QueryBuilder<OperationJobItem, OperationJobItem, QDistinct> distinctByBlobId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'blobId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QDistinct>
      distinctByFailureReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'failureReason',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QDistinct>
      distinctByJobId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jobId');
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QDistinct>
      distinctByPartialBlobPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'partialBlobPath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QDistinct>
      distinctBySourcePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourcePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QDistinct>
      distinctBySourceSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceSizeBytes');
    });
  }

  QueryBuilder<OperationJobItem, OperationJobItem, QDistinct>
      distinctByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state');
    });
  }
}

extension OperationJobItemQueryProperty
    on QueryBuilder<OperationJobItem, OperationJobItem, QQueryProperty> {
  QueryBuilder<OperationJobItem, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<OperationJobItem, String, QQueryOperations> blobIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'blobId');
    });
  }

  QueryBuilder<OperationJobItem, String?, QQueryOperations>
      failureReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'failureReason');
    });
  }

  QueryBuilder<OperationJobItem, int, QQueryOperations> jobIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jobId');
    });
  }

  QueryBuilder<OperationJobItem, String?, QQueryOperations>
      partialBlobPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'partialBlobPath');
    });
  }

  QueryBuilder<OperationJobItem, String, QQueryOperations>
      sourcePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourcePath');
    });
  }

  QueryBuilder<OperationJobItem, int, QQueryOperations>
      sourceSizeBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceSizeBytes');
    });
  }

  QueryBuilder<OperationJobItem, JobItemState, QQueryOperations>
      stateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state');
    });
  }
}
