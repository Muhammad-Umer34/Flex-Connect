import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/credential_gate.dart';
import 'services/telemetry_service.dart';
import 'services/home_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('--- main() started ---');
  const url = 'https://nnqfrezmjddywhyfggtz.supabase.co';
  print('Initializing Supabase with URL: $url');
  await Supabase.initialize(
    url: url,
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ucWZyZXptamRkeXdoeWZnZ3R6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MTMyMTUsImV4cCI6MjA5NzA4OTIxNX0.YaUELjWIMTPpXofArXNVkW0ZQDihE4DFI-zwBu3IMnc',
  );

  // Trigger telemetry logging for already logged in users in the background
  TelemetryService.recordLaunch();
  HomeWidgetService.updateNextClassWidget();

  runApp(
    const RestartWidget(
      child: FlexConnectApp(),
    ),
  );
}

class FlexConnectApp extends StatelessWidget {
  const FlexConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppEntry();
  }
}

class RestartWidget extends StatefulWidget {
  final Widget child;

  const RestartWidget({super.key, required this.child});

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}
