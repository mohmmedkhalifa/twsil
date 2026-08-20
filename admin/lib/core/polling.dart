import 'dart:async';
import 'package:flutter/widgets.dart';

/// Adds light polling (~10s) so admin screens stay in sync with the backend
/// without tying the whole app to WebSockets.
mixin PollingMixin<T extends StatefulWidget> on State<T> {
  Timer? _poll;
  Duration pollEvery = const Duration(seconds: 10);

  void startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(pollEvery, (_) {
      if (mounted) onPoll();
    });
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  void onPoll();

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}