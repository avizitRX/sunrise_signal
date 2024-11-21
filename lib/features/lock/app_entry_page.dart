// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:sunrise_signal/features/calendar/calendar_page.dart';
// import '../../services/auth_service.dart';
// import 'lock_screen.dart';

// class AppEntryPage extends StatefulWidget {
//   const AppEntryPage({Key? key}) : super(key: key);

//   @override
//   State<AppEntryPage> createState() => _AppEntryPageState();
// }

// class _AppEntryPageState extends State<AppEntryPage> {
//   bool _isLocked = false;

//   @override
//   void initState() {
//     super.initState();
//     _checkLockStatus();
//   }

//   Future<void> _checkLockStatus() async {
//     final authService = Provider.of<AuthService>(context, listen: false);

//     // Check if either passcode or biometric is set
//     final passcodeExists = await authService.getPasscode() != null;
//     final biometricEnabled = await authService.isBiometricEnabled();

//     setState(() {
//       _isLocked = passcodeExists || biometricEnabled;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return _isLocked ? const LockScreen() : const CalendarPage();
//   }
// }
