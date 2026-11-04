import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layer rules, checked on every test run. Copy this into your app.
void main() {
  List<File> dartFiles(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  List<String> filesImporting(Iterable<File> files, String import) => [
    for (final file in files)
      if (file.readAsStringSync().contains(import)) file.path,
  ];

  const store = 'lib/modules/store';

  test('only data/ and main.dart know about reusable_iap', () {
    final outsiders = dartFiles('lib').where(
      (file) =>
          !file.path.contains('/data/') && !file.path.endsWith('main.dart'),
    );

    expect(filesImporting(outsiders, 'package:reusable_iap/'), isEmpty);
  });

  test('domain is plain Dart that depends on no outer layer', () {
    final domain = dartFiles('$store/domain');

    expect(domain, isNotEmpty);
    expect(filesImporting(domain, 'package:flutter/'), isEmpty);
    expect(filesImporting(domain, '/data/'), isEmpty);
    expect(filesImporting(domain, '/presentation/'), isEmpty);
  });

  test('presentation never reaches into data', () {
    final presentation = dartFiles('$store/presentation');

    expect(presentation, isNotEmpty);
    expect(filesImporting(presentation, '/data/'), isEmpty);
  });
}
