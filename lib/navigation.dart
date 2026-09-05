import 'package:flutter/material.dart';

/// App-wide navigator key so services (e.g. OneSignal notification
/// listeners) can push screens without a BuildContext of their own.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
