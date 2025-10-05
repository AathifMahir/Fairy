import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/locator/fairy_scope.dart';

void main() {
  group('FairyScopeData', () {
    late FairyScopeData data;

    setUp(() {
      data = FairyScopeData();
    });

    group('register()', () {
      test('should register ViewModel', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm);
        
        expect(data.contains<TestViewModel>(), isTrue);
        expect(identical(data.get<TestViewModel>(), vm), isTrue);
      });

      test('should register owned ViewModel', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm, owned: true);
        
        expect(data.contains<TestViewModel>(), isTrue);
      });

      test('should register non-owned ViewModel', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm, owned: false);
        
        expect(data.contains<TestViewModel>(), isTrue);
      });

      test('should allow registering multiple types', () {
        final vm1 = TestViewModel();
        final vm2 = AnotherViewModel();
        
        data.register<TestViewModel>(vm1);
        data.register<AnotherViewModel>(vm2);
        
        expect(data.contains<TestViewModel>(), isTrue);
        expect(data.contains<AnotherViewModel>(), isTrue);
      });
    });

    group('get<T>()', () {
      test('should retrieve registered ViewModel', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm);
        
        final retrieved = data.get<TestViewModel>();
        expect(identical(retrieved, vm), isTrue);
      });

      test('should throw if ViewModel not found', () {
        expect(
          () => data.get<TestViewModel>(),
          throwsStateError,
        );
      });

      test('should throw with helpful error message', () {
        try {
          data.get<TestViewModel>();
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('No ViewModel'));
          expect(e.toString(), contains('TestViewModel'));
          expect(e.toString(), contains('FairyScope'));
        }
      });
    });

    group('contains<T>()', () {
      test('should return false when not registered', () {
        expect(data.contains<TestViewModel>(), isFalse);
      });

      test('should return true when registered', () {
        data.register<TestViewModel>(TestViewModel());
        expect(data.contains<TestViewModel>(), isTrue);
      });
    });

    group('dispose()', () {
      test('should dispose owned ViewModels', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm, owned: true);
        
        expect(vm.isDisposed, isFalse);
        
        data.dispose();
        
        expect(vm.isDisposed, isTrue);
      });

      test('should NOT dispose non-owned ViewModels', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm, owned: false);
        
        expect(vm.isDisposed, isFalse);
        
        data.dispose();
        
        expect(vm.isDisposed, isFalse);
      });

      test('should dispose only owned ViewModels in mixed scenario', () {
        final ownedVm = TestViewModel();
        final suppliedVm = AnotherViewModel();
        
        data.register<TestViewModel>(ownedVm, owned: true);
        data.register<AnotherViewModel>(suppliedVm, owned: false);
        
        data.dispose();
        
        expect(ownedVm.isDisposed, isTrue);
        expect(suppliedVm.isDisposed, isFalse);
      });

      test('should clear registry after dispose', () {
        final vm = TestViewModel();
        data.register<TestViewModel>(vm, owned: true);
        
        data.dispose();
        
        expect(data.contains<TestViewModel>(), isFalse);
      });

      test('should handle multiple owned ViewModels', () {
        final vm1 = TestViewModel();
        final vm2 = AnotherViewModel();
        final vm3 = ThirdViewModel();
        
        data.register<TestViewModel>(vm1, owned: true);
        data.register<AnotherViewModel>(vm2, owned: true);
        data.register<ThirdViewModel>(vm3, owned: true);
        
        data.dispose();
        
        expect(vm1.isDisposed, isTrue);
        expect(vm2.isDisposed, isTrue);
        expect(vm3.isDisposed, isTrue);
      });
    });
  });

  group('FairyScope widget', () {
    testWidgets('should provide scope data to descendants', (tester) async {
      FairyScopeData? capturedData;
      
      await tester.pumpWidget(
        FairyScope(
          create: () => TestViewModel(),
          child: Builder(
            builder: (context) {
              capturedData = FairyScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      
      expect(capturedData, isNotNull);
      expect(capturedData!.contains<TestViewModel>(), isTrue);
    });

    testWidgets('should return null when no scope in tree', (tester) async {
      FairyScopeData? capturedData;
      
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            capturedData = FairyScope.of(context);
            return const SizedBox();
          },
        ),
      );
      
      expect(capturedData, isNull);
    });

    group('create parameter', () {
      testWidgets('should create and register ViewModel via factory', (tester) async {
        TestViewModel? vm;
        
        await tester.pumpWidget(
          FairyScope(
            create: () => TestViewModel(),
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context);
                vm = data?.get<TestViewModel>();
                return const SizedBox();
              },
            ),
          ),
        );
        
        expect(vm, isNotNull);
        expect(vm, isA<TestViewModel>());
      });

      testWidgets('should create ViewModel only once', (tester) async {
        var createCount = 0;
        TestViewModel? firstVm;
        TestViewModel? secondVm;
        
        await tester.pumpWidget(
          FairyScope(
            create: () {
              createCount++;
              return TestViewModel();
            },
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context);
                firstVm = data?.get<TestViewModel>();
                return const SizedBox();
              },
            ),
          ),
        );
        
        expect(createCount, equals(1));
        
        // Rebuild
        await tester.pumpWidget(
          FairyScope(
            create: () {
              createCount++;
              return TestViewModel();
            },
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context);
                secondVm = data?.get<TestViewModel>();
                return const SizedBox();
              },
            ),
          ),
        );
        
        expect(createCount, equals(1)); // Still 1
        expect(identical(firstVm, secondVm), isTrue);
      });

      testWidgets('should mark created VM as owned by default', (tester) async {
        final vm = TestViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            create: () => vm,
            child: const SizedBox(),
          ),
        );
        
        expect(vm.isDisposed, isFalse);
        
        // Remove scope
        await tester.pumpWidget(const SizedBox());
        
        // Should be disposed (owned by scope)
        expect(vm.isDisposed, isTrue);
      });
    });

    group('viewModels parameter', () {
      testWidgets('should register pre-created ViewModels', (tester) async {
        final vm1 = TestViewModel();
        final vm2 = AnotherViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            viewModels: [vm1, vm2],
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context);
                expect(data!.contains<TestViewModel>(), isTrue);
                expect(data.contains<AnotherViewModel>(), isTrue);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('should NOT dispose supplied ViewModels', (tester) async {
        final vm = TestViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            viewModels: [vm],
            child: const SizedBox(),
          ),
        );
        
        expect(vm.isDisposed, isFalse);
        
        // Remove scope
        await tester.pumpWidget(const SizedBox());
        
        // Should NOT be disposed (supplied, not created by scope)
        expect(vm.isDisposed, isFalse);
      });

      testWidgets('should register multiple ViewModels', (tester) async {
        final vm1 = TestViewModel();
        final vm2 = AnotherViewModel();
        final vm3 = ThirdViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            viewModels: [vm1, vm2, vm3],
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context)!;
                expect(identical(data.get<TestViewModel>(), vm1), isTrue);
                expect(identical(data.get<AnotherViewModel>(), vm2), isTrue);
                expect(identical(data.get<ThirdViewModel>(), vm3), isTrue);
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('autoDispose parameter', () {
      testWidgets('should dispose created VM when autoDispose is true', (tester) async {
        final vm = TestViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            create: () => vm,
            autoDispose: true,
            child: const SizedBox(),
          ),
        );
        
        expect(vm.isDisposed, isFalse);
        
        await tester.pumpWidget(const SizedBox());
        
        expect(vm.isDisposed, isTrue);
      });

      testWidgets('should NOT dispose created VM when autoDispose is false', (tester) async {
        final vm = TestViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            create: () => vm,
            autoDispose: false,
            child: const SizedBox(),
          ),
        );
        
        expect(vm.isDisposed, isFalse);
        
        await tester.pumpWidget(const SizedBox());
        
        expect(vm.isDisposed, isFalse);
      });

      testWidgets('should default autoDispose to true', (tester) async {
        final vm = TestViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            create: () => vm,
            // autoDispose not specified (defaults to true)
            child: const SizedBox(),
          ),
        );
        
        await tester.pumpWidget(const SizedBox());
        
        expect(vm.isDisposed, isTrue);
      });
    });

    group('disposal behavior', () {
      testWidgets('should dispose only owned ViewModels', (tester) async {
        final createdVm = TestViewModel();
        final suppliedVm = AnotherViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            create: () => createdVm,
            viewModels: [suppliedVm],
            child: const SizedBox(),
          ),
        );
        
        expect(createdVm.isDisposed, isFalse);
        expect(suppliedVm.isDisposed, isFalse);
        
        // Remove scope
        await tester.pumpWidget(const SizedBox());
        
        // Created VM should be disposed, supplied should not
        expect(createdVm.isDisposed, isTrue);
        expect(suppliedVm.isDisposed, isFalse);
      });

      testWidgets('should handle dispose on widget removal', (tester) async {
        final vm = TestViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            create: () => vm,
            child: const SizedBox(),
          ),
        );
        
        expect(vm.isDisposed, isFalse);
        
        // Replace with different widget
        await tester.pumpWidget(const Text('New widget', textDirection: TextDirection.ltr));
        
        expect(vm.isDisposed, isTrue);
      });

      testWidgets('should not throw when disposing twice', (tester) async {
        final vm = TestViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            create: () => vm,
            child: const SizedBox(),
          ),
        );
        
        await tester.pumpWidget(const SizedBox());
        
        // Should not throw even if dispose is called again
        expect(() => vm.dispose(), returnsNormally);
      });
    });

    group('nested scopes', () {
      testWidgets('should support nested scopes', (tester) async {
        TestViewModel? outerVm;
        AnotherViewModel? innerVm;
        
        await tester.pumpWidget(
          FairyScope(
            create: () => TestViewModel(),
            child: Builder(
              builder: (outerContext) {
                final outerData = FairyScope.of(outerContext);
                outerVm = outerData?.get<TestViewModel>();
                
                return FairyScope(
                  create: () => AnotherViewModel(),
                  child: Builder(
                    builder: (innerContext) {
                      final innerData = FairyScope.of(innerContext);
                      innerVm = innerData?.get<AnotherViewModel>();
                      return const SizedBox();
                    },
                  ),
                );
              },
            ),
          ),
        );
        
        expect(outerVm, isNotNull);
        expect(innerVm, isNotNull);
      });

      testWidgets('should access nearest scope', (tester) async {
        AnotherViewModel? innerScopeVm;
        bool? hasTestVmInInnerScope;
        
        await tester.pumpWidget(
          FairyScope(
            create: () => TestViewModel(),
            child: FairyScope(
              create: () => AnotherViewModel(),
              child: Builder(
                builder: (context) {
                  final data = FairyScope.of(context);
                  innerScopeVm = data?.get<AnotherViewModel>();
                  hasTestVmInInnerScope = data?.contains<TestViewModel>();
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        
        // Inner scope should have AnotherViewModel
        expect(innerScopeVm, isNotNull);
        // But not TestViewModel (that's in outer scope)
        expect(hasTestVmInInnerScope, isFalse);
      });

      testWidgets('should dispose nested scopes independently', (tester) async {
        final outerVm = TestViewModel();
        final innerVm = AnotherViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            create: () => outerVm,
            child: FairyScope(
              create: () => innerVm,
              child: const SizedBox(),
            ),
          ),
        );
        
        expect(outerVm.isDisposed, isFalse);
        expect(innerVm.isDisposed, isFalse);
        
        // Remove entire tree
        await tester.pumpWidget(const SizedBox());
        
        expect(outerVm.isDisposed, isTrue);
        expect(innerVm.isDisposed, isTrue);
      });
    });

    group('integration scenarios', () {
      testWidgets('should work with typical page scenario', (tester) async {
        final viewModel = PageViewModel();
        
        await tester.pumpWidget(
          FairyScope(
            create: () => viewModel,
            child: _TestPageWidget(),
          ),
        );
        
        expect(find.text('Count: 0'), findsOneWidget);
        
        // Increment
        viewModel.increment();
        await tester.pump();
        
        expect(find.text('Count: 1'), findsOneWidget);
      });

      testWidgets('should handle mixed create and viewModels', (tester) async {
        final suppliedVm = TestViewModel();
        AnotherViewModel? createdVm;
        
        await tester.pumpWidget(
          FairyScope(
            create: () => AnotherViewModel(),
            viewModels: [suppliedVm],
            child: Builder(
              builder: (context) {
                final data = FairyScope.of(context)!;
                expect(data.contains<TestViewModel>(), isTrue);
                expect(data.contains<AnotherViewModel>(), isTrue);
                createdVm = data.get<AnotherViewModel>();
                return const SizedBox();
              },
            ),
          ),
        );
        
        expect(createdVm, isNotNull);
        
        // Remove scope
        await tester.pumpWidget(const SizedBox());
        
        // Created should be disposed, supplied should not
        expect(createdVm!.isDisposed, isTrue);
        expect(suppliedVm.isDisposed, isFalse);
      });

      testWidgets('should maintain ViewModel state across rebuilds', (tester) async {
        var rebuildCount = 0;
        
        Widget buildScope() {
          rebuildCount++;
          return FairyScope(
            create: () => PageViewModel(),
            child: Builder(
              builder: (context) {
                final vm = FairyScope.of(context)!.get<PageViewModel>();
                return Text('Count: ${vm.count}', textDirection: TextDirection.ltr);
              },
            ),
          );
        }
        
        await tester.pumpWidget(buildScope());
        expect(find.text('Count: 0'), findsOneWidget);
        
        // Get VM and increment
        final BuildContext context = tester.element(find.byType(Builder));
        final vm = FairyScope.of(context)!.get<PageViewModel>();
        vm.increment();
        
        // Rebuild
        await tester.pumpWidget(buildScope());
        
        // State should be preserved
        expect(find.text('Count: 1'), findsOneWidget);
        expect(rebuildCount, equals(2));
      });
    });
  });
}

// Test helper classes

class TestViewModel extends ObservableObject {
  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return; // Safe for double disposal
    isDisposed = true;
    super.dispose();
  }
}

class AnotherViewModel extends ObservableObject {
  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return; // Safe for double disposal
    isDisposed = true;
    super.dispose();
  }
}

class ThirdViewModel extends ObservableObject {
  bool isDisposed = false;

  @override
  void dispose() {
    if (isDisposed) return; // Safe for double disposal
    isDisposed = true;
    super.dispose();
  }
}

class PageViewModel extends ObservableObject {
  int count = 0;

  void increment() {
    count++;
    onPropertyChanged();
  }
}

// Helper widget that rebuilds when PageViewModel changes
class _TestPageWidget extends StatefulWidget {
  @override
  State<_TestPageWidget> createState() => _TestPageWidgetState();
}

class _TestPageWidgetState extends State<_TestPageWidget> {
  late PageViewModel _vm;

  VoidCallback? _vmDisposer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = FairyScope.of(context)!;
    _vm = data.get<PageViewModel>();
    _vmDisposer = _vm.listen(_onVmChanged);
  }

  void _onVmChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _vmDisposer?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Count: ${_vm.count}',
      textDirection: TextDirection.ltr,
    );
  }
}
