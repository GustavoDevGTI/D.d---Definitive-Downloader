import '../../library/domain/models.dart';

class CollectionGroup {
  const CollectionGroup(this.id, this.name, this.count);
  final int id, count;
  final String name;
}

class CollectionListing {
  const CollectionListing(this.items, this.total);
  final List<Collection> items;
  final int total;
}

String organizationName(String input, {int maxLength = 160}) {
  final value = input.trim();
  if (value.isEmpty ||
      value.length > maxLength ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw FormatException(
        'Use um nome de 1 a $maxLength caracteres, sem quebras de linha.');
  }
  return value;
}
