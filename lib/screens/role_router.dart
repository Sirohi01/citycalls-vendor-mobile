import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import 'main_shell.dart';
import 'vendor_owner_shell.dart';

// Single place deciding which shell a logged-in user lands in — EMPLOYEE/
// TECHNICIAN/VENDOR_TECHNICIAN all do field work (MainShell); VENDOR_OWNER/
// VENDOR_MANAGER manage a company instead (VendorOwnerShell). Used by both
// otp_verify_screen.dart (fresh login) and splash_screen.dart (session restore).
Widget homeScreenForUser(AuthUser user) {
  if (user.isVendorManagement) return const VendorOwnerShell();
  return const MainShell();
}
