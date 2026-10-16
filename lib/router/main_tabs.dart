// 하단 탭 상태. 다른 화면에서 탭을 바꾸고 싶을 때 사용합니다.
//   context.read<MainTabs>().go(MainTab.step, step: 4);   // STEP 탭의 STEP 4 로 이동
import 'package:flutter/foundation.dart';

enum MainTab { home, step, scrap, all }

class MainTabs extends ChangeNotifier {
  MainTab _tab = MainTab.home;
  MainTab get tab => _tab;

  /// STEP 탭에서 선택된 단계 (1~4)
  int _step = 1;
  int get step => _step;

  void go(MainTab tab, {int? step}) {
    _tab = tab;
    if (step != null) _step = step;
    notifyListeners();
  }

  void selectStep(int step) {
    _step = step;
    notifyListeners();
  }
}
