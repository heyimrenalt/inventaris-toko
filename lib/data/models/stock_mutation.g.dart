// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_mutation.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStockMutationCollection on Isar {
  IsarCollection<StockMutation> get stockMutations => this.collection();
}

const StockMutationSchema = CollectionSchema(
  name: r'StockMutation',
  id: -2155642014273145552,
  properties: {
    r'costPriceSnapshot': PropertySchema(
      id: 0,
      name: r'costPriceSnapshot',
      type: IsarType.double,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'enteredQuantity': PropertySchema(
      id: 2,
      name: r'enteredQuantity',
      type: IsarType.double,
    ),
    r'enteredUnit': PropertySchema(
      id: 3,
      name: r'enteredUnit',
      type: IsarType.string,
      enumMap: _StockMutationenteredUnitEnumValueMap,
    ),
    r'note': PropertySchema(id: 4, name: r'note', type: IsarType.string),
    r'productId': PropertySchema(
      id: 5,
      name: r'productId',
      type: IsarType.long,
    ),
    r'quantity': PropertySchema(
      id: 6,
      name: r'quantity',
      type: IsarType.double,
    ),
    r'sellPriceSnapshot': PropertySchema(
      id: 7,
      name: r'sellPriceSnapshot',
      type: IsarType.double,
    ),
    r'snapshotBackfilled': PropertySchema(
      id: 8,
      name: r'snapshotBackfilled',
      type: IsarType.bool,
    ),
    r'stockAfter': PropertySchema(
      id: 9,
      name: r'stockAfter',
      type: IsarType.double,
    ),
    r'type': PropertySchema(
      id: 10,
      name: r'type',
      type: IsarType.string,
      enumMap: _StockMutationtypeEnumValueMap,
    ),
  },

  estimateSize: _stockMutationEstimateSize,
  serialize: _stockMutationSerialize,
  deserialize: _stockMutationDeserialize,
  deserializeProp: _stockMutationDeserializeProp,
  idName: r'id',
  indexes: {
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _stockMutationGetId,
  getLinks: _stockMutationGetLinks,
  attach: _stockMutationAttach,
  version: '3.3.2',
);

int _stockMutationEstimateSize(
  StockMutation object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.enteredUnit;
    if (value != null) {
      bytesCount += 3 + value.name.length * 3;
    }
  }
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.type.name.length * 3;
  return bytesCount;
}

void _stockMutationSerialize(
  StockMutation object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.costPriceSnapshot);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeDouble(offsets[2], object.enteredQuantity);
  writer.writeString(offsets[3], object.enteredUnit?.name);
  writer.writeString(offsets[4], object.note);
  writer.writeLong(offsets[5], object.productId);
  writer.writeDouble(offsets[6], object.quantity);
  writer.writeDouble(offsets[7], object.sellPriceSnapshot);
  writer.writeBool(offsets[8], object.snapshotBackfilled);
  writer.writeDouble(offsets[9], object.stockAfter);
  writer.writeString(offsets[10], object.type.name);
}

StockMutation _stockMutationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StockMutation();
  object.costPriceSnapshot = reader.readDoubleOrNull(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.enteredQuantity = reader.readDoubleOrNull(offsets[2]);
  object.enteredUnit =
      _StockMutationenteredUnitValueEnumMap[reader.readStringOrNull(
        offsets[3],
      )];
  object.id = id;
  object.note = reader.readStringOrNull(offsets[4]);
  object.productId = reader.readLong(offsets[5]);
  object.quantity = reader.readDouble(offsets[6]);
  object.sellPriceSnapshot = reader.readDoubleOrNull(offsets[7]);
  object.snapshotBackfilled = reader.readBool(offsets[8]);
  object.stockAfter = reader.readDouble(offsets[9]);
  object.type =
      _StockMutationtypeValueEnumMap[reader.readStringOrNull(offsets[10])] ??
      StockMutationType.stockIn;
  return object;
}

