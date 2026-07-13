// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cost_price_adjustment.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCostPriceAdjustmentCollection on Isar {
  IsarCollection<CostPriceAdjustment> get costPriceAdjustments =>
      this.collection();
}

const CostPriceAdjustmentSchema = CollectionSchema(
  name: r'CostPriceAdjustment',
  id: -3805647792872603317,
  properties: {
    r'adjustedAt': PropertySchema(
      id: 0,
      name: r'adjustedAt',
      type: IsarType.dateTime,
    ),
    r'newCost': PropertySchema(id: 1, name: r'newCost', type: IsarType.double),
    r'note': PropertySchema(id: 2, name: r'note', type: IsarType.string),
    r'oldCost': PropertySchema(id: 3, name: r'oldCost', type: IsarType.double),
    r'productId': PropertySchema(
      id: 4,
      name: r'productId',
      type: IsarType.long,
    ),
  },

  estimateSize: _costPriceAdjustmentEstimateSize,
  serialize: _costPriceAdjustmentSerialize,
  deserialize: _costPriceAdjustmentDeserialize,
  deserializeProp: _costPriceAdjustmentDeserializeProp,
  idName: r'id',
  indexes: {
    r'productId': IndexSchema(
      id: 5580769080710688203,
      name: r'productId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'productId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _costPriceAdjustmentGetId,
  getLinks: _costPriceAdjustmentGetLinks,
  attach: _costPriceAdjustmentAttach,
  version: '3.3.2',
);

int _costPriceAdjustmentEstimateSize(
  CostPriceAdjustment object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _costPriceAdjustmentSerialize(
  CostPriceAdjustment object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.adjustedAt);
  writer.writeDouble(offsets[1], object.newCost);
  writer.writeString(offsets[2], object.note);
  writer.writeDouble(offsets[3], object.oldCost);
  writer.writeLong(offsets[4], object.productId);
}

CostPriceAdjustment _costPriceAdjustmentDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CostPriceAdjustment();
  object.adjustedAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.newCost = reader.readDoubleOrNull(offsets[1]);
  object.note = reader.readStringOrNull(offsets[2]);
  object.oldCost = reader.readDoubleOrNull(offsets[3]);
  object.productId = reader.readLong(offsets[4]);
  return object;
}

P _costPriceAdjustmentDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _costPriceAdjustmentGetId(CostPriceAdjustment object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _costPriceAdjustmentGetLinks(
  CostPriceAdjustment object,
) {
  return [];
}

void _costPriceAdjustmentAttach(
  IsarCollection<dynamic> col,
  Id id,
  CostPriceAdjustment object,
) {
  object.id = id;
}

extension CostPriceAdjustmentQueryWhereSort
    on QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QWhere> {
  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhere>
  anyProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'productId'),
      );
    });
  }
}

extension CostPriceAdjustmentQueryWhere
    on QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QWhereClause> {
  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhereClause>
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhereClause>
  idBetween(
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhereClause>
  productIdEqualTo(int productId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'productId', value: [productId]),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhereClause>
  productIdNotEqualTo(int productId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'productId',
                lower: [],
                upper: [productId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'productId',
                lower: [productId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'productId',
                lower: [productId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'productId',
                lower: [],
                upper: [productId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhereClause>
  productIdGreaterThan(int productId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'productId',
          lower: [productId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhereClause>
  productIdLessThan(int productId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'productId',
          lower: [],
          upper: [productId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterWhereClause>
  productIdBetween(
    int lowerProductId,
    int upperProductId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'productId',
          lower: [lowerProductId],
          includeLower: includeLower,
          upper: [upperProductId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension CostPriceAdjustmentQueryFilter
    on
        QueryBuilder<
          CostPriceAdjustment,
          CostPriceAdjustment,
          QFilterCondition
        > {
  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  adjustedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'adjustedAt', value: value),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  adjustedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'adjustedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  adjustedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'adjustedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  adjustedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'adjustedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  idBetween(
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  newCostIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'newCost'),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  newCostIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'newCost'),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  newCostEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'newCost',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  newCostGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'newCost',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  newCostLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'newCost',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  newCostBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'newCost',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'note'),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'note'),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  noteEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  noteBetween(
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  noteMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'note', value: ''),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'note', value: ''),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  oldCostIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'oldCost'),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  oldCostIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'oldCost'),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  oldCostEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'oldCost',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  oldCostGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'oldCost',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  oldCostLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'oldCost',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  oldCostBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'oldCost',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
  productIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'productId', value: value),
      );
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
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

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterFilterCondition>
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
}

extension CostPriceAdjustmentQueryObject
    on
        QueryBuilder<
          CostPriceAdjustment,
          CostPriceAdjustment,
          QFilterCondition
        > {}

extension CostPriceAdjustmentQueryLinks
    on
        QueryBuilder<
          CostPriceAdjustment,
          CostPriceAdjustment,
          QFilterCondition
        > {}

extension CostPriceAdjustmentQuerySortBy
    on QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QSortBy> {
  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  sortByAdjustedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'adjustedAt', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  sortByAdjustedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'adjustedAt', Sort.desc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  sortByNewCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newCost', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  sortByNewCostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newCost', Sort.desc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  sortByOldCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'oldCost', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  sortByOldCostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'oldCost', Sort.desc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  sortByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  sortByProductIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.desc);
    });
  }
}

extension CostPriceAdjustmentQuerySortThenBy
    on QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QSortThenBy> {
  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByAdjustedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'adjustedAt', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByAdjustedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'adjustedAt', Sort.desc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByNewCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newCost', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByNewCostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newCost', Sort.desc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByOldCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'oldCost', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByOldCostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'oldCost', Sort.desc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.asc);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QAfterSortBy>
  thenByProductIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.desc);
    });
  }
}

extension CostPriceAdjustmentQueryWhereDistinct
    on QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QDistinct> {
  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QDistinct>
  distinctByAdjustedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'adjustedAt');
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QDistinct>
  distinctByNewCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'newCost');
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QDistinct>
  distinctByNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QDistinct>
  distinctByOldCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'oldCost');
    });
  }

  QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QDistinct>
  distinctByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productId');
    });
  }
}

extension CostPriceAdjustmentQueryProperty
    on QueryBuilder<CostPriceAdjustment, CostPriceAdjustment, QQueryProperty> {
  QueryBuilder<CostPriceAdjustment, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CostPriceAdjustment, DateTime, QQueryOperations>
  adjustedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'adjustedAt');
    });
  }

  QueryBuilder<CostPriceAdjustment, double?, QQueryOperations>
  newCostProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'newCost');
    });
  }

  QueryBuilder<CostPriceAdjustment, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<CostPriceAdjustment, double?, QQueryOperations>
  oldCostProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'oldCost');
    });
  }

  QueryBuilder<CostPriceAdjustment, int, QQueryOperations> productIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productId');
    });
  }
}
