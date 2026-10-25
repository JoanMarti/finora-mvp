import 'package:finora/domain/models.dart';

/// The 26 cantons, by their official abbreviation.
enum Canton {
  ag('Aargau'),
  ai('Appenzell Innerrhoden'),
  ar('Appenzell Ausserrhoden'),
  be('Bern'),
  bl('Basel-Landschaft'),
  bs('Basel-Stadt'),
  fr('Fribourg'),
  ge('Genève'),
  gl('Glarus'),
  gr('Graubünden'),
  ju('Jura'),
  lu('Luzern'),
  ne('Neuchâtel'),
  nw('Nidwalden'),
  ow('Obwalden'),
  sg('St. Gallen'),
  sh('Schaffhausen'),
  so('Solothurn'),
  sz('Schwyz'),
  tg('Thurgau'),
  ti('Ticino'),
  ur('Uri'),
  vd('Vaud'),
  vs('Valais'),
  zg('Zug'),
  zh('Zürich');

  const Canton(this.officialName);

  /// Name in the canton's own language; the same in every app language.
  final String officialName;

  String get code => name.toUpperCase();

  /// Rough tax level used only for first estimates: cantonal and communal
  /// tax on middle incomes differs by roughly ten points across cantons.
  TaxLevel get taxLevel => switch (this) {
    zg || sz || nw || ow || ai || ur || ar || lu => TaxLevel.low,
    ge || vd || ne || ju || be || bs || vs || fr || so => TaxLevel.high,
    _ => TaxLevel.medium,
  };
}

enum TaxLevel { low, medium, high }

enum CivilStatus { single, married, registeredPartnership, divorced, widowed }

enum Employment { employee, selfEmployed, student, notWorking, retired }

enum Housing { renting, owning, withFamily }

enum RiskProfile { cautious, balanced, dynamic }

/// What the user wants their money to do. Shapes ideas and offers.
enum Interest { saveMore, investing, buyHome, retireEarly, payOffDebt, family, travel }

/// Who the user is, as far as money goes. Every field is optional: Finora
/// works without it, and each answer makes estimates and ideas more
/// personal. Kept on the device; used for offers only with consent.
class UserProfile {
  const UserProfile({
    this.birthYear,
    this.canton,
    this.civilStatus,
    this.children,
    this.employment,
    this.grossIncome,
    this.housing,
    this.monthlyRent,
    this.rentDeposit,
    this.risk,
    this.interests = const {},
  });

  final int? birthYear;
  final Canton? canton;
  final CivilStatus? civilStatus;
  final int? children;
  final Employment? employment;

  /// Gross yearly income from work.
  final Money? grossIncome;
  final Housing? housing;
  final Money? monthlyRent;

  /// Rent deposit held in a blocked bank account.
  final Money? rentDeposit;
  final RiskProfile? risk;
  final Set<Interest> interests;

  static const earliestBirthYear = 1920;

  int? ageAt(DateTime now) => birthYear == null ? null : now.year - birthYear!;

  bool get isRenting => housing == Housing.renting;
  bool get isSelfEmployed => employment == Employment.selfEmployed;
  bool get isMarried =>
      civilStatus == CivilStatus.married ||
      civilStatus == CivilStatus.registeredPartnership;
  bool get hasChildren => (children ?? 0) > 0;

  /// Answers counted for the completeness meter.
  List<bool> get _answered => [
    birthYear != null,
    canton != null,
    civilStatus != null,
    children != null,
    employment != null,
    grossIncome != null,
    housing != null,
    risk != null,
    interests.isNotEmpty,
  ];

  /// Share of the profile filled in, from 0 to 1.
  double get completeness =>
      _answered.where((answered) => answered).length / _answered.length;

  bool get isEmpty => completeness == 0;

  static const _unset = Object();

  UserProfile copyWith({
    Object? birthYear = _unset,
    Object? canton = _unset,
    Object? civilStatus = _unset,
    Object? children = _unset,
    Object? employment = _unset,
    Object? grossIncome = _unset,
    Object? housing = _unset,
    Object? monthlyRent = _unset,
    Object? rentDeposit = _unset,
    Object? risk = _unset,
    Set<Interest>? interests,
  }) {
    T pick<T>(Object? value, T current) =>
        identical(value, _unset) ? current : value as T;
    return UserProfile(
      birthYear: pick(birthYear, this.birthYear),
      canton: pick(canton, this.canton),
      civilStatus: pick(civilStatus, this.civilStatus),
      children: pick(children, this.children),
      employment: pick(employment, this.employment),
      grossIncome: pick(grossIncome, this.grossIncome),
      housing: pick(housing, this.housing),
      monthlyRent: pick(monthlyRent, this.monthlyRent),
      rentDeposit: pick(rentDeposit, this.rentDeposit),
      risk: pick(risk, this.risk),
      interests: interests ?? this.interests,
    );
  }

