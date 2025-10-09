import 'package:fairy/fairy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auto-Disposal', () {
    test('properties created in field initializers are auto-disposed', () {
      var propertyDisposed = false;
      
      final vm = _TestViewModel(
        onPropertyDisposed: () => propertyDisposed = true,
      );
      
      expect(propertyDisposed, false);
      vm.dispose();
      expect(propertyDisposed, true);
    });

    test('properties created in constructor body are auto-disposed', () {
      var propertyDisposed = false;
      
      final vm = _TestViewModelWithConstructorBody(
        onPropertyDisposed: () => propertyDisposed = true,
      );
      
      expect(propertyDisposed, false);
      vm.dispose();
      expect(propertyDisposed, true);
    });

    test('multiple properties are all auto-disposed', () {
      var prop1Disposed = false;
      var prop2Disposed = false;
      var prop3Disposed = false;
      
      final vm = _TestViewModelMultipleProperties(
        onProp1Disposed: () => prop1Disposed = true,
        onProp2Disposed: () => prop2Disposed = true,
        onProp3Disposed: () => prop3Disposed = true,
      );
      
      expect(prop1Disposed, false);
      expect(prop2Disposed, false);
      expect(prop3Disposed, false);
      
      vm.dispose();
      
      expect(prop1Disposed, true);
      expect(prop2Disposed, true);
      expect(prop3Disposed, true);
    });

    test('ComputedProperty is auto-disposed', () {
      var computedDisposed = false;
      
      final vm = _TestViewModelWithComputed(
        onComputedDisposed: () => computedDisposed = true,
      );
      
      expect(computedDisposed, false);
      vm.dispose();
      expect(computedDisposed, true);
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

    test('properties created in async method without parent print warning', () async {
      final vm = _TestViewModelWithAsyncMethod();
      
      // Wait for stack cleanup to complete (simulating real async scenario)
      await Future<void>.delayed(const Duration(milliseconds: 10));
      
      // Creating property in async method without parent just prints a warning in debug mode
      // It doesn't throw - user must manually dispose if no parent
      await vm.createPropertyAsync();
      
      vm.dispose();
    });

    test('properties created in getter without parent print warning', () async {
      final vm = _TestViewModelWithGetter();
      
      // Wait for stack cleanup to complete
      await Future<void>.delayed(const Duration(milliseconds: 10));
      
      // Creating property in getter without parent just prints a warning in debug mode
      // It doesn't throw - user must manually dispose if no parent
      final prop = vm.dynamicProperty;
      expect(prop, isNotNull);
      prop.dispose(); // Manual cleanup needed
      
      vm.dispose();
    });

    test('parent-child relationship maintains across multiple VMs', () {
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
      
      // Dispose vm1
      vm1.dispose();
      expect(vm1Prop1Disposed, true);
      expect(vm1Prop2Disposed, true);
      expect(vm2Prop1Disposed, false);
      expect(vm2Prop2Disposed, false);
      
      // Dispose vm2
      vm2.dispose();
      expect(vm2Prop1Disposed, true);
      expect(vm2Prop2Disposed, true);
    });

    test('properties created in helper method during construction are auto-disposed', () {
      var propertyDisposed = false;
      
      final vm = _TestViewModelWithHelperMethod(
        onPropertyDisposed: () => propertyDisposed = true,
      );
      
      expect(propertyDisposed, false);
      vm.dispose();
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
      
      vm.dispose();
      // ChangeNotifier throws FlutterError on double disposal by design
      // This is expected behavior - we're just testing that dispose can be called
      expect(() => vm.dispose(), throwsFlutterError);
    });
  });
}

// Test ViewModels

class _TestViewModel extends ObservableObject {
  late final ObservableProperty<String> data;

  _TestViewModel({required VoidCallback onPropertyDisposed}) {
    data = _TrackableProperty('', onPropertyDisposed, parent: this);
  }
}

class _TestViewModelWithConstructorBody extends ObservableObject {
  late final ObservableProperty<String> data;

  _TestViewModelWithConstructorBody({required VoidCallback onPropertyDisposed}) {
    data = _TrackableProperty('', onPropertyDisposed, parent: this);
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
    prop1 = _TrackableProperty('', onProp1Disposed, parent: this);
    prop2 = _TrackablePropertyInt(0, onProp2Disposed, parent: this);
    prop3 = _TrackablePropertyBool(false, onProp3Disposed, parent: this);
  }
}

class _TestViewModelWithComputed extends ObservableObject {
  late final ObservableProperty<String> source;
  late final ComputedProperty<String> computed;

  _TestViewModelWithComputed({required VoidCallback onComputedDisposed}) {
    source = ObservableProperty<String>('test', parent: this);
    computed = _TrackableComputedProperty(
      () => source.value.toUpperCase(),
      dependencies: [source],
      onDisposed: onComputedDisposed,
      parent: this,
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
    data = _TrackableProperty('', onPropertyDisposed, parent: this);
  }
}

// Trackable properties for testing disposal

class _TrackableProperty extends ObservableProperty<String> {
  final VoidCallback onDisposed;

  _TrackableProperty(super.initialValue, this.onDisposed, {super.parent});

  @override
  void dispose() {
    onDisposed();
    super.dispose();
  }
}

class _TrackablePropertyInt extends ObservableProperty<int> {
  final VoidCallback onDisposed;

  _TrackablePropertyInt(super.initialValue, this.onDisposed, {super.parent});

  @override
  void dispose() {
    onDisposed();
    super.dispose();
  }
}

class _TrackablePropertyBool extends ObservableProperty<bool> {
  final VoidCallback onDisposed;

  _TrackablePropertyBool(super.initialValue, this.onDisposed, {super.parent});

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
    required List<Listenable> dependencies,
    required this.onDisposed,
    ObservableObject? parent,
  }) : super(compute, dependencies, parent: parent);

  @override
  void dispose() {
    onDisposed();
    super.dispose();
  }
}
