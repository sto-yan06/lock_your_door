import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class LoggingService {
  // Private constructor
  LoggingService._();

  static Logger? _logger;
  static File? _logFile;

  static Future<void> _init() async {
    if (_logger != null) return;

    // Create a file to store logs
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/app_logs.txt');

    _logger = Logger(
      // Set the log level based on the build mode (e.g., show more logs in debug)
      level: kDebugMode ? Level.debug : Level.info,
      // Use MultiOutput to log to both console and file
      output: MultiOutput([
        ConsoleOutput(),
        FileOutput(
          file: _logFile!,
          overrideExisting: true, // Start with a fresh log file each time
          encoding: const SystemEncoding(),
        ),
      ]),
      printer: PrettyPrinter(
        methodCount: 1, // number of method calls to be displayed
        errorMethodCount: 8, // number of method calls if stacktrace is provided
        lineLength: 120, // width of the log print
        colors: true, // Colorful log messages
        printEmojis: true, // Print an emoji for each log message
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart, // Replaces the deprecated printTime
      ),
    );

    info('Logging service initialized. Log file at: ${_logFile?.path}');
  }

  static Future<void> _log(Function(Logger) logFunction) async {
    // Ensure logger is initialized before first use
    if (_logger == null) {
      await _init();
    }
    logFunction(_logger!);
  }

  /// Log a message at level [Level.debug].
  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log((logger) => logger.d(message, error: error, stackTrace: stackTrace));
  }

  /// Log a message at level [Level.info].
  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log((logger) => logger.i(message, error: error, stackTrace: stackTrace));
  }

  /// Log a message at level [Level.warning].
  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log((logger) => logger.w(message, error: error, stackTrace: stackTrace));
  }

  /// Log a message at level [Level.error].
  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log((logger) => logger.e(message, error: error, stackTrace: stackTrace));
  }

  /// Optional: A method to get the log file content for bug reports
  static Future<String?> getLogFileContent() async {
    if (_logFile != null && await _logFile!.exists()) {
      return _logFile!.readAsString();
    }
    return null;
  }
}