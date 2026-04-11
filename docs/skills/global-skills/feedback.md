---
name: feedback
description: Ship 이후 피드백(PR 리뷰, QA, 버그 리포트)을 수집하고 분류하여 적절한 phase로 재진입합니다. 사용법 - /feedback 또는 /dev-flow [기능명] feedback
tools: Bash, Read, Grep, Glob
---

# Feedback - 피드백 수집 및 재진입

ship 이후 피드백을 수집하고, 심각도/유형을 분류하여 올바른 phase로 재진입하는 스킬입니다.

## 사용법

```
/feedback               # 독립 호출 (현재 브랜치의 PR에서 피드백 수집)
```

dev-flow에서 Phase 7(선택)로 자동 호출될 수도 있습니다.

## cmux 프로토콜

```bash
CMUX="$(command -v cmux-dev || command -v cmux)"

# 시작
"$CMUX" set-status phase "FEEDBACK" --icon "💬" --color "#F97316"
"$CMUX" set-progress 0.0 --label "Feedback: 시작"

# 수집
"$CMUX" set-progress 0.2 --label "Feedback: 수집 중"

# 분류
"$CMUX" set-progress 0.5 --label "Feedback: 분류 중"

# 재진입 결정
"$CMUX" set-progress 0.8 --label "Feedback: 재진입점 결정"

# 완료
"$CMUX" workspace-memo append "### Iteration [N]: Feedback
- 소스: [PR 코멘트 / QA / 사용자 입력]
- 항목: [n]건 (critical: [n], minor: [n])
- 재진입: [phase]
---"
"$CMUX" set-progress 1.0 --label "Feedback: 완료"
"$CMUX" notify --title "Feedback 분석 완료" --body "[n]건 → [phase]로 재진입"

# history 기록 (전역 축적) — 각 피드백 항목마다:
"$CMUX" history add --type feedback --phase feedback --summary "[피드백 내용]" --tags [유형],[심각도],[관련 decision 태그]
# 반복 패턴 발견 시 (플라이휠 핵심):
"$CMUX" history add --type pattern --summary "[반복 패턴 설명]" --tags [관련 phase],[키워드]
# 과거 패턴 참조 (feedback 시작 시):
"$CMUX" history list --type pattern --limit 10
```

## 프로세스

### 1. 피드백 수집

세 가지 소스에서 피드백을 수집합니다:

#### a) PR 코멘트 (자동)

```bash
# 현재 브랜치의 PR 번호 확인
gh pr view --json number,url,reviewDecision,comments,reviews

# 리뷰 코멘트 수집
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[] | {body, path, line, created_at, user: .user.login}'

# 일반 코멘트 수집
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --jq '.[] | {body, created_at, user: .user.login}'
```

PR이 없으면 이 단계를 건너뛰고 사용자 입력으로 진행합니다.

#### b) 사용자 직접 입력

PR 코멘트 외 추가 피드백이 있는지 사용자에게 질문합니다:
- QA 결과
- 버그 리포트
- 디자인/UX 피드백
- 성능 이슈

#### c) memo 참조

기존 memo에서 이전 iteration의 미해결 항목이 있는지 확인합니다.

```bash
"$CMUX" workspace-memo get
```

### 2. 피드백 분류

수집된 피드백을 분류합니다:

| 유형 | 설명 | 재진입점 |
|------|------|----------|
| **bug** | 기능이 의도대로 동작하지 않음 | /test → /build |
| **requirement** | 요구사항 변경/추가 | /spec |
| **design** | 구조/설계 변경 필요 | /plan |
| **polish** | 코드 스타일, 오타, 경미한 수정 | /build |
| **question** | 코드 의도 질문 (코드 변경 불필요) | 답변 후 종료 |

| 심각도 | 설명 | 행동 |
|--------|------|------|
| **critical** | 블로커, 데이터 손실, 보안 | 즉시 재진입 |
| **important** | 기능 이슈, 주요 UX 문제 | 재진입 권장 |
| **minor** | 스타일, 사소한 개선 | 모아서 처리 가능 |

### 3. 재진입점 결정

