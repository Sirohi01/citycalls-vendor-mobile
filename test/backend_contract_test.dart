// Contract tests: each fixture below is shaped exactly like what
// citycalls-api returns for that endpoint (the service/controller noted next
// to it), and each test checks the app parses it and behaves correctly.
// Network is a fake (support/fake_backend.dart) — nothing hits the live API.
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citycalls_vendor/data/api_client.dart';
import 'package:citycalls_vendor/data/auth_repository.dart';
import 'package:citycalls_vendor/data/invoice_repository.dart';
import 'package:citycalls_vendor/data/job_repository.dart';
import 'package:citycalls_vendor/data/notification_repository.dart';
import 'package:citycalls_vendor/models/employee_models.dart';
import 'package:citycalls_vendor/models/job_models.dart';
import 'package:citycalls_vendor/models/vendor_models.dart';
import 'package:citycalls_vendor/sync/local_database.dart';
import 'package:citycalls_vendor/sync/sync_engine.dart';
import 'package:citycalls_vendor/sync/sync_repository.dart';

import 'support/fake_backend.dart';

ApiClient _client(FakeBackend backend) {
  final client = ApiClient(baseUrl: 'https://api.test/api/v1');
  client.dio.httpClientAdapter = backend;
  return client;
}

// serviceRequests.service.ts listServiceRequests → shaped item.
Map<String, dynamic> _listItem(String id, String status, {Object? branchId = 'b1'}) => {
      '_id': id,
      'number': 'SR-$id',
      'status': status,
      'priority': 'HIGH',
      'customerId': 'c1',
      'customer': {'name': 'Amit Sharma', 'mobile': '9876543210'},
      'serviceId': 's1',
      'service': {'name': 'AC Repair'},
      'addressSnapshot': {
        'line1': 'B-204',
        'city': 'Gurugram',
        'state': 'Haryana',
        'pinCode': '122018',
        'country': 'India'
      },
      'branchId': branchId,
      'assigneeType': 'VENDOR',
      'assigneeId': 'v1',
      'symptoms': ['Not cooling'],
      'images': <String>[],
      'scheduledDate': '2026-10-22T00:00:00.000Z',
      'scheduledSlot': '10:00 AM - 12:00 PM',
      'sla': {'dueAt': '2026-10-22T12:00:00.000Z'},
      'assignee': {'type': 'VENDOR', 'name': 'CoolTech'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({
        'citycalls_access_token': 'access',
        'citycalls_refresh_token': 'refresh',
      }));

  group('Service requests', () {
    test('list items parse, including a vendor job with no branch', () {
      final job = JobSummary.fromJson(_listItem('1', 'ASSIGNED_TO_VENDOR', branchId: null));
      expect(job.serviceName, 'AC Repair');
      expect(job.customerMobile, '9876543210');
      expect(job.city, 'Gurugram');
      expect(job.scheduledSlot, '10:00 AM - 12:00 PM');
    });

    test('detail parses with customerProduct and no branchId (was a crash)', () {
      final json = {
        ..._listItem('1', 'WORK_IN_PROGRESS', branchId: null),
        'customerProduct': {
          'brand': 'Voltas',
          'productType': 'Split AC',
          'modelNumber': '183V',
          'warrantyExpiresAt': '2027-01-01T00:00:00.000Z'
        },
        'createdByName': 'Admin',
      };
      final detail = JobDetail.fromJson(json);
      expect(detail.branchId, '');
      expect(detail.product?.brand, 'Voltas');
      expect(detail.addressLine, contains('Gurugram'));
    });

    test('a vendor job awaiting response counts as new, paid ones as done', () {
      for (final s in ['ASSIGNED_TO_VENDOR', 'OUTSOURCED', 'ASSIGNED_TO_EMPLOYEE']) {
        expect(jobStatusLabel(s), 'New — Awaiting Response');
        expect(isCompletedJobStatus(s), isFalse);
      }
      // Still needs the technician to collect money — must stay in My Jobs.
      expect(isCompletedJobStatus('PAYMENT_PENDING'), isFalse);
      expect(isCompletedJobStatus('PAID'), isTrue);
    });
  });

  group('Profiles', () {
    test('GET /employees/me (populated userId/branch/team)', () {
      final p = EmployeeProfile.fromJson({
        '_id': 'e1',
        'userId': {'_id': 'u1', 'name': 'Rohit', 'mobile': '9811122233', 'email': 'r@x.in'},
        'branchId': {'_id': 'b1', 'name': 'Gurugram', 'code': 'GGN'},
        'subBranchId': {'_id': 'sb', 'name': 'Sector 49'},
        'teamId': {'_id': 't', 'name': 'AC Team'},
        'skills': ['AC'],
        'certifications': <String>[],
        'availability': [
          {'day': 1, 'available': true}
        ],
        'dailyCapacity': 6,
        'active': true,
      });
      expect(p.name, 'Rohit');
      expect(p.branchName, 'Gurugram');
      expect(p.availability.single.label, 'Monday');
    });

    test('GET /vendor-technicians/me', () {
      final p = EmployeeProfile.fromVendorTechnicianJson({
        '_id': 'vt1',
        'userId': {'name': 'Suresh', 'mobile': '9811100001'},
        'vendorId': {'_id': 'v1', 'companyName': 'CoolTech'},
        'skills': ['AC'],
        'active': true,
      });
      expect(p.isVendorTechnician, isTrue);
      expect(p.branchName, 'CoolTech');
    });

    test('vendor finance items', () {
      final inv = VendorInvoice.fromJson({
        '_id': 'i',
        'number': 'VINV-1',
        'amount': 850,
        'commissionBreakup': {
          'grossAmount': 1000,
          'commissionRate': 15,
          'commissionAmount': 150,
          'netPayable': 850
        },
        'status': 'APPROVED',
      });
      expect(inv.netAmount, 850);
      expect(inv.commissionAmount, 150);
    });
  });

  group('Invoices (finance.routes.ts)', () {
    test('a cancelled invoice is skipped in favour of the live one', () async {
      final backend = FakeBackend((r) {
        if (r.path == '/invoices') {
          expect(r.query['serviceRequestId'], 'job1');
          return FakeResponse.ok([
            {'_id': 'new', 'number': 'INV-2', 'status': 'CANCELLED', 'total': 500, 'amountPaid': 0},
            {'_id': 'old', 'number': 'INV-1', 'status': 'ISSUED', 'total': 900, 'amountPaid': 100},
          ]);
        }
        return null;
      });
      final invoice = await InvoiceRepository(_client(backend)).getInvoiceForRequest('job1');
      expect(invoice?.id, 'old');
      expect(invoice?.outstanding, 800);
    });

    test('only cancelled / converted bills means "no bill yet"', () async {
      final backend = FakeBackend((r) => r.path == '/proforma-invoices'
          ? FakeResponse.ok([
              {'_id': 'p1', 'number': 'PF-1', 'status': 'CANCELLED', 'total': 1},
              {'_id': 'p2', 'number': 'PF-2', 'status': 'CONVERTED', 'total': 1},
            ])
          : null);
      expect(await InvoiceRepository(_client(backend)).getProformaForRequest('job1'), isNull);
    });
  });

  group('Notifications (one document per channel per event)', () {
    final event = DateTime.utc(2026, 10, 22, 10);
    Map<String, dynamic> doc(String id, String channel, {int secs = 0, bool read = false, String trigger = 'SERVICE_REQUEST_ASSIGNED'}) => {
          '_id': id,
          'templateId': 't-$channel',
          'triggerKey': trigger,
          'channel': channel,
          'subject': channel == 'PUSH' ? 'New job' : null,
          'body': '$channel text',
          'status': 'SENT',
          if (read) 'readAt': event.toIso8601String(),
          'createdAt': event.add(Duration(seconds: secs)).toIso8601String(),
        };

    test('copies of one event fold into one entry; badge counts events', () async {
      final backend = FakeBackend((r) => r.path == '/notifications'
          ? FakeResponse.ok([
              doc('a', 'SMS'),
              doc('b', 'PUSH', secs: 1),
              doc('c', 'WHATSAPP', secs: 2),
              doc('d', 'IN_APP', secs: 2),
              doc('e', 'PUSH', secs: 3600, trigger: 'ESTIMATE_APPROVED', read: true),
            ])
          : null);
      final repo = NotificationRepository(_client(backend));
      final items = await repo.listNotifications();
      expect(items, hasLength(2));
      final assigned = items.firstWhere((n) => n.triggerKey == 'SERVICE_REQUEST_ASSIGNED');
      expect(assigned.body, 'IN_APP text'); // in-app copy preferred
      expect(assigned.subject, 'New job');
      expect(assigned.ids.toSet(), {'a', 'b', 'c', 'd'});
      expect(await repo.unreadCount(), 1);
    });

    test('marking read marks every channel copy', () async {
      final backend = FakeBackend((r) {
        if (r.path == '/notifications') {
          return FakeResponse.ok([doc('a', 'SMS'), doc('b', 'PUSH', secs: 1)]);
        }
        if (r.method == 'PATCH') return FakeResponse.ok({});
        return null;
      });
      final repo = NotificationRepository(_client(backend));
      final item = (await repo.listNotifications()).single;
      await repo.markRead(item);
      final patched = backend.requests.where((r) => r.method == 'PATCH').map((r) => r.path).toSet();
      expect(patched, {'/notifications/a/read', '/notifications/b/read'});
    });
  });

  group('Logout', () {
    test('revokes the refresh token on the server, then clears it', () async {
      final backend = FakeBackend((r) => r.path == '/auth/logout' ? FakeResponse.ok(null) : null);
      final client = _client(backend);
      await AuthRepository(client).logout();
      final call = backend.requests.singleWhere((r) => r.path == '/auth/logout');
      expect(call.body, {'refreshToken': 'refresh'});
      expect(await client.readRefreshToken(), isNull);
    });

    test('still logs out locally when offline', () async {
      final backend = FakeBackend((r) => throw offline(r));
      final client = _client(backend);
      await AuthRepository(client).logout();
      expect(await client.readAccessToken(), isNull);
    });
  });

  group('Offline sync queue → POST /service-requests/:id/sync-batch', () {
    late LocalDatabase db;
    late SyncRepository repo;
    setUp(() {
      db = LocalDatabase.forTesting(NativeDatabase.memory());
      repo = SyncRepository(db);
    });
    tearDown(() => db.close());

    Future<String> statusOf(int id) async => (await repo.getById(id)).status;

    test('APPLIED / REPLAYED become SYNCED, REJECTED keeps the server message', () async {
      final a = await repo.enqueue(jobId: 'j1', actionType: 'STATUS_CHANGE', payload: {'toStatus': 'ACCEPTED'});
      final b = await repo.enqueue(jobId: 'j1', actionType: 'STATUS_CHANGE', payload: {'toStatus': 'WORK_STARTED'});
      final backend = FakeBackend((r) {
        final actions = (r.body as Map)['actions'] as List;
        expect(actions.first['payload'], {'toStatus': 'ACCEPTED'});
        expect(actions.first['clientTimestamp'], isA<String>());
        return FakeResponse.ok([
          {'idempotencyKey': a.idempotencyKey, 'actionType': 'STATUS_CHANGE', 'status': 'APPLIED', 'message': 'ok'},
          {'idempotencyKey': b.idempotencyKey, 'actionType': 'STATUS_CHANGE', 'status': 'REJECTED', 'message': 'Invalid transition'},
        ]);
      });
      final ok = await SyncEngine(repo, _client(backend)).syncJob('j1');
      expect(ok, isFalse);
      expect(await statusOf(a.id), 'SYNCED');
      expect(await statusOf(b.id), 'REJECTED');
      expect((await repo.getById(b.id)).resultMessage, 'Invalid transition');
    });

    test('whole batch refused (403 menu access) → REJECTED, not stuck pending', () async {
      final a = await repo.enqueue(jobId: 'j1', actionType: 'UPDATE_WORK', payload: {'workNotes': 'x'});
      final backend = FakeBackend((r) => FakeResponse.error(403, "You don't have access to this menu"));
      await SyncEngine(repo, _client(backend)).syncJob('j1');
      expect(await statusOf(a.id), 'REJECTED');
      expect((await repo.getById(a.id)).resultMessage, "You don't have access to this menu");
    });

    test('server error or no internet → stays PENDING for a later retry', () async {
      final a = await repo.enqueue(jobId: 'j1', actionType: 'ADD_PARTS', payload: {'parts': []});
      await SyncEngine(repo, _client(FakeBackend((r) => FakeResponse.error(503, 'down')))).syncJob('j1');
      expect(await statusOf(a.id), 'PENDING');
      await SyncEngine(repo, _client(FakeBackend((r) => throw offline(r)))).syncJob('j1');
      expect(await statusOf(a.id), 'PENDING');
    });

    test('a rejected status change surfaces as an error on screen', () async {
      final backend = FakeBackend((r) {
        final key = (((r.body as Map)['actions'] as List).single as Map)['idempotencyKey'];
        return FakeResponse.ok([
          {'idempotencyKey': key, 'actionType': 'STATUS_CHANGE', 'status': 'REJECTED', 'message': 'Not allowed'}
        ]);
      });
      final client = _client(backend);
      final jobs = JobRepository(client, repo, SyncEngine(repo, client));
      expect(() => jobs.changeStatus('j1', 'ACCEPTED'), throwsA(isA<SyncRejectedException>()));
    });
  });

  group('Field actions payloads match serviceVisits.validation.ts', () {
    late LocalDatabase db;
    late SyncRepository repo;
    setUp(() {
      db = LocalDatabase.forTesting(NativeDatabase.memory());
      repo = SyncRepository(db);
    });
    tearDown(() => db.close());

    test('parts / work / completion bodies use the API field names', () async {
      final sent = <Map>[];
      final backend = FakeBackend((r) {
        final action = ((r.body as Map)['actions'] as List).single as Map;
        sent.add(action);
        return FakeResponse.ok([
          {'idempotencyKey': action['idempotencyKey'], 'actionType': action['actionType'], 'status': 'APPLIED', 'message': 'ok'}
        ]);
      });
      final client = _client(backend);
      final jobs = JobRepository(client, repo, SyncEngine(repo, client));
      await jobs.addParts('j1', [PartEntry(name: 'Capacitor', qty: 2, unitPrice: 150)]);
      await jobs.updateWork('j1', labourCharge: 300, workNotes: 'Gas refilled');
      await jobs.completeVisit('j1', proofType: 'APP_CONFIRMATION');
      await jobs.updateInspection('j1', defectFound: 'Leak', symptoms: ['Not cooling']);

      expect(sent[0]['actionType'], 'ADD_PARTS');
      expect(sent[0]['payload'], {
        'parts': [
          {'name': 'Capacitor', 'qty': 2, 'unitPrice': 150.0}
        ]
      });
      expect(sent[1]['payload'], {'labourCharge': 300.0, 'workNotes': 'Gas refilled'});
      expect(sent[2]['payload'], {
        'completionProof': {'type': 'APP_CONFIRMATION'}
      });
      expect(sent[3]['payload'], {'defectFound': 'Leak', 'symptoms': ['Not cooling']});
    });
  });

  group('Reschedule & visits', () {
    test('slots and reschedule hit the right endpoints', () async {
      final backend = FakeBackend((r) {
        if (r.path == '/appointment-slots') {
          expect(r.query, {'branchId': 'b1', 'date': '2026-10-25'});
          return FakeResponse.ok({
            'dayClosed': false,
            'slots': [
              {'key': 'M', 'label': '10:00 AM - 12:00 PM', 'capacity': 5, 'booked': 5, 'remaining': 0, 'available': false},
              {'key': 'E', 'label': '4:00 PM - 6:00 PM', 'capacity': 5, 'booked': 1, 'remaining': 4, 'available': true},
            ]
          });
        }
        if (r.path == '/service-requests/j1/reschedule') {
          expect(r.method, 'PATCH');
          expect((r.body as Map)['scheduledSlot'], '4:00 PM - 6:00 PM');
          expect((r.body as Map)['scheduledDate'], startsWith('2026-10-25'));
          return FakeResponse.ok({});
        }
        return null;
      });
      final db = LocalDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final client = _client(backend);
      final repo = SyncRepository(db);
      final jobs = JobRepository(client, repo, SyncEngine(repo, client));
      final slots = await jobs.getAppointmentSlots('b1', DateTime(2026, 10, 25));
      expect(slots.slots.where((s) => s.available).single.remaining, 4);
      await jobs.reschedule('j1', date: DateTime(2026, 10, 25), slot: '4:00 PM - 6:00 PM');
    });

    test('a full slot comes back as a readable error', () async {
      final backend = FakeBackend((r) => FakeResponse.error(409, 'This time slot is fully booked, please pick another'));
      final db = LocalDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final client = _client(backend);
      final repo = SyncRepository(db);
      final jobs = JobRepository(client, repo, SyncEngine(repo, client));
      expect(
          () => jobs.reschedule('j1', date: DateTime(2026, 10, 25), slot: 'x'),
          throwsA(isA<SyncRejectedException>().having(
              (e) => e.message, 'message', contains('fully booked'))));
    });

    test('visit record parses (GET /service-requests/:id/visits)', () async {
      final backend = FakeBackend((r) => FakeResponse.ok([
            {
              '_id': 'v2',
              'visitNumber': 2,
              'inspection': {'symptoms': <String>[]},
              'parts': <Map>[],
              'beforeImages': <String>[],
              'afterImages': <String>[],
            },
            {
              '_id': 'v1',
              'visitNumber': 1,
              'technicianId': 'u1',
              'inspection': {'defectFound': 'Gas leak', 'symptoms': ['Not cooling'], 'solutionType': 'Refill'},
              'parts': [
                {'_id': 'p', 'name': 'Gas', 'qty': 1, 'unitPrice': 1200}
              ],
              'labourCharge': 400,
              'workNotes': 'Refilled',
              'beforeImages': ['https://x/b.jpg'],
              'afterImages': ['https://x/a.jpg'],
              'completedAt': '2026-10-22T10:00:00.000Z',
              'completionProof': {'type': 'OTP', 'value': 'hashed'},
            },
          ]));
      final db = LocalDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final client = _client(backend);
      final repo = SyncRepository(db);
      final visits = await JobRepository(client, repo, SyncEngine(repo, client)).getVisits('j1');
      expect(visits.map((v) => v.visitNumber), [1, 2]);
      expect(visits.first.parts.single.total, 1200);
      expect(visits.first.hasContent, isTrue);
      expect(visits.last.hasContent, isFalse);
    });
  });
}
