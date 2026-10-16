import '../../models/models.dart';

enum StepSort {
  recommend('추천순'),
  deadline('마감순'),
  name('이름순');

  const StepSort(this.label);
  final String label;
}

/// STEP 3·4 공고 정렬
List<Opportunity> sortOpportunities(List<Opportunity> list, StepSort sort) {
  final v = [...list];
  switch (sort) {
    case StepSort.deadline:
      v.sort((a, b) => a.dday.compareTo(b.dday));
    case StepSort.name:
      v.sort((a, b) => a.title.compareTo(b.title));
    case StepSort.recommend:
      break; // TODO(추천): 서버 추천 순서 사용
  }
  return v;
}
