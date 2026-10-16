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
  bool _agree = false;
  String? _error;
  final _f = {
    for (final k in ['email', 'name', 'age', 'phone', 'major', 'education', 'address', 'addressDetail'])
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
          education: _f['education']!.text,
          address: _f['address']!.text,
          addressDetail: _f['addressDetail']!.text,
        ));
    AppNav.resetTo(context, _role == UserRole.youth ? Routes.diagnosis : Routes.main);
  }

  @override
  Widget build(BuildContext context) {
    final youth = _role == UserRole.youth;
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      bottomNavigationBar: BottomBar(child: AppButton(label: '가입하기', onPressed: _submit)),
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
              Expanded(child: LabeledField(label: '학력', hint: '선택', controller: _f['education'])),
            ]),
            const TodoBox('학력은 선택 목록(고졸/대학 재학/대학 졸업…)으로 교체'),
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