  Map<String, Object?> toJson() => {
    'birthYear': birthYear,
    'canton': canton?.name,
    'civilStatus': civilStatus?.name,
    'children': children,
    'employment': employment?.name,
    'grossIncome': grossIncome?.cents,
    'housing': housing?.name,
    'monthlyRent': monthlyRent?.cents,
    'rentDeposit': rentDeposit?.cents,
    'risk': risk?.name,
    'interests': [for (final interest in interests) interest.name],
  };

  static UserProfile fromJson(Object? raw) {
    if (raw is! Map) return const UserProfile();
    T? named<T extends Enum>(List<T> values, Object? value) =>
        values.where((item) => item.name == value).firstOrNull;
    Money? money(Object? value) => value is int ? Money.cents(value) : null;
    final birthYear = raw['birthYear'];
    final children = raw['children'];
    return UserProfile(
      birthYear: birthYear is int ? birthYear : null,
      canton: named(Canton.values, raw['canton']),
      civilStatus: named(CivilStatus.values, raw['civilStatus']),
      children: children is int && children >= 0 ? children : null,
      employment: named(Employment.values, raw['employment']),
      grossIncome: money(raw['grossIncome']),
      housing: named(Housing.values, raw['housing']),
      monthlyRent: money(raw['monthlyRent']),
      rentDeposit: money(raw['rentDeposit']),
      risk: named(RiskProfile.values, raw['risk']),
      interests: {
        if (raw['interests'] case final List names)
          for (final name in names) ?named(Interest.values, name),
      },
    );
  }
}

/// Three questions that place the user on a cautious–balanced–dynamic
/// scale. Each answer scores 0 (cautious) to 2 (dynamic).
abstract final class RiskQuestionnaire {
  static const questions = 3;

  /// [answers] are the chosen option per question (0, 1 or 2).
  static RiskProfile score(List<int> answers) {
    assert(answers.length == questions, 'one answer per question');
    final total = answers.fold(0, (sum, answer) => sum + answer.clamp(0, 2));
    if (total <= 2) return RiskProfile.cautious;
    if (total <= 4) return RiskProfile.balanced;
    return RiskProfile.dynamic;
  }

  /// Share of long-term money that suits the profile in stocks, used to
  /// set the wealth plan's long-term target.
  static double longTermShare(RiskProfile risk) => switch (risk) {
    RiskProfile.cautious => .3,
    RiskProfile.balanced => .45,
    RiskProfile.dynamic => .6,
  };
}

/// First estimates derived from the profile, always shown as estimates.
abstract final class ProfileEstimates {
  /// Pillar 3a maximum for the self-employed without a pension fund: 20 % of
  /// net earned income, at most CHF 36,288 (2025 and 2026).
  static const selfEmployedPillar3aMax = Money.cents(3628800);

  static Money pillar3aLimit(UserProfile profile, Money employeeLimit) {
    final income = profile.grossIncome;
    if (!profile.isSelfEmployed || income == null) return employeeLimit;
    final fifth = Money.cents((income.cents * .2).round());
    return fifth.cents > selfEmployedPillar3aMax.cents
        ? selfEmployedPillar3aMax
        : fifth;
  }

  /// Rough combined marginal tax rate (federal, cantonal, communal) from
  /// income band, canton level and civil status. A starting point for the
  /// simulator, which the user should correct with their own assessment.
  static double? marginalRate(UserProfile profile) {
    final income = profile.grossIncome;
    if (income == null) return null;
    final francs = income.amount;
    var rate = francs < 60000
        ? .15
        : francs < 100000
        ? .22
        : francs < 150000
        ? .28
        : .33;
    rate += switch (profile.canton?.taxLevel) {
      TaxLevel.low => -.05,
      TaxLevel.high => .03,
      TaxLevel.medium || null => 0,
    };
    if (profile.isMarried) rate -= .03;
    return rate.clamp(.1, .45).toDouble();
  }
}
