import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/core/observable_node.dart';
import 'package:fairy/src/internal/dependency_tracker.dart';

void main() {
  group('DependencyTracker', () {
    group('isTracking', () {
      test('should return false when no tracking session is active', () {
        expect(DependencyTracker.isTracking, isFalse);
      });

      test('should return true during tracking session', () {
        DependencyTracker.track(() {
          expect(DependencyTracker.isTracking, isTrue);
          return null;
        });
      });

      test('should return false after tracking session completes', () {
        DependencyTracker.track(() => null);
        expect(DependencyTracker.isTracking, isFalse);
      });
    });

    group('track', () {
      test('should track single property access', () {
        final prop = ObservableProperty<int>(0);

        final (result, accessed) = DependencyTracker.track(() {
          final value = prop.value; // Access property
          return value;
        });

        expect(result, equals(0));
        expect(accessed, contains(prop));
        expect(accessed.length, equals(1));

        prop.dispose();
      });

      test('should track multiple property accesses', () {
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<String>('test');
        final prop3 = ObservableProperty<bool>(true);

        final (_, accessed) = DependencyTracker.track(() {
          prop1.value;
          prop2.value;
          prop3.value;
          return null;
        });

        expect(accessed.length, equals(3));
        expect(accessed, containsAll([prop1, prop2, prop3]));

        prop1.dispose();
        prop2.dispose();
        prop3.dispose();
      });

      test('should deduplicate same property accessed multiple times', () {
        final prop = ObservableProperty<int>(0);

        final (_, accessed) = DependencyTracker.track(() {
          prop.value; // Access 1
          prop.value; // Access 2
          prop.value; // Access 3
          return null;
        });

        expect(accessed.length, equals(1), reason: 'Set should deduplicate');
        expect(accessed, contains(prop));

        prop.dispose();
      });

      test('should track nested property accesses', () {
        final outer = ObservableProperty<int>(1);
        final inner = ObservableProperty<int>(2);

        final (_, accessed) = DependencyTracker.track(() {
          if (outer.value > 0) {
            return inner.value;
          }
          return 0;
        });

        expect(accessed.length, equals(2));
        expect(accessed, containsAll([outer, inner]));

        outer.dispose();
        inner.dispose();
      });

      test('should track computed property dependencies', () {
        final vm = _TestViewModel();

        final (_, accessed) = DependencyTracker.track(() {
          return vm.fullName.value;
        });

        // Should track fullName access (which internally tracks firstName and lastName)
        expect(accessed, contains(vm.fullName));
        // Tracks: fullName, firstName, lastName (3 total)
        expect(accessed.length, equals(3));

        vm.dispose();
      });

      test('should return function result', () {
        final (result, _) = DependencyTracker.track(() {
          return 'test result';
        });

        expect(result, equals('test result'));
      });

      test('should return null result', () {
        final (result, _) = DependencyTracker.track(() {
          return null;
        });

        expect(result, isNull);
      });

      test('should handle function returning complex types', () {
        final (result, _) = DependencyTracker.track(() {
          return {'key': 'value', 'number': 42};
        });

        expect(result, equals({'key': 'value', 'number': 42}));
      });
    });

    group('reportAccess', () {
      test('should not track when no session is active', () {
        final prop = ObservableProperty<int>(0);

        // reportAccess called without tracking session
        DependencyTracker.reportAccess(prop);

        // Verify no crash and isTracking is false
        expect(DependencyTracker.isTracking, isFalse);

        prop.dispose();
      });

      test('should track when session is active', () {
        final prop = ObservableProperty<int>(0);

        final (_, accessed) = DependencyTracker.track(() {
          DependencyTracker.reportAccess(prop);
          return null;
        });

        expect(accessed, contains(prop));
        prop.dispose();
      });

      test('should add to current session, not parent session', () {
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<int>(2);

        final (_, outerAccessed) = DependencyTracker.track(() {
          DependencyTracker.reportAccess(prop1);

          final (_, innerAccessed) = DependencyTracker.track(() {
            DependencyTracker.reportAccess(prop2);
            return null;
          });

          expect(innerAccessed, contains(prop2));
          expect(innerAccessed, isNot(contains(prop1)));

          return null;
        });

        expect(outerAccessed, contains(prop1));
        expect(outerAccessed, isNot(contains(prop2)));

        prop1.dispose();
        prop2.dispose();
      });
    });

    group('nested tracking', () {
      test('should support nested tracking sessions', () {
        final outer = ObservableProperty<int>(1);
        final inner = ObservableProperty<int>(2);

        final (_, outerAccessed) = DependencyTracker.track(() {
          outer.value;

          final (_, innerAccessed) = DependencyTracker.track(() {
            inner.value;
            return null;
          });

          expect(innerAccessed, contains(inner));
          expect(innerAccessed, isNot(contains(outer)));

          return null;
        });

        expect(outerAccessed, contains(outer));
        expect(outerAccessed, isNot(contains(inner)));

        outer.dispose();
        inner.dispose();
      });

      test('should isolate nested sessions', () {
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<int>(2);
        final prop3 = ObservableProperty<int>(3);

        final (_, level1) = DependencyTracker.track(() {
          prop1.value;

          final (_, level2) = DependencyTracker.track(() {
            prop2.value;

            final (_, level3) = DependencyTracker.track(() {
              prop3.value;
              return null;
            });

            expect(level3, equals({prop3}));
            return null;
          });

          expect(level2, equals({prop2}));
          return null;
        });

        expect(level1, equals({prop1}));

        prop1.dispose();
        prop2.dispose();
        prop3.dispose();
      });

      test('should restore parent session after nested session completes', () {
        final outer = ObservableProperty<int>(1);
        final inner = ObservableProperty<int>(2);

        final (_, accessed) = DependencyTracker.track(() {
          outer.value; // Track in outer

          DependencyTracker.track(() {
            inner.value; // Track in inner
            return null;
          });

          // After inner session, should still track in outer
          outer.value;
          return null;
        });

        expect(accessed, contains(outer));
        expect(accessed, isNot(contains(inner)));

        outer.dispose();
        inner.dispose();
      });

      test('should handle deeply nested tracking (10 levels)', () {
        final props = List.generate(10, (i) => ObservableProperty<int>(i));

        Set<ObservableNode> trackLevel(int level) {
          if (level >= props.length) return {};

          final (_, accessed) = DependencyTracker.track(() {
            props[level].value;
            if (level < props.length - 1) {
              trackLevel(level + 1);
            }
            return null;
          });

          return accessed;
        }

        final level0 = trackLevel(0);
        expect(level0, equals({props[0]}));

        for (final prop in props) {
          prop.dispose();
        }
      });
    });

    group('exception handling', () {
      test('should capture accessed nodes before exception', () {
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<int>(2);

        expect(() {
          DependencyTracker.track(() {
            prop1.value;
            prop2.value;
            throw Exception('Test exception');
          });
        }, throwsException);

        // Verify no memory leak - stack should be empty
        expect(DependencyTracker.isTracking, isFalse);

        prop1.dispose();
        prop2.dispose();
      });

      test('should clean up stack on exception', () {
        expect(() {
          DependencyTracker.track(() {
            throw Exception('Test');
          });
        }, throwsException);

        // Verify stack is clean
        expect(DependencyTracker.isTracking, isFalse);
      });

      test('should clean up nested sessions on exception', () {
        final outer = ObservableProperty<int>(1);

        expect(() {
          DependencyTracker.track(() {
            outer.value;

            DependencyTracker.track(() {
              throw Exception('Inner exception');
            });

            return null;
          });
        }, throwsException);

        expect(DependencyTracker.isTracking, isFalse);
        outer.dispose();
      });

      test('should allow new tracking after exception', () {
        // First tracking throws
        expect(() {
          DependencyTracker.track(() {
            throw Exception('Test');
          });
        }, throwsException);

        // Second tracking should work
        final prop = ObservableProperty<int>(0);
        final (_, accessed) = DependencyTracker.track(() {
          prop.value;
          return null;
        });

        expect(accessed, contains(prop));
        prop.dispose();
      });
    });

    group('captureAccessed', () {
      test('should return empty set when no tracking session', () {
        final accessed = DependencyTracker.captureAccessed();
        expect(accessed, isEmpty);
      });

      test('should capture accessed nodes in current session', () {
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<int>(2);

        late Set<ObservableNode> captured;

        DependencyTracker.track(() {
          prop1.value;
          prop2.value;

          captured = DependencyTracker.captureAccessed();
          return null;
        });

        expect(captured, containsAll([prop1, prop2]));
        expect(captured.length, equals(2));

        prop1.dispose();
        prop2.dispose();
      });

      test('should capture partial dependencies on exception', () {
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<int>(2);

        Set<ObservableNode>? captured;

        expect(() {
          DependencyTracker.track(() {
            prop1.value;
            prop2.value;

            captured = DependencyTracker.captureAccessed();

            throw Exception('Test');
          });
        }, throwsException);

        expect(captured, isNotNull);
        expect(captured, containsAll([prop1, prop2]));

        prop1.dispose();
        prop2.dispose();
      });

      test('should only capture current session, not parent', () {
        final outer = ObservableProperty<int>(1);
        final inner = ObservableProperty<int>(2);

        DependencyTracker.track(() {
          outer.value;

          DependencyTracker.track(() {
            inner.value;

            final captured = DependencyTracker.captureAccessed();
            expect(captured, equals({inner}));

            return null;
          });

          final captured = DependencyTracker.captureAccessed();
          expect(captured, equals({outer}));

          return null;
        });

        outer.dispose();
        inner.dispose();
      });
    });

    group('performance', () {
      test('should handle tracking 1000 unique properties', () {
        final props = List.generate(1000, (i) => ObservableProperty<int>(i));

        final stopwatch = Stopwatch()..start();

        final (_, accessed) = DependencyTracker.track(() {
          for (final prop in props) {
            prop.value;
          }
          return null;
        });

        stopwatch.stop();

        expect(accessed.length, equals(1000));
        expect(stopwatch.elapsedMilliseconds, lessThan(100),
            reason: 'Should track 1000 properties in under 100ms');

        for (final prop in props) {
          prop.dispose();
        }
      });

      test('should handle tracking same property 1000 times (deduplication)',
          () {
        final prop = ObservableProperty<int>(0);

        final stopwatch = Stopwatch()..start();

        final (_, accessed) = DependencyTracker.track(() {
          for (int i = 0; i < 1000; i++) {
            prop.value;
          }
          return null;
        });

        stopwatch.stop();

        expect(accessed.length, equals(1));
        expect(stopwatch.elapsedMilliseconds, lessThan(50),
            reason: 'Deduplication should be fast');

        prop.dispose();
      });

      test('reportAccess should be fast when not tracking', () {
        final prop = ObservableProperty<int>(0);

        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 10000; i++) {
          DependencyTracker.reportAccess(prop);
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMicroseconds, lessThan(1000),
            reason: 'isTracking check should be O(1) and fast');

        prop.dispose();
      });
    });

    group('edge cases', () {
      test('should handle empty tracking function', () {
        final (result, accessed) = DependencyTracker.track(() {
          return 'done';
        });

        expect(result, equals('done'));
        expect(accessed, isEmpty);
      });

      test('should handle recursive tracking', () {
        final prop = ObservableProperty<int>(0);

        Set<ObservableNode> recursiveTrack(int depth) {
          if (depth == 0) return {};

          final (_, accessed) = DependencyTracker.track(() {
            prop.value;
            recursiveTrack(depth - 1);
            return null;
          });

          return accessed;
        }

        final accessed = recursiveTrack(5);
        expect(accessed, contains(prop));

        prop.dispose();
      });

      test('should handle null property values', () {
        final prop = ObservableProperty<String?>(null);

        final (result, accessed) = DependencyTracker.track(() {
          return prop.value;
        });

        expect(result, isNull);
        expect(accessed, contains(prop));

        prop.dispose();
      });

      test(
          'should handle concurrent tracking in different isolates (simulation)',
          () {
        // Simulate by ensuring sessions don't interfere
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<int>(2);

        final (_, accessed1) = DependencyTracker.track(() {
          prop1.value;
          return null;
        });

        final (_, accessed2) = DependencyTracker.track(() {
          prop2.value;
          return null;
        });

        expect(accessed1, equals({prop1}));
        expect(accessed2, equals({prop2}));

        prop1.dispose();
        prop2.dispose();
      });
    });
  });
}

class _TestViewModel extends ObservableObject {
  final firstName = ObservableProperty<String>('John');
  final lastName = ObservableProperty<String>('Doe');
  late final fullName = ComputedProperty<String>(
    () => '${firstName.value} ${lastName.value}',
    [firstName, lastName],
    this,
  );
}
