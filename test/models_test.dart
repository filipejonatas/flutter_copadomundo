import 'package:copa_palpite/models/app_user.dart';
import 'package:copa_palpite/models/leaderboard_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUser', () {
    test(
      'copyWith should override selected fields and preserve the others',
      () {
        // Arrange
        const user = AppUser(
          id: 'user-1',
          email: 'old@example.com',
          displayName: 'Old Name',
          nick: 'Old',
          avatarId: 'star',
        );

        // Act
        final updated = user.copyWith(
          email: 'new@example.com',
          nick: 'New',
          avatarId: 'cup',
        );

        // Assert
        expect(updated.id, 'user-1');
        expect(updated.email, 'new@example.com');
        expect(updated.displayName, 'Old Name');
        expect(updated.nick, 'New');
        expect(updated.avatarId, 'cup');
      },
    );
  });

  group('LeaderboardEntry', () {
    test(
      'copyWith should override selected fields and preserve the others',
      () {
        // Arrange
        const entry = LeaderboardEntry(
          position: 4,
          userId: 'user-1',
          nick: 'Palpiteiro',
          avatarId: 'ball',
          points: 10,
          predictionsCount: 5,
          exactScores: 2,
        );

        // Act
        final updated = entry.copyWith(
          position: 1,
          points: 20,
          exactScores: 4,
          isCurrentUser: true,
        );

        // Assert
        expect(updated.position, 1);
        expect(updated.userId, 'user-1');
        expect(updated.nick, 'Palpiteiro');
        expect(updated.avatarId, 'ball');
        expect(updated.points, 20);
        expect(updated.predictionsCount, 5);
        expect(updated.exactScores, 4);
        expect(updated.isCurrentUser, isTrue);
      },
    );
  });
}
