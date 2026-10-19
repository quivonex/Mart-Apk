// lib/utils/login_gate.dart
//
// Shared "please log in" check for screens that call login-only APIs.
//
//   if (!await ensureLoggedIn(context, reason: 'send an enquiry')) return;

import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import 'shared_preferences_helper.dart';

/// True when the user has a token. Otherwise asks to log in (opens
/// [LoginScreen]) and returns false – the caller should stop.
Future<bool> ensureLoggedIn(BuildContext context, {String reason = 'continue'}) async {
  final token = await SharedPreferencesHelper.getAccessToken();
  if (token != null && token.isNotEmpty) return true;
  if (!context.mounted) return false;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
        child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6366F1), size: 28),
      ),
      title: const Text('Login required', textAlign: TextAlign.center),
      content: Text('Please log in to $reason.', textAlign: TextAlign.center),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Login'),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }
  return false;
}
