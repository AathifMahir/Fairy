import 'package:fairy/src/internal/fairy_scope_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Internal InheritedWidget that bridges FairyScope to overlay trees.
@internal
class FairyScopeBridge extends InheritedWidget {
  final FairyScopeData scopeData;

  const FairyScopeBridge({super.key, 
    required this.scopeData,
    required super.child,
  });

  @override
  bool updateShouldNotify(FairyScopeBridge oldWidget) =>
      scopeData != oldWidget.scopeData;

  static FairyScopeData? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FairyScopeBridge>()
        ?.scopeData;
  }
}