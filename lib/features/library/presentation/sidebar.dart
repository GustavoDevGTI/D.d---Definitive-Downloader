import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/brand.dart';
import '../../../core/app_identity.dart';
import '../../workspace/domain/workspace_models.dart';

const appDestinations = <(AppSection, String, IconData)>[
  (AppSection.home, 'Início', Icons.home_outlined),
  (AppSection.music, 'Músicas', Icons.queue_music_outlined),
  (AppSection.media, 'Vídeos e Fotos', Icons.perm_media_outlined),
  (AppSection.files, 'Arquivos', Icons.folder_open_outlined),
  (AppSection.settings, 'Configurações', Icons.settings_outlined),
];

class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar(
      {super.key, required this.selected, required this.onSelect});
  final AppSection selected;
  final ValueChanged<AppSection> onSelect;
  @override
  Widget build(BuildContext context) => Container(
      width: 204,
      decoration: const BoxDecoration(color: AppColors.navigation),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(22, 24, 18, 28),
            child: BrandLockup(
                stacked: true, markSize: 44, fontSize: 14, inverse: true)),
        Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
          for (final (section, label, icon) in appDestinations)
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: Material(
                    borderRadius: BorderRadius.circular(10),
                    color: section == selected
                        ? AppColors.accentActive
                        : Colors.transparent,
                    child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        minLeadingWidth: 18,
                        horizontalTitleGap: 10,
                        dense: true,
                        selected: section == selected,
                        selectedColor: Colors.white,
                        textColor: Colors.white,
                        hoverColor: Colors.white12,
                        focusColor: Colors.white24,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        leading: Icon(icon, size: 21, color: Colors.white),
                        title: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: section == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        onTap: () => onSelect(section)))),
        ])),
        const Padding(
            key: ValueKey('sidebar-version'),
            padding: EdgeInsets.fromLTRB(24, 12, 16, 16),
            child: Text('Versão ${AppIdentity.version} · local',
                style: TextStyle(
                    fontSize: 11, height: 1.8, color: Colors.white70))),
      ]));
}

class MobileNavigation extends StatelessWidget {
  const MobileNavigation(
      {super.key, required this.selected, required this.onSelect});
  final AppSection selected;
  final ValueChanged<AppSection> onSelect;
  @override
  Widget build(BuildContext context) => BottomNavigationBar(
          elevation: 0,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          currentIndex: selected.index,
          selectedItemColor: AppColors.accentActive,
          unselectedItemColor: AppColors.secondary,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          onTap: (index) => onSelect(AppSection.values[index]),
          items: [
            for (final (section, label, icon) in appDestinations)
              BottomNavigationBarItem(
                  icon: Icon(icon,
                      size: 20,
                      key: ValueKey('mobile-destination-${section.name}')),
                  label: label == 'Vídeos e Fotos'
                      ? 'Mídias'
                      : label == 'Configurações'
                          ? 'Ajustes'
                          : label,
                  tooltip: label)
          ]);
}

class MobileLandscapeNavigation extends StatelessWidget {
  const MobileLandscapeNavigation(
      {super.key, required this.selected, required this.onSelect});
  final AppSection selected;
  final ValueChanged<AppSection> onSelect;
  @override
  Widget build(BuildContext context) => NavigationRail(
          minWidth: 64,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.accentSoft,
          selectedIconTheme: const IconThemeData(color: AppColors.accentActive),
          unselectedIconTheme: const IconThemeData(color: AppColors.secondary),
          labelType: NavigationRailLabelType.none,
          selectedIndex: selected.index,
          onDestinationSelected: (index) => onSelect(AppSection.values[index]),
          destinations: [
            for (final (section, label, icon) in appDestinations)
              NavigationRailDestination(
                  icon: Tooltip(
                      message: label,
                      child: Icon(icon,
                          key: ValueKey('mobile-destination-${section.name}'))),
                  label: Text(label))
          ]);
}
