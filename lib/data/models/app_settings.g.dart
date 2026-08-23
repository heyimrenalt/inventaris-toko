// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppSettingsCollection on Isar {
  IsarCollection<AppSettings> get appSettings => this.collection();
}

const AppSettingsSchema = CollectionSchema(
  name: r'AppSettings',
  id: -5633561779022347008,
  properties: {
    r'backupReminderFirstSeenAt': PropertySchema(
      id: 0,
      name: r'backupReminderFirstSeenAt',
      type: IsarType.dateTime,
    ),
    r'batteryOptimizationDialogDismissed': PropertySchema(
      id: 1,
      name: r'batteryOptimizationDialogDismissed',
      type: IsarType.bool,
    ),
    r'criticalStockAlertEnabled': PropertySchema(
      id: 2,
      name: r'criticalStockAlertEnabled',
      type: IsarType.bool,
    ),
    r'criticalStockAlertHour1': PropertySchema(
      id: 3,
      name: r'criticalStockAlertHour1',
      type: IsarType.long,
    ),
    r'criticalStockAlertHour2': PropertySchema(
      id: 4,
      name: r'criticalStockAlertHour2',
      type: IsarType.long,
    ),
    r'criticalStockAlertHour3': PropertySchema(
      id: 5,
      name: r'criticalStockAlertHour3',
      type: IsarType.long,
    ),
    r'criticalStockAlertMinute1': PropertySchema(
      id: 6,
      name: r'criticalStockAlertMinute1',
      type: IsarType.long,
    ),
    r'criticalStockAlertMinute2': PropertySchema(
      id: 7,
      name: r'criticalStockAlertMinute2',
      type: IsarType.long,
    ),
    r'criticalStockAlertMinute3': PropertySchema(
      id: 8,
      name: r'criticalStockAlertMinute3',
      type: IsarType.long,
    ),
    r'dailySummaryEnabled': PropertySchema(
      id: 9,
      name: r'dailySummaryEnabled',
      type: IsarType.bool,
    ),
    r'dailySummaryHour': PropertySchema(
      id: 10,
      name: r'dailySummaryHour',
      type: IsarType.long,
    ),
    r'dailySummaryMinute': PropertySchema(
      id: 11,
      name: r'dailySummaryMinute',
      type: IsarType.long,
    ),
    r'defaultMinStockThreshold': PropertySchema(
      id: 12,
      name: r'defaultMinStockThreshold',
      type: IsarType.double,
    ),
    r'lastBackupAt': PropertySchema(
      id: 13,
      name: r'lastBackupAt',
      type: IsarType.dateTime,
    ),
    r'lastBackupReminderAt': PropertySchema(
      id: 14,
      name: r'lastBackupReminderAt',
      type: IsarType.dateTime,
    ),
    r'lastExportedAt': PropertySchema(
      id: 15,
      name: r'lastExportedAt',
      type: IsarType.dateTime,
    ),
    r'lastRetentionSweepAt': PropertySchema(
      id: 16,
      name: r'lastRetentionSweepAt',
      type: IsarType.dateTime,
    ),
    r'mutationPriceSnapshotBackfillDone': PropertySchema(
      id: 17,
      name: r'mutationPriceSnapshotBackfillDone',
      type: IsarType.bool,
    ),
    r'restockCoverDays': PropertySchema(
      id: 18,
      name: r'restockCoverDays',
      type: IsarType.long,
    ),
    r'restockLeadTimeDays': PropertySchema(
      id: 19,
      name: r'restockLeadTimeDays',
      type: IsarType.long,
    ),
  },

  estimateSize: _appSettingsEstimateSize,
  serialize: _appSettingsSerialize,
  deserialize: _appSettingsDeserialize,
  deserializeProp: _appSettingsDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _appSettingsGetId,
  getLinks: _appSettingsGetLinks,
  attach: _appSettingsAttach,
  version: '3.3.2',
);

