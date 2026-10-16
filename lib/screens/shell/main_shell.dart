// 하단 탭 4개(홈 · STEP · 스크랩 · 전체)를 묶는 메인 화면.
// 탭 화면은 IndexedStack 으로 유지되어 탭을 오가도 스크롤·입력 상태가 남습니다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../router/main_tabs.dart';
import '../../theme/app_theme.dart';
import '../all/all_screen.dart';
import '../home/home_screen.dart';
import '../scrap/scrap_screen.dart';
import '../step/step_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<MainTabs>();
    return Scaffold(
      body: IndexedStack(
        index: tabs.tab.index,
        children: const [HomeScreen(), StepScreen(), ScrapScreen(), AllScreen()],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: BottomNavigationBar(
          currentIndex: tabs.tab.index,
          onTap: (i) => tabs.go(MainTab.values[i]),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.paper,
          elevation: 0,
          selectedItemColor: AppColors.ink,
          unselectedItemColor: AppColors.subtle,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'STEP'),
            BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), activeIcon: Icon(Icons.bookmark), label: '스크랩'),
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view), label: '전체'),
          ],
        ),
      ),
    );
  }
}
