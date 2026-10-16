// 앱 진입점: 전역 상태(provider) → MaterialApp(테마·라우트)
// 화면 코드는 lib/screens 아래에 있습니다. 이 파일은 되도록 수정하지 않습니다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'router/main_tabs.dart';
import 'router/routes.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const HangeoleumApp());
}

class HangeoleumApp extends StatelessWidget {
  const HangeoleumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => MainTabs()),
      ],
      child: MaterialApp(
        title: '한걸음',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: Routes.login,
        onGenerateRoute: onGenerateRoute,
        // 웹·태블릿에서도 휴대폰 폭으로 보이도록 최대 폭 제한
        builder: (context, child) => ColoredBox(
          color: AppColors.paper,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
