// 로그인
// 흐름: 청년(진단 전) → AI 대화 / 진단한 청년·기관 → 메인(홈) / 회원가입
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/main_tabs.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _showPw = false;
  bool _auto = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _enter(UserRole role, {required bool diagnosed}) {
    context.read<AppState>().loginAs(role, diagnosed: diagnosed);
    context.read<MainTabs>().go(MainTab.home);
    AppNav.resetTo(context, diagnosed ? Routes.main : Routes.diagnosis);
  }

  void _login() {
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(_email.text)) {
      setState(() => _error = '이메일을 확인해 주세요.');
      return;
    }
    if (_pw.text.isEmpty) {
      setState(() => _error = '비밀번호를 입력해 주세요.');
      return;
    }
    // TODO(인증): 로그인 API 호출 → 응답의 role / diagnosed 로 분기
    _enter(UserRole.youth, diagnosed: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)),
                child: Image.asset('assets/images/logo.png', width: 80, height: 80, fit: BoxFit.contain, semanticLabel: '앱 로고',),
              ),
            ),
            const SizedBox(height: 16),
            Text('한걸음', style: AppText.h1.copyWith(fontSize: 24)),
            Text('지금 할 수 있는 다음 한 걸음', style: AppText.body.copyWith(color: AppColors.muted)),
            const SizedBox(height: 40),
            LabeledField(controller: _email, hint: '이메일', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            LabeledField(
              controller: _pw,
              hint: '비밀번호',
              obscure: !_showPw,
              suffix: IconButton(
                tooltip: '비밀번호 보기',
                icon: Icon(_showPw ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: AppColors.subtle),
                onPressed: () => setState(() => _showPw = !_showPw),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _auto = !_auto),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Icon(_auto ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: _auto ? AppColors.green : AppColors.subtle),
                      const SizedBox(width: 6),
                      Text('자동 로그인', style: AppText.small.copyWith(fontSize: 12)),
                    ]),
                  ),
                ),
                const Spacer(),
                Text('비밀번호 찾기', style: AppText.caption.copyWith(fontSize: 12)),
              ],
            ),
            ErrorText(_error),
            const SizedBox(height: 10),
            AppButton(label: '로그인', onPressed: _login),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('아직 계정이 없나요? ', style: AppText.caption.copyWith(fontSize: 12.5)),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, Routes.signup),
                  child: Text('회원가입', style: AppText.bodyBold.copyWith(fontSize: 12.5)),
                ),
              ],
            ),

            // 개발용 미리보기: 백엔드 없이 각 흐름 확인
            const SizedBox(height: 36),
            const TodoBox('개발용 미리보기 버튼입니다. 인증 연결 후 삭제하세요.'),
            AppButton(
              label: '청년 · 진단 전 → AI 대화',
              small: true,
              variant: ButtonVariant.ghost,
              onPressed: () => _enter(UserRole.youth, diagnosed: false),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: '청년 · 진단 완료 → 홈',
              small: true,
              variant: ButtonVariant.ghost,
              onPressed: () => _enter(UserRole.youth, diagnosed: true),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: '활동기관 → 홈',
              small: true,
              variant: ButtonVariant.ghost,
              onPressed: () => _enter(UserRole.institution, diagnosed: true),
            ),
          ],
        ),
      ),
    );
  }
}
