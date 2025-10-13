import 'package:fairy/fairy.dart';
import 'package:fairy/src/core/observable_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObservableNode Garbage Collection', () {
    test('properties are garbage collected when ViewModel is dereferenced', () {
      WeakReference<ObservableProperty<String>>? weakProp;
      
      // Create scope to allow GC
      void createAndDispose() {
        final vm = _TestViewModel(onPropertyDisposed: () {});
        weakProp = WeakReference(vm.data);
        expect(weakProp!.target, isNotNull);
        // vm goes out of scope here
      }
      
      createAndDispose();
      
      // Force GC (not guaranteed but helps in tests)
      final List<List<int>> garbage = [];
      for (int i = 0; i < 100; i++) {
        garbage.add(List.filled(10000, i));
      }
      garbage.clear();
      
      // After GC, weak reference should be null (property was collected)
      // Note: GC timing is not guaranteed, so this might still pass if GC hasn't run
      // This is more of a demonstration that GC CAN collect it
      expect(weakProp?.target, isNull, 
        reason: 'ObservableProperty should be garbage collected when ViewModel is dereferenced');
    });

    test('dispose() clears listeners but object still usable', () {
      var listenerCalled = false;
      
      final vm = _TestViewModel(onPropertyDisposed: () {});
      
      // Add listener
      vm.data.propertyChanged(() => listenerCalled = true);
      
      // Change value - listener should be called
      vm.data.value = 'test';
      expect(listenerCalled, true);
      
      // Reset flag
      listenerCalled = false;
      
      // Dispose clears listeners
      vm.data.dispose();
      
      // Property still usable after dispose
      vm.data.value = 'after dispose';
      expect(vm.data.value, 'after dispose');
      
      // But listener was cleared, so not called
      expect(listenerCalled, false);
    });

    test('multiple dispose calls are safe (no-op)', () {
      final vm = _TestViewModel(onPropertyDisposed: () {});
      
      // Multiple dispose calls don't throw
      expect(() {
        vm.data.dispose();
        vm.data.dispose();
        vm.data.dispose();
      }, returnsNormally);
      
      // Property still usable
      vm.data.value = 'still works';
      expect(vm.data.value, 'still works');
    });

    test('computed property releases dependency listeners on dispose', () {
      final vm = _TestViewModelWithComputed(onComputedDisposed: () {});
      
      // Computed property has listeners on source
      expect(vm.source.hasListeners, true);
      
      // Dispose computed property
      vm.computed.dispose();
      
      // Dependency listeners should be removed
      expect(vm.source.hasListeners, false);
    });

    test('nested ObservableObject is NOT auto-disposed', () {
      var childDisposed = false;
      
      final vm = _TestViewModelWithNestedVM(
        onChildDisposed: () => childDisposed = true,
      );
      
      vm.dispose();
      
      // Nested VM should NOT be auto-disposed
      expect(childDisposed, false);
      
      // Manual disposal required
      vm.childVM.dispose();
      expect(childDisposed, true);
    });

    test('properties created in async method can be manually disposed', () async {
      final vm = _TestViewModelWithAsyncMethod();
      
      // Wait for stack cleanup to complete (simulating real async scenario)
      await Future<void>.delayed(const Duration(milliseconds: 10));
      
      // Creating property in async method works fine
      // With ObservableNode, no parent tracking needed - just manual disposal
      await vm.createPropertyAsync();
      
      vm.dispose();
    });

    test('properties created in getter can be manually disposed', () async {
      final vm = _TestViewModelWithGetter();
      
      // Wait for stack cleanup to complete
      await Future<void>.delayed(const Duration(milliseconds: 10));
      
      // Creating property in getter works fine
      // With ObservableNode, disposal is optional (just convenience)
      final prop = vm.dynamicProperty;
      expect(prop, isNotNull);
      prop.dispose(); // Optional cleanup
      
      vm.dispose();
    });

    test('multiple ViewModels can have independent properties', () {
      var vm1Prop1Disposed = false;
      var vm1Prop2Disposed = false;
      var vm2Prop1Disposed = false;
      var vm2Prop2Disposed = false;
      
      final vm1 = _TestViewModelMultipleProperties(
        onProp1Disposed: () => vm1Prop1Disposed = true,
        onProp2Disposed: () => vm1Prop2Disposed = true,
        onProp3Disposed: () {},
      );
      
      final vm2 = _TestViewModelMultipleProperties(
        onProp1Disposed: () => vm2Prop1Disposed = true,
        onProp2Disposed: () => vm2Prop2Disposed = true,
        onProp3Disposed: () {},
      );
      
      // Dispose vm1 properties manually
      vm1.prop1.dispose();
      vm1.prop2.dispose();
      expect(vm1Prop1Disposed, true);
      expect(vm1Prop2Disposed, true);
      expect(vm2Prop1Disposed, false);
      expect(vm2Prop2Disposed, false);
      
      // Dispose vm2 properties manually
      vm2.prop1.dispose();
      vm2.prop2.dispose();
      expect(vm2Prop1Disposed, true);
      expect(vm2Prop2Disposed, true);
      
      // ViewModels can still dispose independently
      vm1.dispose();
      vm2.dispose();
    });

    test('properties created in helper method can be manually disposed', () {
      var propertyDisposed = false;
      
      final vm = _TestViewModelWithHelperMethod(
        onPropertyDisposed: () => propertyDisposed = true,
      );
      
      expect(propertyDisposed, false);
      
      // ViewModel dispose doesn't dispose properties
      vm.dispose();
      expect(propertyDisposed, false);
      
      // Manual disposal required
      vm.data.dispose();
      expect(propertyDisposed, true);
    });

    test('property values remain accessible before disposal', () {
      final vm = _TestViewModel(onPropertyDisposed: () {});
      
      vm.data.value = 'test value';
      expect(vm.data.value, 'test value');
      
      vm.data.value = 'updated value';
      expect(vm.data.value, 'updated value');
      
      vm.dispose();
    });

    test('ObservableObject can be disposed multiple times safely', () {
      final vm = _TestViewModel(onPropertyDisposed: () {});
      
      // ObservableNode allows multiple disposals (just clears listeners)
      // Unlike ChangeNotifier, this doesn't throw - disposal is just a convenience
      vm.dispose();
      expect(() => vm.dispose(), returnsNormally);
    });
  });
}