int _appSettingsEstimateSize(
  AppSettings object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _appSettingsSerialize(
  AppSettings object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.backupReminderFirstSeenAt);
  writer.writeBool(offsets[1], object.batteryOptimizationDialogDismissed);
  writer.writeBool(offsets[2], object.criticalStockAlertEnabled);
  writer.writeLong(offsets[3], object.criticalStockAlertHour1);
  writer.writeLong(offsets[4], object.criticalStockAlertHour2);
  writer.writeLong(offsets[5], object.criticalStockAlertHour3);
  writer.writeLong(offsets[6], object.criticalStockAlertMinute1);
  writer.writeLong(offsets[7], object.criticalStockAlertMinute2);
  writer.writeLong(offsets[8], object.criticalStockAlertMinute3);
  writer.writeBool(offsets[9], object.dailySummaryEnabled);
  writer.writeLong(offsets[10], object.dailySummaryHour);
  writer.writeLong(offsets[11], object.dailySummaryMinute);
  writer.writeDouble(offsets[12], object.defaultMinStockThreshold);
  writer.writeDateTime(offsets[13], object.lastGeneratedAt);
  writer.writeDateTime(offsets[14], object.lastBackupReminderAt);
  writer.writeDateTime(offsets[15], object.lastExportedAt);
  writer.writeDateTime(offsets[16], object.lastRetentionSweepAt);
  writer.writeBool(offsets[17], object.mutationPriceSnapshotBackfillDone);
  writer.writeLong(offsets[18], object.restockCoverDays);
  writer.writeLong(offsets[19], object.restockLeadTimeDays);
}

AppSettings _appSettingsDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppSettings();
  object.backupReminderFirstSeenAt = reader.readDateTimeOrNull(offsets[0]);
  object.batteryOptimizationDialogDismissed = reader.readBool(offsets[1]);
  object.criticalStockAlertEnabled = reader.readBool(offsets[2]);
  object.criticalStockAlertHour1 = reader.readLong(offsets[3]);
  object.criticalStockAlertHour2 = reader.readLongOrNull(offsets[4]);
  object.criticalStockAlertHour3 = reader.readLongOrNull(offsets[5]);
  object.criticalStockAlertMinute1 = reader.readLong(offsets[6]);
  object.criticalStockAlertMinute2 = reader.readLongOrNull(offsets[7]);
  object.criticalStockAlertMinute3 = reader.readLongOrNull(offsets[8]);
  object.dailySummaryEnabled = reader.readBool(offsets[9]);
  object.dailySummaryHour = reader.readLong(offsets[10]);
  object.dailySummaryMinute = reader.readLong(offsets[11]);
  object.defaultMinStockThreshold = reader.readDouble(offsets[12]);
  object.id = id;
  object.lastGeneratedAt = reader.readDateTimeOrNull(offsets[13]);
  object.lastBackupReminderAt = reader.readDateTimeOrNull(offsets[14]);
  object.lastExportedAt = reader.readDateTimeOrNull(offsets[15]);
  object.lastRetentionSweepAt = reader.readDateTimeOrNull(offsets[16]);
  object.mutationPriceSnapshotBackfillDone = reader.readBool(offsets[17]);
  object.restockCoverDays = reader.readLong(offsets[18]);
  object.restockLeadTimeDays = reader.readLong(offsets[19]);
  return object;
}

