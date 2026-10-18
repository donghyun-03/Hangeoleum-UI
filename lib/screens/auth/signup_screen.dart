// 회원가입 (청년 / 활동기관)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  UserRole _role = UserRole.youth;
  String _gender = 'female';
  Education? _education;
  bool _agree = false;
  String? _error;
  final _f = {
    for (final k in ['email', 'name', 'age', 'phone', 'major', 'address', 'addressDetail'])
      k: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    String? err;
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(_f['email']!.text)) {
      err = '이메일을 확인해 주세요.';
    } else if (_f['name']!.text.trim().isEmpty) {
      err = _role == UserRole.youth ? '이름을 입력해 주세요.' : '기관명을 입력해 주세요.';
    } else if (!_agree) {
      err = '개인정보 수집·이용에 동의해 주세요.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    // TODO(인증): 회원가입 API
    final state = context.read<AppState>();
    state.loginAs(_role, diagnosed: _role == UserRole.institution);
    state.updateUser((u) => u.copyWith(
          email: _f['email']!.text,
          name: _f['name']!.text.trim(),
          age: int.tryParse(_f['age']!.text) ?? 0,
          gender: _gender,
          phone: _f['phone']!.text,
          major: _f['major']!.text,
          education: _role == UserRole.youth ? (_education?.label ?? '') : '',
          address: _f['address']!.text,
          addressDetail: _f['addressDetail']!.text,
        ));
    AppNav.resetTo(context, _role == UserRole.youth ? Routes.diagnosis : Routes.main);
  }

  // 폼 배치를 바꾸지 않고 입력칸 아래에 메뉴를 겹쳐 표시합니다.
  Widget _buildEducationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('학력', style: AppText.small.copyWith(fontSize: 12)),
        const SizedBox(height: 4),
        Builder(builder: (fieldContext) {
          return InkWell(
            onTap: () async {
              final field = fieldContext.findRenderObject() as RenderBox;
              final overlay = Overlay.of(fieldContext)
                  .context.findRenderObject() as RenderBox;
              final origin = field.localToGlobal(Offset.zero, ancestor: overlay);
              final media = MediaQuery.of(fieldContext);
              final top = origin.dy + field.size.height + 4;
              final bottom = overlay.size.height -
                  media.viewInsets.bottom - media.padding.bottom - 8;
              final height = (bottom - top).clamp(0.0, 192.0).toDouble();
              if (height < 48) return;
              final selected = await showGeneralDialog<Education>(
                context: context,
                useRootNavigator: false,
                barrierDismissible: true,
                barrierLabel: MaterialLocalizations.of(context)
                    .modalBarrierDismissLabel,
                barrierColor: AppColors.ink.withValues(alpha: 0),
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (menuContext, animation, secondaryAnimation) {
                  return Material(
                    color: AppColors.paper,
                    surfaceTintColor: AppColors.paper,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: height,
                      child: ListView.builder(
                        primary: false,
                        padding: EdgeInsets.zero,
                        itemExtent: 48,
                        itemCount: Education.values.length,
                        itemBuilder: (context, index) {
                          final option = Education.values[index];
                          return InkWell(
                            onTap: () => Navigator.of(menuContext).pop(option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  option.label,
                                  style: AppText.body.copyWith(fontSize: 14),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                transitionBuilder: (context, animation, secondaryAnimation, child) {
                  final curve = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  // 배경과 글자를 포함한 메뉴 전체에 같은 애니메이션 적용.
                  return Stack(
                    children: [
                      Positioned(
                        left: origin.dx,
                        top: top,
                        width: field.size.width,
                        child: SizeTransition(
                          sizeFactor: curve,
                          alignment: Alignment.center,
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                      ),
                    ],
                  );
                },
              );
              if (!mounted || selected == null) return;
              setState(() => _education = selected);
            },
            child: InputDecorator(
              isEmpty: _education == null,
              decoration: const InputDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _education?.label ?? '선택',
                      style: _education == null
                          ? AppText.body.copyWith(fontSize: 14).merge(
                              Theme.of(context).inputDecorationTheme.hintStyle,
                            )
                          : AppText.body.copyWith(fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.expand_more, color: AppColors.muted),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // 세로 배치에서는 Expanded를 쓰지 않아 스크롤 높이 충돌을 피합니다.
  Widget _pairChild({required bool narrow, required Widget child}) {
    return narrow ? child : Expanded(child: child);
  }

  @override
  Widget build(BuildContext context) {
    final youth = _role == UserRole.youth;
    return LayoutBuilder(
      builder: (context, viewport) {
        // 웹의 가로 폭 전체로 입력칸이 늘어나지 않도록 제한합니다.
        const maxFormWidth = 480.0;
        final horizontal = (viewport.maxWidth * 0.05).clamp(16.0, 24.0).toDouble();
        return Scaffold(
          appBar: AppBar(title: const Text('회원가입')),
          bottomNavigationBar: BottomBar(
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxFormWidth),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(label: '가입하기', onPressed: _submit),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '이미 계정이 있나요? ',
                              style: AppText.small.copyWith(fontSize: 12.5),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, Routes.login),
                              child: Text(
                                '로그인',
                                style: AppText.body.copyWith(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25)
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, bodySize) {
                final vertical = (bodySize.maxHeight * 0.025).clamp(12.0, 24.0).toDouble();
                return SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: maxFormWidth),
                      child: LayoutBuilder(
                        builder: (context, formSize) {
                          final narrow = formSize.maxWidth < 340;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
          Text('가입 정보를 입력해 주세요', style: AppText.h1),
          const SizedBox(height: 12),
          Segmented<UserRole>(
            value: _role,
            onChanged: (v) => setState(() => _role = v),
            options: const [(UserRole.youth, '청년'), (UserRole.institution, '활동 제공자')],
          ),
          const SizedBox(height: 16),
          LabeledField(label: '이메일', hint: 'example@email.com', controller: _f['email'], keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          if (youth) ...[
            Row(children: [
              Expanded(flex: 2, child: LabeledField(label: '이름', hint: '이름', controller: _f['name'])),
              const SizedBox(width: 10),
              Expanded(child: LabeledField(label: '나이', hint: '만 나이', controller: _f['age'], keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            Flex(
              direction: narrow ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: narrow ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
              children: [
              _pairChild(narrow: narrow,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('성별', style: AppText.small.copyWith(fontSize: 12)),
                  const SizedBox(height: 6),
                  Segmented<String>(
                    value: _gender,
                    onChanged: (v) => setState(() => _gender = v),
                    options: const [('female', '여성'), ('male', '남성')],
                  ),
                ]),
              ),
              SizedBox(width: narrow ? 0 : 10, height: narrow ? 12 : 0),
              _pairChild(narrow: narrow, child: LabeledField(label: '연락처', hint: '010-0000-0000', controller: _f['phone'], keyboardType: TextInputType.phone)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: LabeledField(label: '학부', hint: '예: 경영학부', controller: _f['major'])),
              const SizedBox(width: 10),
              Expanded(child: _buildEducationField()),
            ]),
          ] else ...[
            LabeledField(label: '기관명', hint: '예: 서울청년센터', controller: _f['name']),
            const SizedBox(height: 12),
            LabeledField(label: '담당자 연락처', hint: '02-000-0000', controller: _f['phone'], keyboardType: TextInputType.phone),
            const TodoBox('기관 인증 항목(사업자등록번호, 증빙 서류 등) 정해지면 추가'),
          ],
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('주소', style: AppText.small.copyWith(fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _f['address'],
                      decoration: const InputDecoration(hintText: '주소 검색'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.paper,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () {},
                      child: SizedBox(
                        width: 64,
                        height: 48,
                        child: Center(
                          child: Text(
                            '검색',
                            style: AppText.body.copyWith(
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LabeledField(hint: '상세 주소', controller: _f['addressDetail']),
          const SizedBox(height: 16),
          InkWell(
  onTap: () => setState(() => _agree = !_agree),
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 흰색 배경 위에 검정 체크박스 아이콘 표시.
        Icon(
  _agree
      ? Icons.check_box
      : Icons.check_box_outline_blank,
  size: 20,
  color: _agree
      ? AppColors.ink
      : AppColors.subtle,
),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '[필수] 개인정보 수집·이용 동의',
            style: AppText.body.copyWith(fontSize: 14),
          ),
        ),
      ],
    ),
  ),
),

          ErrorText(_error),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
