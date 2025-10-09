import 'package:flutter/foundation.dart';

/// Counter ChangeNotifier for basic performance testing
class ProviderCounterNotifier extends ChangeNotifier {
  int _counter = 0;
  int get counter => _counter;

  void increment() {
    _counter++;
    notifyListeners();
  }
}

/// Multi-property ChangeNotifier for selective rebuild testing
class ProviderMultiPropertyNotifier extends ChangeNotifier {
  int _property1 = 0;
  int _property2 = 0;
  int _property3 = 0;

  int get property1 => _property1;
  int get property2 => _property2;
  int get property3 => _property3;

  void updateProperty1() {
    _property1++;
    notifyListeners(); // Notifies ALL listeners
  }

  void updateProperty2() {
    _property2++;
    notifyListeners(); // Notifies ALL listeners
  }

  void updateProperty3() {
    _property3++;
    notifyListeners(); // Notifies ALL listeners
  }
}