// Test ViewModels

class _TestViewModel extends ObservableObject {
  late final ObservableProperty<String> data;

  _TestViewModel({required VoidCallback onPropertyDisposed}) {
    data = _TrackableProperty('', onPropertyDisposed);
  }
}

class _TestViewModelMultipleProperties extends ObservableObject {
  late final ObservableProperty<String> prop1;
  late final ObservableProperty<int> prop2;
  late final ObservableProperty<bool> prop3;

  _TestViewModelMultipleProperties({
    required VoidCallback onProp1Disposed,
    required VoidCallback onProp2Disposed,
    required VoidCallback onProp3Disposed,
  }) {
    prop1 = _TrackableProperty('', onProp1Disposed);
    prop2 = _TrackablePropertyInt(0, onProp2Disposed);
    prop3 = _TrackablePropertyBool(false, onProp3Disposed);
  }
}

class _TestViewModelWithComputed extends ObservableObject {
  late final ObservableProperty<String> source;
  late final ComputedProperty<String> computed;

  _TestViewModelWithComputed({required VoidCallback onComputedDisposed}) {
    source = ObservableProperty<String>('test');
    computed = _TrackableComputedProperty(
      () => source.value.toUpperCase(),
      dependencies: <ObservableNode>[source],
      onDisposed: onComputedDisposed,
    );
  }
}

class _ChildViewModel extends ObservableObject {
  final VoidCallback onDisposed;
  
  _ChildViewModel(this.onDisposed);
  
  @override
  void dispose() {
    onDisposed();
    super.dispose();
  }
}

class _TestViewModelWithNestedVM extends ObservableObject {
  late final _ChildViewModel childVM;

  _TestViewModelWithNestedVM({required VoidCallback onChildDisposed}) {
    childVM = _ChildViewModel(onChildDisposed);
  }
  
  // Nested VM should NOT be auto-disposed
  // User must manually dispose if needed
}

class _TestViewModelWithAsyncMethod extends ObservableObject {
  Future<void> createPropertyAsync() async {
    await Future<void>.delayed(Duration.zero);
    // This should throw StateError
    final prop = ObservableProperty<String>('');
    prop.dispose(); // cleanup if it didn't throw
  }
}

class _TestViewModelWithGetter extends ObservableObject {
  // This should throw StateError when accessed
  ObservableProperty<String> get dynamicProperty => ObservableProperty<String>('');
}

class _TestViewModelWithHelperMethod extends ObservableObject {
  late final ObservableProperty<String> data;

  _TestViewModelWithHelperMethod({required VoidCallback onPropertyDisposed}) {
    _initializeProperties(onPropertyDisposed);
  }

  void _initializeProperties(VoidCallback onPropertyDisposed) {
    data = _TrackableProperty('', onPropertyDisposed);
  }
}

// Trackable properties for testing disposal

class _TrackableProperty extends ObservableProperty<String> {
  final VoidCallback onDisposed;

  _TrackableProperty(super.initialValue, this.onDisposed);

  @override
  void dispose() {
    onDisposed();
    super.dispose();
  }
}

class _TrackablePropertyInt extends ObservableProperty<int> {
  final VoidCallback onDisposed;

  _TrackablePropertyInt(super.initialValue, this.onDisposed);

  @override
  void dispose() {
    onDisposed();
    super.dispose();
  }
}

class _TrackablePropertyBool extends ObservableProperty<bool> {
  final VoidCallback onDisposed;

  _TrackablePropertyBool(super.initialValue, this.onDisposed);

  @override
  void dispose() {
    onDisposed();
    super.dispose();
  }
}

class _TrackableComputedProperty extends ComputedProperty<String> {
  final VoidCallback onDisposed;

  _TrackableComputedProperty(
    String Function() compute, {
    required List<ObservableNode> dependencies,
    required this.onDisposed,
  }) : super(compute, dependencies);

  @override
  void dispose() {
    onDisposed();
    super.dispose();
  }
}
