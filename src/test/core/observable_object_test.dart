import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';

// Test implementation of ObservableObject
class TestViewModel extends ObservableObject {
  int _count = 0;
  int get count => _count;

  String _name = '';
  String get name => _name;

  // Manual property setter with notify
  void setCountManually(int value) {
    _count = value;
    onPropertyChanged();
  }

  // Using setProperty helper
  void setCountWithHelper(int value) {
    setProperty(_count, value, () => _count = value);
  }

  void setName(String value) {
    setProperty(_name, value, () => _name = value);
  }

  // Method that doesn't change state
  void doNothing() {
    // Intentionally empty
  }

  // Public access to setProperty for testing
  bool testSetProperty<T>(T oldValue, T newValue, void Function() assign) {
    return setProperty(oldValue, newValue, assign);
  }

  // Public access to notify for testing
  void testNotify() {
    onPropertyChanged();
  }

  // Public access to hasListeners for testing
  bool get testHasListeners => hasListeners;
}

void main() {
  group('ObservableObject', () {
    late TestViewModel viewModel;

    setUp(() {
      viewModel = TestViewModel();
    });

    tearDown(() {
      // Safe disposal - ignore if already disposed
      try {
        viewModel.dispose();
      } catch (_) {
        // Already disposed, which is fine
      }
    });

    group('onPropertyChanged()', () {
      test('should call notifyListeners when onPropertyChanged is called', () {
        var notificationCount = 0;
        final dispose = viewModel.propertyChanged(() {
          notificationCount++;
        });

        viewModel.testNotify();
        expect(notificationCount, equals(1));

        viewModel.testNotify();
        expect(notificationCount, equals(2));
        
        dispose();
      });

      test('should notify all registered listeners', () {
        var listener1Count = 0;
        var listener2Count = 0;
        var listener3Count = 0;

        final dispose1 = viewModel.propertyChanged(() => listener1Count++);
        final dispose2 = viewModel.propertyChanged(() => listener2Count++);
        final dispose3 = viewModel.propertyChanged(() => listener3Count++);

        viewModel.testNotify();

        expect(listener1Count, equals(1));
        expect(listener2Count, equals(1));
        expect(listener3Count, equals(1));
        
        dispose1();
        dispose2();
        dispose3();
      });

      test('should not notify removed listeners', () {
        var notificationCount = 0;
        void listener() {
          notificationCount++;
        }

        final dispose = viewModel.propertyChanged(listener);
        viewModel.testNotify();
        expect(notificationCount, equals(1));

        dispose();
        viewModel.testNotify();
        expect(notificationCount, equals(1)); // Still 1, not incremented
      });
    });

    group('setProperty()', () {
      test('should notify listeners when value changes', () {
        var notificationCount = 0;
        final dispose = viewModel.propertyChanged(() {
          notificationCount++;
        });

        viewModel.setCountWithHelper(5);
        expect(viewModel.count, equals(5));
        expect(notificationCount, equals(1));
        
        dispose();
      });

      test('should NOT notify listeners when value is the same', () {
        var notificationCount = 0;
        viewModel.setCountWithHelper(10);
        
        final dispose = viewModel.propertyChanged(() {
          notificationCount++;
        });

        viewModel.setCountWithHelper(10); // Same value
        expect(viewModel.count, equals(10));
        expect(notificationCount, equals(0)); // No notification
        
        dispose();
      });

      test('should return true when value changes', () {
        var changed = viewModel.testSetProperty(
          0,
          5,
          () {}, // Empty assign for testing return value
        );
        expect(changed, isTrue);
      });

      test('should return false when value stays the same', () {
        var changed = viewModel.testSetProperty(
          5,
          5,
          () {}, // Empty assign for testing return value
        );
        expect(changed, isFalse);
      });

      test('should call assign function when value changes', () {
        var assignCalled = false;
        viewModel.testSetProperty(
          0,
          5,
          () => assignCalled = true,
        );
        expect(assignCalled, isTrue);
      });

      test('should NOT call assign function when value is the same', () {
        var assignCalled = false;
        viewModel.testSetProperty(
          5,
          5,
          () => assignCalled = true,
        );
        expect(assignCalled, isFalse);
      });

      test('should work with different types', () {
        var notificationCount = 0;
        final dispose = viewModel.propertyChanged(() {
          notificationCount++;
        });

        // Test with String
        viewModel.setName('Alice');
        expect(viewModel.name, equals('Alice'));
        expect(notificationCount, equals(1));

        // Same value should not notify
        viewModel.setName('Alice');
        expect(notificationCount, equals(1));

        // Different value should notify
        viewModel.setName('Bob');
        expect(viewModel.name, equals('Bob'));
        expect(notificationCount, equals(2));
        
        dispose();
      });

      test('should handle null values correctly', () {
        String? nullableValue;
        var notificationCount = 0;
        final dispose = viewModel.propertyChanged(() => notificationCount++);

        // null to non-null
        var changed = viewModel.testSetProperty(
          nullableValue,
          'value',
          () => nullableValue = 'value',
        );
        expect(changed, isTrue);
        expect(notificationCount, equals(1));

        // non-null to null
        changed = viewModel.testSetProperty(
          nullableValue,
          null,
          () => nullableValue = null,
        );
        expect(changed, isTrue);
        expect(notificationCount, equals(2));

        // null to null
        changed = viewModel.testSetProperty(
          nullableValue,
          null,
          () => nullableValue = null,
        );
        expect(changed, isFalse);
        expect(notificationCount, equals(2));
        
        dispose();
      });
    });

    group('manual notification', () {
      test('should notify when using manual onPropertyChanged() call', () {
        var notificationCount = 0;
        final dispose = viewModel.propertyChanged(() {
          notificationCount++;
        });

        viewModel.setCountManually(42);
        expect(viewModel.count, equals(42));
        expect(notificationCount, equals(1));
        
        dispose();
      });

      test('should allow notification even without property changes', () {
        var notificationCount = 0;
        final dispose = viewModel.propertyChanged(() {
          notificationCount++;
        });

        // Change value
        viewModel.setCountManually(5);
        expect(notificationCount, equals(1));

        // Set to same value but still notify (manual control)
        viewModel.setCountManually(5);
        expect(notificationCount, equals(2)); // Still notifies
        
        dispose();
      });
    });

    group('disposal', () {
      test('should not notify listeners after disposal', () {
        var notificationCount = 0;
        final dispose = viewModel.propertyChanged(() {
          notificationCount++;
        });

        viewModel.testNotify();
        expect(notificationCount, equals(1));

        dispose();
        viewModel.dispose();

        // Attempting to notify after disposal should throw
        expect(() => viewModel.testNotify(), throwsFlutterError);
      });

      test('should throw when disposed multiple times', () {
        viewModel.dispose();
        // ChangeNotifier throws when disposed twice in debug mode
        expect(() => viewModel.dispose(), throwsFlutterError);
      });

      test('should not allow adding listeners after disposal', () {
        viewModel.dispose();
        expect(
          () => viewModel.propertyChanged(() {}),
          throwsFlutterError,
        );
      });
    });

    group('listen() method', () {
      test('should support multiple listeners', () {
        final counts = <int>[];
        
        final dispose1 = viewModel.propertyChanged(() => counts.add(1));
        final dispose2 = viewModel.propertyChanged(() => counts.add(2));
        final dispose3 = viewModel.propertyChanged(() => counts.add(3));

        viewModel.testNotify();

        expect(counts, equals([1, 2, 3]));
        
        dispose1();
        dispose2();
        dispose3();
      });

      test('should allow same listener to be added multiple times', () {
        var count = 0;
        void listener() => count++;

        final dispose1 = viewModel.propertyChanged(listener);
        final dispose2 = viewModel.propertyChanged(listener);
        final dispose3 = viewModel.propertyChanged(listener);

        viewModel.testNotify();

        // Flutter's ChangeNotifier calls each registration separately
        expect(count, equals(3));
        
        dispose1();
        dispose2();
        dispose3();
      });

      test('should only remove one instance of duplicate listeners', () {
        var count = 0;
        void listener() => count++;

        final dispose1 = viewModel.propertyChanged(listener);
        final dispose2 = viewModel.propertyChanged(listener);
        
        dispose1(); // Removes one
        
        viewModel.testNotify();
        expect(count, equals(1)); // One listener still registered
        
        dispose2();
      });
      
      test('should return disposer function that removes listener', () {
        var count = 0;
        final dispose = viewModel.propertyChanged(() => count++);
        
        viewModel.testNotify();
        expect(count, equals(1));
        
        dispose(); // Remove listener
        
        viewModel.testNotify();
        expect(count, equals(1)); // Count unchanged - listener removed
      });
    });

    group('hasListeners', () {
      test('should return false when no listeners are registered', () {
        expect(viewModel.testHasListeners, isFalse);
      });

      test('should return true when listeners are registered', () {
        final dispose = viewModel.propertyChanged(() {});
        expect(viewModel.testHasListeners, isTrue);
        dispose();
      });

      test('should return false after all listeners are removed', () {
        void listener() {}
        
        final dispose = viewModel.propertyChanged(listener);
        expect(viewModel.testHasListeners, isTrue);
        
        dispose();
        expect(viewModel.testHasListeners, isFalse);
      });
    });

    group('integration scenarios', () {
      test('should handle complex state updates correctly', () {
        var notificationCount = 0;
        final dispose = viewModel.propertyChanged(() => notificationCount++);

        // Multiple changes
        viewModel.setCountWithHelper(1);
        viewModel.setName('Test');
        viewModel.setCountWithHelper(2);

        expect(viewModel.count, equals(2));
        expect(viewModel.name, equals('Test'));
        expect(notificationCount, equals(3));
        
        dispose();
      });

      test('should handle mixed manual and automatic notifications', () {
        var notificationCount = 0;
        final dispose = viewModel.propertyChanged(() => notificationCount++);

        viewModel.setCountManually(1);
        viewModel.setCountWithHelper(2);
        viewModel.testNotify();

        expect(notificationCount, equals(3));
        
        dispose();
      });
    });
  });
}
