import 'package:flutter/material.dart';
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

        final (result, accessed, _) = DependencyTracker.track(() {
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

        final (_, accessed, _) = DependencyTracker.track(() {
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

        final (_, accessed, _) = DependencyTracker.track(() {
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

        final (_, accessed, _) = DependencyTracker.track(() {
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

        final (_, accessed, _) = DependencyTracker.track(() {
          return vm.fullName.value;
        });

        // Should track fullName access (which internally tracks firstName and lastName)
        expect(accessed, contains(vm.fullName));
        // Tracks: fullName, firstName, lastName (3 total)
        expect(accessed.length, equals(3));

        vm.dispose();
      });

      test('should return function result', () {
        final (result, _, _) = DependencyTracker.track(() {
          return 'test result';
        });

        expect(result, equals('test result'));
      });

      test('should return null result', () {
        final (result, _, _) = DependencyTracker.track(() {
          return null;
        });

        expect(result, isNull);
      });

      test('should handle function returning complex types', () {
        final (result, _, _) = DependencyTracker.track(() {
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

        final (_, accessed, _) = DependencyTracker.track(() {
          DependencyTracker.reportAccess(prop);
          return null;
        });

        expect(accessed, contains(prop));
        prop.dispose();
      });

      test('should add to current session, not parent session', () {
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<int>(2);

        final (_, outerAccessed, _) = DependencyTracker.track(() {
          DependencyTracker.reportAccess(prop1);

          final (_, innerAccessed, _) = DependencyTracker.track(() {
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

        final (_, outerAccessed, _) = DependencyTracker.track(() {
          outer.value;

          final (_, innerAccessed, _) = DependencyTracker.track(() {
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

        final (_, level1, _) = DependencyTracker.track(() {
          prop1.value;

          final (_, level2, _) = DependencyTracker.track(() {
            prop2.value;

            final (_, level3, _) = DependencyTracker.track(() {
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

        final (_, accessed, _) = DependencyTracker.track(() {
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

          final (_, accessed, _) = DependencyTracker.track(() {
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
        final (_, accessed, _) = DependencyTracker.track(() {
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

        final (_, accessed, _) = DependencyTracker.track(() {
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

        final (_, accessed, _) = DependencyTracker.track(() {
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
        final (result, accessed, _) = DependencyTracker.track(() {
          return 'done';
        });

        expect(result, equals('done'));
        expect(accessed, isEmpty);
      });

      test('should handle recursive tracking', () {
        final prop = ObservableProperty<int>(0);

        Set<ObservableNode> recursiveTrack(int depth) {
          if (depth == 0) return {};

          final (_, accessed, _) = DependencyTracker.track(() {
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

        final (result, accessed, _) = DependencyTracker.track(() {
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

        final (_, accessed1, _) = DependencyTracker.track(() {
          prop1.value;
          return null;
        });

        final (_, accessed2, _) = DependencyTracker.track(() {
          prop2.value;
          return null;
        });

        expect(accessed1, equals({prop1}));
        expect(accessed2, equals({prop2}));

        prop1.dispose();
        prop2.dispose();
      });
    });

    group('lazy builder support (InheritedWidget)', () {
      testWidgets('should NOT track property access outside tracking session',
          (tester) async {
        final prop = ObservableProperty<int>(42);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                onTap: () {
                  // This access should NOT be tracked
                  final value = prop.value;
                  expect(value, equals(42));
                  expect(DependencyTracker.isTracking, isFalse);
                },
                child: const Text('Tap me'),
              ),
            ),
          ),
        );

        // Trigger the onTap callback
        await tester.tap(find.text('Tap me'));
        await tester.pump();

        prop.dispose();
      });

      testWidgets('should NOT track in event callbacks (onPressed, onChanged)',
          (tester) async {
        final prop = ObservableProperty<int>(0);
        int tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Access inside onPressed should NOT be tracked
                      tapCount = prop.value + 1;
                      prop.value = tapCount;
                      expect(DependencyTracker.isTracking, isFalse);
                    },
                    child: const Text('Button'),
                  ),
                  TextField(
                    onChanged: (text) {
                      // Access inside onChanged should NOT be tracked
                      final _ = prop.value;
                      expect(DependencyTracker.isTracking, isFalse);
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        // Trigger onPressed
        await tester.tap(find.text('Button'));
        await tester.pump();

        expect(tapCount, equals(1));

        // Trigger onChanged
        await tester.enterText(find.byType(TextField), 'test');
        await tester.pump();

        prop.dispose();
      });

      testWidgets('should track in builder but NOT in callbacks',
          (tester) async {
        final viewModel = _CallbackTestViewModel();
        Set<ObservableNode>? trackedNodes;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final (widget, accessed, _) = DependencyTracker.track(() {
                    // This SHOULD be tracked
                    final count = viewModel.counter.value;

                    return Column(
                      children: [
                        Text('Count: $count'),
                        ElevatedButton(
                          onPressed: () {
                            // This should NOT be tracked
                            viewModel.increment();
                            expect(DependencyTracker.isTracking, isFalse);
                          },
                          child: const Text('Increment'),
                        ),
                      ],
                    );
                  });

                  trackedNodes = accessed;
                  return widget;
                },
              ),
            ),
          ),
        );

        // Verify counter was tracked during build
        expect(trackedNodes, contains(viewModel.counter));
        expect(trackedNodes?.length, equals(1));

        // Tap button - should NOT add to tracked nodes
        await tester.tap(find.text('Increment'));
        await tester.pump();

        // Tracked nodes should remain the same
        expect(trackedNodes?.length, equals(1));

        viewModel.dispose();
      });

      testWidgets('should track in initState but NOT in dispose',
          (tester) async {
        final prop = ObservableProperty<int>(100);
        bool accessedInInitState = false;
        bool accessedInDispose = false;

        await tester.pumpWidget(
          MaterialApp(
            home: _LifecycleTestWidget(
              property: prop,
              onInitState: () {
                // Check tracking state in initState
                accessedInInitState = DependencyTracker.isTracking;
                final _ = prop.value;
              },
              onDispose: () {
                // Check tracking state in dispose
                accessedInDispose = DependencyTracker.isTracking;
                final _ = prop.value;
              },
            ),
          ),
        );

        expect(accessedInInitState, isFalse,
            reason: 'initState is not inside tracking session');

        // Dispose the widget
        await tester.pumpWidget(const SizedBox());

        expect(accessedInDispose, isFalse,
            reason: 'dispose is not inside tracking session');

        prop.dispose();
      });

      test('should return session when wrapWithContext is true', () {
        final prop = ObservableProperty<int>(42);

        final (result, accessed, session) = DependencyTracker.track<Widget>(
          () {
            prop.value;
            return Container();
          },
          wrapWithContext: true,
        );

        expect(result, isA<Widget>());
        expect(accessed, contains(prop));
        expect(session, isNotNull, reason: 'Session should be returned');

        prop.dispose();
      });

      test('should return null session when wrapWithContext is false', () {
        final prop = ObservableProperty<int>(42);

        final (result, accessed, session) = DependencyTracker.track(
          () {
            prop.value;
            return 123;
          },
          wrapWithContext: false,
        );

        expect(result, equals(123));
        expect(accessed, contains(prop));
        expect(session, isNull, reason: 'Session should be null');

        prop.dispose();
      });

      test('should return null session when result is not a Widget', () {
        final prop = ObservableProperty<int>(42);

        final (result, accessed, session) = DependencyTracker.track(
          () {
            prop.value;
            return 'not a widget';
          },
          wrapWithContext: true,
        );

        expect(result, equals('not a widget'));
        expect(accessed, contains(prop));
        expect(session, isNull,
            reason: 'Session should be null for non-Widget results');

        prop.dispose();
      });

      test('should create snapshot of accesses at track() time', () {
        final prop1 = ObservableProperty<int>(1);

        final (_, accessed, session) = DependencyTracker.track<Widget>(
          () {
            prop1.value;
            return Container();
          },
          wrapWithContext: true,
        );

        // Initial snapshot should only have prop1
        expect(accessed, equals({prop1}));
        expect(session, isNotNull);

        // Session should be available for deferred tracking
        // (tested indirectly through bind_viewmodel_lazy_builder_test.dart)

        prop1.dispose();
      });
    });

    group('memory and cleanup', () {
      test('should not leak sessions after successful tracking', () {
        final prop = ObservableProperty<int>(0);

        for (int i = 0; i < 100; i++) {
          DependencyTracker.track(() {
            prop.value;
            return null;
          });
        }

        // Stack should be clean
        expect(DependencyTracker.isTracking, isFalse);

        prop.dispose();
      });

      test('should not leak sessions after failed tracking', () {
        final prop = ObservableProperty<int>(0);

        for (int i = 0; i < 100; i++) {
          try {
            DependencyTracker.track(() {
              prop.value;
              throw Exception('Test');
            });
          } catch (_) {}
        }

        // Stack should be clean
        expect(DependencyTracker.isTracking, isFalse);

        prop.dispose();
      });

      test('should handle interleaved tracking and non-tracking', () {
        final prop = ObservableProperty<int>(0);

        for (int i = 0; i < 10; i++) {
          // Tracking
          final (_, accessed, _) = DependencyTracker.track(() {
            prop.value;
            return null;
          });
          expect(accessed, contains(prop));

          // Non-tracking
          final value = prop.value;
          expect(value, equals(0));
          expect(DependencyTracker.isTracking, isFalse);
        }

        prop.dispose();
      });

      test('should not leak memory with wrapWithContext sessions', () {
        final prop = ObservableProperty<int>(0);

        for (int i = 0; i < 100; i++) {
          final (_, _, session) = DependencyTracker.track<Widget>(
            () {
              prop.value;
              return Container();
            },
            wrapWithContext: true,
          );

          // Session should be returned but not leaked
          expect(session, isNotNull);
        }

        // Stack should be clean after all tracking
        expect(DependencyTracker.isTracking, isFalse);

        prop.dispose();
      });

      test('should clean up nested tracking with exceptions at various levels',
          () {
        final prop = ObservableProperty<int>(0);

        // Exception at level 1
        expect(() {
          DependencyTracker.track(() {
            throw Exception('Level 1');
          });
        }, throwsException);

        expect(DependencyTracker.isTracking, isFalse);

        // Exception at level 2
        expect(() {
          DependencyTracker.track(() {
            prop.value;
            DependencyTracker.track(() {
              throw Exception('Level 2');
            });
            return null;
          });
        }, throwsException);

        expect(DependencyTracker.isTracking, isFalse);

        // Exception at level 3
        expect(() {
          DependencyTracker.track(() {
            DependencyTracker.track(() {
              DependencyTracker.track(() {
                throw Exception('Level 3');
              });
              return null;
            });
            return null;
          });
        }, throwsException);

        expect(DependencyTracker.isTracking, isFalse);

        prop.dispose();
      });

      test('should handle rapid tracking cycles without leaks', () {
        final props = List.generate(10, (i) => ObservableProperty<int>(i));

        // Simulate rapid UI rebuilds
        for (int cycle = 0; cycle < 50; cycle++) {
          for (final prop in props) {
            final (_, accessed, _) = DependencyTracker.track(() {
              prop.value;
              return null;
            });
            expect(accessed.length, equals(1));
          }

          // Verify clean state between cycles
          expect(DependencyTracker.isTracking, isFalse);
        }

        for (final prop in props) {
          prop.dispose();
        }
      });

      testWidgets('should clean up BuildContext reference on widget disposal',
          (tester) async {
        final prop = ObservableProperty<int>(42);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final (widget, _, _) = DependencyTracker.track<Widget>(
                  () {
                    prop.value;
                    return const Text('Test');
                  },
                  wrapWithContext: true,
                );
                return widget;
              },
            ),
          ),
        );

        // Context should be set during build
        expect(find.text('Test'), findsOneWidget);

        // Dispose the widget tree
        await tester.pumpWidget(const SizedBox.shrink());

        // Context should be cleared (can't directly test _currentContext,
        // but we verify no crashes occur with subsequent tracking)
        final (_, accessed, _) = DependencyTracker.track(() {
          prop.value;
          return null;
        });

        expect(accessed, contains(prop));
        expect(DependencyTracker.isTracking, isFalse);

        prop.dispose();
      });

      testWidgets('should handle multiple widgets with tracking simultaneously',
          (tester) async {
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<int>(2);
        final prop3 = ObservableProperty<int>(3);

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    final (widget, accessed, session) =
                        DependencyTracker.track<Widget>(
                      () {
                        prop1.value;
                        return Text('Value 1: ${prop1.value}');
                      },
                      wrapWithContext: true,
                    );
                    // Verify tracking works for each widget
                    expect(accessed, contains(prop1));
                    expect(session, isNotNull);
                    return widget;
                  },
                ),
                Builder(
                  builder: (context) {
                    final (widget, accessed, session) =
                        DependencyTracker.track<Widget>(
                      () {
                        prop2.value;
                        return Text('Value 2: ${prop2.value}');
                      },
                      wrapWithContext: true,
                    );
                    expect(accessed, contains(prop2));
                    expect(session, isNotNull);
                    return widget;
                  },
                ),
                Builder(
                  builder: (context) {
                    final (widget, accessed, session) =
                        DependencyTracker.track<Widget>(
                      () {
                        prop3.value;
                        return Text('Value 3: ${prop3.value}');
                      },
                      wrapWithContext: true,
                    );
                    expect(accessed, contains(prop3));
                    expect(session, isNotNull);
                    return widget;
                  },
                ),
              ],
            ),
          ),
        );

        // All widgets should render
        expect(find.text('Value 1: 1'), findsOneWidget);
        expect(find.text('Value 2: 2'), findsOneWidget);
        expect(find.text('Value 3: 3'), findsOneWidget);

        // Dispose the widget tree
        await tester.pumpWidget(const SizedBox.shrink());

        // Verify no leaks - all sessions should be cleaned up
        expect(DependencyTracker.isTracking, isFalse);

        prop1.dispose();
        prop2.dispose();
        prop3.dispose();
      });

      testWidgets('should properly clean up on hot reload simulation',
          (tester) async {
        final prop = ObservableProperty<int>(100);

        // Simulate multiple hot reloads
        for (int reload = 0; reload < 5; reload++) {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  final (widget, _, _) = DependencyTracker.track<Widget>(
                    () {
                      prop.value;
                      return Text('Reload $reload: ${prop.value}');
                    },
                    wrapWithContext: true,
                  );
                  return widget;
                },
              ),
            ),
          );

          expect(find.textContaining('Reload $reload'), findsOneWidget);

          // Change value between reloads
          prop.value = 100 + reload;
          await tester.pump();
        }

        // Final cleanup
        await tester.pumpWidget(const SizedBox.shrink());
        expect(DependencyTracker.isTracking, isFalse);

        prop.dispose();
      });

      test('should handle deep recursion without stack overflow', () {
        final prop = ObservableProperty<int>(0);

        int recursiveTrack(int depth) {
          if (depth == 0) return 0;

          final (result, _, _) = DependencyTracker.track(() {
            prop.value;
            return recursiveTrack(depth - 1);
          });

          return result + 1;
        }

        // Test with 100 levels of recursion
        final result = recursiveTrack(100);
        expect(result, equals(100));
        expect(DependencyTracker.isTracking, isFalse);

        prop.dispose();
      });

      test('should maintain isolation between concurrent-like tracking', () {
        final props = List.generate(50, (i) => ObservableProperty<int>(i));
        final results = <Set<ObservableNode>>[];

        // Simulate interleaved tracking sessions
        for (int i = 0; i < props.length; i += 2) {
          final (_, accessed1, _) = DependencyTracker.track(() {
            props[i].value;
            return null;
          });
          results.add(accessed1);

          if (i + 1 < props.length) {
            final (_, accessed2, _) = DependencyTracker.track(() {
              props[i + 1].value;
              return null;
            });
            results.add(accessed2);
          }
        }

        // Verify each session tracked exactly one property
        expect(results.length, equals(props.length));
        for (int i = 0; i < results.length; i++) {
          expect(results[i].length, equals(1));
          expect(results[i], contains(props[i]));
        }

        expect(DependencyTracker.isTracking, isFalse);

        for (final prop in props) {
          prop.dispose();
        }
      });
    });

    group('complex scenarios', () {
      test('should handle tracking with conditional branches', () {
        final condition = ObservableProperty<bool>(true);
        final trueValue = ObservableProperty<int>(1);
        final falseValue = ObservableProperty<int>(2);

        final (result, accessed, _) = DependencyTracker.track(() {
          if (condition.value) {
            return trueValue.value;
          } else {
            return falseValue.value;
          }
        });

        expect(result, equals(1));
        expect(accessed, containsAll([condition, trueValue]));
        expect(accessed, isNot(contains(falseValue)));

        condition.dispose();
        trueValue.dispose();
        falseValue.dispose();
      });

      test('should track all branches in loops', () {
        final items = List.generate(
          3,
          (i) => ObservableProperty<int>(i),
        );

        final (sum, accessed, _) = DependencyTracker.track(() {
          var total = 0;
          for (final item in items) {
            total += item.value;
          }
          return total;
        });

        expect(sum, equals(3)); // 0 + 1 + 2
        expect(accessed.length, equals(3));
        expect(accessed, containsAll(items));

        for (final item in items) {
          item.dispose();
        }
      });

      test('should handle early returns', () {
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<int>(2);

        final (result, accessed, _) = DependencyTracker.track(() {
          if (prop1.value > 0) {
            return 'early';
          }
          // This is never reached
          return prop2.value.toString();
        });

        expect(result, equals('early'));
        expect(accessed, equals({prop1}));
        expect(accessed, isNot(contains(prop2)));

        prop1.dispose();
        prop2.dispose();
      });

      test('should track through async/await boundaries', () async {
        final prop = ObservableProperty<int>(42);

        final (future, accessed, _) = DependencyTracker.track(() {
          final value = prop.value;
          return Future.value(value);
        });

        expect(accessed, contains(prop));

        final result = await future;
        expect(result, equals(42));

        prop.dispose();
      });

      test('should handle tracking with try-catch-finally', () {
        final prop1 = ObservableProperty<int>(1);
        final prop2 = ObservableProperty<int>(2);
        final prop3 = ObservableProperty<int>(3);

        final (result, accessed, _) = DependencyTracker.track(() {
          try {
            prop1.value;
            return 'success';
          } catch (e) {
            prop2.value;
            return 'caught';
          } finally {
            prop3.value;
          }
        });

        expect(result, equals('success'));
        expect(accessed, containsAll([prop1, prop3]));
        expect(accessed, isNot(contains(prop2)));

        prop1.dispose();
        prop2.dispose();
        prop3.dispose();
      });
    });
  });
}

// Test helpers
class _TestViewModel extends ObservableObject {
  final firstName = ObservableProperty<String>('John');
  final lastName = ObservableProperty<String>('Doe');
  late final fullName = ComputedProperty<String>(
    () => '${firstName.value} ${lastName.value}',
    [firstName, lastName],
    this,
  );
}

class _CallbackTestViewModel extends ObservableObject {
  final counter = ObservableProperty<int>(0);

  void increment() {
    counter.value++;
  }
}

class _LifecycleTestWidget extends StatefulWidget {
  final ObservableProperty<int> property;
  final VoidCallback onInitState;
  final VoidCallback onDispose;

  const _LifecycleTestWidget({
    required this.property,
    required this.onInitState,
    required this.onDispose,
  });

  @override
  State<_LifecycleTestWidget> createState() => _LifecycleTestWidgetState();
}

class _LifecycleTestWidgetState extends State<_LifecycleTestWidget> {
  @override
  void initState() {
    super.initState();
    widget.onInitState();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('Value: ${widget.property.value}');
  }
}
