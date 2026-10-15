// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_job.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetOperationJobCollection on Isar {
  IsarCollection<OperationJob> get operationJobs => this.collection();
}

const OperationJobSchema = CollectionSchema(
  name: r'OperationJob',
  id: -4503300166057972159,
  properties: {
    r'completedAt': PropertySchema(
      id: 0,
      name: r'completedAt',
      type: IsarType.dateTime,
    ),
    r'completedItems': PropertySchema(
      id: 1,
      name: r'completedItems',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'currentItemName': PropertySchema(
      id: 3,
      name: r'currentItemName',
      type: IsarType.string,
    ),
    r'destinationDescriptor': PropertySchema(
      id: 4,
      name: r'destinationDescriptor',
      type: IsarType.string,
    ),
    r'failureCode': PropertySchema(
      id: 5,
      name: r'failureCode',
      type: IsarType.string,
    ),
    r'processedBytes': PropertySchema(
      id: 6,
      name: r'processedBytes',
      type: IsarType.long,
    ),
    r'resumeData': PropertySchema(
      id: 7,
      name: r'resumeData',
      type: IsarType.string,
    ),
    r'retryCount': PropertySchema(
      id: 8,
      name: r'retryCount',
      type: IsarType.long,
    ),
    r'sourceDescriptor': PropertySchema(
      id: 9,
      name: r'sourceDescriptor',
      type: IsarType.string,
    ),
    r'startedAt': PropertySchema(
      id: 10,
      name: r'startedAt',
      type: IsarType.dateTime,
    ),
    r'state': PropertySchema(
      id: 11,
      name: r'state',
      type: IsarType.byte,
      enumMap: _OperationJobstateEnumValueMap,
    ),
    r'totalBytes': PropertySchema(
      id: 12,
      name: r'totalBytes',
      type: IsarType.long,
    ),
    r'totalItems': PropertySchema(
      id: 13,
      name: r'totalItems',
      type: IsarType.long,
    ),
    r'type': PropertySchema(
      id: 14,
      name: r'type',
      type: IsarType.byte,
      enumMap: _OperationJobtypeEnumValueMap,
    )
  },
  estimateSize: _operationJobEstimateSize,
  serialize: _operationJobSerialize,
  deserialize: _operationJobDeserialize,
  deserializeProp: _operationJobDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _operationJobGetId,
  getLinks: _operationJobGetLinks,
  attach: _operationJobAttach,
  version: '3.1.0+1',
);

int _operationJobEstimateSize(
  OperationJob object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.currentItemName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.destinationDescriptor;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.failureCode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.resumeData;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.sourceDescriptor;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _operationJobSerialize(
  OperationJob object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.completedAt);
  writer.writeLong(offsets[1], object.completedItems);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeString(offsets[3], object.currentItemName);
  writer.writeString(offsets[4], object.destinationDescriptor);
  writer.writeString(offsets[5], object.failureCode);
  writer.writeLong(offsets[6], object.processedBytes);
  writer.writeString(offsets[7], object.resumeData);
  writer.writeLong(offsets[8], object.retryCount);
  writer.writeString(offsets[9], object.sourceDescriptor);
  writer.writeDateTime(offsets[10], object.startedAt);
  writer.writeByte(offsets[11], object.state.index);
  writer.writeLong(offsets[12], object.totalBytes);
  writer.writeLong(offsets[13], object.totalItems);
  writer.writeByte(offsets[14], object.type.index);
}

OperationJob _operationJobDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = OperationJob();
  object.completedAt = reader.readDateTimeOrNull(offsets[0]);
  object.completedItems = reader.readLong(offsets[1]);
  object.createdAt = reader.readDateTime(offsets[2]);
  object.currentItemName = reader.readStringOrNull(offsets[3]);
  object.destinationDescriptor = reader.readStringOrNull(offsets[4]);
  object.failureCode = reader.readStringOrNull(offsets[5]);
  object.id = id;
  object.processedBytes = reader.readLong(offsets[6]);
  object.resumeData = reader.readStringOrNull(offsets[7]);
  object.retryCount = reader.readLong(offsets[8]);
  object.sourceDescriptor = reader.readStringOrNull(offsets[9]);
  object.startedAt = reader.readDateTimeOrNull(offsets[10]);
  object.state =
      _OperationJobstateValueEnumMap[reader.readByteOrNull(offsets[11])] ??
          JobState.queued;
  object.totalBytes = reader.readLong(offsets[12]);
  object.totalItems = reader.readLong(offsets[13]);
  object.type =
      _OperationJobtypeValueEnumMap[reader.readByteOrNull(offsets[14])] ??
          JobType.import;
  return object;
}

