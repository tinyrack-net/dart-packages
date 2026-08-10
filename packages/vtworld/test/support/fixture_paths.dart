import 'dart:io';

/// Resolves [relative], a path under the package directory, from any cwd.
///
/// `dart test` runs from the package directory, but a workspace-wide run and
/// most editors run from the repository root. Probing for the path instead of
/// inspecting the current directory's name keeps both working and does not
/// silently break when the package or a directory above it is renamed.
String fixturePath(String relative) {
  const packageRelative = 'packages/vtworld';
  if (FileSystemEntity.typeSync(relative) != FileSystemEntityType.notFound) {
    return relative;
  }
  return '$packageRelative/$relative';
}

/// Resolves [relative] as a directory under the package directory.
Directory fixtureDirectory(String relative) => Directory(fixturePath(relative));

/// Resolves [relative] as a file under the package directory.
File fixtureFile(String relative) => File(fixturePath(relative));
