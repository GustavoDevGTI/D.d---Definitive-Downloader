import 'package:flutter/material.dart';
import '../../../core/network/bounded_http.dart';
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
  late ManualSourceMode _mode = widget.track.manualMode;
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.track.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _url,
                                autofocus: true,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                    labelText: 'URL da fonte'),
                                validator: (value) {
                                  try {
                                    validateHttpUrl(
                                        Uri.parse(value?.trim() ?? ''));
                                    return null;
                                  } catch (_) {
                                    return 'Use uma URL HTTP ou HTTPS sem credenciais.';
                                  }
                                }),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<ManualSourceMode>(
                                initialValue: _mode,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Tratamento da fonte'),
                                items: const [
                                  DropdownMenuItem(
                                      value: ManualSourceMode.extractAudio,
                                      child: Text('Extrair somente áudio',
                                          style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(
                                      value: ManualSourceMode.originalAudio,
                                      child: Text(
                                          'Utilizar áudio original, se disponível',
                                          style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (v) => setState(() => _mode = v!)),
                            const SizedBox(height: 12),
                            Text(
                                _mode == ManualSourceMode.extractAudio
                                    ? 'O vínculo será salvo para revisão. A extração de páginas e videoclipes ainda não está disponível.'
                                    : 'Nesta versão, o endereço deve fornecer um arquivo MP3 diretamente. O conteúdo será verificado durante o download.',
                                style:
                                    const TextStyle(fontSize: 12, height: 1.6)),
                            const SizedBox(height: 8),
                            const Text(
                                'Use um link público estável. Não informe credenciais ou URLs temporárias assinadas.',
                                style: TextStyle(fontSize: 11)),
                          ])))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(
                        context, ManualSourceChoice(_url.text.trim(), _mode));
                  }
                },
                child: const Text('Aplicar link'))
          ]);
}
