import 'package:finora/domain/calendar.dart';

/// Which calendar events the user wants push reminders for.
class ReminderPreferences {
  const ReminderPreferences({this.enabled, this.muted = const {}});

  /// `null` until the user has been asked.
  final bool? enabled;

  /// Event kinds switched off individually.
  final Set<CalendarEventKind> muted;

  /// Kinds that can be reminded at all (bills change monthly and stay in
  /// the app).
  static List<CalendarEventKind> get kinds => [
    for (final kind in CalendarEventKind.values)
      if (kind.exportable) kind,
  ];

  bool wants(CalendarEventKind kind) =>
      enabled == true && kind.exportable && !muted.contains(kind);

  /// The events to send to the backend: none when reminders are off.
  List<CalendarEvent> filter(List<CalendarEvent> events) => [
    for (final event in events)
      if (wants(event.kind)) event,
  ];

  ReminderPreferences copyWith({bool? enabled, Set<CalendarEventKind>? muted}) =>
      ReminderPreferences(
        enabled: enabled ?? this.enabled,
        muted: muted ?? this.muted,
      );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'muted': [for (final kind in muted) kind.name],
  };

  static ReminderPreferences fromJson(Object? raw) {
    if (raw is! Map) return const ReminderPreferences();
    return ReminderPreferences(
      enabled: raw['enabled'] as bool?,
      muted: {
        for (final name in (raw['muted'] as List?) ?? const [])
          ...CalendarEventKind.values.where((kind) => kind.name == name),
      },
    );
  }
}
