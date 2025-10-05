import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/locator/fairy_locator.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:fairy/src/locator/viewmodel_locator.dart';

void main() {
  setUp(() {
    // Clear FairyLocator before each test
    FairyLocator.instance.clear();
  });

  tearDown(() {
    // Clean up after each test
    FairyLocator.instance.clear();
  });

  group('ViewModelLocator.resolve()', () {
    testWidgets('should resolve ViewModel from FairyScope first', (tester) async {
      final scopeVm = ScopedViewModel();
      ScopedViewModel? resolvedVm;

      await tester.pumpWidget(
        FairyScope(
          create: () => scopeVm,
          child: Builder(
            builder: (context) {
              resolvedVm = ViewModelLocator.resolve<ScopedViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, scopeVm), isTrue);
    });

    testWidgets('should resolve ViewModel from FairyLocator if not in scope', (tester) async {
      final globalVm = GlobalViewModel();
      FairyLocator.instance.registerSingleton<GlobalViewModel>(globalVm);

      GlobalViewModel? resolvedVm;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedVm = ViewModelLocator.resolve<GlobalViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, globalVm), isTrue);
    });

    testWidgets('should prioritize FairyScope over FairyLocator', (tester) async {
      final scopeVm = TestViewModel();
      final globalVm = TestViewModel();

      FairyLocator.instance.registerSingleton<TestViewModel>(globalVm);

      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        FairyScope(
          create: () => scopeVm,
          child: Builder(
            builder: (context) {
              resolvedVm = ViewModelLocator.resolve<TestViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedVm, isNotNull);
      // Should get scope VM, not global
      expect(identical(resolvedVm, scopeVm), isTrue);
      expect(identical(resolvedVm, globalVm), isFalse);
    });

    testWidgets('should throw StateError when ViewModel not found', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              ViewModelLocator.resolve<TestViewModel>(context);
              fail('Should have thrown StateError');
            } catch (e) {
              expect(e, isA<StateError>());
              expect(e.toString(), contains('No ViewModel of type TestViewModel found'));
            }
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('should provide helpful error message with registration hints', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              ViewModelLocator.resolve<TestViewModel>(context);
              fail('Should have thrown StateError');
            } catch (e) {
              expect(e.toString(), contains('FairyLocator.instance.registerSingleton'));
              expect(e.toString(), contains('FairyScope'));
              expect(e.toString(), contains('Make sure to either'));
            }
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('should work with nested FairyScopes', (tester) async {
      final outerVm = OuterViewModel();
      final innerVm = InnerViewModel();

      InnerViewModel? resolvedInner;

      await tester.pumpWidget(
        FairyScope(
          create: () => outerVm,
          child: FairyScope(
            create: () => innerVm,
            child: Builder(
              builder: (context) {
                resolvedInner = ViewModelLocator.resolve<InnerViewModel>(context);
                
                // OuterViewModel should not be found in inner scope
                try {
                  ViewModelLocator.resolve<OuterViewModel>(context);
                  fail('Should have thrown - OuterViewModel not in inner scope');
                } catch (e) {
                  expect(e, isA<StateError>());
                }
                
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedInner, isNotNull);
      expect(identical(resolvedInner, innerVm), isTrue);
    });

    testWidgets('should resolve from outer scope if available', (tester) async {
      final outerVm = TestViewModel();

      await tester.pumpWidget(
        FairyScope(
          create: () => outerVm,
          child: Builder(
            builder: (outerContext) {
              return FairyScope(
                create: () => InnerViewModel(),
                child: Builder(
                  builder: (innerContext) {
                    // Try to get TestViewModel from inner context
                    // Should fail because FairyScope.of() only gets nearest scope
                    try {
                      ViewModelLocator.resolve<TestViewModel>(innerContext);
                      fail('Should have thrown');
                    } catch (e) {
                      expect(e, isA<StateError>());
                    }
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );
    });

    testWidgets('should work with FairyScope and FairyLocator together', (tester) async {
      final scopeVm = ScopedViewModel();
      final globalVm = GlobalViewModel();

      FairyLocator.instance.registerSingleton<GlobalViewModel>(globalVm);

      ScopedViewModel? resolvedScoped;
      GlobalViewModel? resolvedGlobal;

      await tester.pumpWidget(
        FairyScope(
          create: () => scopeVm,
          child: Builder(
            builder: (context) {
              resolvedScoped = ViewModelLocator.resolve<ScopedViewModel>(context);
              resolvedGlobal = ViewModelLocator.resolve<GlobalViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedScoped, isNotNull);
      expect(identical(resolvedScoped, scopeVm), isTrue);

      expect(resolvedGlobal, isNotNull);
      expect(identical(resolvedGlobal, globalVm), isTrue);
    });
  });

  group('ViewModelLocator.tryResolve()', () {
    testWidgets('should return ViewModel from FairyScope', (tester) async {
      final scopeVm = ScopedViewModel();
      ScopedViewModel? resolvedVm;

      await tester.pumpWidget(
        FairyScope(
          create: () => scopeVm,
          child: Builder(
            builder: (context) {
              resolvedVm = ViewModelLocator.tryResolve<ScopedViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, scopeVm), isTrue);
    });

    testWidgets('should return ViewModel from FairyLocator', (tester) async {
      final globalVm = GlobalViewModel();
      FairyLocator.instance.registerSingleton<GlobalViewModel>(globalVm);

      GlobalViewModel? resolvedVm;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedVm = ViewModelLocator.tryResolve<GlobalViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, globalVm), isTrue);
    });

    testWidgets('should return null when ViewModel not found', (tester) async {
      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedVm = ViewModelLocator.tryResolve<TestViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolvedVm, isNull);
    });

    testWidgets('should prioritize FairyScope over FairyLocator', (tester) async {
      final scopeVm = TestViewModel();
      final globalVm = TestViewModel();

      FairyLocator.instance.registerSingleton<TestViewModel>(globalVm);

      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        FairyScope(
          create: () => scopeVm,
          child: Builder(
            builder: (context) {
              resolvedVm = ViewModelLocator.tryResolve<TestViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, scopeVm), isTrue);
      expect(identical(resolvedVm, globalVm), isFalse);
    });

    testWidgets('should not throw when ViewModel not found', (tester) async {
      TestViewModel? resolvedVm;
      var didThrow = false;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              resolvedVm = ViewModelLocator.tryResolve<TestViewModel>(context);
            } catch (e) {
              didThrow = true;
            }
            return const SizedBox();
          },
        ),
      );

      expect(didThrow, isFalse);
      expect(resolvedVm, isNull);
    });

    testWidgets('should work with mixed scope and global ViewModels', (tester) async {
      final scopeVm = ScopedViewModel();
      final globalVm = GlobalViewModel();

      FairyLocator.instance.registerSingleton<GlobalViewModel>(globalVm);

      ScopedViewModel? resolvedScoped;
      GlobalViewModel? resolvedGlobal;
      TestViewModel? resolvedMissing;

      await tester.pumpWidget(
        FairyScope(
          create: () => scopeVm,
          child: Builder(
            builder: (context) {
              resolvedScoped = ViewModelLocator.tryResolve<ScopedViewModel>(context);
              resolvedGlobal = ViewModelLocator.tryResolve<GlobalViewModel>(context);
              resolvedMissing = ViewModelLocator.tryResolve<TestViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedScoped, isNotNull);
      expect(resolvedGlobal, isNotNull);
      expect(resolvedMissing, isNull);
    });
  });

  group('ViewModelLocator resolution order', () {
    testWidgets('should check FairyScope before FairyLocator', (tester) async {
      final scopeVm = TestViewModel();
      final globalVm = TestViewModel();

      // Register in global first
      FairyLocator.instance.registerSingleton<TestViewModel>(globalVm);

      TestViewModel? firstResolve;
      TestViewModel? secondResolve;

      await tester.pumpWidget(
        Column(
          children: [
            Builder(
              builder: (context) {
                // Outside scope - should get global
                firstResolve = ViewModelLocator.resolve<TestViewModel>(context);
                return const SizedBox();
              },
            ),
            FairyScope(
              create: () => scopeVm,
              child: Builder(
                builder: (context) {
                  // Inside scope - should get scoped
                  secondResolve = ViewModelLocator.resolve<TestViewModel>(context);
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      );

      expect(identical(firstResolve, globalVm), isTrue);
      expect(identical(secondResolve, scopeVm), isTrue);
    });

    testWidgets('should handle scope removal gracefully', (tester) async {
      final scopeVm = ScopedViewModel();
      final globalVm = ScopedViewModel();

      FairyLocator.instance.registerSingleton<ScopedViewModel>(globalVm);

      ScopedViewModel? resolvedBefore;
      ScopedViewModel? resolvedAfter;

      // With scope
      await tester.pumpWidget(
        FairyScope(
          create: () => scopeVm,
          child: Builder(
            builder: (context) {
              resolvedBefore = ViewModelLocator.resolve<ScopedViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(identical(resolvedBefore, scopeVm), isTrue);

      // Remove scope
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedAfter = ViewModelLocator.resolve<ScopedViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(identical(resolvedAfter, globalVm), isTrue);
    });
  });

  group('ViewModelLocator edge cases', () {
    testWidgets('should handle multiple ViewModels of different types', (tester) async {
      final vm1 = TestViewModel();
      final vm2 = ScopedViewModel();
      final vm3 = GlobalViewModel();

      FairyLocator.instance.registerSingleton<TestViewModel>(vm1);
      FairyLocator.instance.registerSingleton<ScopedViewModel>(vm2);
      FairyLocator.instance.registerSingleton<GlobalViewModel>(vm3);

      TestViewModel? resolved1;
      ScopedViewModel? resolved2;
      GlobalViewModel? resolved3;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved1 = ViewModelLocator.resolve<TestViewModel>(context);
            resolved2 = ViewModelLocator.resolve<ScopedViewModel>(context);
            resolved3 = ViewModelLocator.resolve<GlobalViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(identical(resolved1, vm1), isTrue);
      expect(identical(resolved2, vm2), isTrue);
      expect(identical(resolved3, vm3), isTrue);
    });

    testWidgets('should work when FairyLocator is empty', (tester) async {
      final scopeVm = TestViewModel();

      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        FairyScope(
          create: () => scopeVm,
          child: Builder(
            builder: (context) {
              resolvedVm = ViewModelLocator.resolve<TestViewModel>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, scopeVm), isTrue);
    });

    testWidgets('should work when no FairyScope in tree', (tester) async {
      final globalVm = TestViewModel();
      FairyLocator.instance.registerSingleton<TestViewModel>(globalVm);

      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedVm = ViewModelLocator.resolve<TestViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolvedVm, isNotNull);
      expect(identical(resolvedVm, globalVm), isTrue);
    });

    testWidgets('should return null with tryResolve when both empty', (tester) async {
      TestViewModel? resolvedVm;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolvedVm = ViewModelLocator.tryResolve<TestViewModel>(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolvedVm, isNull);
    });
  });
}

// Test ViewModels

class TestViewModel extends ObservableObject {
  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    super.dispose();
  }
}

class ScopedViewModel extends ObservableObject {}

class GlobalViewModel extends ObservableObject {}

class OuterViewModel extends ObservableObject {}

class InnerViewModel extends ObservableObject {}
