import 'package:flutter/material.dart';

import 'modules/board/view/pages/kanban_board_page.dart';

class KanbanApp extends StatelessWidget {
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panel GitLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF111111),
        colorScheme: const ColorScheme.light(
          surface: Color(0xFF1A1A1A),
          primary: Color(0xFF4A7C2F),
        ),
      ),
      home: const KanbanBoardPage(),
    );
  }
}
