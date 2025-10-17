import 'package:fairy/fairy.dart';
import 'package:fairy/src/core/observable_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Parent-Child Auto Disposal', () {
    test('ComputedProperty with parent is auto-disposed', () {
      var computedDisposed = false;

      final vm = _TestViewModelWithParent(
        onComputedDisposed: () => computedDisposed = true,
      );

      expect(computedDisposed, false);
      expect(vm.source.hasListeners, true); // ComputedProperty listening

      // Dispose parent
      vm.dispose();

      // ComputedProperty should be auto-disposed
      expect(computedDisposed, true);
      expect(vm.source.hasListeners, false); // Listeners removed
    });

    test('Multiple ComputedProperties with parent are all auto-disposed', () {
      var computed1Disposed = false;
      var computed2Disposed = false;
      var computed3Disposed = false;

      final vm = _TestViewModelMultipleComputed(
        onComputed1Disposed: () => computed1Disposed = true,
        onComputed2Disposed: () => computed2Disposed = true,
        onComputed3Disposed: () => computed3Disposed = true,
      );

      expect(computed1Disposed, false);
      expect(computed2Disposed, false);
      expect(computed3Disposed, false);

      // Dispose parent
      vm.dispose();

      // All should be auto-disposed
      expect(computed1Disposed, true);
      expect(computed2Disposed, true);
      expect(computed3Disposed, true);
    });

    test('Nested ComputedProperty (computed depends on computed)', () {
      var fullNameDisposed = false;
      var upperNameDisposed = false;

      final vm = _TestViewModelNestedComputed(
        onFullNameDisposed: () => fullNameDisposed = true,
        onUpperNameDisposed: () => upperNameDisposed = true,
      );

      expect(fullNameDisposed, false);
      expect(upperNameDisposed, false);

      // Dispose parent
      vm.dispose();

      // Both should be auto-disposed
      expect(fullNameDisposed, true);
      expect(upperNameDisposed, true);

      // Verify no listeners remain
      expect(vm.firstName.hasListeners, false);
      expect(vm.lastName.hasListeners, false);
    });

    test('Disposing parent twice is safe', () {
      final vm = _TestViewModelWithParent(
        onComputedDisposed: () {},
      );

      // Multiple dispose calls are safe
      expect(() {
        vm.dispose();
        vm.dispose();
        vm.dispose();
      }, returnsNormally);
    });

    test('Child can be disposed before parent', () {
      var computedDisposed = false;

      final vm = _TestViewModelWithParent(
        onComputedDisposed: () => computedDisposed = true,
      );

      // Dispose child first
      vm.computed.dispose();
      expect(computedDisposed, true);

      // Parent dispose should not throw
      expect(() => vm.dispose(), returnsNormally);
    });

    test('Creating ComputedProperty after parent disposal throws', () {
      final vm = _TestViewModelWithParent(
        onComputedDisposed: () {},
      );

      vm.dispose();

      // Should throw when trying to create ComputedProperty after parent is disposed
      expect(
        () => ComputedProperty<String>(
          () => 'test',
          [],
          vm, // Parent is already disposed
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

// Test ViewModels

class _TestViewModelWithParent extends ObservableObject {
  late final ObservableProperty<String> source;
  late final ComputedProperty<String> computed;

  _TestViewModelWithParent({required VoidCallback onComputedDisposed}) {
    source = ObservableProperty<String>('test');
    computed = _TrackableComputedProperty(
      () => source.value.toUpperCase(),
      dependencies: [source],
      onDisposed: onComputedDisposed,
      parent: this, // Auto-disposal
    );
  }
}

class _TestViewModelMultipleComputed extends ObservableObject {
  late final ObservableProperty<int> value;
  late final ComputedProperty<int> doubled;
  late final ComputedProperty<int> tripled;
  late final ComputedProperty<int> quadrupled;

  _TestViewModelMultipleComputed({
    required VoidCallback onComputed1Disposed,
    required VoidCallback onComputed2Disposed,
    required VoidCallback onComputed3Disposed,
  }) {
    value = ObservableProperty<int>(5);
    doubled = _TrackableComputedProperty(
      () => value.value * 2,
      dependencies: [value],
      onDisposed: onComputed1Disposed,
      parent: this,
    );
    tripled = _TrackableComputedProperty(
      () => value.value * 3,
      dependencies: [value],
      onDisposed: onComputed2Disposed,
      parent: this,
    );
    quadrupled = _TrackableComputedProperty(
      () => value.value * 4,
      dependencies: [value],
      onDisposed: onComputed3Disposed,
      parent: this,
    );
  }
}

class _TestViewModelNestedComputed extends ObservableObject {
  late final ObservableProperty<String> firstName;
  late final ObservableProperty<String> lastName;
  late final ComputedProperty<String> fullName;
  late final ComputedProperty<String> upperName;

  _TestViewModelNestedComputed({
    required VoidCallback onFullNameDisposed,
    required VoidCallback onUpperNameDisposed,
  }) {
    firstName = ObservableProperty<String>('John');
    lastName = ObservableProperty<String>('Doe');

    fullName = _TrackableComputedProperty(
      () => '${firstName.value} ${lastName.value}',
      dependencies: [firstName, lastName],
      onDisposed: onFullNameDisposed,
      parent: this,
    );

    // Computed depends on another computed
    upperName = _TrackableComputedProperty(
      () => fullName.value.toUpperCase(),
      dependencies: [fullName],
      onDisposed: onUpperNameDisposed,
      parent: this,
    );
  }
}

// Trackable ComputedProperty for testing
class _TrackableComputedProperty<T> extends ComputedProperty<T> {
  final VoidCallback onDisposed;

  _TrackableComputedProperty(
    T Function() compute, {
    required List<ObservableNode> dependencies,
    required this.onDisposed,
    required ObservableObject parent,
  }) : super(compute, dependencies, parent);

  @override
  void dispose() {
    onDisposed();
    super.dispose();
  }
}
