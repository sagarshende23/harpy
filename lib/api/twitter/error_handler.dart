import 'dart:async';

import 'package:flushbar/flushbar.dart';
import 'package:harpy/core/misc/flushbar_service.dart';
import 'package:harpy/core/utils/string_utils.dart';
import 'package:harpy/harpy.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

Logger _log = Logger("Error handler");

/// Handles the [error] from a request.
///
/// An error message is shown in a [Flushbar] when the [error] has been handled.
///
/// If the error hasn't been handled and [backupErrorMessage] is set, the
/// [backupErrorMessage] is shown in a [Flushbar].
void twitterClientErrorHandler(dynamic error, [String backupErrorMessage]) {
  final flushbarService = app<FlushbarService>();

  _log.fine("handling error: $error");

  if (error is String) {
    flushbarService.error(error);
    return;
  }

  if (error is Response) {
    if (_reachedRateLimit(error)) {
      final limitReset = _limitResetString(error);

      _log.fine("rate limit reached, reset in $limitReset");

      final message = limitReset != null
          ? "Rate limit reached.\nPlease try again in $limitReset."
          : "Rate limit reached.\nPlease try again later.";

      flushbarService.error(message);
      return;
    }

    _log.severe("unhandled response exception\n"
        "statuscode: ${error.statusCode}\n"
        "body: ${error.body}");
  }

  if (error is TimeoutException) {
    flushbarService.error("Request timed out");
    return;
  }

  if (backupErrorMessage != null) {
    flushbarService.error(backupErrorMessage);
    return;
  }

  _log.warning("error not handled");

  // todo: maybe allow to report the error through a flushbar action
  flushbarService.error("An unexpected error occurred");
}

bool _reachedRateLimit(Response response) => response.statusCode == 429;

String _limitResetString(Response response) {
  try {
    final limitReset = int.parse(response.headers["x-rate-limit-reset"]);

    return prettyPrintDurationDifference(
        DateTime.fromMillisecondsSinceEpoch(limitReset * 1000)
            .difference(DateTime.now()));
  } catch (e) {
    return null;
  }
}
