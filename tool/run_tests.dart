#!/usr/bin/env dart
// Copyright (c) 2025, Klas Kalaß <habbatical@gmail.com>
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/// Script to run all tests with code coverage
///
/// Usage: dart tool/run_tests.dart
library;

import 'dart:io';

Future<void> main() async {
  print('Running tests with coverage...');

  // Run tests with coverage
  final testProcess = await Process.start(
      'dart',
      [
        'test',
        '--coverage=coverage',
      ],
      mode: ProcessStartMode.inheritStdio);

  final exitCode = await testProcess.exitCode;
  if (exitCode != 0) {
    print('Tests failed with exit code $exitCode');
    exit(exitCode);
  }

  print('Converting coverage data to LCOV format...');
  final formatProcess = await Process.start(
      'dart',
      [
        'run',
        'coverage:format_coverage',
        '--lcov',
        '--in=coverage',
        '--out=coverage/lcov.info',
        '--packages=.dart_tool/package_config.json',
        '--report-on=lib',
      ],
      mode: ProcessStartMode.inheritStdio);

  final formatExitCode = await formatProcess.exitCode;
  if (formatExitCode != 0) {
    print('Coverage formatting failed with exit code $formatExitCode');
    exit(formatExitCode);
  }

  // Generate HTML report if lcov is installed
  try {
    print('Generating HTML coverage report...');
    final lcovProcess = await Process.start(
        'genhtml',
        [
          'coverage/lcov.info',
          '-o',
          'coverage/html',
        ],
        mode: ProcessStartMode.inheritStdio);

    final lcovExitCode = await lcovProcess.exitCode;
    if (lcovExitCode != 0) {
      print('HTML report generation failed with exit code $lcovExitCode');
    } else {
      print('HTML coverage report generated at coverage/html/index.html');
    }
  } catch (e) {
    print('Could not generate HTML report. Make sure lcov is installed.');
    print('On macOS: brew install lcov');
    print('On Ubuntu: apt-get install lcov');
  }

  print('Tests completed successfully!');
}