P _operationJobDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 11:
      return (_OperationJobstateValueEnumMap[reader.readByteOrNull(offset)] ??
          JobState.queued) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (reader.readLong(offset)) as P;
    case 14:
      return (_OperationJobtypeValueEnumMap[reader.readByteOrNull(offset)] ??
          JobType.import) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _OperationJobstateEnumValueMap = {
  'queued': 0,
  'running': 1,
  'pausing': 2,
  'paused': 3,
  'cancelling': 4,
  'cancelled': 5,
  'completed': 6,
  'failed': 7,
  'interrupted': 8,
};
const _OperationJobstateValueEnumMap = {
  0: JobState.queued,
  1: JobState.running,
  2: JobState.pausing,
  3: JobState.paused,
  4: JobState.cancelling,
  5: JobState.cancelled,
  6: JobState.completed,
  7: JobState.failed,
  8: JobState.interrupted,
};
const _OperationJobtypeEnumValueMap = {
  'import': 0,
  'export': 1,
  'decryptForViewer': 2,
  'migrateEncryption': 3,
};
const _OperationJobtypeValueEnumMap = {
  0: JobType.import,
  1: JobType.export,
  2: JobType.decryptForViewer,
  3: JobType.migrateEncryption,
};

Id _operationJobGetId(OperationJob object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _operationJobGetLinks(OperationJob object) {
  return [];
}

void _operationJobAttach(
    IsarCollection<dynamic> col, Id id, OperationJob object) {
  object.id = id;
}

extension OperationJobQueryWhereSort
    on QueryBuilder<OperationJob, OperationJob, QWhere> {
  QueryBuilder<OperationJob, OperationJob, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension OperationJobQueryWhere
    on QueryBuilder<OperationJob, OperationJob, QWhereClause> {
  QueryBuilder<OperationJob, OperationJob, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<OperationJob, OperationJob, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterWhereClause> idBetween(
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
}

extension OperationJobQueryFilter
    on QueryBuilder<OperationJob, OperationJob, QFilterCondition> {
  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      completedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedAt',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      completedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedAt',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      completedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      completedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      completedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      completedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      completedItemsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedItems',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      completedItemsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedItems',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      completedItemsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedItems',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      completedItemsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedItems',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
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

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      createdAtLessThan(
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

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      createdAtBetween(
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

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'currentItemName',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'currentItemName',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'currentItemName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'currentItemName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'currentItemName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'currentItemName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'currentItemName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'currentItemName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'currentItemName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'currentItemName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'currentItemName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      currentItemNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'currentItemName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'destinationDescriptor',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'destinationDescriptor',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'destinationDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'destinationDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'destinationDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'destinationDescriptor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'destinationDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'destinationDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'destinationDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'destinationDescriptor',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'destinationDescriptor',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      destinationDescriptorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'destinationDescriptor',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'failureCode',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'failureCode',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'failureCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'failureCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'failureCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'failureCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'failureCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'failureCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'failureCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'failureCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'failureCode',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      failureCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'failureCode',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition> idBetween(
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

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      processedBytesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'processedBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      processedBytesGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'processedBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      processedBytesLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'processedBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      processedBytesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'processedBytes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resumeData',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resumeData',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resumeData',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resumeData',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resumeData',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resumeData',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resumeData',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resumeData',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resumeData',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resumeData',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resumeData',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      resumeDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resumeData',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      retryCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retryCount',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      retryCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retryCount',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      retryCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retryCount',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      retryCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retryCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sourceDescriptor',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sourceDescriptor',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceDescriptor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceDescriptor',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceDescriptor',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceDescriptor',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      sourceDescriptorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceDescriptor',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      startedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'startedAt',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      startedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'startedAt',
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      startedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      startedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'startedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      startedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'startedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      startedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'startedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition> stateEqualTo(
      JobState value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'state',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      stateGreaterThan(
    JobState value, {
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

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition> stateLessThan(
    JobState value, {
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

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition> stateBetween(
    JobState lower,
    JobState upper, {
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

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      totalBytesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      totalBytesGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      totalBytesLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      totalBytesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalBytes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      totalItemsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalItems',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      totalItemsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalItems',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      totalItemsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalItems',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      totalItemsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalItems',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition> typeEqualTo(
      JobType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition>
      typeGreaterThan(
    JobType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition> typeLessThan(
    JobType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterFilterCondition> typeBetween(
    JobType lower,
    JobType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'type',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension OperationJobQueryObject
    on QueryBuilder<OperationJob, OperationJob, QFilterCondition> {}

extension OperationJobQueryLinks
    on QueryBuilder<OperationJob, OperationJob, QFilterCondition> {}

extension OperationJobQuerySortBy
    on QueryBuilder<OperationJob, OperationJob, QSortBy> {
  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByCompletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByCompletedItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedItems', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByCompletedItemsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedItems', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByCurrentItemName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentItemName', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByCurrentItemNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentItemName', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByDestinationDescriptor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'destinationDescriptor', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByDestinationDescriptorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'destinationDescriptor', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByFailureCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureCode', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByFailureCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureCode', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByProcessedBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processedBytes', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByProcessedBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processedBytes', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByResumeData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resumeData', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByResumeDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resumeData', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortBySourceDescriptor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDescriptor', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortBySourceDescriptorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDescriptor', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByStartedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByTotalBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalBytes', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByTotalBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalBytes', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByTotalItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalItems', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      sortByTotalItemsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalItems', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension OperationJobQuerySortThenBy
    on QueryBuilder<OperationJob, OperationJob, QSortThenBy> {
  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByCompletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByCompletedItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedItems', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByCompletedItemsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedItems', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByCurrentItemName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentItemName', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByCurrentItemNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentItemName', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByDestinationDescriptor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'destinationDescriptor', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByDestinationDescriptorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'destinationDescriptor', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByFailureCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureCode', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByFailureCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureCode', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByProcessedBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processedBytes', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByProcessedBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processedBytes', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByResumeData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resumeData', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByResumeDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resumeData', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenBySourceDescriptor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDescriptor', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenBySourceDescriptorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDescriptor', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByStartedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByTotalBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalBytes', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByTotalBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalBytes', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByTotalItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalItems', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy>
      thenByTotalItemsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalItems', Sort.desc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension OperationJobQueryWhereDistinct
    on QueryBuilder<OperationJob, OperationJob, QDistinct> {
  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedAt');
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct>
      distinctByCompletedItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedItems');
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByCurrentItemName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'currentItemName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct>
      distinctByDestinationDescriptor({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'destinationDescriptor',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByFailureCode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'failureCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct>
      distinctByProcessedBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'processedBytes');
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByResumeData(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resumeData', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retryCount');
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct>
      distinctBySourceDescriptor({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceDescriptor',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startedAt');
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state');
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByTotalBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalBytes');
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByTotalItems() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalItems');
    });
  }

  QueryBuilder<OperationJob, OperationJob, QDistinct> distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }
}

extension OperationJobQueryProperty
    on QueryBuilder<OperationJob, OperationJob, QQueryProperty> {
  QueryBuilder<OperationJob, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<OperationJob, DateTime?, QQueryOperations>
      completedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedAt');
    });
  }

  QueryBuilder<OperationJob, int, QQueryOperations> completedItemsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedItems');
    });
  }

  QueryBuilder<OperationJob, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<OperationJob, String?, QQueryOperations>
      currentItemNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'currentItemName');
    });
  }

  QueryBuilder<OperationJob, String?, QQueryOperations>
      destinationDescriptorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'destinationDescriptor');
    });
  }

  QueryBuilder<OperationJob, String?, QQueryOperations> failureCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'failureCode');
    });
  }

  QueryBuilder<OperationJob, int, QQueryOperations> processedBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'processedBytes');
    });
  }

  QueryBuilder<OperationJob, String?, QQueryOperations> resumeDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resumeData');
    });
  }

  QueryBuilder<OperationJob, int, QQueryOperations> retryCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retryCount');
    });
  }

  QueryBuilder<OperationJob, String?, QQueryOperations>
      sourceDescriptorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceDescriptor');
    });
  }

  QueryBuilder<OperationJob, DateTime?, QQueryOperations> startedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startedAt');
    });
  }

  QueryBuilder<OperationJob, JobState, QQueryOperations> stateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state');
    });
  }

  QueryBuilder<OperationJob, int, QQueryOperations> totalBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalBytes');
    });
  }

  QueryBuilder<OperationJob, int, QQueryOperations> totalItemsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalItems');
    });
  }

  QueryBuilder<OperationJob, JobType, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }
}
