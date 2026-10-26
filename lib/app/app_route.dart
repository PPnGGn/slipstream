import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A [GoRoute] whose page is Flutter's [MaterialPage], so the theme's
/// [PageTransitionsTheme] animates push and pop.
///
/// A plain `GoRoute(builder: ...)` does not: go_router 18 detects the app type
/// by looking for `MaterialApp` from `package:material_ui`, our app uses the
/// one from `package:flutter/material.dart`, so go_router falls back to
/// `NoTransitionPage` (zero duration). Drop this helper once go_router and the
/// app use the same Material package.
GoRoute appRoute({
  required String path,
  required GoRouterWidgetBuilder builder,
  List<RouteBase> routes = const [],
}) {
  return GoRoute(
    path: path,
    routes: routes,
    pageBuilder: (context, state) => MaterialPage<void>(
      key: state.pageKey,
      name: state.name ?? state.path,
      arguments: <String, String>{
        ...state.pathParameters,
        ...state.uri.queryParameters,
      },
      restorationId: state.pageKey.value,
      child: builder(context, state),
    ),
  );
}
