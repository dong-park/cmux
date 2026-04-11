---
name: plan
description: Spec을 구현 가능한 작업 단위로 분해합니다. 코드베이스 탐색, 태스크 분해, 의존성 정리를 수행하고 cmux memo에 기록합니다. 사용법 - /plan 또는 dev-flow에서 자동 호출
tools: Bash, Read, Grep, Glob
---

# Plan - 작업 분해

Spec을 구현 가능한 작은 작업 단위로 분해하는 스킬입니다.

## 사용법

```
/plan                  # 현재 컨텍스트에서 작업 분해
```

dev-flow에서 Phase 2로 자동 호출될 수도 있습니다.

## cmux 프로토콜

```bash
CMUX="$(command -v cmux-dev || command -v cmux)"

# 시작
"$CMUX" set-status phase "PLAN" --icon "🗺️" --color "#8B5CF6"
"$CMUX" set-progress 0.0 --label "Plan: 시작"

# 기존 도메인 지식 로드 — 과거 삽질을 피하기 위해 반드시 읽기
"$CMUX" folder-memo get   # 이 프로젝트의 축적된 교훈
"$CMUX" global-memo get   # 범용 교훈
# → 태스크 분해 시 교훈에서 언급된 제약/주의사항을 반영

# 레이아웃: 코드 탐색용 pane 추가
"$CMUX" new-pane --type terminal --direction right

# 진행: 탐색/분해 시 progress 갱신

# 완료
"$CMUX" workspace-memo append "### Plan 완료 ✅\n#### Tasks\n- [ ] Task 1: ...\n---"
"$CMUX" set-progress 1.0 --label "Plan: 완료"
"$CMUX" notify --title "Plan 완료" --body "[n]개 태스크"

# history 기록 (전역 축적)
"$CMUX" history add --type phase --phase plan --summary "PLAN 완료: [n]개 태스크"
# 각 태스크마다:
"$CMUX" history add --type task --phase plan --summary "[태스크 설명]" --tags task:1,[관련 decision 태그]
```

## 프로세스

### 1. 코드베이스 탐색

기존 코드를 탐색하여 영향 범위를 파악합니다.

```bash
"$CMUX" set-progress 0.2 --label "Plan: 코드 탐색"
```

- 관련 파일/모듈 식별
- 기존 패턴과 컨벤션 파악
- 변경 영향이 미치는 범위 추정

### 2. 태스크 분해

Spec을 작업 단위로 분해합니다. 각 작업은:

- **하나의 관심사**만 다룸
- **독립적으로 테스트 가능**
- **수용 기준이 이진적** (통과/실패 명확)

### 태스크 크기 가이드

| 파일 수 | 판정 | 행동 |
|---------|------|------|
| 1-2 | Small | 적정 |
| 3-5 | Medium | 적정 |
| 5-8 | Large | 분할 검토 |
| 8+ | Too Large | 반드시 분할 |

### 태스크 작성 형식

```
- [ ] Task [n]: [한 줄 설명]
  - 파일: [영향 받는 파일]
  - 수용 기준: [검증 방법]
  - 의존: [선행 task 번호, 없으면 "없음"]
```

```bash
"$CMUX" set-progress 0.6 --label "Plan: 태스크 분해"
```

### 3. 의존성 순서 결정

- Task 간 의존 관계를 파악하여 실행 순서 결정
- 병렬 가능한 task 식별
- 순환 의존이 있으면 task를 재분해

### 4. 사용자 확인

태스크 목록을 사용자에게 제시하고 승인을 요청합니다.

```bash
"$CMUX" set-progress 0.8 --label "Plan: 확인 대기"
```

## Gate

- [ ] 모든 task에 수용 기준이 있는가?
- [ ] 의존성 순서가 논리적인가?
- [ ] Spec의 모든 요구사항이 task로 커버되는가?
- [ ] 각 task가 8파일 이하인가?
- [ ] 크기가 대체로 균일한가?

## 합리화 방지

| 합리화 | 반론 |
|--------|------|
| "전체적으로 한 번에 하는 게 빨라" | 한 번에 하면 어디서 깨졌는지 모른다. 슬라이스가 디버깅 시간을 줄인다 |
| "이 정도면 task 분해 안 해도 돼" | task 분해는 크기와 상관없다. 수용 기준을 정의하는 게 핵심 |
| "수용 기준은 나중에 정해도 돼" | 수용 기준 없는 task는 끝을 알 수 없다. 지금 정해라 |
| "의존성은 머릿속으로 알고 있어" | 적지 않으면 잊는다. 명시해라 |

## Red Flags

- Task 하나가 나머지 전부보다 큼 → 더 쪼개라
- 수용 기준에 "잘 동작함" → 측정 불가, 이진적으로 다시 작성
- 모든 task가 서로 의존 → 슬라이스가 아니라 수평 분해된 것. 수직으로 재분해
- Task 수가 10개 초과 → 기능 자체를 쪼개야 할 수 있음
