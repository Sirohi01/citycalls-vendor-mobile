// End-to-end UI flow tests: real screens, real repositories, offline queue
// and sync engine, against a fake citycalls-api that enforces the same
// SERVICE_REQUEST status transitions as scripts/seed.ts. Buttons are tapped
// exactly as a technician would.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citycalls_vendor/data/api_client.dart';
import 'package:citycalls_vendor/models/auth_models.dart';
import 'package:citycalls_vendor/providers/auth_providers.dart';
import 'package:citycalls_vendor/providers/sync_providers.dart';
import 'package:citycalls_vendor/screens/job_detail_screen.dart';
import 'package:citycalls_vendor/screens/otp_request_screen.dart';
import 'package:citycalls_vendor/sync/local_database.dart';
import 'package:citycalls_vendor/sync/sync_engine.dart';
import 'package:citycalls_vendor/theme/app_theme.dart';

import 'support/fake_backend.dart';

// SERVICE_REQUEST transitions a field technician may make (scripts/seed.ts).
const _allowed = <String, Set<String>>{
  'ASSIGNED_TO_EMPLOYEE': {'ACCEPTED', 'REASSIGNMENT_REQUIRED'},
  'ASSIGNED_TO_VENDOR': {'ACCEPTED', 'REASSIGNMENT_REQUIRED'},
  'ACCEPTED': {'APPOINTMENT_SCHEDULED'},
  'APPOINTMENT_SCHEDULED': {'TECHNICIAN_EN_ROUTE', 'RESCHEDULED'},
  'RESCHEDULED': {'TECHNICIAN_EN_ROUTE'},
  'TECHNICIAN_EN_ROUTE': {'TECHNICIAN_ARRIVED'},
  'TECHNICIAN_ARRIVED': {'INSPECTION_STARTED', 'CUSTOMER_UNAVAILABLE'},
  'INSPECTION_STARTED': {'INSPECTION_COMPLETED'},
  'INSPECTION_COMPLETED': {'ESTIMATE_PENDING', 'WORK_STARTED'},
  'ESTIMATE_APPROVED': {'WORK_STARTED'},
  'WORK_STARTED': {'WORK_IN_PROGRESS'},
  'WORK_IN_PROGRESS': {'PARTS_PENDING', 'ON_HOLD', 'SERVICE_COMPLETED'},
  'PARTS_PENDING': {'WORK_IN_PROGRESS'},
  'ON_HOLD': {'WORK_IN_PROGRESS'},
  'SERVICE_COMPLETED': {'CUSTOMER_CONFIRMATION_PENDING'},
  'CUSTOMER_CONFIRMATION_PENDING': {'PAYMENT_PENDING'},
};

/// A tiny in-memory citycalls-api for one job.
class FakeApi {
  String status;
  final String? branchId;
  final List<String> history = [];
  final List<String> actionTypes = [];
  final List<Map<String, dynamic>> invoices = [];
  final List<Map<String, dynamic>> payments = [];
  late final FakeBackend backend = FakeBackend(_handle);

  FakeApi(this.status, {this.branchId = 'b1'});

  Map<String, dynamic> _job() => {
        '_id': 'job1',
        'number': 'SR-1',
        'status': status,
        'priority': 'NORMAL',
        'customerId': 'c1',
        'customer': {'name': 'Amit', 'mobile': '9876543210'},
        'serviceId': 's1',
        'service': {'name': 'AC Repair'},
        'addressSnapshot': {
          'line1': 'B-204',
          'city': 'Gurugram',
          'state': 'HR',
          'pinCode': '122018'
        },
        'branchId': branchId,
        'symptoms': <String>[],
        'images': <String>[],
      };

  String? _apply(String to) {
    if (!(_allowed[status]?.contains(to) ?? false)) {
      return 'Invalid transition from $status to $to';
    }
    status = to;
    history.add(to);
    return null;
  }