P _stockMutationDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDoubleOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readDoubleOrNull(offset)) as P;
    case 3:
      return (_StockMutationenteredUnitValueEnumMap[reader.readStringOrNull(
            offset,
          )])
          as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readDouble(offset)) as P;
    case 7:
      return (reader.readDoubleOrNull(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readDouble(offset)) as P;
    case 10:
      return (_StockMutationtypeValueEnumMap[reader.readStringOrNull(offset)] ??
              StockMutationType.stockIn)
          as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _StockMutationenteredUnitEnumValueMap = {
  r'pcs': r'pcs',
  r'pack': r'pack',
  r'dus': r'dus',
};
const _StockMutationenteredUnitValueEnumMap = {
  r'pcs': EnteredUnit.pcs,
  r'pack': EnteredUnit.pack,
  r'dus': EnteredUnit.dus,
};
const _StockMutationtypeEnumValueMap = {
  r'stockIn': r'stockIn',
  r'stockOut': r'stockOut',
};
const _StockMutationtypeValueEnumMap = {
  r'stockIn': StockMutationType.stockIn,
  r'stockOut': StockMutationType.stockOut,
};

Id _stockMutationGetId(StockMutation object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _stockMutationGetLinks(StockMutation object) {
  return [];
}

void _stockMutationAttach(
  IsarCollection<dynamic> col,
  Id id,
  StockMutation object,
) {
  object.id = id;
}

extension StockMutationQueryWhereSort
    on QueryBuilder<StockMutation, StockMutation, QWhere> {
  QueryBuilder<StockMutation, StockMutation, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }
}

extension StockMutationQueryWhere
    on QueryBuilder<StockMutation, StockMutation, QWhereClause> {
  QueryBuilder<StockMutation, StockMutation, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<StockMutation, StockMutation, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterWhereClause> idBetween(
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

  QueryBuilder<StockMutation, StockMutation, QAfterWhereClause>
  createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'createdAt', value: [createdAt]),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterWhereClause>
  createdAtNotEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterWhereClause>
  createdAtGreaterThan(DateTime createdAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [createdAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterWhereClause>
  createdAtLessThan(DateTime createdAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [],
          upper: [createdAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterWhereClause>
  createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [lowerCreatedAt],
          includeLower: includeLower,
          upper: [upperCreatedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension StockMutationQueryFilter
    on QueryBuilder<StockMutation, StockMutation, QFilterCondition> {
  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  costPriceSnapshotIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'costPriceSnapshot'),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  costPriceSnapshotIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'costPriceSnapshot'),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  costPriceSnapshotEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'costPriceSnapshot',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  costPriceSnapshotGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'costPriceSnapshot',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  costPriceSnapshotLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'costPriceSnapshot',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  costPriceSnapshotBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'costPriceSnapshot',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredQuantityIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'enteredQuantity'),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredQuantityIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'enteredQuantity'),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredQuantityEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'enteredQuantity',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredQuantityGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'enteredQuantity',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredQuantityLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'enteredQuantity',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredQuantityBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'enteredQuantity',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'enteredUnit'),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'enteredUnit'),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitEqualTo(EnteredUnit? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'enteredUnit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitGreaterThan(
    EnteredUnit? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'enteredUnit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitLessThan(
    EnteredUnit? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'enteredUnit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitBetween(
    EnteredUnit? lower,
    EnteredUnit? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'enteredUnit',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'enteredUnit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'enteredUnit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'enteredUnit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'enteredUnit',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'enteredUnit', value: ''),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  enteredUnitIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'enteredUnit', value: ''),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
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

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition> idBetween(
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

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'note'),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'note'),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition> noteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition> noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'note',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  noteStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  noteEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition> noteMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'note',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'note', value: ''),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'note', value: ''),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  productIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'productId', value: value),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  productIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'productId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  productIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'productId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  productIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'productId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  quantityEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'quantity',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  quantityGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'quantity',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  quantityLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'quantity',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  quantityBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'quantity',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  sellPriceSnapshotIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sellPriceSnapshot'),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  sellPriceSnapshotIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sellPriceSnapshot'),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  sellPriceSnapshotEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sellPriceSnapshot',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  sellPriceSnapshotGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sellPriceSnapshot',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  sellPriceSnapshotLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sellPriceSnapshot',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  sellPriceSnapshotBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sellPriceSnapshot',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  snapshotBackfilledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'snapshotBackfilled', value: value),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  stockAfterEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'stockAfter',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  stockAfterGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'stockAfter',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  stockAfterLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'stockAfter',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  stockAfterBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'stockAfter',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition> typeEqualTo(
    StockMutationType value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  typeGreaterThan(
    StockMutationType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  typeLessThan(
    StockMutationType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition> typeBetween(
    StockMutationType lower,
    StockMutationType upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  typeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  typeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  typeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition> typeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'type',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  typeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: ''),
      );
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterFilterCondition>
  typeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'type', value: ''),
      );
    });
  }
}

