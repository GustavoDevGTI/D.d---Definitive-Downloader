import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

Future<SecurityContext>? _cachedContext;

/// Adds public roots already trusted by Windows, without changing system stores
/// or accepting invalid server certificates. Other systems use Dart's defaults.
Future<SecurityContext> platformSecurityContext() =>
    _cachedContext ??= _loadContext();

Future<SecurityContext> _loadContext() async {
  final context = SecurityContext(withTrustedRoots: true);
  if (!Platform.isWindows) return context;
  final roots = await Isolate.run(_windowsRoots);
  for (final root in roots) {
    final pem = utf8.encode('-----BEGIN CERTIFICATE-----\n'
        '${base64.encode(root)}\n-----END CERTIFICATE-----\n');
    context.setTrustedCertificatesBytes(pem);
  }
  return context;
}

final class _CertificateContext extends Struct {
  @Uint32()
  external int encoding;
  external Pointer<Uint8> bytes;
  @Uint32()
  external int length;
  external Pointer<Void> info;
  external Pointer<Void> store;
}

List<Uint8List> _windowsRoots() {
  final library = DynamicLibrary.open('crypt32.dll');
  final open = library.lookupFunction<
      Pointer<Void> Function(
          Pointer<Void>, Uint32, IntPtr, Uint32, Pointer<Void>),
      Pointer<Void> Function(
          Pointer<Void>, int, int, int, Pointer<Void>)>('CertOpenStore');
  final next = library.lookupFunction<
      Pointer<_CertificateContext> Function(
          Pointer<Void>, Pointer<_CertificateContext>),
      Pointer<_CertificateContext> Function(Pointer<Void>,
          Pointer<_CertificateContext>)>('CertEnumCertificatesInStore');
  final free = library.lookupFunction<
      Int32 Function(Pointer<_CertificateContext>),
      int Function(Pointer<_CertificateContext>)>('CertFreeCertificateContext');
  final close = library.lookupFunction<Int32 Function(Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int)>('CertCloseStore');
  final name = 'ROOT'.toNativeUtf16();
  final roots = <Uint8List>[];
  try {
    // SYSTEM_W (10), CURRENT_USER / LOCAL_MACHINE. Open existing, read only.
    for (final location in [0x00010000, 0x00020000]) {
      final store = open(Pointer.fromAddress(10), 0, 0,
          location | 0x00004000 | 0x00008000, name.cast());
      if (store == nullptr) continue;
      Pointer<_CertificateContext> certificate = nullptr;
      try {
        while (true) {
          certificate = next(store, certificate);
          if (certificate == nullptr) break;
          final length = certificate.ref.length;
          if (roots.length >= 2000 || length < 1 || length > 128 * 1024) {
            throw const TlsException('Certificados do sistema fora do limite.');
          }
          roots.add(
              Uint8List.fromList(certificate.ref.bytes.asTypedList(length)));
        }
      } finally {
        if (certificate != nullptr) free(certificate);
        close(store, 0);
      }
    }
  } finally {
    calloc.free(name);
  }
  return roots;
}
