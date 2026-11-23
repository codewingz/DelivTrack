import '../../parcels/domain/parcel_enums.dart';

/// The owner's preferences. They are saved in the owner's account, so they
/// follow the owner to any phone.
class AppSettings {
  const AppSettings({
    this.remindersEnabled = true,
    this.reminderMinutes = defaultReminderMinutes,
    this.showOverdueAlerts = true,
    this.payLaterDueDays,
    this.defaultMethod,
    this.promptWhatsAppTracking = true,
  });

  /// 9:00 AM, in minutes after midnight (Pakistan time).
  static const defaultReminderMinutes = 9 * 60;

  /// The choices offered for [payLaterDueDays].
  static const payLaterDueDayOptions = [7, 14, 30];

  /// Phone notifications for Pay Later payments.
  final bool remindersEnabled;

  /// When a reminder arrives on its due day: minutes after midnight, Pakistan
  /// time (0 to 1439).
  final int reminderMinutes;

  /// Whether overdue Pay Later payments are listed under "Needs attention".
  final bool showOverdueAlerts;

  /// Days from today pre-filled as the payment date of a new Pay Later
  /// parcel; null leaves the date empty.
  final int? payLaterDueDays;

  /// Parcel type pre-selected on Add parcel; null asks every time.
  final CollectionMethod? defaultMethod;

  /// Whether a handover is followed by "Send tracking update?".
  final bool promptWhatsAppTracking;

  /// "9:00 AM" for [reminderMinutes].
  String get reminderTimeLabel => formatMinutesOfDay(reminderMinutes);

  Map<String, dynamic> toMap() => {
    'remindersEnabled': remindersEnabled,
    'reminderMinutes': reminderMinutes,
    'showOverdueAlerts': showOverdueAlerts,
    'promptWhatsAppTracking': promptWhatsAppTracking,
    'payLaterDueDays': ?payLaterDueDays,
    'defaultMethod': ?defaultMethod?.value,
  };

  /// Unknown or out-of-range values fall back to the defaults, so a document
  /// written by a newer app version never breaks this one.
  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final minutes = map['reminderMinutes'];
    final days = map['payLaterDueDays'];
    return AppSettings(
      remindersEnabled: map['remindersEnabled'] != false,
      reminderMinutes: minutes is int && minutes >= 0 && minutes < 24 * 60
          ? minutes
          : defaultReminderMinutes,
      showOverdueAlerts: map['showOverdueAlerts'] != false,
      promptWhatsAppTracking: map['promptWhatsAppTracking'] != false,
      payLaterDueDays: payLaterDueDayOptions.contains(days)
          ? days as int
          : null,
      defaultMethod: CollectionMethod.values
          .where((method) => method.value == map['defaultMethod'])
          .firstOrNull,
    );
  }

  /// A copy with some values changed. [payLaterDueDays] and [defaultMethod]
  /// take a function so they can also be set back to "none".
  AppSettings copyWith({
    bool? remindersEnabled,
    int? reminderMinutes,
    bool? showOverdueAlerts,
    int? Function()? payLaterDueDays,
    CollectionMethod? Function()? defaultMethod,
    bool? promptWhatsAppTracking,
  }) => AppSettings(
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    showOverdueAlerts: showOverdueAlerts ?? this.showOverdueAlerts,
    payLaterDueDays: payLaterDueDays == null
        ? this.payLaterDueDays
        : payLaterDueDays(),
    defaultMethod: defaultMethod == null ? this.defaultMethod : defaultMethod(),
    promptWhatsAppTracking:
        promptWhatsAppTracking ?? this.promptWhatsAppTracking,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      remindersEnabled == other.remindersEnabled &&
      reminderMinutes == other.reminderMinutes &&
      showOverdueAlerts == other.showOverdueAlerts &&
      payLaterDueDays == other.payLaterDueDays &&
      defaultMethod == other.defaultMethod &&
      promptWhatsAppTracking == other.promptWhatsAppTracking;

  @override
  int get hashCode => Object.hash(
    remindersEnabled,
    reminderMinutes,
    showOverdueAlerts,
    payLaterDueDays,
    defaultMethod,
    promptWhatsAppTracking,
  );
}

/// "9:00 AM" / "12:30 PM" for minutes after midnight.
String formatMinutesOfDay(int minutes) {
  final hour = minutes ~/ 60;
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:${(minutes % 60).toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
}
