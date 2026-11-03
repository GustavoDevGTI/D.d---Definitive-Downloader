import 'package:flutter/material.dart';
import '../../importing/music_link.dart';
import '../domain/models.dart';

class ManualSourceChoice {
  const ManualSourceChoice(this.url, this.mode);
  final String url;
  final ManualSourceMode mode;
}

class ManualSourceInput extends StatefulWidget {
  const ManualSourceInput({super.key, required this.track});
  final Track track;
  @override
  State<ManualSourceInput> createState() => _ManualSourceInputState();
}

class _ManualSourceInputState extends State<ManualSourceInput> {
  late final _url = TextEditingController(text: widget.track.manualUrl);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Informar link manualmente'),
          content: SizedBox(
              width: 470,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(widget.track.displayTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _url,
                                autofocus: true,
                                keyboardType: TextInputType.url,
                                maxLength: 4096,
                                decoration: const InputDecoration(
                                    labelText: 'Link de faixa, YouTube ou MP3',
                                    counterText: ''),
                                validator: (value) {
                                  try {
                                    MusicLink.parse(value ?? '');
                                    return null;
                                  } on FormatException catch (error) {
                                    return error.message;
                                  }
                                }),
                          ])))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(
                        context,
                        ManualSourceChoice(
                            _url.text.trim(), ManualSourceMode.originalAudio));
                  }
                },
                child: const Text('Aplicar link')),
          ]);
}
