import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/library/domain/matching.dart';
import 'support.dart';

void main() {
  const matcher = TrackMatcher();
  test('mesma gravação com título, artista e duração compatíveis', () {
    final result = matcher.assess(testTrack(), candidate());
    expect(result.score, 1);
    expect(result.needsReview, false);
  });
  test('não aceita título semelhante de outro artista automaticamente', () {
    final result = matcher.assess(
        testTrack(), candidate(artist: 'Outro artista', duration: 80000));
    expect(result.needsReview, true);
    expect(result.score, lessThan(.7));
  });
  test('distingue gravação ao vivo da original', () {
    final result =
        matcher.assess(testTrack(), candidate(title: 'Entre linhas live'));
    expect(result.needsReview, true);
    expect(result.reason, contains('Versão diferente'));
  });
  test('duração ausente exige conferência', () {
    expect(matcher.assess(testTrack(duration: null), candidate()).needsReview,
        true);
  });
}
