class ErrorFormatter {
  /// Converts raw exceptions or technical error messages into user-friendly text.
  static String format(dynamic error, {String? defaultMsg}) {
    if (error == null) {
      return defaultMsg ?? "Something went wrong. Please wait a moment and try again.";
    }

    final errStr = error.toString().toLowerCase();

    if (errStr.contains("socketexception") ||
        errStr.contains("clientexception") ||
        errStr.contains("connection reset") ||
        errStr.contains("timeout") ||
        errStr.contains("handshakeexception") ||
        errStr.contains("network_error") ||
        errStr.contains("failed host lookup")) {
      return "Network connection issue. Please wait a moment and try again.";
    }

    if (error is String &&
        !errStr.contains("exception") &&
        !errStr.contains("error:") &&
        !errStr.contains("errno") &&
        !errStr.contains("http") &&
        error.trim().isNotEmpty) {
      return error;
    }

    return defaultMsg ?? "Something went wrong. Please wait a moment and try again.";
  }
}
