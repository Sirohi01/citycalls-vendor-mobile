import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'local_database.g.dart';

// Per docs/manish/09-vendor-app-functional-plan.md §1 — "a local action queue
// (`pending_actions` table: actionType, payload, clientTimestamp,
// idempotencyKey, syncStatus)". This is the offline-first backbone: every
// Execution action (status change, inspection, work update, completion)
// writes here FIRST and only reaches the server via sync_engine.dart's
// flush — so tapping a button never blocks on connectivity.
class PendingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jobId => text()(); // ServiceRequest _id
  // Matches syncActionSchema.actionType exactly (serviceVisits.validation.ts):
  // START_VISIT | ARRIVE | UPDATE_INSPECTION | ADD_PARTS | UPDATE_WORK |
  // COMPLETE_VISIT | STATUS_CHANGE.
  TextColumn get actionType => text()();
  // JSON-encoded payload matching that actionType's expected shape
  // (serviceVisits.service.ts's applyAction()) — kept as opaque JSON here
  // rather than modeled per-column since each actionType has a different
  // shape and this table has to hold all of them.
  TextColumn get payloadJson => text()();
  TextColumn get idempotencyKey => text().unique()();
  DateTimeColumn get clientTimestamp => dateTime()();
  // PENDING -> (SYNCING transient, not persisted) -> SYNCED | REJECTED.
  // REPLAYED from the server is treated as SYNCED client-side — it means the
  // server already applied this exact idempotencyKey previously.
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  TextColumn get resultMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [PendingActions])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());
  LocalDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Per sqlite3_flutter_libs docs — must run before any sqlite3 API use on
    // Android/iOS so the bundled native library is picked up.
    if (Platform.isAndroid || Platform.isIOS) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'citycalls_vendor.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
