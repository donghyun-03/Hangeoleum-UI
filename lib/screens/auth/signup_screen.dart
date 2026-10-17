// 회원가입 (청년 / 활동기관)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';

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
                  return Stack(
                    children: [
                      Positioned(
                        left: origin.dx,
                        top: top,
                        width: field.size.width,
                        child: SizeTransition(
                          sizeFactor: curve,
                          alignment: const Alignment(-1.0, -1.0),
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

@override
  Widget build(BuildContext context) {
    final youth = _role == UserRole.youth;
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      bottomNavigationBar: BottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 50,
              child: AppButton(label: '가입하기', onPressed: _submit),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text.rich(
                TextSpan(
                  text: '이미 계정이 있나요? ',
                  style: AppText.small.copyWith(fontSize: 12.5),
                  children: [
                    TextSpan(
                      text: '로그인',
                      style: AppText.bodyBold.copyWith(fontSize: 12.5, color: AppColors.green),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.pushNamed(context, Routes.login),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('가입 정보를 입력해 주세요', style: AppText.h2),
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
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
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
              const SizedBox(width: 10),
              Expanded(child: LabeledField(label: '연락처', hint: '010-0000-0000', controller: _f['phone'], keyboardType: TextInputType.phone)),
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
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: LabeledField(label: '주소', hint: '주소 검색', controller: _f['address'])),
            const SizedBox(width: 8),
            AppButton(label: '검색', small: true, expand: false, variant: ButtonVariant.ghost, onPressed: () {}),
          ]),
          const SizedBox(height: 8),
          LabeledField(hint: '상세 주소', controller: _f['addressDetail']),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _agree = !_agree),
            child: Row(children: [
              Icon(_agree ? Icons.check_box : Icons.check_box_outline_blank, size: 20, color: _agree ? AppColors.green : AppColors.subtle),
              const SizedBox(width: 6),
              Text('[필수] 개인정보 수집·이용 동의', style: AppText.body.copyWith(fontSize: 13)),
            ]),
          ),
          ErrorText(_error),
        ],
      ),
    );
  }
}