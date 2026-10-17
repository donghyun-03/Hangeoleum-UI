// 기록 작성 (LLM 채팅)
// [추가 기능 1] 파일 첨부 · 깃허브 링크 첨부
// 기록 수정 → 'AI로 다시 작성하기' 로 오면 기존 제목·STAR 가 미리 채워지고, 저장하면 같은 기록이 바뀜
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const _maxLength = 500;
final _githubRe = RegExp(r'^https://github\.com/[\w.-]+(/[\w.-]+)?/?$');

class RecordWriteScreen extends StatefulWidget {
  const RecordWriteScreen({super.key, this.missionId, this.editing, this.initialText});

  /// 미션에서 바로 기록할 때 넘김 (없으면 자유 기록)
  final String? missionId;

  /// 기록 수정에서 다시 작성할 때 넘김 → 같은 기록(id · 날짜 · 첨부)으로 저장
  final ActivityRecord? editing;

  /// 입력칸에 미리 채울 내용 (기존 제목 · STAR)
  final String? initialText;

  @override
  State<RecordWriteScreen> createState() => _RecordWriteScreenState();
}

class _RecordWriteScreenState extends State<RecordWriteScreen> {
  late final _text = TextEditingController(text: widget.initialText);
  final _github = TextEditingController();
  late final List<Attachment> _attachments = [...?widget.editing?.attachments];
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {})); // 글자 수 표시 갱신
  }

  @override
  void dispose() {
    _text.dispose();
    _github.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      // file_picker 13: 여러 개 선택, 취소하면 빈 목록
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;
      setState(() {
        for (final f in files) {
          _attachments.add(Attachment(
            id: 'f-${DateTime.now().microsecondsSinceEpoch}-${f.name}',
            type: AttachmentType.file,
            name: f.name,
            // 웹에서는 path 가 없어서 이름만 저장. 업로드 API 연결 시 f.readAsBytes() 사용
            uri: f.path ?? f.name,
            size: f.lengthSync(),
          ));
        }
      });
    } catch (_) {
      if (mounted) showToast(context, '파일을 불러오지 못했어요');
    }
  }

  void _addGithub() {
    final url = _github.text.trim();
    if (!_githubRe.hasMatch(url)) {
      setState(() => _error = 'https://github.com/아이디/저장소 형식으로 입력해 주세요.');
      return;
    }
    setState(() {
      _attachments.add(Attachment(
        id: 'g-${DateTime.now().microsecondsSinceEpoch}',
        type: AttachmentType.github,
        name: url.replaceFirst('https://github.com/', '').replaceAll(RegExp(r'/$'), ''),
        uri: url,
      ));
      _github.clear();
      _error = null;
    });
  }

  void _summarize() {
    final text = _text.text.trim();
    if (text.length < 5) {
      setState(() => _error = '오늘 한 일을 조금만 더 적어 주세요.');
      return;
    }
    if (text.length > _maxLength) {
      setState(() => _error = '$_maxLength자 이내로 줄여 주세요.');
      return;
    }
    final state = context.read<AppState>();
    Mission? mission;
    for (final m in state.missions) {
      if (m.id == widget.missionId) mission = m;
    }
    final now = DateTime.now();
    final editing = widget.editing;
    // TODO(AI): text 를 LLM 에 보내 STAR 로 정리받기. 지금은 원문을 그대로 넣은 임시 결과입니다.
    final draft = ActivityRecord(
      id: editing?.id ?? 'rec-${now.microsecondsSinceEpoch}',
      step: editing?.step ?? state.user.currentStep,
      title: mission?.title ?? (text.split('\n').first.length > 24 ? text.split('\n').first.substring(0, 24) : text.split('\n').first),
      // YYYY-MM-DD (예: 2026-10-16)
      date: editing?.date ?? '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      raw: text,
      star: Star(s: '(AI 정리 예정) 상황', t: '(AI 정리 예정) 목표', a: text, r: '(AI 정리 예정) 결과'),
      attachments: List.of(_attachments),
    );
    AppNav.toRecordResult(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('활동 기록하기')),
      bottomNavigationBar: BottomBar(child: AppButton(label: 'AI로 정리하기', onPressed: _summarize)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('오늘 한 일을 편하게 적어 보세요', style: AppText.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            maxLines: 8,
            // 글자 수 제한은 _summarize 에서 검사 (미리 채운 글이 500자를 넘어도 잘리지 않게)
            style: AppText.body,
            decoration: const InputDecoration(
              hintText: '예) 청년센터 엑셀 워크숍 3번 들음. 배운 거로 내 가계부 자동 정리 시트 만들어 봄.',
              fillColor: AppColors.paper,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                borderSide: BorderSide(color: AppColors.green),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text('문장이 어색해도 괜찮아요. 그냥 적기만 하면 돼요.', style: AppText.caption.copyWith(fontSize: 11))),
            Text(
              '${_text.text.length}/$_maxLength',
              style: AppText.caption.copyWith(fontSize: 11, color: _text.text.length > _maxLength ? AppColors.red : null),
            ),
          ]),

          // ── [추가 기능 1] 첨부
          SectionTitle('첨부', aside: '${_attachments.length}개'),
          OutlinedButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.attach_file, size: 18),
            label: const Text('파일 첨부'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.muted,
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: AppColors.dim),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: LabeledField(
                controller: _github,
                hint: 'https://github.com/아이디/저장소',
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(width: 8),
            AppButton(label: '추가', icon: Icons.code, small: true, expand: false, variant: ButtonVariant.outline, onPressed: _addGithub),
          ]),
          for (final a in _attachments)
            AppCard(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                Icon(a.type == AttachmentType.github ? Icons.code : Icons.insert_drive_file_outlined, size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name, style: AppText.body.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
                    if (a.size != null) Text('${(a.size! / 1024).toStringAsFixed(0)} KB', style: AppText.caption.copyWith(fontSize: 11)),
                  ]),
                ),
                IconButton(
                  tooltip: '${a.name} 삭제',
                  onPressed: () => setState(() => _attachments.remove(a)),
                  icon: const Icon(Icons.close, size: 16, color: AppColors.subtle),
                ),
              ]),
            ),
          ErrorText(_error),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('+ AI가 이렇게 정리해 드려요', style: AppText.bodyBold.copyWith(fontSize: 12, color: AppColors.greenDark)),
              const SizedBox(height: 4),
              Text('S 상황 → T 목표 → A 행동 → R 결과', style: AppText.small.copyWith(fontSize: 11.5)),
            ]),
          ),
        ],
      ),
    );
  }
}
