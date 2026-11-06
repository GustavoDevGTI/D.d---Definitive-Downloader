import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IncomingMusic {
  const IncomingMusic(this.id, this.text, this.files, this.error);
  final String id, text, error;
  final List<String> files;
}

/// Receipt is independent of library mutations and downloads.
class AndroidIncoming extends ChangeNotifier {
  static const channel = MethodChannel('br.com.definitivedownloader/incoming');
  AndroidIncoming() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') {
        notifyListeners();
      }
    });
  }
  Future<IncomingMusic?> peek() async {
    final map = await channel.invokeMapMethod<String, Object?>('peek');
    if (map == null) return null;
    return IncomingMusic(map['id']! as String, map['text']! as String,
        List<String>.from(map['files']! as List), map['error']! as String);
  }

  Future<void> finish(String id) => channel.invokeMethod('finish', {'id': id});
  @override
  void dispose() {
    channel.setMethodCallHandler(null);
    super.dispose();
  }
}
