// 공통 위젯. 화면에서 반복되는 모양은 여기 추가해서 같이 씁니다.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 화면 아래에 잠깐 뜨는 안내 메시지
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}

/// 흰 배경 + 얇은 테두리 카드. onTap 을 주면 눌림 효과가 생깁니다.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.color, this.margin});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.paper;
    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: color == null ? AppColors.line : bg),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

enum ButtonVariant { primary, outline, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.small = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool small;

  /// true 면 가로로 꽉 채움
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final fg = switch (variant) {
      ButtonVariant.primary => AppColors.paper,
      ButtonVariant.outline => AppColors.green,
      ButtonVariant.ghost => AppColors.muted,
    };
    final bg = switch (variant) {
      ButtonVariant.primary => AppColors.green,
      ButtonVariant.outline => AppColors.paper,
      ButtonVariant.ghost => AppColors.soft,
    };
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: small ? 15 : 18, color: fg), const SizedBox(width: 6)],
        Text(label, style: TextStyle(fontSize: small ? 12.5 : 15, fontWeight: FontWeight.w700, color: fg)),
      ],
    );
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: onPressed == null ? AppColors.dim : bg,
        foregroundColor: fg,
        minimumSize: Size(0, small ? 34 : 50),
        padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(small ? 999 : AppRadius.md),
          side: variant == ButtonVariant.outline ? const BorderSide(color: AppColors.green) : BorderSide.none,
        ),
      ),
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

enum BadgeTone { green, gray, dark, amber, red }

class TagBadge extends StatelessWidget {
  const TagBadge(this.text, {super.key, this.tone = BadgeTone.green});

  final String text;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.green => (AppColors.greenLight, AppColors.greenDark),
      BadgeTone.gray => (AppColors.soft, AppColors.muted),
      BadgeTone.dark => (AppColors.black, AppColors.paper),
      BadgeTone.amber => (AppColors.amberLight, AppColors.amber),
      BadgeTone.red => (AppColors.redLight, AppColors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// 선택형 칩 (관심 분야, 필터, 정렬 등). dark=true 면 선택 시 검정 (AI 대화 답변)
class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap, this.dark = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final on = dark ? AppColors.black : AppColors.green;
    return Material(
      color: selected ? (dark ? on : AppColors.greenLight) : AppColors.paper,
      shape: StadiumBorder(side: BorderSide(color: selected ? on : AppColors.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: selected ? (dark ? AppColors.paper : AppColors.greenDark) : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// 여러 칩을 줄바꿈하며 나열
class ChipWrap extends StatelessWidget {
  const ChipWrap({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: children);
}

/// 검색창 (STEP2, STEP3, 전체 탭). onFilter 를 넘기면 오른쪽에 필터 아이콘이 생깁니다.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.hint = '검색',
    this.onChanged,
    this.onFilter,
    this.filterCount = 0,
    this.filterOpen = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilter;

  /// 선택된 필터 개수 (0 보다 크면 필터 아이콘에 숫자 표시)
  final int filterCount;

  /// 필터 패널이 열려 있는지 (아이콘 색 변경)
  final bool filterOpen;

  @override
  Widget build(BuildContext context) {
    final active = filterOpen || filterCount > 0;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.subtle),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
            ),
          ),
        ),
        if (onFilter != null)
          IconButton(
            onPressed: onFilter,
            tooltip: '필터',
            icon: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              backgroundColor: AppColors.green,
              child: Icon(Icons.tune, color: active ? AppColors.green : AppColors.ink),
            ),
          ),
      ],
    );
  }
}

/// 라벨이 붙은 입력칸
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.obscure = false,
    this.suffix,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool obscure;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(hintText: hint, suffixIcon: suffix, counterText: ''),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: AppText.small.copyWith(fontSize: 12)),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}

/// 2~3개 중 하나 고르는 버튼 묶음 (청년/활동기관, 성별 등)
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: options[i].$1 == value ? AppColors.greenLight : AppColors.paper,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: options[i].$1 == value ? AppColors.green : AppColors.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => onChanged(options[i].$1),
                child: SizedBox(
                  height: 42,
                  child: Center(
                    child: Text(
                      options[i].$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: options[i].$1 == value ? FontWeight.w700 : FontWeight.w400,
                        color: options[i].$1 == value ? AppColors.greenDark : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.aside, this.onAside});

  final String title;
  final String? aside;
  final VoidCallback? onAside;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.title)),
          if (aside != null)
            GestureDetector(onTap: onAside, child: Text(aside!, style: AppText.caption)),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 36, this.color = AppColors.green});

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1),
        style: TextStyle(color: AppColors.paper, fontSize: size * 0.42, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value, required this.total});
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: total == 0 ? 0 : value / total,
        minHeight: 6,
        backgroundColor: AppColors.line,
        color: AppColors.green,
      ),
    );
  }
}

/// 숫자 + 라벨 3칸 요약 (내 경험 요약, 스크랩 요약 등)
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.items, this.center = false});
  final List<(int, String)> items;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (n, label) in items)
          Expanded(
            child: Column(
              crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Text('$n', style: AppText.h2.copyWith(color: AppColors.green)),
                Text(label, style: AppText.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.icon = Icons.inbox_outlined, required this.title, this.desc});

  final IconData icon;
  final String title;
  final String? desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.dim),
            const SizedBox(height: 8),
            Text(title, style: AppText.bodyBold.copyWith(color: AppColors.muted)),
            if (desc != null) ...[
              const SizedBox(height: 4),
              Text(desc!, style: AppText.caption, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// 아직 구현하지 않은 부분 표시용 박스. 담당자가 구현하면 지워 주세요.
class TodoBox extends StatelessWidget {
  const TodoBox(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.amberLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.amber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODO', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.amber)),
          Text(text, style: const TextStyle(fontSize: 12, color: AppColors.amber)),
        ],
      ),
    );
  }
}

/// 화면 하단 고정 버튼 영역 (Scaffold.bottomNavigationBar 에 넣어 사용)
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: child),
      ),
    );
  }
}

/// 에러 문구 (빨간 글씨). text 가 비어 있으면 아무것도 안 그림
class ErrorText extends StatelessWidget {
  const ErrorText(this.text, {super.key});
  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(text!, style: const TextStyle(fontSize: 12.5, color: AppColors.red)),
    );
  }
}
