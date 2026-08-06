import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'local_database.dart';

// Thin wrapper over the generated drift database — every Execution action
// (see job_repository.dart) writes here first via enqueue(), never straight
// to the network, so a tap always succeeds locally regardless of
// connectivity. sync_engine.dart is the only thing that reads this queue and
// actually talks to the server.
class SyncRepository {
  final LocalDatabase _db;
  SyncRepository(this._db);

  static const _uuid = Uuid();

  Future<PendingAction> enqueue({required String jobId, required String actionType, required Map<String, dynamic> payload}) async {
    final idempotencyKey = '${jobId}_${actionType}_${_uuid.v4()}';
    final now = DateTime.now();
    final id = await _db.into(_db.pendingActions).insert(
          PendingActionsCompanion.insert(
            jobId: jobId,
            actionType: actionType,
            payloadJson: jsonEncode(payload),
            idempotencyKey: idempotencyKey,
            clientTimestamp: now,
          ),
        );
    return (_db.select(_db.pendingActions)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<PendingAction> getById(int id) {
    return (_db.select(_db.pendingActions)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<List<PendingAction>> pendingForJob(String jobId) {
    return (_db.select(_db.pendingActions)
          ..where((t) => t.jobId.equals(jobId) & t.status.equals('PENDING'))
          ..orderBy([(t) => OrderingTerm.asc(t.clientTimestamp)]))
        .get();
  }

  Future<List<String>> jobIdsWithPendingActions() async {
    final rows = await (_db.selectOnly(_db.pendingActions, distinct: true)
          ..addColumns([_db.pendingActions.jobId])
          ..where(_db.pendingActions.status.equals('PENDING')))
        .map((row) => row.read(_db.pendingActions.jobId)!)
        .get();
    return rows;
  }

  Stream<List<PendingAction>> watchAll() {
    return (_db.select(_db.pendingActions)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Future<int> pendingCount() async {
    final rows = await (_db.select(_db.pendingActions)..where((t) => t.status.equals('PENDING'))).get();
    return rows.length;
  }

  Future<void> markSynced(int id, {String? message}) {
    return (_db.update(_db.pendingActions)..where((t) => t.id.equals(id))).write(PendingActionsCompanion(status: const Value('SYNCED'), resultMessage: Value(message)));
  }

  Future<void> markRejected(int id, String message) {
    return (_db.update(_db.pendingActions)..where((t) => t.id.equals(id))).write(PendingActionsCompanion(status: const Value('REJECTED'), resultMessage: Value(message)));
  }

  Future<void> discard(int id) {
    return (_db.delete(_db.pendingActions)..where((t) => t.id.equals(id))).go();
  }

  // Re-queues a REJECTED action against current server state — deliberately
  // a fresh idempotencyKey, not a resend of the old one: the server's
  // SyncedActionModel already recorded the old key as REJECTED, so replaying
  // it verbatim would just come back REPLAYED with the same stale rejection
  // instead of being re-evaluated against whatever the state is now.
  Future<PendingAction> retryRejected(int id) async {
    final original = await getById(id);
    await discard(id);
    final newId = await _db.into(_db.pendingActions).insert(
          PendingActionsCompanion.insert(
            jobId: original.jobId,
            actionType: original.actionType,
            payloadJson: original.payloadJson,
            idempotencyKey: '${original.jobId}_${original.actionType}_${_uuid.v4()}',
            clientTimestamp: DateTime.now(),
          ),
        );
    return getById(newId);
  }

  Future<void> clearSynced() {
    return (_db.delete(_db.pendingActions)..where((t) => t.status.equals('SYNCED'))).go();
  }
}
