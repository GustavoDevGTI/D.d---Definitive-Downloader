import 'package:flutter/foundation.dart';
import '../data/collection_organization_repository.dart';
import '../domain/collection_organization.dart';

class CollectionOrganizationController extends ChangeNotifier {
  CollectionOrganizationController(this.repository);
  final CollectionOrganizationRepository repository;
  CollectionListing listing = const CollectionListing([], 0);
  List<CollectionGroup> groups = [];
  String query = '', error = '';
  int? groupId;
  int offset = 0, _generation = 0;
  bool saving = false, loading = true, _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    loading = true;
    _notify();
    try {
      final nextGroups = await repository.groups();
      var selected = groupId;
      if (selected != null &&
          selected > 0 &&
          !nextGroups.any((g) => g.id == selected)) {
        selected = null;
      }
      var nextOffset = offset;
      var next = await repository.list(
          query: query, groupId: selected, offset: nextOffset);
      if (next.items.isEmpty && nextOffset > 0) {
        nextOffset = next.total == 0 ? 0 : ((next.total - 1) ~/ 30) * 30;
        next = await repository.list(
            query: query, groupId: selected, offset: nextOffset);
      }
      if (_disposed || generation != _generation) return;
      groups = nextGroups;
      groupId = selected;
      offset = nextOffset;
      listing = next;
      error = '';
    } catch (_) {
      if (generation == _generation) {
        error = 'Não foi possível carregar as playlists. Tente novamente.';
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> filter(String value, int? group) {
    query = value;
    groupId = group;
    offset = 0;
    return refresh();
  }

  Future<void> turnPage(int direction) {
    offset = (offset + direction * 30).clamp(0, 1 << 30);
    return refresh();
  }

  Future<String?> mutate(Future<void> Function() action) async {
    if (saving) return 'Aguarde a alteração em andamento.';
    saving = true;
    _notify();
    try {
      await action();
      await refresh();
      return null;
    } on FormatException catch (e) {
      return e.message;
    } catch (_) {
      return 'Não foi possível salvar. Tente novamente.';
    } finally {
      saving = false;
      _notify();
    }
  }
}
