import 'package:fairy/src/core/observable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/command.dart';

void main() {
  group('RelayCommand', () {
    group('initialization', () {
      test('should create command with action only', () {
        var executed = false;
        final command = RelayCommand(() => executed = true);
        
        expect(command.canExecute, isTrue);
        
        command.execute();
        expect(executed, isTrue);
        
        command.dispose();
      });

      test('should create command with action and canExecute', () {
        var executed = false;
        var canRun = true;
        
        final command = RelayCommand(
          () => executed = true,
          canExecute: () => canRun,
        );
        
        expect(command.canExecute, isTrue);
        
        command.execute();
        expect(executed, isTrue);
        
        command.dispose();
      });

      test('should default canExecute to true when not provided', () {
        final command = RelayCommand(() {});
        
        expect(command.canExecute, isTrue);
        
        command.dispose();
      });
    });

    group('execute()', () {
      test('should execute action when canExecute is true', () {
        var executeCount = 0;
        final command = RelayCommand(() => executeCount++);
        
        command.execute();
        expect(executeCount, equals(1));
        
        command.execute();
        expect(executeCount, equals(2));
        
        command.dispose();
      });

      test('should NOT execute action when canExecute is false', () {
        var executeCount = 0;
        final command = RelayCommand(
          () => executeCount++,
          canExecute: () => false,
        );
        
        command.execute();
        expect(executeCount, equals(0));
        
        command.dispose();
      });

      test('should respect canExecute predicate', () {
        var executeCount = 0;
        var canRun = true;
        
        final command = RelayCommand(
          () => executeCount++,
          canExecute: () => canRun,
        );
        
        // Can run
        command.execute();
        expect(executeCount, equals(1));
        
        // Cannot run
        canRun = false;
        command.execute();
        expect(executeCount, equals(1)); // Still 1
        
        // Can run again
        canRun = true;
        command.execute();
        expect(executeCount, equals(2));
        
        command.dispose();
      });

      test('should handle exceptions in action', () {
        final command = RelayCommand(() => throw Exception('Test error'));
        
        expect(() => command.execute(), throwsException);
        
        command.dispose();
      });
    });

    group('canExecute', () {
      test('should return true when no predicate provided', () {
        final command = RelayCommand(() {});
        
        expect(command.canExecute, isTrue);
        
        command.dispose();
      });

      test('should return predicate result', () {
        var canRun = true;
        final command = RelayCommand(
          () {},
          canExecute: () => canRun,
        );
        
        expect(command.canExecute, isTrue);
        
        canRun = false;
        expect(command.canExecute, isFalse);
        
        canRun = true;
        expect(command.canExecute, isTrue);
        
        command.dispose();
      });

      test('should re-evaluate predicate on each call', () {
        var callCount = 0;
        final command = RelayCommand(
          () {},
          canExecute: () {
            callCount++;
            return true;
          },
        );
        
        command.canExecute;
        expect(callCount, equals(1));
        
        command.canExecute;
        expect(callCount, equals(2));
        
        command.dispose();
      });
    });

    group('refresh()', () {
      test('should notify listeners when refresh is called', () {
        var notificationCount = 0;
        final command = RelayCommand(() {});
        
        command.canExecuteChanged(() => notificationCount++);
        
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1));
        
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(2));
        
        command.dispose();
      });

      test('should notify all registered listeners', () {
        var listener1Count = 0;
        var listener2Count = 0;
        final command = RelayCommand(() {});
        
        command.canExecuteChanged(() => listener1Count++);
        command.canExecuteChanged(() => listener2Count++);
        
        command.notifyCanExecuteChanged();
        
        expect(listener1Count, equals(1));
        expect(listener2Count, equals(1));
        
        command.dispose();
      });

      test('should be used to update canExecute state in UI', () {
        var isValid = false;
        var canExecuteChecks = <bool>[];
        
        final command = RelayCommand(
          () {},
          canExecute: () => isValid,
        );
        
        command.canExecuteChanged(() {
          canExecuteChecks.add(command.canExecute);
        });
        
        // Initially false
        expect(command.canExecute, isFalse);
        
        // Change condition and refresh
        isValid = true;
        command.notifyCanExecuteChanged(); // UI should check canExecute now
        
        expect(canExecuteChecks.last, isTrue);
        
        command.dispose();
      });
    });

    group('listener management', () {
      test('should support multiple listeners', () {
        final command = RelayCommand(() {});
        final callOrder = <int>[];
        
        command.canExecuteChanged(() => callOrder.add(1));
        command.canExecuteChanged(() => callOrder.add(2));
        command.canExecuteChanged(() => callOrder.add(3));
        
        command.notifyCanExecuteChanged();
        
        expect(callOrder, equals([1, 2, 3]));
        
        command.dispose();
      });

      test('should not notify removed listeners', () {
        var notificationCount = 0;
        final command = RelayCommand(() {});
        
        void listener() {
          notificationCount++;
        }
        
        final disposer = command.canExecuteChanged(listener);
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1));
        
        disposer();
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1)); // Still 1
        
        command.dispose();
      });
    });

    group('disposal', () {
      test('should not notify after disposal', () {
        final command = RelayCommand(() {});
        var notificationCount = 0;
        
        command.canExecuteChanged(() => notificationCount++);
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1));
        
        command.dispose();
        
        // ObservableNode allows notifying after disposal (listeners cleared)
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1)); // Still 1, not incremented
      });

      test('should allow adding listeners after disposal', () {
        final command = RelayCommand(() {});
        command.dispose();
        
        // ObservableNode allows adding listeners after disposal
        expect(() => command.canExecuteChanged(() {}), returnsNormally);
      });
    });

    group('integration scenarios', () {
      test('should work in ViewModel scenario with validation', () {
        final viewModel = TestViewModel();
        
        viewModel.saveCommand.canExecuteChanged(() {});
        
        // Initially cannot save (empty username)
        expect(viewModel.saveCommand.canExecute, isFalse);
        viewModel.saveCommand.execute();
        expect(viewModel.saveCount, equals(0));
        
        // Set username and refresh command
        viewModel.userName.value = 'Alice';
        viewModel.saveCommand.notifyCanExecuteChanged();
        
        // Now can save
        expect(viewModel.saveCommand.canExecute, isTrue);
        viewModel.saveCommand.execute();
        expect(viewModel.saveCount, equals(1));
        
        viewModel.dispose();
      });

      test('should handle multiple rapid refreshes', () {
        var notificationCount = 0;
        final command = RelayCommand(() {});
        
        command.canExecuteChanged(() => notificationCount++);
        
        for (var i = 0; i < 100; i++) {
          command.notifyCanExecuteChanged();
        }
        
        expect(notificationCount, equals(100));
        
        command.dispose();
      });
    });
  });

  group('AsyncRelayCommand', () {
    group('initialization', () {
      test('should create async command with action only', () async {
        var executed = false;
        final command = AsyncRelayCommand(() async {
          executed = true;
        });
        
        expect(command.canExecute, isTrue);
        expect(command.isRunning, isFalse);
        
        await command.execute();
        expect(executed, isTrue);
        
        command.dispose();
      });

      test('should create async command with action and canExecute', () async {
        var executed = false;
        var canRun = true;
        
        final command = AsyncRelayCommand(
          () async => executed = true,
          canExecute: () => canRun,
        );
        
        expect(command.canExecute, isTrue);
        await command.execute();
        expect(executed, isTrue);
        
        command.dispose();
      });

      test('should default canExecute to true when not provided', () {
        final command = AsyncRelayCommand(() async {});
        
        expect(command.canExecute, isTrue);
        expect(command.isRunning, isFalse);
        
        command.dispose();
      });
    });

    group('execute()', () {
      test('should execute async action', () async {
        var executeCount = 0;
        final command = AsyncRelayCommand(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          executeCount++;
        });
        
        await command.execute();
        expect(executeCount, equals(1));
        
        await command.execute();
        expect(executeCount, equals(2));
        
        command.dispose();
      });

      test('should NOT execute when canExecute is false', () async {
        var executeCount = 0;
        final command = AsyncRelayCommand(
          () async => executeCount++,
          canExecute: () => false,
        );
        
        await command.execute();
        expect(executeCount, equals(0));
        
        command.dispose();
      });

      test('should handle exceptions and reset isRunning', () async {
        final command = AsyncRelayCommand(() async {
          throw Exception('Test error');
        });
        
        expect(command.isRunning, isFalse);
        
        try {
          await command.execute();
        } catch (_) {
          // Expected
        }
        
        // isRunning should be reset even after exception
        expect(command.isRunning, isFalse);
        expect(command.canExecute, isTrue);
        
        command.dispose();
      });
    });

    group('isRunning state', () {
      test('should set isRunning to true during execution', () async {
        final command = AsyncRelayCommand(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        
        expect(command.isRunning, isFalse);
        
        final future = command.execute();
        
        // Should be running now
        expect(command.isRunning, isTrue);
        
        await future;
        
        // Should be done
        expect(command.isRunning, isFalse);
        
        command.dispose();
      });

      test('should notify listeners when isRunning changes', () async {
        var notificationCount = 0;
        final isRunningStates = <bool>[];
        
        final command = AsyncRelayCommand(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        
        command.canExecuteChanged(() {
          notificationCount++;
          isRunningStates.add(command.isRunning);
        });
        
        await command.execute();
        
        // Should notify: once when starting, once when completing
        expect(notificationCount, equals(2));
        expect(isRunningStates, equals([true, false]));
        
        command.dispose();
      });

      test('should reset isRunning even if action throws', () async {
        final command = AsyncRelayCommand(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw Exception('Error');
        });
        
        expect(command.isRunning, isFalse);
        
        try {
          await command.execute();
        } catch (_) {}
        
        expect(command.isRunning, isFalse);
        
        command.dispose();
      });
    });

    group('canExecute with isRunning', () {
      test('should disable canExecute while running', () async {
        var canRun = true;
        final command = AsyncRelayCommand(
          () async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          },
          canExecute: () => canRun,
        );
        
        expect(command.canExecute, isTrue);
        
        final future = command.execute();
        
        // Should be disabled while running, even though predicate is true
        expect(command.canExecute, isFalse);
        
        await future;
        
        // Should be enabled again
        expect(command.canExecute, isTrue);
        
        command.dispose();
      });

      test('should respect canExecute predicate when not running', () async {
        var canRun = true;
        final command = AsyncRelayCommand(
          () async {},
          canExecute: () => canRun,
        );
        
        expect(command.canExecute, isTrue);
        
        canRun = false;
        expect(command.canExecute, isFalse);
        
        canRun = true;
        expect(command.canExecute, isTrue);
        
        command.dispose();
      });
    });

    group('re-entry prevention', () {
      test('should prevent concurrent execution', () async {
        var executionCount = 0;
        final command = AsyncRelayCommand(() async {
          executionCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        
        // Start first execution
        final future1 = command.execute();
        
        // Try to start second execution (should be ignored)
        final future2 = command.execute();
        final future3 = command.execute();
        
        await Future.wait([future1, future2, future3]);
        
        // Should only execute once
        expect(executionCount, equals(1));
        
        command.dispose();
      });

      test('should allow execution after previous completes', () async {
        var executionCount = 0;
        final command = AsyncRelayCommand(() async {
          executionCount++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        
        await command.execute();
        expect(executionCount, equals(1));
        
        await command.execute();
        expect(executionCount, equals(2));
        
        await command.execute();
        expect(executionCount, equals(3));
        
        command.dispose();
      });
    });

    group('refresh()', () {
      test('should notify listeners when refresh is called', () {
        var notificationCount = 0;
        final command = AsyncRelayCommand(() async {});
        
        command.canExecuteChanged(() => notificationCount++);
        
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1));
        
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(2));
        
        command.dispose();
      });

      test('should be used to update canExecute state', () {
        var isValid = false;
        final command = AsyncRelayCommand(
          () async {},
          canExecute: () => isValid,
        );
        
        expect(command.canExecute, isFalse);
        
        isValid = true;
        command.notifyCanExecuteChanged();
        
        expect(command.canExecute, isTrue);
        
        command.dispose();
      });
    });

    group('disposal', () {
      test('should not notify after disposal', () {
        final command = AsyncRelayCommand(() async {});
        var notificationCount = 0;
        
        command.canExecuteChanged(() => notificationCount++);
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1));
        
        command.dispose();
        
        // ObservableNode allows notifying after disposal (listeners cleared)
        command.notifyCanExecuteChanged();
        expect(notificationCount, equals(1)); // Still 1, not incremented
      });
    });

    group('integration scenarios', () {
      test('should work in ViewModel data fetching scenario', () async {
        final viewModel = AsyncTestViewModel();
        final capturedStates = <bool>[];
        
        viewModel.fetchCommand.canExecuteChanged(() {
          capturedStates.add(viewModel.fetchCommand.isRunning);
        });
        
        expect(viewModel.fetchCommand.isRunning, isFalse);
        expect(viewModel.data.value, isEmpty);
        
        await viewModel.fetchCommand.execute();
        
        expect(viewModel.data.value, equals(['item1', 'item2', 'item3']));
        expect(viewModel.fetchCommand.isRunning, isFalse);
        expect(capturedStates, equals([true, false]));
        
        viewModel.dispose();
      });

      test('should handle rapid execute attempts correctly', () async {
        var executionCount = 0;
        final command = AsyncRelayCommand(() async {
          executionCount++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        
        // Fire multiple executions rapidly
        final futures = <Future<void>>[];
        for (var i = 0; i < 10; i++) {
          futures.add(command.execute());
        }
        
        await Future.wait(futures);
        
        // Should only execute once (first call)
        expect(executionCount, equals(1));
        
        command.dispose();
      });
    });
  });
}

// Test helper classes

class TestViewModel {
  final userName = ObservableProperty<String>('');
  late final RelayCommand saveCommand;
  var saveCount = 0;

  TestViewModel() {
    saveCommand = RelayCommand(
      _save,
      canExecute: () => userName.value.isNotEmpty,
    );
  }

  void _save() {
    saveCount++;
  }

  void dispose() {
    // userName auto-disposed
    saveCommand.dispose();
  }
}

class AsyncTestViewModel {
  final data = ObservableProperty<List<String>>([]);
  late final AsyncRelayCommand fetchCommand;

  AsyncTestViewModel() {
    fetchCommand = AsyncRelayCommand(_fetchData);
  }

  Future<void> _fetchData() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    data.value = ['item1', 'item2', 'item3'];
  }

  void dispose() {
    fetchCommand.dispose();
  }
}
