import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/src/core/observable.dart';

void main() {
  group('ObservableProperty<T>', () {
    group('initialization', () {
      test('should initialize with provided value', () {
        final prop = ObservableProperty<int>(42);
        expect(prop.value, equals(42));
        prop.dispose();
      });

      test('should work with nullable types', () {
        final prop = ObservableProperty<String?>(null);
        expect(prop.value, isNull);
        prop.dispose();
      });

      test('should work with complex types', () {
        final list = <int>[1, 2, 3];
        final prop = ObservableProperty<List<int>>(list);
        expect(prop.value, equals([1, 2, 3]));
        expect(prop.value, same(list)); // Same reference
        prop.dispose();
      });
    });

    group('value setter', () {
      test('should update value when set to different value', () {
        final prop = ObservableProperty<int>(0);
        prop.value = 5;
        expect(prop.value, equals(5));
        prop.dispose();
      });

      test('should notify listeners when value changes', () {
        final prop = ObservableProperty<int>(0);
        var notificationCount = 0;
        
        prop.propertyChanged(() {
          notificationCount++;
        });

        prop.value = 5;
        expect(notificationCount, equals(1));

        prop.value = 10;
        expect(notificationCount, equals(2));

        prop.dispose();
      });

      test('should NOT notify listeners when value is the same', () {
        final prop = ObservableProperty<int>(5);
        var notificationCount = 0;
        
        prop.propertyChanged(() {
          notificationCount++;
        });

        prop.value = 5; // Same value
        expect(notificationCount, equals(0));

        prop.value = 5; // Still same
        expect(notificationCount, equals(0));

        prop.dispose();
      });

      test('should notify all registered listeners', () {
        final prop = ObservableProperty<String>('initial');
        var listener1Count = 0;
        var listener2Count = 0;
        var listener3Count = 0;

        prop.propertyChanged(() => listener1Count++);
        prop.propertyChanged(() => listener2Count++);
        prop.propertyChanged(() => listener3Count++);

        prop.value = 'changed';

        expect(listener1Count, equals(1));
        expect(listener2Count, equals(1));
        expect(listener3Count, equals(1));

        prop.dispose();
      });

      test('should work with null values', () {
        final prop = ObservableProperty<String?>('initial');
        var notificationCount = 0;
        
        prop.propertyChanged(() => notificationCount++);

        // non-null to null
        prop.value = null;
        expect(prop.value, isNull);
        expect(notificationCount, equals(1));

        // null to null (no change)
        prop.value = null;
        expect(notificationCount, equals(1)); // Still 1

        // null to non-null
        prop.value = 'restored';
        expect(prop.value, equals('restored'));
        expect(notificationCount, equals(2));

        prop.dispose();
      });
    });

    group('update() method', () {
      test('should update value using updater function', () {
        final prop = ObservableProperty<int>(0);
        
        prop.update((current) => current + 1);
        expect(prop.value, equals(1));

        prop.update((current) => current * 2);
        expect(prop.value, equals(2));

        prop.dispose();
      });

      test('should notify listeners when value changes via update', () {
        final prop = ObservableProperty<int>(10);
        var notificationCount = 0;
        
        prop.propertyChanged(() {
          notificationCount++;
        });

        prop.update((current) => current + 5);
        expect(prop.value, equals(15));
        expect(notificationCount, equals(1));

        prop.dispose();
      });

      test('should NOT notify if updater returns same value', () {
        final prop = ObservableProperty<int>(10);
        var notificationCount = 0;
        
        prop.propertyChanged(() {
          notificationCount++;
        });

        // Return same value
        prop.update((current) => current);
        expect(notificationCount, equals(0));

        prop.dispose();
      });

      test('should work with complex types', () {
        final prop = ObservableProperty<String>('hello');
        
        prop.update((current) => '$current world');
        expect(prop.value, equals('hello world'));

        prop.update((current) => current.toUpperCase());
        expect(prop.value, equals('HELLO WORLD'));

        prop.dispose();
      });

      test('should provide current value to updater', () {
        final prop = ObservableProperty<int>(5);
        var providedValue = 0;
        
        prop.update((current) {
          providedValue = current;
          return current + 1;
        });

        expect(providedValue, equals(5));
        expect(prop.value, equals(6));

        prop.dispose();
      });

      test('should work with nullable types', () {
        final prop = ObservableProperty<int?>(null);
        var notificationCount = 0;
        
        prop.propertyChanged(() => notificationCount++);

        // null to non-null
        prop.update((current) => (current ?? 0) + 1);
        expect(prop.value, equals(1));
        expect(notificationCount, equals(1));

        // non-null to null
        prop.update((current) => null);
        expect(prop.value, isNull);
        expect(notificationCount, equals(2));

        prop.dispose();
      });
    });

    group('listener management', () {
      test('should support multiple listeners', () {
        final prop = ObservableProperty<int>(0);
        final values = <int>[];
        
        prop.propertyChanged(() => values.add(prop.value));
        prop.propertyChanged(() => values.add(prop.value * 2));
        prop.propertyChanged(() => values.add(prop.value * 3));

        prop.value = 5;

        expect(values, equals([5, 10, 15]));

        prop.dispose();
      });

      test('should not notify removed listeners', () {
        final prop = ObservableProperty<String>('initial');
        var notificationCount = 0;
        
        void listener() {
          notificationCount++;
        }

        final disposer = prop.propertyChanged(listener);
        prop.value = 'changed1';
        expect(notificationCount, equals(1));

        disposer();
        prop.value = 'changed2';
        expect(notificationCount, equals(1)); // Still 1

        prop.dispose();
      });

      test('should handle listener removal during notification', () {
        final prop = ObservableProperty<int>(0);
        var listener1Called = false;
        var listener2Called = false;
        late void Function() disposeListener1;
        
        void listener1() {
          listener1Called = true;
        }

        void listener2() {
          listener2Called = true;
          disposeListener1(); // Remove listener1 during notification
        }

        disposeListener1 = prop.propertyChanged(listener1);
        prop.propertyChanged(listener2);

        prop.value = 1;

        expect(listener1Called, isTrue);
        expect(listener2Called, isTrue);

        prop.dispose();
      });
    });

    group('type safety', () {
      test('should enforce type safety with generics', () {
        final intProp = ObservableProperty<int>(0);
        final stringProp = ObservableProperty<String>('');
        final boolProp = ObservableProperty<bool>(false);

        // These should compile (type-safe)
        intProp.value = 42;
        stringProp.value = 'test';
        boolProp.value = true;

        expect(intProp.value, isA<int>());
        expect(stringProp.value, isA<String>());
        expect(boolProp.value, isA<bool>());

        intProp.dispose();
        stringProp.dispose();
        boolProp.dispose();
      });

      test('should work with custom types', () {
        final prop = ObservableProperty<User>(User('Alice', 30));
        
        expect(prop.value.name, equals('Alice'));
        expect(prop.value.age, equals(30));

        prop.value = User('Bob', 25);
        expect(prop.value.name, equals('Bob'));

        prop.dispose();
      });

      test('should work with generic collections', () {
        final listProp = ObservableProperty<List<String>>([]);
        final mapProp = ObservableProperty<Map<String, int>>({});
        final setProp = ObservableProperty<Set<int>>({});

        listProp.value = ['a', 'b'];
        mapProp.value = {'key': 42};
        setProp.value = {1, 2, 3};

        expect(listProp.value, equals(['a', 'b']));
        expect(mapProp.value, equals({'key': 42}));
        expect(setProp.value, equals({1, 2, 3}));

        listProp.dispose();
        mapProp.dispose();
        setProp.dispose();
      });
    });

    group('equality comparison', () {
      test('should use default equality for primitives', () {
        final prop = ObservableProperty<int>(5);
        var notificationCount = 0;
        
        prop.propertyChanged(() => notificationCount++);

        prop.value = 5;
        expect(notificationCount, equals(0)); // No change

        prop.value = 6;
        expect(notificationCount, equals(1)); // Changed

        prop.dispose();
      });

      test('should use reference equality for objects without custom equals', () {
        final user1 = UserWithoutEquals('Alice', 30);
        final user2 = UserWithoutEquals('Alice', 30); // Same values, different object
        
        final prop = ObservableProperty<UserWithoutEquals>(user1);
        var notificationCount = 0;
        
        prop.propertyChanged(() => notificationCount++);

        // Same reference
        prop.value = user1;
        expect(notificationCount, equals(0));

        // Different reference (even with same values)
        prop.value = user2;
        expect(notificationCount, equals(1)); // Notifies because reference differs

        prop.dispose();
      });

      test('should use custom equality for objects with equals override', () {
        final user1 = User('Alice', 30);
        final user2 = User('Alice', 30); // Same values, different object
        
        final prop = ObservableProperty<User>(user1);
        var notificationCount = 0;
        
        prop.propertyChanged(() => notificationCount++);

        // Different object but equal values
        prop.value = user2;
        expect(notificationCount, equals(0)); // No notification (equal values)

        // Different values
        prop.value = User('Bob', 25);
        expect(notificationCount, equals(1));

        prop.dispose();
      });
    });

    group('disposal', () {
      test('should not notify after disposal', () {
        final prop = ObservableProperty<int>(0);
        var notificationCount = 0;
        
        prop.propertyChanged(() => notificationCount++);

        prop.value = 5;
        expect(notificationCount, equals(1));

        prop.dispose();

        // Should throw when trying to modify after disposal
        expect(() => prop.value = 10, throwsFlutterError);
      });

      test('should not allow adding listeners after disposal', () {
        final prop = ObservableProperty<int>(0);
        prop.dispose();

        expect(
          () => prop.propertyChanged(() {}),
          throwsFlutterError,
        );
      });

      test('should still allow reading value after disposal', () {
        final prop = ObservableProperty<int>(42);
        prop.dispose();

        // Reading should still work
        expect(prop.value, equals(42));
      });
    });

    group('integration scenarios', () {
      test('should handle rapid successive changes correctly', () {
        final prop = ObservableProperty<int>(0);
        var notificationCount = 0;
        final capturedValues = <int>[];
        
        prop.propertyChanged(() {
          notificationCount++;
          capturedValues.add(prop.value);
        });

        // Rapid changes
        for (var i = 1; i <= 10; i++) {
          prop.value = i;
        }

        expect(notificationCount, equals(10));
        expect(capturedValues, equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));

        prop.dispose();
      });

      test('should handle alternating update methods', () {
        final prop = ObservableProperty<int>(0);
        var notificationCount = 0;
        
        prop.propertyChanged(() => notificationCount++);

        prop.value = 1;
        prop.update((c) => c + 1);
        prop.value = 3;
        prop.update((c) => c + 1);

        expect(prop.value, equals(4));
        expect(notificationCount, equals(4));

        prop.dispose();
      });

      test('should work in ViewModel scenario', () {
        final viewModel = TestViewModel();
        var nameChangeCount = 0;
        var ageChangeCount = 0;

        viewModel.name.propertyChanged(() => nameChangeCount++);
        viewModel.age.propertyChanged(() => ageChangeCount++);

        viewModel.updateName('Alice');
        expect(nameChangeCount, equals(1));
        expect(ageChangeCount, equals(0));

        viewModel.updateAge(30);
        expect(nameChangeCount, equals(1));
        expect(ageChangeCount, equals(1));

        viewModel.updateName('Alice'); // Same value
        expect(nameChangeCount, equals(1)); // No change

        viewModel.dispose();
      });
    });
  });
}

// Test helper classes

class TestViewModel extends ObservableObject {
  final name = ObservableProperty<String>('');
  final age = ObservableProperty<int>(0);

  void updateName(String value) {
    name.value = value;
  }

  void updateAge(int value) {
    age.value = value;
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    super.dispose();
  }
}

class User {
  final String name;
  final int age;

  User(this.name, this.age);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && name == other.name && age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}

class UserWithoutEquals {
  final String name;
  final int age;

  UserWithoutEquals(this.name, this.age);
}
