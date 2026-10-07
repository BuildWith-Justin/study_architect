/// What produced an XP award. The enum name is what gets stored.
enum XpSource { session, task, examTopic, bonus }

/// One line of the XP ledger. Total XP, level and "XP today" are always
/// computed from these rows, never stored separately.
class XpEntry {
  final String id;
  final XpSource sourceType;
  final String sourceId;
  final int amount;
  final String reason;
  final DateTime earnedAt;

  const XpEntry({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.amount,
    this.reason = '',
    required this.earnedAt,
  });

  /// Same source -> same id. This is what stops a session or a task from
  /// paying twice, even after a cloud sync or a backup restore.
  static String idFor(XpSource type, String sourceId) =>
      '${type.name}:$sourceId';

  factory XpEntry.forSource({
    required XpSource type,
    required String sourceId,
    required int amount,
    String reason = '',
    required DateTime earnedAt,
  }) {
    return XpEntry(
      id: idFor(type, sourceId),
      sourceType: type,
      sourceId: sourceId,
      amount: amount,
      reason: reason,
      earnedAt: earnedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'sourceType': sourceType.name,
        'sourceId': sourceId,
        'amount': amount,
        'reason': reason,
        'earnedAt': earnedAt.toIso8601String(),
      };

  factory XpEntry.fromMap(Map<String, dynamic> map) => XpEntry(
        id: map['id'] as String,
        sourceType: XpSource.values.firstWhere(
          (s) => s.name == map['sourceType'],
          orElse: () => XpSource.bonus,
        ),
        sourceId: map['sourceId'] as String,
        amount: map['amount'] as int,
        reason: (map['reason'] as String?) ?? '',
        earnedAt: DateTime.parse(map['earnedAt'] as String),
      );
}
