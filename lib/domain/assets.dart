import 'package:finora/domain/models.dart';

/// Things the user owns outside banks and brokers. Their value is entered by
/// the user, so it is always an estimate.
enum ManualAssetKind {
  property,
  vehicle,
  crypto,
  other;

  /// How long a value stays reasonably current before Finora suggests an
  /// update. Crypto moves fast; a house value can wait a year.
  Duration get reviewAfter => switch (this) {
    ManualAssetKind.property => const Duration(days: 365),
    ManualAssetKind.vehicle => const Duration(days: 365),
    ManualAssetKind.crypto => const Duration(days: 30),
    ManualAssetKind.other => const Duration(days: 180),
  };
}

class ManualAsset {
  const ManualAsset({
    required this.id,
    required this.kind,
    required this.name,
    required this.value,
    required this.valuedAt,
  });

  final String id;
  final ManualAssetKind kind;
  final String name;
  final Money value;
  final DateTime valuedAt;

  bool isOutdated(DateTime now) => now.difference(valuedAt) > kind.reviewAfter;

  ManualAsset copyWith({
    ManualAssetKind? kind,
    String? name,
    Money? value,
    DateTime? valuedAt,
  }) => ManualAsset(
    id: id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    value: value ?? this.value,
    valuedAt: valuedAt ?? this.valuedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'value': value.cents,
    'valuedAt': valuedAt.toIso8601String(),
  };

  static ManualAsset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = ManualAssetKind.values
        .where((value) => value.name == raw['kind'])
        .firstOrNull;
    final valuedAt = DateTime.tryParse('${raw['valuedAt']}');
    final cents = raw['value'];
    final id = raw['id'];
    if (kind == null || valuedAt == null || cents is! int || id is! String) {
      return null;
    }
    return ManualAsset(
      id: id,
      kind: kind,
      name: raw['name'] as String? ?? '',
      value: Money.cents(cents),
      valuedAt: valuedAt,
    );
  }
}

extension ManualAssetTotals on Iterable<ManualAsset> {
  Money get total => Money.sum(map((asset) => asset.value));

  Money totalOf(ManualAssetKind kind) =>
      Money.sum(where((asset) => asset.kind == kind).map((asset) => asset.value));
}
