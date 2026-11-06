import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/button_hover_motion.dart';
import '../application/music_player_controller.dart';
import '../domain/playback.dart';
import 'audio_slider.dart';

String audioTime(Duration value) {
  final s = value.inSeconds.clamp(0, 359999);
  return s >= 3600
      ? '${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}'
      : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key, required this.player});
  final MusicPlayerController player;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: player,
      builder: (context, _) => LayoutBuilder(builder: (context, box) {
            final compact =
                box.maxWidth < 780 || MediaQuery.sizeOf(context).height < 500;
            final controls = PlayerTransport(player: player, compact: compact);
            return Material(
                color: AppColors.navigation,
                child: SafeArea(
                    top: false,
                    child: Padding(
                        key: const ValueKey('music-player-bar'),
                        padding: EdgeInsets.symmetric(
                            horizontal: compact ? 12 : 24,
                            vertical: compact ? 8 : 10),
                        child: compact
                            ? Column(mainAxisSize: MainAxisSize.min, children: [
                                Row(children: [
                                  Expanded(
                                      child: InkWell(
                                          onTap: () => _expand(context),
                                          child: _metadata(40))),
                                  controls
                                ]),
                                if (player.current != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: ListenableBuilder(
                                          listenable: player.timeline,
                                          builder: (context, _) =>
                                              LinearProgressIndicator(
                                                  value: player.duration
                                                              .inMilliseconds <=
                                                          0
                                                      ? 0
                                                      : (player.position
                                                                  .inMilliseconds /
                                                              player.duration
                                                                  .inMilliseconds)
                                                          .clamp(0, 1),
                                                  minHeight: 2,
                                                  backgroundColor:
                                                      Colors.white24,
                                                  color: AppColors.accent))),
                              ])
                            : Row(children: [
                                Expanded(flex: 3, child: _metadata(52)),
                                const SizedBox(width: 16),
                                Expanded(
                                    flex: 5,
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          controls,
                                          SizedBox(
                                              height: 28,
                                              child: PlayerSeek(player: player))
                                        ])),
                                const SizedBox(width: 16),
                                Expanded(
                                    flex: 3,
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          _queueButton(context),
                                          if (player.current?.reference
                                                  .isNotEmpty ==
                                              true)
                                            PlayerIcon(
                                                label: 'Abrir referência',
                                                icon: Icons.open_in_new_rounded,
                                                onPressed: () => unawaited(
                                                    player.openReference(player
                                                        .current!.reference))),
                                          Flexible(
                                              child: ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                          maxWidth: 164),
                                                  child: PlayerVolume(
                                                      player: player))),
                                        ])),
                              ]))));
          }));
  Widget _metadata(double size) => Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
                width: size,
                height: size,
                child: player.cover == null
                    ? const ColoredBox(
                        color: AppColors.accentActive,
                        child: Icon(Icons.music_note_rounded,
                            color: Colors.white, size: 25))
                    : Image.memory(player.cover!,
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.music_note,
                            color: Colors.white)))),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(player.title.isEmpty ? 'Selecione uma música' : player.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(
                  player.message.isNotEmpty
                      ? player.message
                      : player.current == null
                          ? 'Ouça seus arquivos baixados'
                          : '${player.current!.isPreview ? 'Prévia · ' : ''}${player.artist}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: player.message.isNotEmpty
                          ? AppColors.accentSoft
                          : Colors.white70,
                      fontSize: 11)),
            ])),
      ]);
  Widget _queueButton(BuildContext context) => PlayerIcon(
      label: 'Fila de reprodução',
      icon: Icons.queue_music_rounded,
      onPressed:
          player.queue.isEmpty ? null : () => showPlayerQueue(context, player));
  void _expand(BuildContext context) {
    unawaited(showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.navigation,
        builder: (context) => ListenableBuilder(
            listenable: player,
            builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Agora tocando',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16))),
                    IconButton(
                        tooltip: 'Fechar player',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70))
                  ]),
                  const SizedBox(height: 16),
                  _metadata(72),
                  const SizedBox(height: 20),
                  PlayerSeek(player: player),
                  const SizedBox(height: 12),
                  PlayerTransport(player: player),
                  const SizedBox(height: 18),
                  PlayerVolume(player: player),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _queueButton(context),
                    if (player.current?.reference.isNotEmpty == true) ...[
                      PlayerIcon(
                          label: 'Abrir referência',
                          icon: Icons.open_in_new,
                          onPressed: () => unawaited(
                              player.openReference(player.current!.reference))),
                      PlayerIcon(
                          label: 'Copiar link',
                          icon: Icons.copy_rounded,
                          onPressed: () => unawaited(
                              player.copyReference(player.current!.reference))),
                    ]
                  ]),
                ])))));
  }
}

