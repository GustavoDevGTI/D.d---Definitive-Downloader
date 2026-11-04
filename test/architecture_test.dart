import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';

Future<Map<String, String>> sources() async => {
      await for (final file in Directory('lib').list(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          p.normalize(p.absolute(file.path)): await file.readAsString()
    };
final directives =
    RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);
void main() {
  test('módulos Dart de produção não têm ciclos de importação/exportação',
      () async {
    final files = await sources(), edges = <String, List<String>>{};
    for (final entry in files.entries) {
      edges[entry.key] = [];
      for (final match in directives.allMatches(entry.value)) {
        var uri = match.group(1)!;
        String target;
        if (uri.startsWith('package:definitive_downloader/')) {
          target = p.normalize(p.absolute(
              'lib', uri.substring('package:definitive_downloader/'.length)));
        } else if (uri.contains(':')) {
          continue;
        } else {
          target = p.normalize(p.join(p.dirname(entry.key), uri));
        }
        if (files.containsKey(target)) edges[entry.key]!.add(target);
      }
    }
    final visited = <String>{}, active = <String>[];
    void visit(String file) {
      if (active.contains(file)) {
        fail('Dependência circular: ${[
          ...active.sublist(active.indexOf(file)),
          file
        ].map((s) => p.relative(s)).join(' → ')}');
      }
      if (!visited.add(file)) return;
      active.add(file);
      for (final next in edges[file]!) {
        visit(next);
      }
      active.removeLast();
    }

    for (final file in files.keys) {
      visit(file);
    }
  });
  test(
      'apresentação e domínio mantêm acesso a plataforma/SQL fora dos módulos visuais',
      () async {
    final files = await sources();
    for (final entry in files.entries) {
      final segments = p.split(entry.key);
      final ui = segments.contains('presentation'),
          domain = segments.contains('domain');
      if (!ui && !domain) continue;
      final imports =
          directives.allMatches(entry.value).map((m) => m.group(1)!).toList();
      expect(
          imports
              .where((u) => u == 'dart:io' || u.startsWith('package:sqlite3')),
          isEmpty,
          reason: p.relative(entry.key));
      if (domain) {
        expect(imports.where((u) => u.startsWith('package:flutter/')), isEmpty,
            reason: p.relative(entry.key));
      }
      if (ui) {
        expect(
            RegExp(r'\bProcess\.(?:run|start)\s*\(|\bHttpClient\s*\(|\bdatabase\.run\s*\(')
                .hasMatch(entry.value),
            isFalse,
            reason: p.relative(entry.key));
      }
    }
  });
}
