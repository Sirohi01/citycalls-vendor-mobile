import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/api_client.dart';
import 'sync_repository.dart';

// Per docs/manish/09-vendor-app-functional-plan.md §2 — pushes queued
// pending_actions to POST /service-requests/{id}/sync-batch "in client-
// recorded order, per action; server processes each independently... returns
// per-action success/conflict; engine marks each local action SYNCED or
// CONFLICT accordingly, never silently drops a conflict." The sync-batch
// endpoint is scoped to one ServiceRequest, so this groups the queue by
// jobId before posting — confirmed against serviceVisits.routes.ts/.service.ts
// (processSyncBatch), not guessed.
class SyncEngine {
  final SyncRepository _repo;
  final ApiClient _client;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _syncing = false;

  SyncEngine(this._repo, this._client);

  void startWatchingConnectivity() {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        // Fire and forget — a reconnect is a good moment to try, but nothing
        // here blocks the UI thread that triggered it.
        syncAll();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // Attempts to flush every job that currently has queued actions. Safe to
  // call as often as you like — re-entrant calls are ignored (`_syncing`
  // guard) rather than racing two flushes of the same queue.
  Future<void> syncAll() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final jobIds = await _repo.jobIdsWithPendingActions();
      for (final jobId in jobIds) {
        await syncJob(jobId);
      }
    } finally {
      _syncing = false;
    }
  }

  // Returns true if every currently-queued action for this job synced
  // cleanly (APPLIED/REPLAYED) — false if anything is still PENDING
  // (network failure) or ended REJECTED (a real business-rule conflict the
  // Sync Issues screen needs to surface, not retried automatically).
  Future<bool> syncJob(String jobId) async {
    final pending = await _repo.pendingForJob(jobId);
    if (pending.isEmpty) return true;

    final List<Map<String, dynamic>> actionsPayload = pending
        .map((a) => {
              'idempotencyKey': a.idempotencyKey,
              'clientTimestamp': a.clientTimestamp.toIso8601String(),
              'actionType': a.actionType,
              'payload': jsonDecode(a.payloadJson),
            })
        .toList();

    try {
      final res = await _client.dio.post('/service-requests/$jobId/sync-batch', data: {'actions': actionsPayload});
      final results = (res.data['data'] as List).cast<Map<String, dynamic>>();
      final byKey = {for (final r in results) r['idempotencyKey'] as String: r};

      var allOk = true;
      for (final action in pending) {
        final result = byKey[action.idempotencyKey];
        if (result == null) continue; // Server didn't report on it — leave PENDING, retry next flush.
        final status = result['status'] as String?;
        if (status == 'APPLIED' || status == 'REPLAYED') {
          await _repo.markSynced(action.id, message: result['message'] as String?);
        } else {
          // REJECTED — a genuine conflict (e.g. stale status transition),
          // not a connectivity problem. Surfaced on the Sync Issues screen,
          // never silently retried per the functional plan's "never silently
          // drop a conflict."
          await _repo.markRejected(action.id, (result['message'] as String?) ?? 'Rejected by server');
          allOk = false;
        }
      }
      return allOk;
    } catch (_) {
      // Network/server unreachable — leave everything PENDING for the next
      // connectivity-triggered or manual sync attempt. Not an error the user
      // needs to see immediately; the queue itself is the source of truth.
      return false;
    }
  }
}
