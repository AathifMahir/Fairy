import 'package:flutter/widgets.dart';
import '../internal/fairy_scope_bridge.dart';
import '../locator/fairy_scope.dart';

/// Bridges parent BuildContext's FairyScope to overlay widget trees.
///
/// When overlays (dialogs, bottom sheets, menus) create separate widget trees,
/// they can't access parent FairyScopes via normal context lookup. [FairyBridge]
/// solves this by capturing the parent context's FairyScope and making it
/// available to the overlay.
///
/// **Common Use Cases:**
/// - Dialogs (`showDialog`)
/// - Bottom sheets (`showModalBottomSheet`)
/// - Menus (`showMenu`)
/// - Any overlay route that creates a separate widget tree
///
/// **Example:**
/// ```dart
/// void _showDialog(BuildContext context) {
///   showDialog(
///     context: context,
///     builder: (_) => FairyBridge(
///       context: context, // Parent context with FairyScope
///       child: AlertDialog(
///         title: Text('Confirm'),
///         actions: [
///           Command<MyViewModel>(
///             command: (vm) => vm.saveCommand,
///             builder: (ctx, execute, canExecute, isRunning) =>
///               TextButton(onPressed: execute, child: Text('Save')),
///           ),
///         ],
///       ),
///     ),
///   );
/// }
/// ```
///
/// **How it works:**
/// 1. Looks up parent context's FairyScope
/// 2. Creates an InheritedWidget that provides the same scope to the overlay
/// 3. `Fairy.of<T>()` inside the overlay now resolves ViewModels normally
/// 4. If no FairyScope found, returns child unchanged (falls back to FairyLocator)
///
/// **When NOT needed:**
/// - Regular navigation (`Navigator.push`) - FairyScope is inherited naturally
/// - Widgets in the same tree - use `Fairy.of()` directly
class FairyBridge extends StatelessWidget {
  /// The parent BuildContext that has access to FairyScope.
  ///
  /// This should be the context from the page/widget that contains the
  /// ViewModels you want to access in the overlay.
  final BuildContext context;

  /// The child widget that needs access to parent ViewModels.
  ///
  /// This is typically the dialog, bottom sheet, or menu content.
  final Widget child;

  /// Creates a widget that bridges parent FairyScope to overlay trees.
  ///
  /// The [context] parameter should be the parent context that has access
  /// to the FairyScope you want to make available. The [child] is the
  /// overlay content that needs access to those ViewModels.
  const FairyBridge({
    super.key,
    required this.context,
    required this.child,
  });

  @override
  Widget build(BuildContext buildContext) {
    // Look up parent's FairyScope
    final parentScope = FairyScope.of(context);

    if (parentScope == null) {
      // No FairyScope in parent, just return child
      // (Fairy.of will fall back to FairyLocator if needed)
      return child;
    }

    // Bridge the parent scope to overlay
    return FairyScopeBridge(
      scopeData: parentScope,
      child: child,
    );
  }
}
