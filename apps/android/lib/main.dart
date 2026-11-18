import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/app.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

void main() {
  runApp(const StudentFinanceApp());
}

class StudentFinanceApp extends StatelessWidget {
  const StudentFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AppShell(),
      ),
    );
  }
}
