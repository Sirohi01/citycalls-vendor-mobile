import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sync/local_database.dart';
import '../sync/sync_repository.dart';
import '../sync/sync_engine.dart';
import 'auth_providers.dart';

// One LocalDatabase per app run — keepAlive since drift databases are meant
// to be long-lived singletons, not recreated per widget rebuild.
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final db = LocalDatabase();
  ref.onDispose(db.close);
  return db;
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(ref.watch(localDatabaseProvider));
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(ref.watch(syncRepositoryProvider), ref.watch(apiClientProvider));
  engine.startWatchingConnectivity();
  ref.onDispose(engine.dispose);
  return engine;
});

// Drives the "pending sync" badge (dashboard/main shell) and the Sync Status
// screen's live list — a drift .watch() stream, so it updates the instant
// enqueue()/markSynced()/markRejected() touch the table, no manual refresh.
final pendingActionsProvider = StreamProvider<List<PendingAction>>((ref) {
  return ref.watch(syncRepositoryProvider).watchAll();
});