P _appSettingsDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readLongOrNull(offset)) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (reader.readLong(offset)) as P;
    case 12:
      return (reader.readDouble(offset)) as P;
    case 13:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 14:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 15:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 16:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 17:
      return (reader.readBool(offset)) as P;
    case 18:
      return (reader.readLong(offset)) as P;
    case 19:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appSettingsGetId(AppSettings object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appSettingsGetLinks(AppSettings object) {
  return [];
}

void _appSettingsAttach(
  IsarCollection<dynamic> col,
  Id id,
  AppSettings object,
) {
  object.id = id;
}

extension AppSettingsQueryWhereSort
    on QueryBuilder<AppSettings, AppSettings, QWhere> {
  QueryBuilder<AppSettings, AppSettings, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppSettingsQueryWhere
    on QueryBuilder<AppSettings, AppSettings, QWhereClause> {
  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension AppSettingsQueryFilter
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {
  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  backupReminderFirstSeenAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'backupReminderFirstSeenAt'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  backupReminderFirstSeenAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'backupReminderFirstSeenAt'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  backupReminderFirstSeenAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'backupReminderFirstSeenAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  backupReminderFirstSeenAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'backupReminderFirstSeenAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  backupReminderFirstSeenAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'backupReminderFirstSeenAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  backupReminderFirstSeenAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'backupReminderFirstSeenAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  batteryOptimizationDialogDismissedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'batteryOptimizationDialogDismissed',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'criticalStockAlertEnabled',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour1EqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'criticalStockAlertHour1',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour1GreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'criticalStockAlertHour1',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour1LessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'criticalStockAlertHour1',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour1Between(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'criticalStockAlertHour1',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour2IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'criticalStockAlertHour2'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour2IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'criticalStockAlertHour2'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour2EqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'criticalStockAlertHour2',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour2GreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'criticalStockAlertHour2',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour2LessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'criticalStockAlertHour2',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour2Between(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'criticalStockAlertHour2',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour3IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'criticalStockAlertHour3'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour3IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'criticalStockAlertHour3'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour3EqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'criticalStockAlertHour3',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour3GreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'criticalStockAlertHour3',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour3LessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'criticalStockAlertHour3',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertHour3Between(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'criticalStockAlertHour3',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute1EqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'criticalStockAlertMinute1',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute1GreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'criticalStockAlertMinute1',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute1LessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'criticalStockAlertMinute1',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute1Between(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'criticalStockAlertMinute1',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute2IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'criticalStockAlertMinute2'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute2IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'criticalStockAlertMinute2'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute2EqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'criticalStockAlertMinute2',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute2GreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'criticalStockAlertMinute2',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute2LessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'criticalStockAlertMinute2',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute2Between(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'criticalStockAlertMinute2',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute3IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'criticalStockAlertMinute3'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute3IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'criticalStockAlertMinute3'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute3EqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'criticalStockAlertMinute3',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute3GreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'criticalStockAlertMinute3',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute3LessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'criticalStockAlertMinute3',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  criticalStockAlertMinute3Between(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'criticalStockAlertMinute3',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  dailySummaryEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dailySummaryEnabled', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  dailySummaryHourEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dailySummaryHour', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  dailySummaryHourGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dailySummaryHour',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  dailySummaryHourLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dailySummaryHour',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  dailySummaryHourBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dailySummaryHour',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  dailySummaryMinuteEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dailySummaryMinute', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  dailySummaryMinuteGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dailySummaryMinute',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  dailySummaryMinuteLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dailySummaryMinute',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  dailySummaryMinuteBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dailySummaryMinute',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultMinStockThresholdEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'defaultMinStockThreshold',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultMinStockThresholdGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'defaultMinStockThreshold',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultMinStockThresholdLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'defaultMinStockThreshold',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultMinStockThresholdBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'defaultMinStockThreshold',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastGeneratedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastBackupAt'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastGeneratedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastBackupAt'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastGeneratedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastBackupAt', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastGeneratedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastBackupAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastGeneratedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastBackupAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastGeneratedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastBackupAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastBackupReminderAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastBackupReminderAt'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastBackupReminderAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastBackupReminderAt'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastBackupReminderAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastBackupReminderAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastBackupReminderAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastBackupReminderAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastBackupReminderAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastBackupReminderAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastBackupReminderAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastBackupReminderAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastExportedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastExportedAt'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastExportedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastExportedAt'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastExportedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastExportedAt', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastExportedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastExportedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastExportedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastExportedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastExportedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastExportedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastRetentionSweepAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastRetentionSweepAt'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastRetentionSweepAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastRetentionSweepAt'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastRetentionSweepAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastRetentionSweepAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastRetentionSweepAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastRetentionSweepAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastRetentionSweepAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastRetentionSweepAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  lastRetentionSweepAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastRetentionSweepAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  mutationPriceSnapshotBackfillDoneEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'mutationPriceSnapshotBackfillDone',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  restockCoverDaysEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'restockCoverDays', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  restockCoverDaysGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'restockCoverDays',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  restockCoverDaysLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'restockCoverDays',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  restockCoverDaysBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'restockCoverDays',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  restockLeadTimeDaysEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'restockLeadTimeDays', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  restockLeadTimeDaysGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'restockLeadTimeDays',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  restockLeadTimeDaysLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'restockLeadTimeDays',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  restockLeadTimeDaysBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'restockLeadTimeDays',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension AppSettingsQueryObject
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {}

extension AppSettingsQueryLinks
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {}

extension AppSettingsQuerySortBy
    on QueryBuilder<AppSettings, AppSettings, QSortBy> {
  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByBackupReminderFirstSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backupReminderFirstSeenAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByBackupReminderFirstSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backupReminderFirstSeenAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByBatteryOptimizationDialogDismissed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'batteryOptimizationDialogDismissed', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByBatteryOptimizationDialogDismissedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'batteryOptimizationDialogDismissed', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertHour1() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour1', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertHour1Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour1', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertHour2() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour2', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertHour2Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour2', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertHour3() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour3', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertHour3Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour3', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertMinute1() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute1', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertMinute1Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute1', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertMinute2() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute2', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertMinute2Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute2', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertMinute3() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute3', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCriticalStockAlertMinute3Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute3', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDailySummaryEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDailySummaryEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDailySummaryHour() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryHour', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDailySummaryHourDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryHour', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDailySummaryMinute() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryMinute', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDailySummaryMinuteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryMinute', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDefaultMinStockThreshold() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultMinStockThreshold', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDefaultMinStockThresholdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultMinStockThreshold', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByLastGeneratedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByLastGeneratedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByLastBackupReminderAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupReminderAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByLastBackupReminderAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupReminderAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByLastExportedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastExportedAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByLastExportedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastExportedAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByLastRetentionSweepAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastRetentionSweepAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByLastRetentionSweepAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastRetentionSweepAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByMutationPriceSnapshotBackfillDone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mutationPriceSnapshotBackfillDone', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByMutationPriceSnapshotBackfillDoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mutationPriceSnapshotBackfillDone', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByRestockCoverDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'restockCoverDays', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByRestockCoverDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'restockCoverDays', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByRestockLeadTimeDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'restockLeadTimeDays', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByRestockLeadTimeDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'restockLeadTimeDays', Sort.desc);
    });
  }
}

extension AppSettingsQuerySortThenBy
    on QueryBuilder<AppSettings, AppSettings, QSortThenBy> {
  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByBackupReminderFirstSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backupReminderFirstSeenAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByBackupReminderFirstSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backupReminderFirstSeenAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByBatteryOptimizationDialogDismissed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'batteryOptimizationDialogDismissed', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByBatteryOptimizationDialogDismissedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'batteryOptimizationDialogDismissed', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertHour1() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour1', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertHour1Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour1', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertHour2() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour2', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertHour2Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour2', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertHour3() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour3', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertHour3Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertHour3', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertMinute1() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute1', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertMinute1Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute1', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertMinute2() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute2', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertMinute2Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute2', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertMinute3() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute3', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCriticalStockAlertMinute3Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criticalStockAlertMinute3', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDailySummaryEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDailySummaryEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDailySummaryHour() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryHour', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDailySummaryHourDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryHour', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDailySummaryMinute() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryMinute', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDailySummaryMinuteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailySummaryMinute', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDefaultMinStockThreshold() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultMinStockThreshold', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDefaultMinStockThresholdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultMinStockThreshold', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByLastGeneratedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByLastGeneratedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByLastBackupReminderAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupReminderAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByLastBackupReminderAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupReminderAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByLastExportedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastExportedAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByLastExportedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastExportedAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByLastRetentionSweepAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastRetentionSweepAt', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByLastRetentionSweepAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastRetentionSweepAt', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByMutationPriceSnapshotBackfillDone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mutationPriceSnapshotBackfillDone', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByMutationPriceSnapshotBackfillDoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mutationPriceSnapshotBackfillDone', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByRestockCoverDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'restockCoverDays', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByRestockCoverDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'restockCoverDays', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByRestockLeadTimeDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'restockLeadTimeDays', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByRestockLeadTimeDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'restockLeadTimeDays', Sort.desc);
    });
  }
}

extension AppSettingsQueryWhereDistinct
    on QueryBuilder<AppSettings, AppSettings, QDistinct> {
  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByBackupReminderFirstSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'backupReminderFirstSeenAt');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByBatteryOptimizationDialogDismissed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'batteryOptimizationDialogDismissed');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByCriticalStockAlertEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'criticalStockAlertEnabled');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByCriticalStockAlertHour1() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'criticalStockAlertHour1');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByCriticalStockAlertHour2() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'criticalStockAlertHour2');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByCriticalStockAlertHour3() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'criticalStockAlertHour3');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByCriticalStockAlertMinute1() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'criticalStockAlertMinute1');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByCriticalStockAlertMinute2() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'criticalStockAlertMinute2');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByCriticalStockAlertMinute3() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'criticalStockAlertMinute3');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByDailySummaryEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dailySummaryEnabled');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByDailySummaryHour() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dailySummaryHour');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByDailySummaryMinute() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dailySummaryMinute');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByDefaultMinStockThreshold() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defaultMinStockThreshold');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByLastGeneratedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastBackupAt');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByLastBackupReminderAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastBackupReminderAt');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByLastExportedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastExportedAt');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByLastRetentionSweepAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastRetentionSweepAt');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByMutationPriceSnapshotBackfillDone() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mutationPriceSnapshotBackfillDone');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByRestockCoverDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'restockCoverDays');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByRestockLeadTimeDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'restockLeadTimeDays');
    });
  }
}

