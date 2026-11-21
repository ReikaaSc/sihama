import 'package:material_ui/material_ui.dart';

import 'auth_screen.dart';
import 'data/sihama_repository.dart';
import 'data/sihama_role.dart';
import 'sihama_shell.dart';

void main() {
  runApp(const SihamaApp());
}

class SihamaApp extends StatefulWidget {
  const SihamaApp({super.key, this.repository});

  final SihamaRepository? repository;

  @override
  State<SihamaApp> createState() => _SihamaAppState();
}

class _SihamaAppState extends State<SihamaApp> {
  SihamaRole? _role;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIHAMA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E5A46)),
        scaffoldBackgroundColor: const Color(0xFFF7F9F6),
      ),
      home: _role == null
          ? AuthScreen(onAuthenticated: (role) => setState(() => _role = role))
          : SihamaShell(
              key: ValueKey(_role),
              repository: widget.repository,
              role: _role!,
              onLogout: () => setState(() => _role = null),
            ),
    );
  }
}