class PlayerIcon extends StatelessWidget {
  const PlayerIcon(
      {super.key,
      required this.label,
      required this.icon,
      this.onPressed,
      this.selected = false,
      this.primary = false});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected, primary;
  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ButtonHoverMotion(
              builder: (states) => IconButton(
                  statesController: states,
                  key: primary ? const ValueKey('player-play-pause') : null,
                  tooltip: label,
                  onPressed: onPressed,
                  style: IconButton.styleFrom(
                      backgroundColor:
                          primary ? Colors.white : Colors.transparent,
                      foregroundColor: primary
                          ? AppColors.navigation
                          : selected
                              ? AppColors.accent
                              : Colors.white70,
                      disabledBackgroundColor:
                          primary ? Colors.white24 : Colors.transparent,
                      disabledForegroundColor: Colors.white30,
                      hoverColor:
                          primary ? AppColors.accentSoft : Colors.white12,
                      highlightColor: AppColors.accent.withAlpha(60),
                      minimumSize: Size(primary ? 42 : 36, primary ? 42 : 36),
                      padding: const EdgeInsets.all(6)),
                  icon: Icon(icon, size: primary ? 26 : 21)))));
}

class PlayerTransport extends StatelessWidget {
  const PlayerTransport(
      {super.key, required this.player, this.compact = false});
  final MusicPlayerController player;
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!compact)
              PlayerIcon(
                  label: player.shuffled
                      ? 'Desativar aleatório'
                      : 'Ativar aleatório',
                  icon: Icons.shuffle_rounded,
                  selected: player.shuffled,
                  onPressed:
                      player.queue.length < 2 ? null : player.toggleShuffle),
            PlayerIcon(
                label: 'Faixa anterior',
                icon: Icons.skip_previous_rounded,
                onPressed: player.current == null || player.loading
                    ? null
                    : () => unawaited(player.previous())),
            PlayerIcon(
                label: player.playing ? 'Pausar' : 'Reproduzir',
                icon: player.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                primary: true,
                onPressed: player.current == null || player.loading
                    ? null
                    : () => unawaited(player.toggle())),
            PlayerIcon(
                label: 'Próxima faixa',
                icon: Icons.skip_next_rounded,
                onPressed: player.current == null || player.loading
                    ? null
                    : () => unawaited(player.next())),
            if (!compact)
              PlayerIcon(
                  label: switch (player.repeat) {
                    AudioRepeat.off => 'Repetição desativada',
                    AudioRepeat.playlist => 'Repetir playlist',
                    AudioRepeat.track => 'Repetir música'
                  },
                  selected: player.repeat != AudioRepeat.off,
                  icon: player.repeat == AudioRepeat.track
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  onPressed:
                      player.current == null ? null : player.cycleRepeat),
          ]);
}

class PlayerSeek extends StatefulWidget {
  const PlayerSeek({super.key, required this.player});
  final MusicPlayerController player;
  @override
  State<PlayerSeek> createState() => _PlayerSeekState();
}

class _PlayerSeekState extends State<PlayerSeek> {
  double? _drag;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.player.timeline,
      builder: (context, _) => _content(context));

  Widget _content(BuildContext context) {
    final p = widget.player;
    final max = p.duration.inMilliseconds.toDouble();
    final value = (_drag ?? p.position.inMilliseconds.toDouble())
        .clamp(0.0, max > 0 ? max : 1.0)
        .toDouble();
    const style = TextStyle(color: Colors.white60, fontSize: 10);
    return Row(children: [
      Text(audioTime(Duration(milliseconds: value.toInt())), style: style),
      Expanded(
          child: AudioSlider(
              key: const ValueKey('player-seek'),
              value: value,
              max: max > 0 ? max : 1,
              label: 'Posição da música',
              activeColor: AppColors.accent,
              step: 5000,
              describe: (v) => audioTime(Duration(milliseconds: v.toInt())),
              onChanged: max <= 0 || p.loading
                  ? null
                  : (v) => setState(() => _drag = v),
              onChangeEnd: (v) {
                setState(() => _drag = null);
                unawaited(p.seek(Duration(milliseconds: v.toInt())));
              })),
      Text(audioTime(p.duration), style: style)
    ]);
  }
}

class PlayerVolume extends StatelessWidget {
  const PlayerVolume({super.key, required this.player});
  final MusicPlayerController player;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        PlayerIcon(
            label: player.volume == 0 ? 'Restaurar volume' : 'Silenciar',
            icon: player.volume == 0
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            onPressed: player.mute),
        Expanded(
            child: AudioSlider(
                key: const ValueKey('player-volume'),
                value: player.volume,
                label: 'Volume',
                activeColor: Colors.white,
                onChanged: player.setVolume,
                describe: (v) => 'Volume ${(v * 100).round()}%',
                onChangeEnd: (_) => unawaited(player.saveVolume()))),
      ]);
}

void showPlayerQueue(BuildContext context, MusicPlayerController player) {
  unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListenableBuilder(
              listenable: player,
              builder: (context, _) => Column(children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  'Fila de reprodução · ${player.queue.length}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16))),
                          IconButton(
                              tooltip: 'Fechar fila',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close))
                        ])),
                    Expanded(
                        child: ListView.builder(
                            itemCount: player.queue.length,
                            itemBuilder: (context, i) {
                              final item = player.queue[i];
                              return ListTile(
                                  selected: i == player.index,
                                  selectedTileColor: AppColors.accentSoft,
                                  leading: Icon(
                                      i == player.index && player.playing
                                          ? Icons.graphic_eq_rounded
                                          : Icons.music_note_rounded),
                                  title: Text(item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                      '${item.isPreview ? 'Prévia · ' : ''}${item.artist}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  onTap: () => unawaited(player.jump(i)));
                            }))
                  ])))));
}
