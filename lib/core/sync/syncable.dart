/// Sync state of a locally stored row.
enum SyncStatus {
  synced(0),
  pendingUpsert(1),
  pendingDelete(2);

  const SyncStatus(this.value);
  final int value;

  static SyncStatus fromValue(int v) =>
      SyncStatus.values.firstWhere((s) => s.value == v, orElse: () => SyncStatus.synced);
}

/// Every syncable local table carries these columns.
/// - id: client-generated UUID (works offline, same id on server)
/// - updatedAt: last modification time (server value after a sync)
/// - deletedAt: soft-delete marker (row is kept until the delete is pushed)
/// - syncStatus: what still needs to be pushed
mixin Syncable {
  String get id;
  DateTime get updatedAt;
  DateTime? get deletedAt;
  SyncStatus get syncStatus;

  bool get isDeleted => deletedAt != null;
  bool get needsPush => syncStatus != SyncStatus.synced;
}

/// Names of tables in the exact order they must be pushed
/// (parents before children, so foreign keys never fail).
const List<String> kSyncPushOrder = [
  'subjects',
  'topics',
  'study_sessions',
  'study_logs',
  'tasks',
  'exams',
  'exam_topics',
  'achievements',
  'xp_log',
];

/// Local key that stores the last successful pull time per table.
String lastPulledKey(String table) => 'last_pulled_$table';