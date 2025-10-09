import 'package:fairy/fairy.dart';

/// Counter ViewModel for basic performance testing
class FairyCounterViewModel extends ObservableObject {
  late final ObservableProperty<int> counter;
  late final RelayCommand incrementCommand;

  FairyCounterViewModel() {
    counter = ObservableProperty(0, parent: this);
    incrementCommand = RelayCommand(() {
      counter.value++;
    }, parent: this);
  }
}

/// Multi-property ViewModel for selective rebuild testing
class FairyMultiPropertyViewModel extends ObservableObject {
  late final ObservableProperty<int> property1;
  late final ObservableProperty<int> property2;
  late final ObservableProperty<int> property3;

  FairyMultiPropertyViewModel() {
    property1 = ObservableProperty(0, parent: this);
    property2 = ObservableProperty(0, parent: this);
    property3 = ObservableProperty(0, parent: this);
  }
  
  /// Helper for ONE-WAY binding: triggers global notifications
  void notifyGlobal() => onPropertyChanged();
}