분류 결과를 종합하여 어느 phase로 돌아갈지 결정합니다:

```
critical bug        → /test (재현부터)
requirement 변경    → /spec (명세 보정부터)
design 이슈         → /plan (태스크 재분해부터)
polish만 있음       → /build (바로 수정)
question만 있음     → 답변 후 종료 (재진입 없음)
혼합               → 가장 앞 phase로 (spec > plan > test > build)
```

### 4. Iteration 기록

memo에 feedback 결과를 기록합니다. iteration 번호는 memo에서 기존 "Iteration" 횟수를 세어 자동 증가합니다.

### 5. 교훈 축적 (도메인 지식 플라이휠)

피드백에서 **재사용 가능한 교훈**을 추출하여 적절한 메모 레벨에 저장합니다.
이 단계가 삽질 반복 방지의 핵심입니다.

**분류 기준:**

| 교훈 범위 | 저장 위치 | 예시 |
|-----------|-----------|------|
| 이 코드베이스/프로젝트에 특화된 지식 | `folder-memo` | "TabItemView의 Equatable+.equatable() 침범 금지", "Info.plist에 UTType 선언 필수" |
| 프로젝트를 넘어 일반적으로 적용되는 지식 | `global-memo` | "SwiftUI onTapGesture count:2와 count:1 동시 사용 시 디바운스 필요", "NSTextField inline editing은 포커스 경합에 취약" |

```bash
CMUX="$(command -v cmux-dev || command -v cmux)"

# 프로젝트 레벨 교훈 축적
"$CMUX" folder-memo append "- [날짜] [피드백 요약]: [이 프로젝트에서 다시는 반복하면 안 되는 것]"

# 전역 레벨 교훈 축적 (다른 프로젝트에서도 적용 가능한 범용 교훈)
"$CMUX" global-memo append "- [날짜] [피드백 요약]: [프로젝트 무관하게 적용되는 교훈]"
```

**언제 어디에 저장할지 판단 기준:**
- "이 코드베이스의 특정 파일/구조/규칙 때문에 발생한 문제" → `folder-memo`
- "어떤 프로젝트에서든 같은 기술 스택을 쓰면 발생할 수 있는 문제" → `global-memo`
- 둘 다에 해당하면 양쪽 모두에 저장 (중복 OK, 안 쓰는 것보다 나음)

### 6. 재진입 실행

결정된 phase의 스킬을 호출합니다. dev-flow 안에서 실행 중이면 해당 phase로 파이프라인을 이어갑니다.

## Gate

- [ ] 피드백이 1건 이상 수집되었는가? (0건이면 "피드백 없음"으로 종료)
- [ ] 모든 피드백에 유형과 심각도가 할당되었는가?
- [ ] 재진입점이 논리적인가?
- [ ] memo에 iteration 기록이 완료되었는가?
- [ ] 교훈이 적절한 메모 레벨(folder-memo/global-memo)에 축적되었는가?

## 합리화 방지

| 합리화 | 반론 |
|--------|------|
| "minor니까 무시해도 돼" | minor도 쌓이면 품질 저하. 모아서라도 처리하라 |
| "PR 승인 받았으니까 끝" | 승인은 "충분히 좋다"이지 "완벽하다"가 아니다 |
| "피드백이 너무 많아서 전부 반영 못 해" | 분류하고 우선순위를 매겨라. 전부 안 해도 critical은 해야 한다 |
| "다음 PR에서 하면 돼" | 다음 PR에서 할 거면 지금 태스크로 만들어라. 기억에 의존하지 마라 |
| "이건 리뷰어가 잘못 이해한 거야" | 리뷰어가 오해했다면 코드가 불명확한 것. 가독성 이슈로 분류하라 |

## Red Flags

- 피드백 수집 없이 "없을 것 같다"로 건너뜀 → PR 코멘트라도 확인하라
- 모든 피드백을 minor로 분류 → critical/important를 회피하는 것
- 재진입 없이 종료하면서 미해결 항목 존재 → 다음 iteration으로 명시적 이월
- memo에 기록 안 하고 바로 수정 → 히스토리 유실, 같은 피드백 반복 위험
