import 'dart:io';

import 'package:lua_tool_runtime/lua_tool_runtime.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('copies module and Markdown maps into an immutable bundle', () {
    final modules = <String, String>{
      'main': 'return {run = function() return true end}',
    };
    final assets = <String, String>{'prompts/system.md': '# System'};

    final bundle = LuaProgramBundle(
      revision: 'sha256:abc',
      entrypoint: 'main',
      modules: modules,
      preloadModules: const ['main'],
      markdownAssets: assets,
    );
    modules['main'] = 'changed';
    assets['prompts/system.md'] = 'changed';

    expect(bundle.modules['main'], 'return {run = function() return true end}');
    expect(bundle.markdownAssets['prompts/system.md'], '# System');
    expect(bundle.preloadModules, ['main']);
    expect(() => bundle.preloadModules.add('other'), throwsUnsupportedError);
    expect(() => bundle.modules['extra'] = 'x', throwsUnsupportedError);
    expect(
      () => bundle.markdownAssets['other.md'] = 'x',
      throwsUnsupportedError,
    );
  });

  test('rejects unsafe module names and asset paths', () {
    expect(
      () => LuaProgramBundle(
        revision: '',
        entrypoint: 'main',
        modules: const {'main': 'return {}'},
      ),
      throwsFormatException,
    );
    expect(
      () => LuaProgramBundle(
        revision: 'r1',
        entrypoint: 'main',
        modules: const {'main': 'return {}'},
        preloadModules: const ['missing'],
      ),
      throwsFormatException,
    );
    expect(
      () => LuaProgramBundle(
        revision: 'r1',
        entrypoint: 'main',
        modules: const {'main': 'return {}'},
        preloadModules: const ['main', 'main'],
      ),
      throwsFormatException,
    );
    expect(
      () => LuaProgramBundle(
        revision: 'r1',
        entrypoint: 'main',
        modules: const {},
      ),
      throwsFormatException,
    );
    expect(
      () => LuaProgramBundle(
        revision: 'r1',
        entrypoint: 'main',
        modules: const {'other': 'return {}'},
      ),
      throwsFormatException,
    );
    expect(
      () => LuaProgramBundle(
        revision: 'r1',
        entrypoint: '../main',
        modules: const {'../main': 'return {}'},
      ),
      throwsFormatException,
    );
    expect(
      () => LuaProgramBundle(
        revision: 'r1',
        entrypoint: 'main',
        modules: const {'main': 'return {}'},
        markdownAssets: const {'../secret.md': 'secret'},
      ),
      throwsFormatException,
    );
    expect(
      () => LuaProgramBundle(
        revision: 'r1',
        entrypoint: 'main',
        modules: const {'main': 'return {}'},
        markdownAssets: const {'prompt.txt': 'not Markdown'},
      ),
      throwsFormatException,
    );
  });

  test('rejects invalid roots and unsupported source files', () async {
    final root = await Directory.systemTemp.createTemp('lua-invalid-bundle-');
    addTearDown(() => root.delete(recursive: true));
    final rootFile = File(p.join(root.path, 'not-a-directory'))
      ..writeAsStringSync('x');
    await expectLater(
      LuaProgramBundleLoader.load(root: rootFile.path, revision: 'r1'),
      throwsA(isA<LuaBundleException>()),
    );

    File(p.join(root.path, 'main.lua')).writeAsStringSync('return {}');
    final lua = Directory(p.join(root.path, 'lua'))..createSync();
    File(p.join(lua.path, 'unsupported.txt')).writeAsStringSync('x');
    await expectLater(
      LuaProgramBundleLoader.load(root: root.path, revision: 'r2'),
      throwsA(isA<LuaBundleException>()),
    );
    File(p.join(lua.path, 'unsupported.txt')).deleteSync();

    final prompts = Directory(p.join(root.path, 'prompts'))..createSync();
    File(p.join(prompts.path, 'unsupported.txt')).writeAsStringSync('x');
    await expectLater(
      LuaProgramBundleLoader.load(root: root.path, revision: 'r3'),
      throwsA(isA<LuaBundleException>()),
    );
    expect(
      const LuaBundleException('invalid').toString(),
      'LuaBundleException: invalid',
    );
  });

  test(
    'loads only Lua modules and Markdown assets without following links',
    () async {
      final root = await Directory.systemTemp.createTemp('lua-bundle-');
      addTearDown(() => root.delete(recursive: true));
      File(p.join(root.path, 'main.lua')).writeAsStringSync('return {}');
      final lua = Directory(p.join(root.path, 'lua'))..createSync();
      File(p.join(lua.path, 'helper.lua')).writeAsStringSync('return 42');
      final prompts = Directory(p.join(root.path, 'prompts'))..createSync();
      File(p.join(prompts.path, 'system.md')).writeAsStringSync('# System');

      final bundle = await LuaProgramBundleLoader.load(
        root: root.path,
        revision: 'sha256:bundle',
      );

      expect(bundle.entrypoint, 'main');
      expect(bundle.modules.keys, {'main', 'helper'});
      expect(bundle.markdownAssets, {'prompts/system.md': '# System'});

      final outside = await Directory.systemTemp.createTemp('lua-outside-');
      addTearDown(() => outside.delete(recursive: true));
      File(p.join(outside.path, 'escape.lua')).writeAsStringSync('return {}');
      final link = Link(p.join(lua.path, 'escape.lua'));
      try {
        await link.create(p.join(outside.path, 'escape.lua'));
      } on FileSystemException {
        return;
      }
      await expectLater(
        LuaProgramBundleLoader.load(root: root.path, revision: 'sha256:linked'),
        throwsA(isA<LuaBundleException>()),
      );
    },
  );
}
