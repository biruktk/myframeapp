import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/pairing_nav_result.dart';
import 'app_diag_log.dart';

/// Production-safe error handling: no red Flutter error screens for users.
class AppReleaseGuard {
  AppReleaseGuard._();

  static void init() {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      AppDiagLog.verbose(
        '[FlutterError] ${details.exceptionAsString()}',
      );
      return const _FriendlyErrorPanel();
    };

    final prev = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      onUncaughtError(error, stack);
      return prev?.call(error, stack) ?? true;
    };
  }

  static void onUncaughtError(Object error, StackTrace stack) {
    AppDiagLog.verbose('[Uncaught] $error\n$stack');
  }

  /// Runs [action]; on failure logs and returns [onError] (or null).
  static Future<T?> guard<T>(
    Future<T> Function() action, {
    T? Function(Object error, StackTrace stack)? onError,
    String? logLabel,
  }) async {
    try {
      return await action();
    } catch (e, st) {
      if (logLabel != null) {
        AppDiagLog.verbose('$logLabel: $e\n$st');
      } else {
        AppDiagLog.verbose('guard: $e\n$st');
      }
      return onError?.call(e, st);
    }
  }

  static void guardSync(
    VoidCallback action, {
    void Function(Object error, StackTrace stack)? onError,
    String? logLabel,
  }) {
    try {
      action();
    } catch (e, st) {
      if (logLabel != null) {
        AppDiagLog.verbose('$logLabel: $e\n$st');
      } else {
        AppDiagLog.verbose('guardSync: $e\n$st');
      }
      onError?.call(e, st);
    }
  }
}

/// Navigator helpers that avoid type mismatches and `_debugLocked` races.
class SafeNav {
  SafeNav._();

  static PairingNavResult asPairingResult(Object? value) {
    if (value is PairingNavResult) return value;
    if (value == true) {
      return const PairingNavResult(success: true, openSendGallery: true);
    }
    return const PairingNavResult(success: false);
  }

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Route<T> route,
  ) async {
    if (!context.mounted) return null;
    try {
      return await Navigator.of(context).push<T>(route);
    } catch (e, st) {
      AppDiagLog.verbose('SafeNav.push: $e\n$st');
      return null;
    }
  }

  static Future<void> popAfterFrame<T extends Object?>(
    BuildContext context, {
    T? result,
  }) async {
    if (!context.mounted) return;
    await SchedulerBinding.instance.endOfFrame;
    if (!context.mounted) return;
    try {
      Navigator.of(context).pop<T>(result);
    } catch (e, st) {
      AppDiagLog.verbose('SafeNav.pop: $e\n$st');
    }
  }

  static Future<void> popPairingResult(
    BuildContext context, {
    required PairingNavResult result,
  }) =>
      popAfterFrame<PairingNavResult>(context, result: result);
}

class _FriendlyErrorPanel extends StatelessWidget {
  const _FriendlyErrorPanel();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Color(0xFF9E9E9E)),
                SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212121),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Unable to load this view. Go back and try again.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF757575)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