extension StockMutationQueryObject
    on QueryBuilder<StockMutation, StockMutation, QFilterCondition> {}

extension StockMutationQueryLinks
    on QueryBuilder<StockMutation, StockMutation, QFilterCondition> {}

extension StockMutationQuerySortBy
    on QueryBuilder<StockMutation, StockMutation, QSortBy> {
  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortByCostPriceSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costPriceSnapshot', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortByCostPriceSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costPriceSnapshot', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortByEnteredQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enteredQuantity', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortByEnteredQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enteredQuantity', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> sortByEnteredUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enteredUnit', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortByEnteredUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enteredUnit', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> sortByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortByProductIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> sortByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortBySellPriceSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sellPriceSnapshot', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortBySellPriceSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sellPriceSnapshot', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortBySnapshotBackfilled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotBackfilled', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortBySnapshotBackfilledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotBackfilled', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> sortByStockAfter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stockAfter', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  sortByStockAfterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stockAfter', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension StockMutationQuerySortThenBy
    on QueryBuilder<StockMutation, StockMutation, QSortThenBy> {
  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenByCostPriceSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costPriceSnapshot', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenByCostPriceSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costPriceSnapshot', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenByEnteredQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enteredQuantity', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenByEnteredQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enteredQuantity', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenByEnteredUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enteredUnit', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenByEnteredUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enteredUnit', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenByProductIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenBySellPriceSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sellPriceSnapshot', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenBySellPriceSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sellPriceSnapshot', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenBySnapshotBackfilled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotBackfilled', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenBySnapshotBackfilledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotBackfilled', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenByStockAfter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stockAfter', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy>
  thenByStockAfterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stockAfter', Sort.desc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension StockMutationQueryWhereDistinct
    on QueryBuilder<StockMutation, StockMutation, QDistinct> {
  QueryBuilder<StockMutation, StockMutation, QDistinct>
  distinctByCostPriceSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'costPriceSnapshot');
    });
  }

  QueryBuilder<StockMutation, StockMutation, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<StockMutation, StockMutation, QDistinct>
  distinctByEnteredQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'enteredQuantity');
    });
  }

  QueryBuilder<StockMutation, StockMutation, QDistinct> distinctByEnteredUnit({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'enteredUnit', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QDistinct> distinctByNote({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StockMutation, StockMutation, QDistinct> distinctByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productId');
    });
  }

  QueryBuilder<StockMutation, StockMutation, QDistinct> distinctByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quantity');
    });
  }

  QueryBuilder<StockMutation, StockMutation, QDistinct>
  distinctBySellPriceSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sellPriceSnapshot');
    });
  }

  QueryBuilder<StockMutation, StockMutation, QDistinct>
  distinctBySnapshotBackfilled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'snapshotBackfilled');
    });
  }

  QueryBuilder<StockMutation, StockMutation, QDistinct> distinctByStockAfter() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stockAfter');
    });
  }

  QueryBuilder<StockMutation, StockMutation, QDistinct> distinctByType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type', caseSensitive: caseSensitive);
    });
  }
}

extension StockMutationQueryProperty
    on QueryBuilder<StockMutation, StockMutation, QQueryProperty> {
  QueryBuilder<StockMutation, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StockMutation, double?, QQueryOperations>
  costPriceSnapshotProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'costPriceSnapshot');
    });
  }

  QueryBuilder<StockMutation, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<StockMutation, double?, QQueryOperations>
  enteredQuantityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'enteredQuantity');
    });
  }

  QueryBuilder<StockMutation, EnteredUnit?, QQueryOperations>
  enteredUnitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'enteredUnit');
    });
  }

  QueryBuilder<StockMutation, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<StockMutation, int, QQueryOperations> productIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productId');
    });
  }

  QueryBuilder<StockMutation, double, QQueryOperations> quantityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quantity');
    });
  }

  QueryBuilder<StockMutation, double?, QQueryOperations>
  sellPriceSnapshotProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sellPriceSnapshot');
    });
  }

  QueryBuilder<StockMutation, bool, QQueryOperations>
  snapshotBackfilledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'snapshotBackfilled');
    });
  }

  QueryBuilder<StockMutation, double, QQueryOperations> stockAfterProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stockAfter');
    });
  }

  QueryBuilder<StockMutation, StockMutationType, QQueryOperations>
  typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }
}
