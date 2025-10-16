import 'package:fairy/fairy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObservableProperty Deep Equality', () {
    group('Lists', () {
      test('detects identical lists as equal (no rebuild)', () {
        final prop = ObservableProperty<List<int>>([1, 2, 3]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same contents, different object
        prop.value = [1, 2, 3];

        expect(notifyCount, 0, reason: 'Should not notify for equal lists');
      });

      test('detects different lists as not equal (rebuild)', () {
        final prop = ObservableProperty<List<int>>([1, 2, 3]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = [1, 2, 3, 4];

        expect(notifyCount, 1, reason: 'Should notify for different lists');
      });

      test('handles empty lists correctly', () {
        final prop = ObservableProperty<List<int>>([]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = [];
        expect(notifyCount, 0);

        prop.value = [1];
        expect(notifyCount, 1);
      });

      test('handles nested lists with deep equality', () {
        final prop = ObservableProperty<List<List<int>>>([
          [1, 2],
          [3, 4]
        ]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same structure, different objects - should NOT rebuild with deep equality
        prop.value = [
          [1, 2],
          [3, 4]
        ];

        // Deep equality now recursively compares nested lists
        expect(notifyCount, 0, reason: 'Should not rebuild for deeply equal nested lists');

        // Different nested content - should rebuild
        prop.value = [
          [1, 2],
          [3, 5]
        ]; // Changed 4 to 5

        expect(notifyCount, 1, reason: 'Should rebuild for different nested content');
      });
    });

    group('Maps', () {
      test('detects identical maps as equal (no rebuild)', () {
        final prop = ObservableProperty<Map<String, int>>({'a': 1, 'b': 2});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = {'a': 1, 'b': 2};

        expect(notifyCount, 0, reason: 'Should not notify for equal maps');
      });

      test('detects different maps as not equal (rebuild)', () {
        final prop = ObservableProperty<Map<String, int>>({'a': 1, 'b': 2});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = {'a': 1, 'b': 3};

        expect(notifyCount, 1, reason: 'Should notify for different maps');
      });

      test('detects different keys as not equal', () {
        final prop = ObservableProperty<Map<String, int>>({'a': 1, 'b': 2});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = {'a': 1, 'c': 2};

        expect(notifyCount, 1);
      });

      test('handles empty maps correctly', () {
        final prop = ObservableProperty<Map<String, int>>({});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = {};
        expect(notifyCount, 0);

        prop.value = {'a': 1};
        expect(notifyCount, 1);
      });
    });

    group('Sets', () {
      test('detects identical sets as equal (no rebuild)', () {
        final prop = ObservableProperty<Set<int>>({1, 2, 3});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = {1, 2, 3};

        expect(notifyCount, 0, reason: 'Should not notify for equal sets');
      });

      test('detects different sets as not equal (rebuild)', () {
        final prop = ObservableProperty<Set<int>>({1, 2, 3});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = {1, 2, 3, 4};

        expect(notifyCount, 1, reason: 'Should notify for different sets');
      });

      test('order does not matter in sets', () {
        final prop = ObservableProperty<Set<int>>({1, 2, 3});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Different order, same contents
        prop.value = {3, 1, 2};

        expect(notifyCount, 0, reason: 'Sets are order-independent');
      });

      test('handles empty sets correctly', () {
        final prop = ObservableProperty<Set<int>>({});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = {};
        expect(notifyCount, 0);

        prop.value = {1};
        expect(notifyCount, 1);
      });
    });

    group('Primitive Types (reference equality)', () {
      test('int uses default equality', () {
        final prop = ObservableProperty<int>(42);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = 42;
        expect(notifyCount, 0);

        prop.value = 43;
        expect(notifyCount, 1);
      });

      test('String uses default equality', () {
        final prop = ObservableProperty<String>('hello');
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = 'hello';
        expect(notifyCount, 0);

        prop.value = 'world';
        expect(notifyCount, 1);
      });

      test('bool uses default equality', () {
        final prop = ObservableProperty<bool>(true);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = true;
        expect(notifyCount, 0);

        prop.value = false;
        expect(notifyCount, 1);
      });
    });

    group('Deep Equality Disabled', () {
      test('lists use reference equality when deepEquality is false', () {
        final prop = ObservableProperty<List<int>>([1, 2, 3], deepEquality: false);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same contents, different object
        prop.value = [1, 2, 3];

        expect(notifyCount, 1, reason: 'Should use reference equality');
      });

      test('maps use reference equality when deepEquality is false', () {
        final prop = ObservableProperty<Map<String, int>>(
          {'a': 1},
          deepEquality: false,
        );
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = {'a': 1};

        expect(notifyCount, 1, reason: 'Should use reference equality');
      });

      test('sets use reference equality when deepEquality is false', () {
        final prop = ObservableProperty<Set<int>>({1, 2}, deepEquality: false);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = {1, 2};

        expect(notifyCount, 1, reason: 'Should use reference equality');
      });
    });

    group('Null Handling', () {
      test('handles null to null transition', () {
        final prop = ObservableProperty<List<int>?>(null);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = null;

        expect(notifyCount, 0);
      });

      test('handles null to non-null transition', () {
        final prop = ObservableProperty<List<int>?>(null);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = [1, 2, 3];

        expect(notifyCount, 1);
      });

      test('handles non-null to null transition', () {
        final prop = ObservableProperty<List<int>?>([1, 2, 3]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.value = null;

        expect(notifyCount, 1);
      });
    });

    group('Update Method', () {
      test('update() uses deep equality for lists', () {
        final prop = ObservableProperty<List<int>>([1, 2, 3]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Update returns same contents
        prop.update((current) => [1, 2, 3]);

        expect(notifyCount, 0, reason: 'Deep equality should prevent notification');
      });

      test('update() triggers on different list', () {
        final prop = ObservableProperty<List<int>>([1, 2, 3]);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.update((current) => [...current, 4]);

        expect(notifyCount, 1);
        expect(prop.value, [1, 2, 3, 4]);
      });

      test('update() uses deep equality for maps', () {
        final prop = ObservableProperty<Map<String, int>>({'a': 1});
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        prop.update((current) => {'a': 1});

        expect(notifyCount, 0);
      });
    });

    group('Custom Types with Overridden Equality', () {
      test('respects custom == operator', () {
        final user1 = User('1', 'Alice');
        final user2 = User('1', 'Bob'); // Same ID, different name
        final user3 = User('2', 'Alice'); // Different ID, same name

        final prop = ObservableProperty<User>(user1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same ID, should be considered equal
        prop.value = user2;
        expect(notifyCount, 0, reason: 'User equality based on ID');

        // Different ID, should trigger notification
        prop.value = user3;
        expect(notifyCount, 1);
      });
    });

    group('Custom Types with Collections (No Custom Equality)', () {
      test('triggers rebuild for same contents without overridden ==', () {
        final todo1 = TodoItem('Work', ['Task 1', 'Task 2']);
        final todo2 = TodoItem('Work', ['Task 1', 'Task 2']); // Same data, different object

        final prop = ObservableProperty<TodoItem>(todo1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Without overridden ==, different object instances are not equal
        prop.value = todo2;
        expect(
          notifyCount,
          1,
          reason: 'Without custom ==, different objects should trigger rebuild',
        );
      });

      test('does not rebuild for identical object reference', () {
        final todo = TodoItem('Work', ['Task 1', 'Task 2']);

        final prop = ObservableProperty<TodoItem>(todo);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same reference
        prop.value = todo;
        expect(notifyCount, 0, reason: 'Identical reference should not trigger rebuild');
      });

      test('demonstrates need for custom equality in models with collections', () {
        // This test shows why users should override == for models with collections

        final todo1 = TodoItem('Work', ['Task 1']);
        final prop = ObservableProperty<TodoItem>(todo1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Add a task by creating new TodoItem
        prop.value = TodoItem('Work', ['Task 1', 'Task 2']);
        expect(notifyCount, 1, reason: 'Should trigger rebuild for different data');

        // Set back to original data (new object)
        prop.value = TodoItem('Work', ['Task 1']);
        expect(
          notifyCount,
          2,
          reason: 'Without custom ==, even "equivalent" data triggers rebuild',
        );

        // To prevent this, users should:
        // 1. Override == in TodoItem to compare name and listEquals(items)
        // 2. This would make TodoItem('Work', ['Task 1']) == TodoItem('Work', ['Task 1'])
      });
    });

    group('Performance - Identical Check', () {
      test('identical objects short-circuit comparison', () {
        final list = [1, 2, 3];
        final prop = ObservableProperty<List<int>>(list);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same reference
        prop.value = list;

        expect(notifyCount, 0, reason: 'Identical check should short-circuit');
      });
    });

    group('Nested Custom Types with Collections', () {
      test('nested custom types with proper equality work correctly', () {
        // Create nested structure: Person -> Address -> List
        // Person also has Set and List
        final address1 = Address('123 Main St', ['Park', 'School']);
        final person1 = Person(
          'John',
          address1,
          {'reading', 'coding'},
          ['Dart', 'Flutter'],
        );

        final prop = ObservableProperty<Person>(person1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same data, different objects - should NOT rebuild
        final address2 = Address('123 Main St', ['Park', 'School']);
        final person2 = Person(
          'John',
          address2,
          {'reading', 'coding'},
          ['Dart', 'Flutter'],
        );
        prop.value = person2;
        expect(notifyCount, 0, reason: 'Same data should not trigger rebuild');

        // Different address - should rebuild
        final address3 = Address('456 Oak Ave', ['Mall', 'Library']);
        final person3 = Person(
          'John',
          address3,
          {'reading', 'coding'},
          ['Dart', 'Flutter'],
        );
        prop.value = person3;
        expect(notifyCount, 1, reason: 'Different address should rebuild');

        // Different hobbies (Set) - should rebuild
        final person4 = Person(
          'John',
          address3,
          {'gaming', 'cooking'},
          ['Dart', 'Flutter'],
        );
        prop.value = person4;
        expect(notifyCount, 2, reason: 'Different hobbies should rebuild');

        // Different skills (List) - should rebuild
        final person5 = Person(
          'John',
          address3,
          {'gaming', 'cooking'},
          ['Python', 'JavaScript'],
        );
        prop.value = person5;
        expect(notifyCount, 3, reason: 'Different skills should rebuild');
      });

      test('nested custom types respect collection order in Lists', () {
        final address1 = Address('123 Main St', ['Park', 'School']);
        final person1 = Person('Alice', address1, {'coding'}, ['A', 'B']);

        final prop = ObservableProperty<Person>(person1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Different order in skills list - should rebuild
        final address2 = Address('123 Main St', ['Park', 'School']);
        final person2 = Person('Alice', address2, {'coding'}, ['B', 'A']);
        prop.value = person2;
        expect(notifyCount, 1, reason: 'Different list order should rebuild');
      });

      test('nested custom types ignore order in Sets', () {
        final address1 = Address('123 Main St', ['Park', 'School']);
        final person1 = Person('Bob', address1, {'x', 'y', 'z'}, ['skill']);

        final prop = ObservableProperty<Person>(person1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Different order in hobbies set - should NOT rebuild
        final address2 = Address('123 Main St', ['Park', 'School']);
        final person2 = Person('Bob', address2, {'z', 'y', 'x'}, ['skill']);
        prop.value = person2;
        expect(notifyCount, 0, reason: 'Different set order should not rebuild');
      });

      test('deep nested equality with multiple collection types', () {
        final address1 = Address('Home', ['A', 'B', 'C']);
        final person1 = Person(
          'Test',
          address1,
          {'h1', 'h2', 'h3'},
          ['s1', 's2', 's3'],
        );

        final prop = ObservableProperty<Person>(person1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Exact same data - no rebuild
        final address2 = Address('Home', ['A', 'B', 'C']);
        final person2 = Person(
          'Test',
          address2,
          {'h1', 'h2', 'h3'},
          ['s1', 's2', 's3'],
        );
        prop.value = person2;
        expect(notifyCount, 0);

        // Different nested list in Address - should rebuild
        final address3 = Address('Home', ['A', 'B', 'D']); // Changed C to D
        final person3 = Person(
          'Test',
          address3,
          {'h1', 'h2', 'h3'},
          ['s1', 's2', 's3'],
        );
        prop.value = person3;
        expect(notifyCount, 1, reason: 'Nested list change should rebuild');
      });

      test('deeply nested structures with multiple levels', () {
        // 3 levels deep: List<Map<String, List<int>>>
        final deep1 = [
          {'a': [1, 2], 'b': [3, 4]},
          {'c': [5, 6], 'd': [7, 8]},
        ];
        final deep2 = [
          {'a': [1, 2], 'b': [3, 4]},
          {'c': [5, 6], 'd': [7, 8]},
        ];

        final prop = ObservableProperty<List<Map<String, List<int>>>>(deep1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same data, different objects - should NOT rebuild
        prop.value = deep2;
        expect(notifyCount, 0, reason: 'Deep equality should handle 3 levels');

        // Change deep nested value
        final deep3 = [
          {'a': [1, 2], 'b': [3, 4]},
          {'c': [5, 6], 'd': [7, 9]}, // Changed 8 to 9
        ];
        prop.value = deep3;
        expect(notifyCount, 1, reason: 'Should detect deep nested change');
      });

      test('complex mixed nested structure', () {
        // Map<String, dynamic> with mixed types
        final complex1 = {
          'users': [
            {'name': 'Alice', 'tags': ['admin', 'user']},
            {'name': 'Bob', 'tags': ['user']},
          ],
          'settings': {
            'theme': 'dark',
            'notifications': [
              'email',
              'push'
            ]
          },
        };

        final complex2 = {
          'users': [
            {'name': 'Alice', 'tags': ['admin', 'user']},
            {'name': 'Bob', 'tags': ['user']},
          ],
          'settings': {
            'theme': 'dark',
            'notifications': [
              'email',
              'push'
            ]
          },
        };

        final prop = ObservableProperty<Map<String, dynamic>>(complex1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same data - should NOT rebuild
        prop.value = complex2;
        expect(notifyCount, 0, reason: 'Should handle complex nested structures');
      });

      test('set with nested lists', () {
        final set1 = {
          [1, 2],
          [3, 4]
        };
        final set2 = {
          [3, 4],
          [1, 2]
        }; // Different order

        final prop = ObservableProperty<Set<List<int>>>(set1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same elements, different order - should NOT rebuild (sets are unordered)
        prop.value = set2;
        expect(notifyCount, 0, reason: 'Set order should not matter with deep equality');

        // Different nested content
        final set3 = {
          [1, 2],
          [3, 5]
        }; // Changed [3, 4] to [3, 5]
        prop.value = set3;
        expect(notifyCount, 1, reason: 'Should detect nested list changes in set');
      });

      test('demonstrates why deepEquality: false is needed for custom collections', () {
        // If deepEquality is true (default), it won't work as expected
        // because Person is not a List/Map/Set itself
        final address = Address('Street', ['L1']);
        final person = Person('Name', address, {'h'}, ['s']);

        // With deepEquality: true (default) - uses Person's == operator
        final prop1 = ObservableProperty<Person>(person);
        var count1 = 0;
        prop1.propertyChanged(() => count1++);

        // Same data, different object
        final address2 = Address('Street', ['L1']);
        final person2 = Person('Name', address2, {'h'}, ['s']);
        prop1.value = person2;
        expect(count1, 0, reason: 'deepEquality: true still uses Person == operator');

        // With deepEquality: false - also uses Person's == operator
        final prop2 = ObservableProperty<Person>(person, deepEquality: false);
        var count2 = 0;
        prop2.propertyChanged(() => count2++);

        prop2.value = person2;
        expect(count2, 0, reason: 'deepEquality: false uses Person == operator');

        // Both behave the same because Person is not a collection type
        // deepEquality parameter only matters for List/Map/Set types
      });
    });

    group('Nested Custom Types WITHOUT Custom Equality', () {
      test('rebuilds on every assignment even with same data', () {
        // Create nested structure without custom equality
        final mainTodo = TodoItem('Main Task', ['Step 1', 'Step 2']);
        final subTodo1 = TodoItem('Sub Task 1', ['Detail 1']);
        final subTodo2 = TodoItem('Sub Task 2', ['Detail 2']);
        final project1 = Project(
          'My Project',
          mainTodo,
          [subTodo1, subTodo2],
          {'urgent', 'backend'},
        );

        final prop = ObservableProperty<Project>(project1);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same data, different objects - WILL rebuild (no custom equality)
        final mainTodo2 = TodoItem('Main Task', ['Step 1', 'Step 2']);
        final subTodo1b = TodoItem('Sub Task 1', ['Detail 1']);
        final subTodo2b = TodoItem('Sub Task 2', ['Detail 2']);
        final project2 = Project(
          'My Project',
          mainTodo2,
          [subTodo1b, subTodo2b],
          {'urgent', 'backend'},
        );
        prop.value = project2;
        expect(
          notifyCount,
          1,
          reason: 'Without custom ==, different objects always trigger rebuild',
        );

        // Another assignment with same data - still rebuilds
        final mainTodo3 = TodoItem('Main Task', ['Step 1', 'Step 2']);
        final subTodo1c = TodoItem('Sub Task 1', ['Detail 1']);
        final subTodo2c = TodoItem('Sub Task 2', ['Detail 2']);
        final project3 = Project(
          'My Project',
          mainTodo3,
          [subTodo1c, subTodo2c],
          {'urgent', 'backend'},
        );
        prop.value = project3;
        expect(notifyCount, 2, reason: 'Still rebuilds without custom equality');
      });

      test('only identical reference prevents rebuild', () {
        final mainTodo = TodoItem('Task', ['A']);
        final project = Project('Proj', mainTodo, [], {'tag'});

        final prop = ObservableProperty<Project>(project);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Same reference - no rebuild
        prop.value = project;
        expect(notifyCount, 0, reason: 'Identical reference should not rebuild');

        // Different reference, same data - rebuilds
        final mainTodo2 = TodoItem('Task', ['A']);
        final project2 = Project('Proj', mainTodo2, [], {'tag'});
        prop.value = project2;
        expect(notifyCount, 1, reason: 'Different reference triggers rebuild');
      });

      test('demonstrates performance impact without custom equality', () {
        // Without custom equality, even "read-only" assignments cause rebuilds
        final mainTodo = TodoItem('Read', ['Only']);
        final project = Project('Test', mainTodo, [], {});

        final prop = ObservableProperty<Project>(project);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Simulating multiple "updates" that don't actually change data
        for (var i = 0; i < 5; i++) {
          final newMainTodo = TodoItem('Read', ['Only']);
          final newProject = Project('Test', newMainTodo, [], {});
          prop.value = newProject;
        }

        expect(
          notifyCount,
          5,
          reason: 'Every assignment triggers rebuild without custom equality',
        );
      });

      test('deepEquality parameter has no effect on custom types', () {
        final mainTodo = TodoItem('Task', ['A', 'B']);
        final project = Project('Proj', mainTodo, [], {'tag'});

        // With deepEquality: true (default)
        final prop1 = ObservableProperty<Project>(project, deepEquality: true);
        var count1 = 0;
        prop1.propertyChanged(() => count1++);

        final mainTodo2 = TodoItem('Task', ['A', 'B']);
        final project2 = Project('Proj', mainTodo2, [], {'tag'});
        prop1.value = project2;
        expect(count1, 1, reason: 'deepEquality: true still uses default ==');

        // With deepEquality: false
        final prop2 = ObservableProperty<Project>(project, deepEquality: false);
        var count2 = 0;
        prop2.propertyChanged(() => count2++);

        final mainTodo3 = TodoItem('Task', ['A', 'B']);
        final project3 = Project('Proj', mainTodo3, [], {'tag'});
        prop2.value = project3;
        expect(count2, 1, reason: 'deepEquality: false also uses default ==');

        // Both behave identically because Project is not a List/Map/Set
        // deepEquality only affects direct collection types
      });

      test('comparison with custom equality shows the difference', () {
        // WITHOUT custom equality (Project/TodoItem)
        final todoNoEq = TodoItem('Task', ['A']);
        final projNoEq = Project('P', todoNoEq, [], {});
        final propNoEq = ObservableProperty<Project>(projNoEq);
        var countNoEq = 0;
        propNoEq.propertyChanged(() => countNoEq++);

        final todoNoEq2 = TodoItem('Task', ['A']);
        final projNoEq2 = Project('P', todoNoEq2, [], {});
        propNoEq.value = projNoEq2;

        // WITH custom equality (Person/Address)
        final addrWithEq = Address('Street', ['L']);
        final personWithEq = Person('Name', addrWithEq, {}, []);
        final propWithEq = ObservableProperty<Person>(personWithEq);
        var countWithEq = 0;
        propWithEq.propertyChanged(() => countWithEq++);

        final addrWithEq2 = Address('Street', ['L']);
        final personWithEq2 = Person('Name', addrWithEq2, {}, []);
        propWithEq.value = personWithEq2;

        // Compare results
        expect(countNoEq, 1, reason: 'Without equality: rebuilds');
        expect(countWithEq, 0, reason: 'With equality: no rebuild');
      });

      test('nested lists and sets in Project are also reference-based', () {
        final todo1 = TodoItem('A', ['1']);
        final todo2 = TodoItem('B', ['2']);
        final project = Project('P', todo1, [todo2], {'tag'});

        final prop = ObservableProperty<Project>(project);
        var notifyCount = 0;
        prop.propertyChanged(() => notifyCount++);

        // Even if we use the SAME TodoItem references, different Project = rebuild
        final project2 = Project('P', todo1, [todo2], {'tag'});
        prop.value = project2;
        expect(
          notifyCount,
          1,
          reason: 'Different Project reference triggers rebuild despite same nested objects',
        );
      });
    });
  });
}

// Test model with custom equality
class User {
  final String id;
  final String name;

  User(this.id, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Test model WITHOUT custom equality (demonstrates need for overriding ==)
class TodoItem {
  final String name;
  final List<String> items;

  TodoItem(this.name, this.items);

  // NOTE: No overridden == operator
  // This means two TodoItems with same data are NOT equal
  // DeepEquals only works for direct List/Map/Set properties,
  // not for custom objects containing collections
}

// Nested custom types WITHOUT custom equality
class Project {
  final String title;
  final TodoItem mainTodo;
  final List<TodoItem> subTodos;
  final Set<String> tags;

  Project(this.title, this.mainTodo, this.subTodos, this.tags);

  // NOTE: No overridden == operator
  // Uses default Object identity (reference equality)
}

// Test nested custom types WITH proper equality
class Address {
  final String street;
  final List<String> landmarks;

  Address(this.street, this.landmarks);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Address &&
          street == other.street &&
          Equals.listEquals(landmarks, other.landmarks);

  @override
  int get hashCode => Object.hash(street, Object.hashAll(landmarks));
}

class Person {
  final String name;
  final Address address;
  final Set<String> hobbies;
  final List<String> skills;

  Person(this.name, this.address, this.hobbies, this.skills);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          name == other.name &&
          address == other.address &&
          Equals.setEquals(hobbies, other.hobbies) &&
          Equals.listEquals(skills, other.skills);

  @override
  int get hashCode => Object.hash(
        name,
        address,
        Object.hashAll(hobbies),
        Object.hashAll(skills),
      );
}
