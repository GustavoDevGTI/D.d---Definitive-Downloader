import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlaylistColorDialog extends StatefulWidget {
  const PlaylistColorDialog(
      {super.key, required this.initialColor, required this.usedColors});

  final int initialColor;
  final Set<int> usedColors;

  @override
  State<PlaylistColorDialog> createState() => _PlaylistColorDialogState();
}

class _PlaylistColorDialogState extends State<PlaylistColorDialog> {
  late int? _rgb = widget.initialColor;
  late final _hex = TextEditingController(text: _format(widget.initialColor));

  String _format(int rgb) =>
      rgb.toRadixString(16).padLeft(6, '0').toUpperCase();

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _pick(Offset point, double size) {
    final delta = point - Offset(size / 2, size / 2);
    final angle = (delta.direction * 180 / math.pi + 360) % 360;
    final radius = (delta.distance / (size / 2)).clamp(0.0, 1.0);
    final rgb = _wheelColor(angle, radius).toARGB32() & 0xFFFFFF;
    setState(() {
      _rgb = rgb;
      _hex.text = _format(rgb);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rgb = _rgb;
    final used = widget.usedColors.contains(rgb);
    final error = used
        ? 'Outra playlist já usa essa cor.'
        : rgb == null
            ? 'Informe seis dígitos hexadecimais.'
            : null;
    return AlertDialog(
        title: const Text('Cor da playlist'),
        scrollable: true,
        content: SizedBox(
            width: 280,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  width: 208,
                  child: AspectRatio(
                      aspectRatio: 1,
                      child: Builder(builder: (wheelContext) {
                        void pick(Offset point) =>
                            _pick(point, wheelContext.size!.width);
                        return MouseRegion(
                            cursor: SystemMouseCursors.precise,
                            child: GestureDetector(
                                key: const ValueKey('playlist-color-wheel'),
                                excludeFromSemantics: true,
                                onTapDown: (details) =>
                                    pick(details.localPosition),
                                onPanStart: (details) =>
                                    pick(details.localPosition),
                                onPanUpdate: (details) =>
                                    pick(details.localPosition),
                                child: CustomPaint(
                                    painter: _ColorWheel(
                                        rgb ?? widget.initialColor))));
                      }))),
              const SizedBox(height: 16),
              TextField(
                  key: const ValueKey('playlist-color-hex'),
                  controller: _hex,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-fA-F0-9]')),
                    LengthLimitingTextInputFormatter(6)
                  ],
                  onChanged: (text) => setState(() {
                        _rgb = text.length == 6
                            ? int.tryParse(text, radix: 16)
                            : null;
                      }),
                  decoration: InputDecoration(
                      labelText: 'Código da cor',
                      prefixText: '#',
                      errorText: error,
                      errorMaxLines: 2,
                      suffixIcon: Center(
                          widthFactor: 1,
                          child: PlaylistColorSwatch(rgb: rgb)))),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: rgb == null || used
                  ? null
                  : () => Navigator.pop(context, rgb),
              child: const Text('Usar cor')),
        ]);
  }
}

class PlaylistColorSwatch extends StatelessWidget {
  const PlaylistColorSwatch({super.key, required this.rgb});

  final int? rgb;

  @override
  Widget build(BuildContext context) => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
          color: rgb == null ? Colors.transparent : Color(0xFF000000 | rgb!),
          border: Border.all(color: Colors.black26),
          shape: BoxShape.circle));
}

Color _wheelColor(double hue, double radius) => Color.alphaBlend(
    Colors.black.withAlpha((110 * radius).round()),
    HSVColor.fromAHSV(1, hue, radius, 1).toColor());

class _ColorWheel extends CustomPainter {
  const _ColorWheel(this.rgb);

  final int rgb;
  static const _hues = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = const SweepGradient(colors: _hues).createShader(bounds));
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader =
              const RadialGradient(colors: [Colors.white, Color(0x00FFFFFF)])
                  .createShader(bounds));
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0x00000000), Color(0x6E000000)])
              .createShader(bounds));
    final selected = Color(0xFF000000 | rgb);
    final hsv = HSVColor.fromColor(selected);
    final angle = hsv.hue * math.pi / 180;
    final distance = hsv.saturation * (radius - 7);
    final marker = center + Offset(math.cos(angle), math.sin(angle)) * distance;
    canvas.drawCircle(marker, 8, Paint()..color = Colors.black54);
    canvas.drawCircle(marker, 7, Paint()..color = Colors.white);
    canvas.drawCircle(marker, 5, Paint()..color = selected);
  }

  @override
  bool shouldRepaint(_ColorWheel oldDelegate) => oldDelegate.rgb != rgb;
}