  FakeResponse? _handle(RecordedRequest r) {
    final p = r.path;
    if (r.method == 'GET' && p == '/service-requests/job1') {
      return FakeResponse.ok(_job());
    }
    if (p == '/service-requests/job1/visits') return FakeResponse.ok([]);
    if (p == '/services/s1/diagnostics') {
      return FakeResponse.ok({'symptoms': [], 'defects': [], 'solutionTypes': []});
    }
    if (p == '/service-requests/job1/sync-batch') {
      final actions = ((r.body as Map)['actions'] as List).cast<Map>();
      return FakeResponse.ok([
        for (final a in actions)
          () {
            actionTypes.add(a['actionType'] as String);
            String? err;
            if (a['actionType'] == 'STATUS_CHANGE') {
              err = _apply((a['payload'] as Map)['toStatus'] as String);
            }
            return {
              'idempotencyKey': a['idempotencyKey'],
              'actionType': a['actionType'],
              'status': err == null ? 'APPLIED' : 'REJECTED',
              'message': err ?? 'ok',
            };
          }()
      ]);
    }
    if (p == '/invoices' && r.method == 'GET') return FakeResponse.ok(invoices);
    if (p == '/proforma-invoices') return FakeResponse.ok([]);
    if (p == '/estimates') return FakeResponse.ok([]);
    if (p == '/invoices' && r.method == 'POST') {
      final items = ((r.body as Map)['items'] as List).cast<Map>();
      final total = items.fold<num>(
          0, (s, i) => s + (i['qty'] as num) * (i['unitPrice'] as num));
      invoices.add({
        '_id': 'inv1',
        'number': 'INV-1',
        'status': 'ISSUED',
        'total': total,
        'amountPaid': 0,
      });
      return FakeResponse.ok(invoices.last);
    }
    if (p == '/invoices/inv1/payments' && r.method == 'POST') {
      final amount = (r.body as Map)['amount'] as num;
      payments.add({
        'number': 'RCPT-1',
        'method': (r.body as Map)['method'],
        'amount': amount
      });
      final inv = invoices.single;
      inv['amountPaid'] = (inv['amountPaid'] as num) + amount;
      final paid = inv['amountPaid'] == inv['total'];
      inv['status'] = paid ? 'PAID' : 'PARTIALLY_PAID';
      // payments.service.ts moves the job along with the invoice.
      status = paid ? 'PAID' : 'PARTIALLY_PAID';
      history.add(status);
      return FakeResponse.ok({});
    }
    if (p == '/invoices/inv1/payments') return FakeResponse.ok(payments);
    return null;
  }
}

class _LoggedIn extends AuthNotifier {
  _LoggedIn(Ref ref, String role)
      : super(ref.read(authRepositoryProvider), ref.read(apiClientProvider)) {
    state = AuthState(
        step: AuthStep.loggedIn,
        sessionChecked: true,
        user: AuthUser(id: 'u1', name: 'Rohit', role: role, vendorId: 'v1'));
  }
}

List<Override> _overrides(FakeBackend backend, {String? role = 'TECHNICIAN'}) {
  return [
    apiClientProvider.overrideWith((ref) {
      final c = ApiClient(baseUrl: 'https://api.test/api/v1');
      c.dio.httpClientAdapter = backend;
      return c;
    }),
    localDatabaseProvider.overrideWith((ref) {
      final db = LocalDatabase.forTesting(NativeDatabase.memory());
      ref.onDispose(db.close);
      return db;
    }),
    // No connectivity plugin in tests — same engine, without the listener.
    syncEngineProvider.overrideWith((ref) => SyncEngine(
        ref.watch(syncRepositoryProvider), ref.watch(apiClientProvider))),
    if (role != null) authProvider.overrideWith((ref) => _LoggedIn(ref, role)),
  ];
}

Future<void> _pumpApp(WidgetTester tester, Widget home, List<Override> o) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: o,
    child: MaterialApp(theme: AppTheme.light(), home: home),
  ));
  await _settle(tester);
}

