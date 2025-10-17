import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';
import 'package:fairy/src/core/command.dart';
import 'package:fairy/src/locator/fairy_scope.dart';
import 'package:fairy/src/ui/bind_widget.dart';

void main() {
  group('BindObserver', () {
    group('basic functionality', () {
      testWidgets('should render initial value', (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) => Text(vm.name.value),
              ),
            ),
          ),
        );

        expect(find.text('Initial'), findsOneWidget);
      });

      testWidgets('should rebuild when accessed property changes',
          (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) => Text(vm.name.value),
              ),
            ),
          ),
        );

        expect(find.text('Initial'), findsOneWidget);

        vm.name.value = 'Updated';
        await tester.pump();

        expect(find.text('Updated'), findsOneWidget);
        expect(find.text('Initial'), findsNothing);
      });

      testWidgets('should NOT rebuild when unaccessed property changes',
          (tester) async {
        final vm = TestViewModel();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  return Text(vm.name.value); // Only accesses name
                },
              ),
            ),
          ),
        );

        expect(buildCount, equals(1));

        // Change unaccessed property
        vm.age.value = 99;
        await tester.pump();

        // Should NOT rebuild
        expect(buildCount, equals(1));
      });

      testWidgets('should rebuild when ViewModel calls onPropertyChanged',
          (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) => Text(vm.regularField),
              ),
            ),
          ),
        );

        expect(find.text('regular'), findsOneWidget);

        // Change regular field and notify
        vm.updateRegularField('changed');
        await tester.pump();

        expect(find.text('changed'), findsOneWidget);
      });
    });

    group('multiple properties', () {
      testWidgets('should track multiple properties', (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) =>
                    Text('${vm.name.value}-${vm.age.value}'),
              ),
            ),
          ),
        );

        expect(find.text('Initial-0'), findsOneWidget);

        vm.name.value = 'John';
        await tester.pump();
        expect(find.text('John-0'), findsOneWidget);

        vm.age.value = 25;
        await tester.pump();
        expect(find.text('John-25'), findsOneWidget);
      });

      testWidgets('should rebuild when any accessed property changes',
          (tester) async {
        final vm = TestViewModel();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  return Text('${vm.name.value}-${vm.age.value}');
                },
              ),
            ),
          ),
        );

        expect(buildCount, equals(1));

        vm.name.value = 'Test';
        await tester.pump();
        expect(buildCount, equals(2));

        vm.age.value = 50;
        await tester.pump();
        expect(buildCount, equals(3));
      });
    });

    group('conditional access', () {
      testWidgets('should track conditionally accessed properties',
          (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) {
                  if (vm.age.value > 18) {
                    return Text(vm.name.value);
                  }
                  return const Text('Minor');
                },
              ),
            ),
          ),
        );

        expect(find.text('Minor'), findsOneWidget);

        // Change age to adult - should now track name
        vm.age.value = 25;
        await tester.pump();
        expect(find.text('Initial'), findsOneWidget);

        // Now changing name should cause rebuild
        vm.name.value = 'Adult';
        await tester.pump();
        expect(find.text('Adult'), findsOneWidget);
      });

      testWidgets('should update subscriptions when accessed properties change',
          (tester) async {
        final vm = TestViewModel();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  // Conditionally access name
                  if (vm.age.value > 18) {
                    return Text(vm.name.value);
                  }
                  return const Text('Child');
                },
              ),
            ),
          ),
        );

        expect(buildCount, equals(1));
        expect(find.text('Child'), findsOneWidget);

        // Change name (not accessed yet) - should NOT rebuild
        vm.name.value = 'Test';
        await tester.pump();
        expect(buildCount, equals(1));

        // Change age to trigger access to name
        vm.age.value = 25;
        await tester.pump();
        expect(buildCount, equals(2));
        expect(find.text('Test'), findsOneWidget);

        // NOW name changes should cause rebuilds
        vm.name.value = 'John';
        await tester.pump();
        expect(buildCount, equals(3));
        expect(find.text('John'), findsOneWidget);
      });
    });

    group('command tracking', () {
      testWidgets('should track command canExecute', (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) =>
                    Text('${vm.incrementCommand.canExecute}'),
              ),
            ),
          ),
        );

        expect(find.text('true'), findsOneWidget);

        vm.canIncrement.value = false;
        vm.incrementCommand.notifyCanExecuteChanged();
        await tester.pump();

        expect(find.text('false'), findsOneWidget);
      });
    });

    group('batching', () {
      testWidgets('should batch rapid changes', (tester) async {
        final vm = TestViewModel();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  return Text('${vm.age.value}');
                },
              ),
            ),
          ),
        );

        expect(buildCount, equals(1));

        // Make multiple rapid changes
        vm.age.value = 1;
        vm.age.value = 2;
        vm.age.value = 3;
        vm.age.value = 4;
        vm.age.value = 5;

        // Pump microtasks to process batching
        await tester.pump();

        // Should rebuild only once due to batching
        expect(buildCount, equals(2));
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('should batch changes from multiple properties',
          (tester) async {
        final vm = TestViewModel();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) {
                  buildCount++;
                  return Text('${vm.name.value}-${vm.age.value}');
                },
              ),
            ),
          ),
        );

        expect(buildCount, equals(1));

        // Change both properties rapidly
        vm.name.value = 'A';
        vm.age.value = 1;
        vm.name.value = 'B';
        vm.age.value = 2;

        await tester.pump();

        // Should batch all changes into one rebuild
        expect(buildCount, equals(2));
        expect(find.text('B-2'), findsOneWidget);
      });
    });

    group('multiple widgets', () {
      testWidgets('should allow multiple widgets to observe same property',
          (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Column(
                children: [
                  Bind.viewModel<TestViewModel>(
                    builder: (context, vm) => Text('Widget1: ${vm.name.value}'),
                  ),
                  Bind.viewModel<TestViewModel>(
                    builder: (context, vm) => Text('Widget2: ${vm.name.value}'),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Widget1: Initial'), findsOneWidget);
        expect(find.text('Widget2: Initial'), findsOneWidget);

        vm.name.value = 'Updated';
        await tester.pump();

        expect(find.text('Widget1: Updated'), findsOneWidget);
        expect(find.text('Widget2: Updated'), findsOneWidget);
      });

      testWidgets('should track different properties per widget',
          (tester) async {
        final vm = TestViewModel();
        var widget1Builds = 0;
        var widget2Builds = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Column(
                children: [
                  Bind.viewModel<TestViewModel>(
                    builder: (context, vm) {
                      widget1Builds++;
                      return Text(vm.name.value);
                    },
                  ),
                  Bind.viewModel<TestViewModel>(
                    builder: (context, vm) {
                      widget2Builds++;
                      return Text('${vm.age.value}');
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(widget1Builds, equals(1));
        expect(widget2Builds, equals(1));

        // Change name - only widget1 should rebuild
        vm.name.value = 'Test';
        await tester.pump();
        expect(widget1Builds, equals(2));
        expect(widget2Builds, equals(1));

        // Change age - only widget2 should rebuild
        vm.age.value = 50;
        await tester.pump();
        expect(widget1Builds, equals(2));
        expect(widget2Builds, equals(2));
      });
    });

    group('exception handling', () {
      testWidgets('should handle exceptions during build', (tester) async {
        final vm = TestViewModel();
        var shouldThrow = false;

        Widget buildApp() => MaterialApp(
              home: FairyScope(
                viewModel: (_) => vm,
                child: Bind.viewModel<TestViewModel>(
                  builder: (context, vm) {
                    final name = vm.name.value;
                    if (shouldThrow) {
                      throw Exception('Test exception');
                    }
                    return Text(name);
                  },
                ),
              ),
            );

        await tester.pumpWidget(buildApp());
        expect(find.text('Initial'), findsOneWidget);

        // Trigger exception
        shouldThrow = true;
        vm.name.value = 'Trigger';

        await tester.pumpAndSettle();
        expect(tester.takeException(), isException);

        // Rebuild widget tree to recover from error state
        shouldThrow = false;
        vm.name.value = 'Recovered';
        await tester.pumpWidget(buildApp());

        expect(find.text('Recovered'), findsOneWidget);
      });

      testWidgets('should track properties accessed before exception',
          (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) {
                  final name = vm.name.value; // Accessed before exception
                  if (vm.age.value > 50) {
                    throw Exception('Age too high');
                  }
                  return Text(name);
                },
              ),
            ),
          ),
        );

        expect(find.text('Initial'), findsOneWidget);

        // Should still track name even after exception with age
        vm.name.value = 'Test';
        await tester.pump();
        expect(find.text('Test'), findsOneWidget);
      });
    });

    group('computed properties', () {
      testWidgets('should track computed properties', (tester) async {
        final vm = ComputedViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<ComputedViewModel>(
                builder: (context, vm) => Text(vm.fullName.value),
              ),
            ),
          ),
        );

        expect(find.text('John Doe'), findsOneWidget);

        vm.firstName.value = 'Jane';
        await tester.pump();

        expect(find.text('Jane Doe'), findsOneWidget);
      });
    });

    group('disposal', () {
      testWidgets('should clean up subscriptions on dispose', (tester) async {
        final vm = TestViewModel();

        await tester.pumpWidget(
          MaterialApp(
            home: FairyScope(
              viewModel: (_) => vm,
              child: Bind.viewModel<TestViewModel>(
                builder: (context, vm) => Text(vm.name.value),
              ),
            ),
          ),
        );

        expect(find.text('Initial'), findsOneWidget);

        // Remove widget
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        // Should not throw when property changes after disposal
        expect(() => vm.name.value = 'Test', returnsNormally);
      });
    });
  });

  group('BindObserver2', () {
    testWidgets('should observe two ViewModels', (tester) async {
      final vm1 = FirstViewModel();
      final vm2 = SecondViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (_) => vm1,
              (_) => vm2,
            ],
            child: Bind.viewModel2<FirstViewModel, SecondViewModel>(
              builder: (context, vm1, vm2) =>
                  Text('${vm1.name.value}-${vm2.name.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Initial-Initial'), findsOneWidget);

      vm1.name.value = 'First';
      await tester.pump();
      expect(find.text('First-Initial'), findsOneWidget);

      vm2.name.value = 'Second';
      await tester.pump();
      expect(find.text('First-Second'), findsOneWidget);
    });

    testWidgets('should track properties from both ViewModels', (tester) async {
      final vm1 = FirstViewModel();
      final vm2 = SecondViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (_) => vm1,
              (_) => vm2,
            ],
            child: Bind.viewModel2<FirstViewModel, SecondViewModel>(
              builder: (context, vm1, vm2) {
                buildCount++;
                return Text('${vm1.name.value}-${vm2.name.value}');
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      vm1.name.value = 'First';
      await tester.pump();
      expect(buildCount, equals(2));

      vm2.name.value = 'Second';
      await tester.pump();
      expect(buildCount, equals(3));
    });

    testWidgets('should handle regular field changes in both VMs',
        (tester) async {
      final vm1 = FirstViewModel();
      final vm2 = SecondViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (_) => vm1,
              (_) => vm2,
            ],
            child: Bind.viewModel2<FirstViewModel, SecondViewModel>(
              builder: (context, vm1, vm2) =>
                  Text('${vm1.regularField}-${vm2.regularField}'),
            ),
          ),
        ),
      );

      expect(find.text('regular-regular'), findsOneWidget);

      vm1.updateRegularField('changed1');
      await tester.pump();
      expect(find.text('changed1-regular'), findsOneWidget);

      vm2.updateRegularField('changed2');
      await tester.pump();
      expect(find.text('changed1-changed2'), findsOneWidget);
    });
  });

  group('BindObserver3', () {
    testWidgets('should observe three ViewModels', (tester) async {
      final vm1 = FirstViewModel();
      final vm2 = SecondViewModel();
      final vm3 = ThirdViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (_) => vm1,
              (_) => vm2,
              (_) => vm3,
            ],
            child: Bind.viewModel3<FirstViewModel, SecondViewModel,
                ThirdViewModel>(
              builder: (context, vm1, vm2, vm3) =>
                  Text('${vm1.name.value}-${vm2.name.value}-${vm3.name.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Initial-Initial-Initial'), findsOneWidget);

      vm1.name.value = 'A';
      await tester.pump();
      expect(find.text('A-Initial-Initial'), findsOneWidget);

      vm2.name.value = 'B';
      await tester.pump();
      expect(find.text('A-B-Initial'), findsOneWidget);

      vm3.name.value = 'C';
      await tester.pump();
      expect(find.text('A-B-C'), findsOneWidget);
    });

    testWidgets('should track selective properties from each VM',
        (tester) async {
      final vm1 = FirstViewModel();
      final vm2 = SecondViewModel();
      final vm3 = ThirdViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModels: [
              (_) => vm1,
              (_) => vm2,
              (_) => vm3,
            ],
            child: Bind.viewModel3<FirstViewModel, SecondViewModel,
                ThirdViewModel>(
              builder: (context, vm1, vm2, vm3) {
                buildCount++;
                // Only access name from vm1, age from vm2, nothing from vm3
                return Text('${vm1.name.value}-${vm2.age.value}');
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Accessed property changes
      vm1.name.value = 'Test';
      await tester.pump();
      expect(buildCount, equals(2));

      vm2.age.value = 99;
      await tester.pump();
      expect(buildCount, equals(3));

      // Unaccessed properties should NOT trigger rebuilds
      vm1.age.value = 50;
      await tester.pump();
      expect(buildCount, equals(3)); // No rebuild

      vm3.name.value = 'Ignored';
      await tester.pump();
      expect(buildCount, equals(3)); // No rebuild

      // But vm3 regular field changes should trigger rebuild (ViewModel subscription)
      vm3.updateRegularField('changed');
      await tester.pump();
      expect(buildCount, equals(4)); // Rebuilds due to VM subscription
    });
  });

  group('performance', () {
    testWidgets('should handle 100 rapid updates efficiently', (tester) async {
      final vm = TestViewModel();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FairyScope(
            viewModel: (_) => vm,
            child: Bind.viewModel<TestViewModel>(
              builder: (context, vm) {
                buildCount++;
                return Text('${vm.age.value}');
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Make 100 rapid changes
      for (int i = 0; i < 100; i++) {
        vm.age.value = i;
      }

      await tester.pump();

      // Should batch into single rebuild
      expect(buildCount, equals(2));
      expect(find.text('99'), findsOneWidget);
    });
  });
}

// ============================================================================
// Test ViewModels
// ============================================================================

class TestViewModel extends ObservableObject {
  late final ObservableProperty<String> name;
  late final ObservableProperty<int> age;
  late final ObservableProperty<bool> canIncrement;
  late final RelayCommand incrementCommand;
  late final AsyncRelayCommand asyncCommand;

  String regularField = 'regular';

  TestViewModel() {
    name = ObservableProperty<String>('Initial');
    age = ObservableProperty<int>(0);
    canIncrement = ObservableProperty<bool>(true);

    incrementCommand = RelayCommand(
      () => age.value++,
      canExecute: () => canIncrement.value,
    );

    asyncCommand = AsyncRelayCommand(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
  }

  void updateRegularField(String value) {
    regularField = value;
    onPropertyChanged();
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    canIncrement.dispose();
    incrementCommand.dispose();
    asyncCommand.dispose();
    super.dispose();
  }
}

class ComputedViewModel extends ObservableObject {
  late final ObservableProperty<String> firstName;
  late final ObservableProperty<String> lastName;
  late final ComputedProperty<String> fullName;

  ComputedViewModel() {
    firstName = ObservableProperty<String>('John');
    lastName = ObservableProperty<String>('Doe');
    fullName = ComputedProperty<String>(
      () => '${firstName.value} ${lastName.value}',
      [firstName, lastName],
    );
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    fullName.dispose();
    super.dispose();
  }
}

class FirstViewModel extends ObservableObject {
  late final ObservableProperty<String> name;
  late final ObservableProperty<int> age;
  String regularField = 'regular';

  FirstViewModel() {
    name = ObservableProperty<String>('Initial');
    age = ObservableProperty<int>(0);
  }

  void updateRegularField(String value) {
    regularField = value;
    onPropertyChanged();
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    super.dispose();
  }
}

class SecondViewModel extends ObservableObject {
  late final ObservableProperty<String> name;
  late final ObservableProperty<int> age;
  String regularField = 'regular';

  SecondViewModel() {
    name = ObservableProperty<String>('Initial');
    age = ObservableProperty<int>(0);
  }

  void updateRegularField(String value) {
    regularField = value;
    onPropertyChanged();
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    super.dispose();
  }
}

class ThirdViewModel extends ObservableObject {
  late final ObservableProperty<String> name;
  late final ObservableProperty<int> age;
  String regularField = 'regular';

  ThirdViewModel() {
    name = ObservableProperty<String>('Initial');
    age = ObservableProperty<int>(0);
  }

  void updateRegularField(String value) {
    regularField = value;
    onPropertyChanged();
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    super.dispose();
  }
}
