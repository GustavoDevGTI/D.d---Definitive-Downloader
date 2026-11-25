import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// Windows publication is atomic and refuses an existing destination, including
/// one created after the caller checked it. No replace/copy/delete flags.
Future<bool> publishLibrarySnapshot(String source, String destination) async {
  if (!Platform.isWindows) {
    if (await FileSystemEntity.type(destination, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return false;
    }
    await File(source).rename(destination);
    return true;
  }
  final kernel = DynamicLibrary.open('kernel32.dll');
  final move = kernel.lookupFunction<
      Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32),
      int Function(Pointer<Utf16>, Pointer<Utf16>, int)>('MoveFileExW');
  final lastError =
      kernel.lookupFunction<Uint32 Function(), int Function()>('GetLastError');
  String extended(String path) {
    final absolute = p.normalize(p.absolute(path));
    if (absolute.startsWith('\\\\?\\')) return absolute;
    return absolute.startsWith('\\\\')
        ? '\\\\?\\UNC\\${absolute.substring(2)}'
        : '\\\\?\\$absolute';
  }

  final from = extended(source).toNativeUtf16();
  final to = extended(destination).toNativeUtf16();
  try {
    if (move(from, to, 0x8) != 0) return true; // MOVEFILE_WRITE_THROUGH.
    final error = lastError();
    if (error == 80 || error == 183) return false;
    throw FileSystemException(
        'Não foi possível publicar a cópia da biblioteca (Windows $error).',
        destination);
  } finally {
    malloc.free(from);
    malloc.free(to);
  }
}
