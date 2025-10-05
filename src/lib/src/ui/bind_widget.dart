import 'package:flutter/widgets.dart';
import '../core/observable.dart';
import '../locator/viewmodel_locator.dart';

/// A widget that binds ViewModel data to UI with automatic type detection.
///
/// [Bind] is the core data binding widget in Fairy. It automatically detects
/// whether to use one-way or two-way binding based on what the [selector] returns:
///
/// **Two-way binding:** When [selector] returns an [ObservableProperty<TValue>],
/// the widget subscribes to that property and provides an `update` callback.
///
/// **One-way binding:** When [selector] returns a raw [TValue], the widget
/// subscribes to the entire ViewModel and the `update` callback is `null`.
///
/// ## Two-Way Binding Example:
/// ```dart
/// class UserViewModel extends ObservableObject {
///   final userName = ObservableProperty<String>('');
/// }
///
/// Bind<UserViewModel, String>(
///   selector: (vm) => vm.userName,  // Returns ObservableProperty<String>
///   builder: (context, value, update) {
///     return TextField(
///       controller: TextEditingController(text: value),
///       onChanged: update,  // update is non-null for two-way binding
///     );
///   },
/// )
/// ```
///
/// ## One-Way Binding Example:
/// ```dart
/// class CounterViewModel extends ObservableObject {
///   final count = ObservableProperty<int>(0);
///   int get doubled => count.value * 2;  // Computed property
/// }
///
/// Bind<CounterViewModel, int>(
///   selector: (vm) => vm.doubled,  // Returns int (raw value)
///   builder: (context, value, update) {
///     return Text('$value');  // update is null for one-way binding
///   },
/// )
/// ```
///
/// **Critical:** Selectors must return **stable references**. Never create
/// new [ObservableProperty] instances inside selectors.
class Bind<TViewModel extends ObservableObject, TValue> extends StatefulWidget {

  const Bind({
    required this.selector, required this.builder, super.key,
    this.oneTime = false,
  });
  /// Selector function that extracts the bindable value from the ViewModel.
  ///
  /// Can return either:
  /// - [ObservableProperty<TValue>] for two-way binding
  /// - [TValue] for one-way binding
  ///
  /// **Must return stable references!** Don't create new objects in selectors.
  final dynamic Function(TViewModel vm) selector;

  /// Builder function that constructs the UI.
  ///
  /// Parameters:
  /// - [context]: BuildContext
  /// - [value]: The current value of type [TValue]
  /// - [update]: Callback to update the value (non-null for two-way binding, null for one-way)
  final Widget Function(
    BuildContext context,
    TValue value,
    void Function(TValue)? update,
  ) builder;

  /// If true, only evaluates the selector once and never subscribes to changes.
  ///
  /// Useful for initial-value-only scenarios where reactivity isn't needed.
  final bool oneTime;

  @override
  State<Bind<TViewModel, TValue>> createState() =>
      _BindState<TViewModel, TValue>();
}

class _BindState<TViewModel extends ObservableObject, TValue>
    extends State<Bind<TViewModel, TValue>> {
  late TViewModel _viewModel;
  dynamic _selected; // Can be ObservableProperty<TValue> or TValue
  VoidCallback? _listener;
  VoidCallback? _listenerDisposer;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) {
      return;
    }
    _initialized = true;

    // Resolve ViewModel from context
    _viewModel = ViewModelLocator.resolve<TViewModel>(context);

    // Evaluate selector
    _selected = widget.selector(_viewModel);

    // Skip subscription for one-time binding
    if (widget.oneTime) {
      return;
    }

    // Subscribe based on what selector returned
    if (_selected is ObservableProperty<TValue>) {
      // Two-way binding: subscribe to the property directly
      _listener = () => setState(() {});
      _listenerDisposer = (_selected as ObservableProperty<TValue>).listen(_listener!);
    } else {
      // One-way binding: subscribe to ViewModel and re-evaluate selector
      _listener = () => setState(() {
            _selected = widget.selector(_viewModel);
          });
      _listenerDisposer = _viewModel.listen(_listener!);
    }
  }

  @override
  void didUpdateWidget(Bind<TViewModel, TValue> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If selector changed, rebind
    if (oldWidget.selector != widget.selector) {
      _removeListener();
      _selected = widget.selector(_viewModel);

      if (!widget.oneTime) {
        if (_selected is ObservableProperty<TValue>) {
          _listener = () => setState(() {});
          _listenerDisposer = (_selected as ObservableProperty<TValue>).listen(_listener!);
        } else {
          _listener = () => setState(() {
                _selected = widget.selector(_viewModel);
              });
          _listenerDisposer = _viewModel.listen(_listener!);
        }
      }
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    _listenerDisposer?.call();
    _listenerDisposer = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    // Extract value and update callback based on binding type
    if (_selected is ObservableProperty<TValue>) {
      // Two-way binding
      final property = _selected as ObservableProperty<TValue>;
      return widget.builder(
        context,
        property.value,
        (newValue) => property.value = newValue,
      );
    } else {
      // One-way binding
      final value = _selected as TValue;
      return widget.builder(context, value, null);
    }
  }
}