// Lets real async work (sqlite queue, fake HTTP) finish between frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  final f = find.text(text);
  expect(f, findsWidgets, reason: 'Button "$text" should be on screen');
  await tester.ensureVisible(f.last);
  await tester.pump();
  await tester.tap(f.last);
  await _settle(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

// The app's real font, so text widths (and any overflow) match a phone.
Future<void> _loadFont() async {
  final loader = FontLoader('PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(Future.value(ByteData.view(
        File('assets/fonts/PlusJakartaSans-$w.ttf').readAsBytesSync().buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadFont);
  setUp(() => FlutterSecureStorage.setMockInitialValues({
        'citycalls_access_token': 'a',
        'citycalls_refresh_token': 'r',
      }));

  testWidgets('full job: accept → travel → inspect → work → complete → pay',
      (tester) async {
    final api = FakeApi('ASSIGNED_TO_VENDOR');
    await _pumpApp(tester, const JobDetailScreen(jobId: 'job1'),
        _overrides(api.backend));

    await _tap(tester, 'Accept Job');
    expect(api.status, 'ACCEPTED');

    await _tap(tester, 'Start Travel'); // hops via APPOINTMENT_SCHEDULED
    expect(api.status, 'TECHNICIAN_EN_ROUTE');

    await _tap(tester, 'Mark Arrived');
    await _tap(tester, 'Start Inspection');
    expect(api.status, 'INSPECTION_STARTED');

    await _tap(tester, 'Enter Inspection Details');
    await tester.enterText(find.byType(TextField).first, 'Gas leak at joint');
    await _tap(tester, 'Save & Complete Inspection');
    expect(api.status, 'INSPECTION_COMPLETED');
    expect(api.actionTypes, contains('UPDATE_INSPECTION'));

    await _tap(tester, 'Start Work');
    expect(api.status, 'WORK_STARTED');

    await _tap(tester, 'Complete');
    await _tap(tester, 'Customer unreachable? Complete without proof');
    await _tap(tester, 'Complete Anyway');
    expect(api.actionTypes, contains('COMPLETE_VISIT'));
    expect(api.status, 'SERVICE_COMPLETED'); // via WORK_IN_PROGRESS

    await _tap(tester, 'Send for Customer Confirmation');
    await _tap(tester, 'Proceed to Payment');
    expect(api.status, 'PAYMENT_PENDING');

    await _tap(tester, 'Invoice & Collect Payment');
    await _tap(tester, 'Add Item');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Gas refill');
    await tester.enterText(fields.at(2), '1500');
    await _tap(tester, 'Add');
    await _tap(tester, 'Create Invoice');
    expect(api.invoices.single['total'], 1500);
    expect(find.text('₹1,500'), findsWidgets);

    await _tap(tester, 'Record Payment');
    await _tap(tester, 'Confirm');
    expect(api.payments.single['amount'], 1500);
    expect(api.payments.single['method'], 'CASH');
    expect(find.text('Paid in full'), findsOneWidget);

    expect(api.history, [
      'ACCEPTED',
      'APPOINTMENT_SCHEDULED',
      'TECHNICIAN_EN_ROUTE',
      'TECHNICIAN_ARRIVED',
      'INSPECTION_STARTED',
      'INSPECTION_COMPLETED',
      'WORK_STARTED',
      'WORK_IN_PROGRESS',
      'SERVICE_COMPLETED',
      'CUSTOMER_CONFIRMATION_PENDING',
      'PAYMENT_PENDING',
      'PAID',
    ]);
    await _unmount(tester);
  });

  testWidgets('reject asks for a reason and hands the job back',
      (tester) async {
    final api = FakeApi('ASSIGNED_TO_EMPLOYEE');
    await tester.pumpWidget(const SizedBox()); // fresh root
    await _pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const JobDetailScreen(jobId: 'job1'))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        _overrides(api.backend));
    await _tap(tester, 'open');
    await _tap(tester, 'Reject');
    await tester.enterText(find.byType(TextField), 'Too far from my area');
    await _tap(tester, 'Reject');
    expect(api.status, 'REASSIGNMENT_REQUIRED');
    // Leaves the job screen once handed back.
    expect(find.text('open'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a step the server refuses shows its message, nothing moves',
      (tester) async {
    final api = FakeApi('ACCEPTED');
    await _pumpApp(tester, const JobDetailScreen(jobId: 'job1'),
        _overrides(api.backend));
    api.status = 'TECHNICIAN_ARRIVED'; // changed elsewhere meanwhile
    await _tap(tester, 'Start Travel');
    expect(find.textContaining('Invalid transition'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('vendor owner sees accept/reject but no field buttons',
      (tester) async {
    final api = FakeApi('WORK_IN_PROGRESS');
    await _pumpApp(tester, const JobDetailScreen(jobId: 'job1'),
        _overrides(api.backend, role: 'VENDOR_OWNER'));
    expect(find.text('Complete'), findsNothing);
    expect(find.text('Parts Used'), findsNothing);
    expect(find.textContaining('Your field technician'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('billing a job without a branch explains instead of failing',
      (tester) async {
    final api = FakeApi('PAYMENT_PENDING', branchId: null);
    await _pumpApp(tester, const JobDetailScreen(jobId: 'job1'),
        _overrides(api.backend));
    await _tap(tester, 'Invoice & Collect Payment');
    await _tap(tester, 'Add Item');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Labour');
    await tester.enterText(fields.at(2), '300');
    await _tap(tester, 'Add');
    await _tap(tester, 'Create Invoice');
    expect(find.textContaining('no branch assigned'), findsOneWidget);
    expect(api.invoices, isEmpty);
    await _unmount(tester);
  });

  group('Login', () {
    Future<FakeBackend> pumpLogin(WidgetTester tester, String role) async {
      final backend = FakeBackend((r) {
        if (r.path == '/auth/otp/request') return FakeResponse.ok(null);
        if (r.path == '/auth/otp/verify') {
          expect(r.body, {'mobile': '9811122233', 'otp': '123456'});
          return FakeResponse.ok({
            'accessToken': 'a',
            'refreshToken': 'r',
            'user': {'id': 'u1', 'name': 'Raj', 'role': role}
          });
        }
        return null;
      });
      FlutterSecureStorage.setMockInitialValues({});
      await _pumpApp(tester, const OtpRequestScreen(),
          _overrides(backend, role: null));
      await tester.enterText(find.byType(TextFormField), '9811122233');
      await _tap(tester, 'Send OTP');
      for (final d in '123456'.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump();
      }
      await _settle(tester);
      return backend;
    }

    testWidgets('a customer number is turned away with a clear message',
        (tester) async {
      await pumpLogin(tester, 'CUSTOMER');
      expect(find.textContaining("isn't registered as a technician"),
          findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a short mobile number is caught before any request',
        (tester) async {
      final backend = FakeBackend((r) => FakeResponse.ok(null));
      FlutterSecureStorage.setMockInitialValues({});
      await _pumpApp(tester, const OtpRequestScreen(),
          _overrides(backend, role: null));
      await tester.enterText(find.byType(TextFormField), '98111');
      await _tap(tester, 'Send OTP');
      expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
      expect(backend.requests, isEmpty);
      await _unmount(tester);
    });
  });

}
