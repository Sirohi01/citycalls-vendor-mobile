// Renders every screen at phone size with fake data and writes a PNG per
// screen to test/shots/. Not a regression test — a way to LOOK at the whole
// app without a device, and to catch layout overflows (which fail a widget
// test). Run with:
//
//   flutter test test/screenshots_test.dart --update-goldens
//
// The PNGs are git-ignored; Roboto/Material Icons are loaded from the Flutter
// SDK so text renders as on Android rather than as test-font boxes.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citycalls_vendor/models/auth_models.dart';
import 'package:citycalls_vendor/models/employee_models.dart';
import 'package:citycalls_vendor/models/invoice_models.dart';
import 'package:citycalls_vendor/models/job_models.dart';
import 'package:citycalls_vendor/models/notification_models.dart';
import 'package:citycalls_vendor/models/vendor_models.dart';
import 'package:citycalls_vendor/providers/auth_providers.dart';
import 'package:citycalls_vendor/providers/employee_providers.dart';
import 'package:citycalls_vendor/providers/job_providers.dart';
import 'package:citycalls_vendor/providers/location_providers.dart';
import 'package:citycalls_vendor/providers/notification_providers.dart';
import 'package:citycalls_vendor/providers/sync_providers.dart';
import 'package:citycalls_vendor/providers/vendor_management_providers.dart';
import 'package:citycalls_vendor/screens/completion_screen.dart';
import 'package:citycalls_vendor/screens/dashboard_screen.dart';
import 'package:citycalls_vendor/screens/estimate_form_screen.dart';
import 'package:citycalls_vendor/screens/inspection_form_screen.dart';
import 'package:citycalls_vendor/screens/invoice_screen.dart';
import 'package:citycalls_vendor/screens/job_detail_screen.dart';
import 'package:citycalls_vendor/screens/job_history_screen.dart';
import 'package:citycalls_vendor/screens/my_jobs_screen.dart';
import 'package:citycalls_vendor/screens/notification_center_screen.dart';
import 'package:citycalls_vendor/screens/otp_request_screen.dart';
import 'package:citycalls_vendor/screens/otp_verify_screen.dart';
import 'package:citycalls_vendor/screens/parts_entry_screen.dart';
import 'package:citycalls_vendor/screens/profile_screen.dart';
import 'package:citycalls_vendor/screens/signature_capture_screen.dart';
import 'package:citycalls_vendor/screens/sync_status_screen.dart';
import 'package:citycalls_vendor/screens/vendor_dashboard_screen.dart';
import 'package:citycalls_vendor/screens/vendor_payouts_screen.dart';
import 'package:citycalls_vendor/screens/vendor_roster_screen.dart';
import 'package:citycalls_vendor/screens/work_progress_screen.dart';
import 'package:citycalls_vendor/sync/local_database.dart';
import 'package:citycalls_vendor/theme/app_theme.dart';
import 'package:citycalls_vendor/widgets/app_bottom_nav.dart';

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final dir = '$flutterRoot/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.view(File('$dir/$name').readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto')
    ..addFont(read('Roboto-Regular.ttf'))
    ..addFont(read('Roboto-Medium.ttf'))
    ..addFont(read('Roboto-Bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

// Component styles in AppTheme that set no fontFamily (buttons, app bar
// titles) use the platform default font — Roboto on a phone, but the block
// test font here. Pin them to Roboto so the renders match a real device.
ThemeData _withRoboto(ThemeData t) {
  TextStyle? f(TextStyle? s) => s?.copyWith(fontFamily: 'Roboto');
  ButtonStyle? b(ButtonStyle? style) => style?.copyWith(
      textStyle: WidgetStateProperty.resolveWith(
          (states) => f(style.textStyle?.resolve(states))));
  return t.copyWith(
    appBarTheme:
        t.appBarTheme.copyWith(titleTextStyle: f(t.appBarTheme.titleTextStyle)),
    filledButtonTheme:
        FilledButtonThemeData(style: b(t.filledButtonTheme.style)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: b(t.outlinedButtonTheme.style)),
    elevatedButtonTheme:
        ElevatedButtonThemeData(style: b(t.elevatedButtonTheme.style)),
    textButtonTheme: TextButtonThemeData(style: b(t.textButtonTheme.style)),
    chipTheme: t.chipTheme.copyWith(labelStyle: f(t.chipTheme.labelStyle)),
    dialogTheme:
        t.dialogTheme.copyWith(titleTextStyle: f(t.dialogTheme.titleTextStyle)),
    listTileTheme: t.listTileTheme.copyWith(
        titleTextStyle: f(t.listTileTheme.titleTextStyle),
        subtitleTextStyle: f(t.listTileTheme.subtitleTextStyle)),
  );
}

final _now = DateTime.now();

JobSummary _job(String n, String status,
        {String service = 'AC Repair & Service',
        String customer = 'Amit Sharma',
        String priority = 'NORMAL',
        int dayOffset = 0}) =>
    JobSummary(
      id: 'job$n',
      number: 'SR-2026-00$n',
      status: status,
      priority: priority,
      serviceName: service,
      customerName: customer,
      customerMobile: '9876543210',
      city: 'Gurugram',
      scheduledDate: _now.add(Duration(days: dayOffset)),
      scheduledSlot: '10:00 AM - 12:00 PM',
    );

final _jobs = [
  _job('41', 'ASSIGNED_TO_VENDOR', priority: 'URGENT'),
  _job('42', 'TECHNICIAN_EN_ROUTE',
      service: 'Washing Machine Repair', customer: 'Priya Verma'),
  _job('43', 'WORK_IN_PROGRESS',
      service: 'Refrigerator Gas Refill', customer: 'Rahul Gupta'),
  _job('44', 'PAYMENT_PENDING',
      service: 'RO Water Purifier Service', customer: 'Sunita Devi'),
  _job('38', 'PAID', service: 'Chimney Cleaning', dayOffset: -1),
  _job('37', 'CLOSED', service: 'TV Wall Mounting', dayOffset: -2),
  _job('36', 'CANCELLED', service: 'AC Installation', dayOffset: -3),
];

JobDetail _detail(String status) => JobDetail(
      id: 'job41',
      number: 'SR-2026-0041',
      serviceId: 'svc1',
      status: status,
      priority: 'URGENT',
      serviceName: 'AC Repair & Service',
      customerName: 'Amit Sharma',
      customerMobile: '9876543210',
      customerId: 'cust1',
      branchId: 'branch1',
      addressLine: 'B-204, Palm Heights, Sector 49, Gurugram, Haryana, 122018',
      symptoms: const ['Not cooling', 'Water leaking', 'Unusual noise'],
      notes: 'AC stopped cooling since yesterday evening. Please bring gas.',
      images: const [],
      scheduledDate: _now,
      scheduledSlot: '10:00 AM - 12:00 PM',
      slaDueAt: _now.add(const Duration(hours: 5)),
      product: CustomerProductInfo(
          brand: 'Voltas',
          productType: 'Split AC',
          modelNumber: '183V CZT',
          warrantyExpiresAt: _now.add(const Duration(days: 120))),
    );

final _profile = EmployeeProfile(
  id: 'e1',
  name: 'Rohit Kumar',
  mobile: '9811122233',
  email: 'rohit@citycalls.in',
  branchName: 'Gurugram Central',
  subBranchName: 'Sector 49',
  teamName: 'AC Team A',
  skills: const ['AC Repair', 'Refrigerator', 'Washing Machine'],
  certifications: const ['HVAC Level 2'],
  availability:
      List.generate(7, (d) => AvailabilityDay(day: d, available: d != 0)),
  dailyCapacity: 6,
  active: true,
);

PendingAction _action(int id, String type, String status,
        {String payload = '{}', String? message}) =>
    PendingAction(
      id: id,
      jobId: 'job4$id',
      actionType: type,
      payloadJson: payload,
      idempotencyKey: 'k$id',
      clientTimestamp: _now.subtract(Duration(minutes: 7 * id)),
      status: status,
      resultMessage: message,
      createdAt: _now,
    );

final _queue = [
  _action(1, 'STATUS_CHANGE', 'REJECTED',
      payload: '{"toStatus":"WORK_STARTED"}',
      message: 'Invalid transition from ACCEPTED to WORK_STARTED'),
  _action(2, 'ADD_PARTS', 'PENDING'),
  _action(3, 'UPDATE_WORK', 'PENDING'),
  _action(4, 'UPDATE_INSPECTION', 'SYNCED'),
];

class _FakeAuth extends AuthNotifier {
  _FakeAuth(Ref ref, AuthState initial)
      : super(ref.read(authRepositoryProvider), ref.read(apiClientProvider)) {
    state = initial;
  }
}

List<Override> _overrides({String role = 'TECHNICIAN', bool otpSent = false}) =>
    [
      authProvider.overrideWith((ref) => _FakeAuth(
          ref,
          AuthState(
              step: otpSent ? AuthStep.otpSent : AuthStep.loggedIn,
              mobile: '9811122233',
              sessionChecked: true,
              user: otpSent
                  ? null
                  : AuthUser(
                      id: 'u1',
                      name: 'Rohit Kumar',
                      role: role,
                      vendorId: 'v1')))),
      myEmployeeProfileProvider.overrideWith((ref) => _profile),
      allJobsProvider.overrideWith((ref) => _jobs),
      unreadNotificationCountProvider.overrideWith((ref) => 3),
      pendingActionsProvider.overrideWith((ref) => Stream.value(_queue)),
      locationPermissionProvider
          .overrideWith((ref) => LocationPermissionState.denied),
      serviceDiagnosticsProvider.overrideWith((ref, id) => ServiceDiagnostics(
            symptoms: [
              MasterOption(id: 's1', label: 'Not cooling'),
              MasterOption(id: 's2', label: 'Water leaking'),
              MasterOption(id: 's3', label: 'Unusual noise'),
            ],
            defects: [
              MasterOption(id: 'd1', label: 'Gas leakage'),
              MasterOption(id: 'd2', label: 'Compressor fault'),
            ],
            solutionTypes: [
              MasterOption(id: 'x1', label: 'Gas refill'),
              MasterOption(id: 'x2', label: 'Part replacement'),
            ],
          )),
      notificationsProvider.overrideWith((ref) => [
            AppNotification(
                id: 'n1',
                subject: 'New job assigned',
                body:
                    'SR-2026-0041 — AC Repair & Service in Gurugram has been assigned to you.',
                channel: 'PUSH',
                status: 'SENT',
                createdAt: _now.subtract(const Duration(minutes: 12))),
            AppNotification(
                id: 'n2',
                subject: 'Estimate approved',
                body: 'The customer approved the estimate for SR-2026-0043.',
                channel: 'PUSH',
                status: 'SENT',
                readAt: _now,
                createdAt: _now.subtract(const Duration(hours: 3))),
          ]),
      ownVendorProvider.overrideWith((ref) => VendorCompany(
          id: 'v1',
          companyName: 'CoolTech Services Pvt Ltd',
          active: true,
          blacklisted: false)),
      vendorJobsProvider.overrideWith((ref) => _jobs),
      vendorTechniciansProvider.overrideWith((ref) => [
            VendorTechnicianEntry(
                id: 't1',
                name: 'Suresh Yadav',
                mobile: '9811100001',
                skills: const ['AC Repair', 'Refrigerator'],
                active: true),
            VendorTechnicianEntry(
                id: 't2',
                name: 'Imran Khan',
                mobile: '9811100002',
                skills: const ['Washing Machine'],
                active: true),
            VendorTechnicianEntry(
                id: 't3',
                name: 'Deepak Singh',
                skills: const [],
                active: false),
          ]),
      vendorInvoicesProvider.overrideWith((ref) => [
            VendorInvoice(
                id: 'i1',
                number: 'VINV-0012',
                grossAmount: 18500,
                commissionAmount: 2775,
                netAmount: 15725,
                status: 'APPROVED'),
          ]),
      vendorPayoutsProvider.overrideWith((ref) => [
            VendorPayout(
                id: 'p1',
                number: 'PO-0007',
                amount: 15725,
                status: 'PAID',
                reference: 'UTR 4412900871'),
            VendorPayout(
                id: 'p2', number: 'PO-0008', amount: 9200, status: 'PENDING'),
          ]),
    ];

void main() {
  setUpAll(_loadFonts);

  // One screen → one PNG. [extra] adds per-shot overrides (e.g. the job
  // status); [setup] can interact before the capture.
  void shot(
    String name,
    Widget screen, {
    List<Override> extra = const [],
    String role = 'TECHNICIAN',
    bool otpSent = false,
    Future<void> Function(WidgetTester tester)? setup,
  }) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        overrides: [..._overrides(role: role, otpSent: otpSent), ...extra],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _withRoboto(AppTheme.light()),
          home: screen,
        ),
      ));
      // Asset images decode asynchronously — let them finish for real.
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pump(const Duration(milliseconds: 1200));
      if (setup != null) await setup(tester);
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));

      // Unmount so periodic timers (OTP countdown etc.) are cancelled.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Widget withNav(Widget body, int index, {bool vendor = false}) => Scaffold(
        body: body,
        bottomNavigationBar: AppBottomNav(
          currentIndex: index,
          onTap: (_) {},
          items: vendor
              ? const [
                  AppNavItemData(
                      icon: Icons.space_dashboard_outlined,
                      activeIcon: Icons.space_dashboard_rounded,
                      label: 'Home'),
                  AppNavItemData(
                      icon: Icons.groups_outlined,
                      activeIcon: Icons.groups_rounded,
                      label: 'Roster'),
                  AppNavItemData(
                      icon: Icons.payments_outlined,
                      activeIcon: Icons.payments_rounded,
                      label: 'Payouts'),
                ]
              : const [
                  AppNavItemData(
                      icon: Icons.space_dashboard_outlined,
                      activeIcon: Icons.space_dashboard_rounded,
                      label: 'Home'),
                  AppNavItemData(
                      icon: Icons.work_outline_rounded,
                      activeIcon: Icons.work_rounded,
                      label: 'My Jobs',
                      badge: 1),
                  AppNavItemData(
                      icon: Icons.history_rounded,
                      activeIcon: Icons.history_rounded,
                      label: 'History'),
                  AppNavItemData(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile'),
                ],
        ),
      );

  List<Override> detail(String status) => [
        jobDetailProvider.overrideWith((ref, id) => _detail(status)),
      ];

  shot('01_login', const OtpRequestScreen());
  shot('02_otp', const OtpVerifyScreen(), otpSent: true);
  shot('03_home', withNav(const DashboardScreen(), 0));
  shot('04_my_jobs', withNav(const MyJobsScreen(), 1));
  shot('05_history', withNav(const JobHistoryScreen(), 2));
  shot('06_profile', withNav(const ProfileScreen(), 3));
  shot('07_job_new', const JobDetailScreen(jobId: 'job41'),
      extra: detail('ASSIGNED_TO_VENDOR'));
  shot('08_job_working', const JobDetailScreen(jobId: 'job41'),
      extra: detail('WORK_IN_PROGRESS'));
  shot('09_job_waiting', const JobDetailScreen(jobId: 'job41'),
      extra: detail('AWAITING_CUSTOMER_APPROVAL'));
  shot('10_inspection', const InspectionFormScreen(jobId: 'job41'),
      extra: detail('INSPECTION_STARTED'));
  shot('11_work_progress', const WorkProgressScreen(jobId: 'job41'));
  shot('12_parts_empty', const PartsEntryScreen(jobId: 'job41'));
  shot('13_parts_sheet', const PartsEntryScreen(jobId: 'job41'),
      setup: (tester) async {
    await tester.tap(find.text('Add Part').last);
    await tester.pump(const Duration(milliseconds: 600));
  });
  shot('14_estimate', EstimateFormScreen(job: _detail('INSPECTION_COMPLETED')));
  shot('15_complete', const CompletionScreen(jobId: 'job41'));
  shot('16_signature', const SignatureCaptureScreen());
  shot('17_invoice_create', InvoiceScreen(job: _detail('PAYMENT_PENDING')),
      extra: [
        invoiceForRequestProvider.overrideWith((ref, id) => null),
        proformaForRequestProvider.overrideWith((ref, id) => null),
        approvedEstimateForRequestProvider.overrideWith((ref, id) => null),
      ]);
  shot('18_invoice_pay', InvoiceScreen(job: _detail('PARTIALLY_PAID')), extra: [
    invoiceForRequestProvider.overrideWith((ref, id) => Invoice(
        id: 'inv1',
        number: 'INV-2026-0098',
        status: 'PARTIALLY_PAID',
        total: 4850,
        amountPaid: 2000)),
    paymentsForInvoiceProvider.overrideWith((ref, id) => [
          PaymentReceipt(
              number: 'RCPT-0211',
              method: 'UPI',
              amount: 2000,
              reference: 'UPI 3391')
        ]),
  ]);
  shot('19_invoice_proforma', InvoiceScreen(job: _detail('PAYMENT_PENDING')),
      extra: [
        invoiceForRequestProvider.overrideWith((ref, id) => null),
        proformaForRequestProvider.overrideWith((ref, id) => ProformaInvoice(
            id: 'pf1', number: 'PF-0031', status: 'SHARED', total: 4850)),
      ]);
  shot('20_sync', const SyncStatusScreen());
  shot('21_notifications', const NotificationCenterScreen());
  shot('22_vendor_home',
      withNav(VendorDashboardScreen(onLogout: () {}), 0, vendor: true),
      role: 'VENDOR_OWNER');
  shot(
      '23_vendor_roster',
      withNav(
          Scaffold(
              appBar: AppBar(title: const Text('Technicians')),
              body: const VendorRosterScreen()),
          1,
          vendor: true),
      role: 'VENDOR_OWNER');
  shot(
      '24_vendor_payouts',
      withNav(
          Scaffold(
              appBar: AppBar(title: const Text('Invoices & Payouts')),
              body: const VendorPayoutsScreen()),
          2,
          vendor: true),
      role: 'VENDOR_OWNER');
}