extension AppSettingsQueryProperty
    on QueryBuilder<AppSettings, AppSettings, QQueryProperty> {
  QueryBuilder<AppSettings, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppSettings, DateTime?, QQueryOperations>
  backupReminderFirstSeenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'backupReminderFirstSeenAt');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
  batteryOptimizationDialogDismissedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'batteryOptimizationDialogDismissed');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
  criticalStockAlertEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'criticalStockAlertEnabled');
    });
  }

  QueryBuilder<AppSettings, int, QQueryOperations>
  criticalStockAlertHour1Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'criticalStockAlertHour1');
    });
  }

  QueryBuilder<AppSettings, int?, QQueryOperations>
  criticalStockAlertHour2Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'criticalStockAlertHour2');
    });
  }

  QueryBuilder<AppSettings, int?, QQueryOperations>
  criticalStockAlertHour3Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'criticalStockAlertHour3');
    });
  }

  QueryBuilder<AppSettings, int, QQueryOperations>
  criticalStockAlertMinute1Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'criticalStockAlertMinute1');
    });
  }

  QueryBuilder<AppSettings, int?, QQueryOperations>
  criticalStockAlertMinute2Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'criticalStockAlertMinute2');
    });
  }

  QueryBuilder<AppSettings, int?, QQueryOperations>
  criticalStockAlertMinute3Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'criticalStockAlertMinute3');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
  dailySummaryEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dailySummaryEnabled');
    });
  }

  QueryBuilder<AppSettings, int, QQueryOperations> dailySummaryHourProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dailySummaryHour');
    });
  }

  QueryBuilder<AppSettings, int, QQueryOperations>
  dailySummaryMinuteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dailySummaryMinute');
    });
  }

  QueryBuilder<AppSettings, double, QQueryOperations>
  defaultMinStockThresholdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultMinStockThreshold');
    });
  }

  QueryBuilder<AppSettings, DateTime?, QQueryOperations>
  lastGeneratedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastBackupAt');
    });
  }

  QueryBuilder<AppSettings, DateTime?, QQueryOperations>
  lastBackupReminderAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastBackupReminderAt');
    });
  }

  QueryBuilder<AppSettings, DateTime?, QQueryOperations>
  lastExportedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastExportedAt');
    });
  }

  QueryBuilder<AppSettings, DateTime?, QQueryOperations>
  lastRetentionSweepAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastRetentionSweepAt');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
  mutationPriceSnapshotBackfillDoneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mutationPriceSnapshotBackfillDone');
    });
  }

  QueryBuilder<AppSettings, int, QQueryOperations> restockCoverDaysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'restockCoverDays');
    });
  }

  QueryBuilder<AppSettings, int, QQueryOperations>
  restockLeadTimeDaysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'restockLeadTimeDays');
    });
  }
}
