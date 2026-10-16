// AI 대화 (Q1~Q4) — 청년 진단. 끝나면 추천 STEP 을 정하고 메인으로 이동
// 지금은 고정 질문/선택지입니다. LLM 연결 시 _answer() 에서 API 를 호출하도록 바꾸세요.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../router/main_tabs.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const _questions = [
  (q: '요즘은 어떻게 지내고 계세요?', options: ['집에 있는 시간이 많아요', '취업 준비 중이에요', '알바 잠깐 하고 있어요', '그냥 그래요']),
  (
    q: '이야기해 줘서 고마워요. 천천히 해도 괜찮아요.\n혹시 조금이라도 관심 가는 분야가 있나요?',
    options: ['IT·데이터', '디자인·영상', '사무·행정', '아직 잘 모르겠어요'],
  ),
  (q: '하루에 얼마나 시간을 낼 수 있을까요?', options: ['10분 정도', '30분 정도', '1시간 이상']),
  (q: '지금 가장 해보고 싶은 건 뭐예요?', options: ['생활 리듬 되찾기', '사람 만나기', '경험 쌓기', '바로 취업 준비']),
];

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  int _idx = 0;
  final List<String> _answers = [];
  final List<(bool fromMe, String text)> _msgs = [
    (false, '안녕하세요! 저는 한걸음 도우미예요.\n정답은 없으니, 편하게 이야기해 주세요.'),
    (false, _questions[0].q),
  ];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  bool get _done => _idx >= _questions.length;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _answer(String text) {
    if (text.trim().isEmpty || _done) return;
    setState(() {
      _answers.add(text.trim());
      _msgs.add((true, text.trim()));
      _idx++;
      _msgs.add((false, _done ? '고마워요! 지금 나에게 맞는 첫 걸음을 준비했어요.' : _questions[_idx].q));
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _finish() {
    // TODO(AI): _answers 를 서버로 보내 추천 STEP·관심 분야 받기
    context.read<AppState>().updateUser((u) => u.copyWith(
          diagnosed: true,
          currentStep: 1,
          interests: _answers.length > 1 ? [_answers[1]] : u.interests,
        ));
    context.read<MainTabs>().go(MainTab.home);
    AppNav.resetTo(context, Routes.main);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('알아보기'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('${_idx.clamp(0, _questions.length)}/${_questions.length}', style: AppText.caption)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: ProgressLine(value: _idx, total: _questions.length),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(20),
              children: [
                Text('한걸음', style: AppText.caption),
                const SizedBox(height: 6),
                for (final (fromMe, text) in _msgs) _Bubble(text: text, fromMe: fromMe),
                const SizedBox(height: 6),
                if (!_done)
                  ChipWrap(children: [
                    for (final o in _questions[_idx].options)
                      SelectChip(label: o, selected: false, dark: true, onTap: () => _answer(o)),
                  ])
                else
                  AppButton(label: '진단 완료 · 시작하기', onPressed: _finish),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
            padding: const EdgeInsets.all(12),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !_done,
                    onSubmitted: _answer,
                    decoration: const InputDecoration(hintText: '직접 입력하기'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: '보내기',
                  style: IconButton.styleFrom(backgroundColor: AppColors.green),
                  onPressed: _done ? null : () => _answer(_input.text),
                  icon: const Icon(Icons.arrow_forward, color: AppColors.paper),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.fromMe});
  final String text;
  final bool fromMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromMe ? AppColors.black : AppColors.soft,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(fromMe ? 14 : 4),
            topRight: Radius.circular(fromMe ? 4 : 14),
            bottomLeft: const Radius.circular(14),
            bottomRight: const Radius.circular(14),
          ),
        ),
        child: Text(text, style: AppText.body.copyWith(fontSize: 13.5, color: fromMe ? AppColors.paper : AppColors.ink)),
      ),
    );
  }
}
