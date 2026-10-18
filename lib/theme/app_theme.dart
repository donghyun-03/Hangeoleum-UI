// 한걸음 디자인 토큰 (화면 흐름도 시안 기준)
// 색을 바꿀 때는 여기만 수정하고, 화면 파일에 Color(0xFF...) 를 직접 쓰지 않습니다.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const bg = Color(0xFFFFFFFF); // 화면 배경 (흰색)
  static const paper = Color(0xFFFFFFFF); // 카드·헤더·탭바
  static const ink = Color(0xFF16181A); // 본문·제목
  static const muted = Color(0xFF5C6166);
  static const subtle = Color(0xFF9097A0);
  static const line = Color(0xFFE6E8EA);
  static const soft = Color(0xFFF1F3F2); // 입력칸·회색 박스
  static const dim = Color(0xFFC9CDD1);

  // 주 색 (한걸음 그린)
  static const green = Color(0xFF17A05D);
  static const greenDark = Color(0xFF0F7A45);
  static const greenLight = Color(0xFFE8F6EE);
  static const greenLine = Color(0xFFBFE5CF);

  // 보조
  static const black = Color(0xFF16181A); // STEP 번호 선택, 사용자 말풍선
  static const amber = Color(0xFFB26A00);
  static const amberLight = Color(0xFFFFF4E0);
  static const red = Color(0xFFD84B3E);
  static const redLight = Color(0xFFFDECEA);
}

class AppRadius {
  AppRadius._();
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
}

/// 자주 쓰는 글자 스타일. 예) Text('제목', style: AppText.title)
class AppText {
  AppText._();
  static const _base = TextStyle(fontFamily: 'Pretendard', color: AppColors.ink, height: 1.45);

  static final h1 = _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700);
  static final h2 = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700);
  static final title = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static final body = _base.copyWith(fontSize: 14);
  static final bodyBold = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w700);
  static final small = _base.copyWith(fontSize: 12.5, color: AppColors.muted);
  static final caption = _base.copyWith(fontSize: 11.5, color: AppColors.subtle);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      surface: AppColors.paper,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide.none,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      shape: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.soft,
      hintStyle: const TextStyle(color: AppColors.subtle, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.green, width: 1.2),
      ),
      isDense: true,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
    ),
  );
}
