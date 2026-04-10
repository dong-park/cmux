---
name: review
description: 5축(정확성/보안/성능/가독성/테스트) 자체 검토를 수행합니다. 변경 크기 확인, lint/typecheck, red flags 감지를 포함합니다. 사용법 - /review 또는 dev-flow에서 자동 호출
tools: Bash, Read, Grep, Glob
---

# Review - 5축 자체 검토

병합 전 5축 기준으로 코드를 검토하는 스킬입니다.

## 사용법

```
/review                # 현재 diff에 대해 5축 검토
```

dev-flow에서 Phase 5로 자동 호출될 수도 있습니다.

## cmux 프로토콜

```bash
CMUX="$(command -v cmux-dev || command -v cmux)"

# 시작
"$CMUX" set-status phase "REVIEW" --icon "🔍" --color "#EC4899"
"$CMUX" set-progress 0.0 --label "Review: 시작"

# diff 확인용 pane
"$CMUX" new-pane --type terminal --direction right

# 축별 진행
"$CMUX" set-progress 0.2 --label "Review: 정확성"
"$CMUX" set-progress 0.4 --label "Review: 보안"
"$CMUX" set-progress 0.6 --label "Review: 성능"
"$CMUX" set-progress 0.7 --label "Review: 가독성"
"$CMUX" set-progress 0.8 --label "Review: 테스트"

# 완료
"$CMUX" workspace-memo append "### Review 완료 ✅ (5축)\n- 정확성: ✅\n- 보안: ✅\n- 성능: ✅\n- 가독성: ✅\n- 테스트: ✅\n- 변경: [n]줄\n---"
"$CMUX" set-progress 1.0 --label "Review: 완료"
"$CMUX" notify --title "Review 완료" --body "5축 통과"

# history 기록 (전역 축적)
"$CMUX" history add --type phase --phase review --summary "REVIEW 완료: 5축 통과, [n]줄 변경"
# 발견사항이 있으면:
"$CMUX" history add --type note --phase review --summary "[발견사항]" --tags [심각도],[관련 태그]
```

## 프로세스

### 0. 변경 범위 파악

```bash
git diff main...HEAD --stat
git diff main...HEAD --numstat | awk '{s+=$1+$2} END {print s " lines changed"}'
```

### 변경 크기 가이드

| 줄 수 | 판정 | 행동 |
|-------|------|------|
| ~100 | 적정 | 그대로 진행 |
| 100-300 | 주의 | 분할 가능한지 검토 |
| 300+ | 위험 | 반드시 분할 |

### 1. 정확성

- [ ] Spec의 모든 성공 기준이 코드에 반영되었는가?
- [ ] 비목표로 명시한 것이 실수로 구현되지 않았는가?
- [ ] 엣지 케이스 처리가 spec과 일치하는가?

### 2. 보안

- [ ] 사용자 입력 → 쿼리/명령 직접 삽입 없는가? (SQL injection, command injection)
- [ ] 인증/인가 체크 누락된 엔드포인트 없는가?
- [ ] `.env`, 시크릿, API 키 하드코딩 없는가?
- [ ] 의존성에 알려진 취약점 없는가?

### 3. 성능

- [ ] N+1 쿼리 패턴 없는가?
- [ ] 루프 안 불필요한 객체 생성/메모리 할당 없는가?
- [ ] 캐시가 필요한 곳에 있는가? (과도한 캐시도 문제)
- [ ] 인덱스 필요한 쿼리에 인덱스 있는가?

### 4. 가독성

- [ ] 함수/변수 이름이 의도를 드러내는가?
- [ ] 불필요한 추상화 없는가? (한 번만 쓰는 헬퍼 등)
- [ ] 매직 넘버에 이름이 있는가?
- [ ] 주석은 why를 설명하는가? (what은 코드가 설명)

### 5. 테스트

- [ ] 핵심 경로(happy path)가 테스트되는가?
- [ ] 실패 경로(error path)가 테스트되는가?
- [ ] 경계값이 테스트되는가?
- [ ] 테스트가 구현이 아닌 행동을 검증하는가?

### 이슈 심각도

| 심각도 | 설명 | 행동 |
|--------|------|------|
| **Critical** | 보안 취약점, 데이터 손실 위험 | 반드시 수정 후 진행 |
| **Important** | 정확성/성능 문제 | 수정 권장, 사유 있으면 예외 |
| **Suggestion** | 가독성, 스타일 개선 | 선택적 |

### 6. Lint / Typecheck

프로젝트의 lint/typecheck 도구를 실행하여 클린 상태를 확인합니다.

### 7. 이슈 수정 및 재검증

발견된 이슈를 수정하고 해당 축을 재검토합니다.

## Gate

- [ ] 5축 모두 통과?
- [ ] Lint/typecheck 클린?
- [ ] Critical/Important 이슈 0건?
- [ ] 변경 크기 300줄 이하? (초과 시 분할 완료?)

## 합리화 방지

| 합리화 | 반론 |
|--------|------|
| "내가 쓴 코드니까 리뷰 필요 없어" | 저자 맹점은 실재한다. 체크리스트로 강제하라 |
| "시간 없으니까 보안은 나중에" | 보안 이슈는 발견 시점이 늦을수록 비용이 기하급수적으로 증가 |
| "성능은 프로파일링 후에 최적화" | N+1 쿼리 같은 명백한 패턴은 프로파일링 없이도 잡아야 한다 |
| "이 정도 변경은 리뷰 안 해도 돼" | 1줄 변경도 프로덕션을 깨뜨릴 수 있다 |
| "테스트가 통과하니까 괜찮아" | 테스트는 작성된 시나리오만 검증한다. 리뷰는 미작성 시나리오를 찾는다 |

## Red Flags

- diff에 `.env`, credential, secret 키워드 → 즉시 제거
- 300줄 초과 변경 → 분할하지 않으면 리뷰 품질 급감
- TODO/FIXME/HACK 주석 추가 → 기술 부채 인지적 방치
- 테스트 없이 핵심 로직 변경 → 가드레일 없는 변경
- Chesterton's Fence: 이유를 모르는 코드 삭제 → 먼저 왜 있는지 파악
