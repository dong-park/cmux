---
name: dev-flow
description: spec → plan → build → test → review → ship → feedback 개발 파이프라인. 각 phase에서 독립 유닛 스킬을 호출하고 cmux로 전체 진행을 조율합니다. 사용법 - /dev-flow [기능명] 또는 /dev-flow [기능명] [phase]
tools: Bash, Read, Grep, Glob, Edit, Write
---

# Dev Flow - 개발 파이프라인 오케스트레이터

각 phase에서 독립 유닛 스킬(/spec, /plan, /build, /test, /review, /ship, /feedback)을 순차 호출하고,
cmux로 전체 진행 상황을 조율하는 오케스트레이터입니다.

## 사용법

```
/dev-flow 사용자 프로필 캐싱            # Phase 1(spec)부터 시작
/dev-flow 사용자 프로필 캐싱 build      # 특정 phase부터 이어하기
/dev-flow 사용자 프로필 캐싱 feedback   # ship 이후 피드백 루프 진입
```

## 파이프라인 개요

```
/spec(0.15) → /plan(0.30) → /build(0.50) → /test(0.65) → /review(0.80) → /ship(1.0)
                                                                                  ↓
                                                                            /feedback (선택)
                                                                                  ↓
                                                                        재진입점 → 반복
```

각 단계는 **Gate(관문)**를 통과해야 다음 단계로 진행합니다.
각 유닛 스킬은 독립 호출도 가능하지만, dev-flow에서는 전체 context를 공유합니다.
ship 이후 피드백이 있으면 `/feedback`으로 수집 → 분류 → 적절한 phase로 재진입합니다.

## 실행 프로토콜

### 0. 초기화

```bash
CMUX="$(command -v cmux-dev || command -v cmux)"
"$CMUX" current-workspace
"$CMUX" tree --all
"$CMUX" workspace-memo set "## Dev Flow: [기능명]
Started: [날짜]
---"
"$CMUX" set-status phase "INIT" --icon "⚡" --color "#6B7280"

# 과거 패턴 참조 (플라이휠: 이전 사이클의 교훈)
"$CMUX" history list --type pattern --limit 10
# → 과거 반복 피드백 패턴을 참고하여 이번 사이클에 반영

"$CMUX" history add --type phase --summary "Dev Flow 시작: [기능명]"
```

### 1. SPEC — /spec 호출

**progress 범위:** 0.00 ~ 0.15

```bash
"$CMUX" set-status phase "SPEC" --icon "📋" --color "#3B82F6"
"$CMUX" set-progress 0.05 --label "Phase 1/6: Spec"
```

`/spec` 스킬의 프로세스를 실행합니다:
- 사용자와 대화하며 목표/비목표/성공 기준/경계 조건 정의
- Gate 통과 시 memo에 결과 기록

```bash
"$CMUX" workspace-memo append "### Phase 1: SPEC ✅
- 목표: [정의된 목표]
- 비목표: [범위 밖 항목]
- 성공 기준: [측정 가능한 조건]
- 경계 조건: [엣지 케이스]
---"
"$CMUX" set-progress 0.15 --label "Phase 1/6: Spec ✅"
```

---

### 2. PLAN — /plan 호출

**progress 범위:** 0.15 ~ 0.30

```bash
"$CMUX" set-status phase "PLAN" --icon "🗺️" --color "#8B5CF6"
"$CMUX" set-progress 0.20 --label "Phase 2/6: Plan"
```

`/plan` 스킬의 프로세스를 실행합니다:
- 코드베이스 탐색 → 태스크 분해 → 의존성 정리
- Gate 통과 시 memo에 태스크 목록 기록

```bash
"$CMUX" workspace-memo append "### Phase 2: PLAN ✅
#### Tasks
- [ ] Task 1: [설명] → 검증: [수용 기준]
---"
"$CMUX" set-progress 0.30 --label "Phase 2/6: Plan ✅"
```

---

### 3. BUILD — /build 호출

**progress 범위:** 0.30 ~ 0.50

```bash
"$CMUX" set-status phase "BUILD" --icon "🔨" --color "#F59E0B"
"$CMUX" set-progress 0.35 --label "Phase 3/6: Build"
```

`/build` 스킬의 프로세스를 실행합니다:
- task별 구현 → 테스트 → 원자적 커밋 루프
- task 완료마다 memo 업데이트 및 progress 갱신 (0.35 ~ 0.50)
- 되돌림 발생 시 memo에 사유 기록 후 이전 phase로

```bash
"$CMUX" workspace-memo append "### Phase 3: BUILD ✅
- Tasks: [n]/[n] 완료
- Commits: [n]개
---"
"$CMUX" set-progress 0.50 --label "Phase 3/6: Build ✅"
```

---

### 4. TEST — /test 호출

**progress 범위:** 0.50 ~ 0.65

```bash
"$CMUX" set-status phase "TEST" --icon "🧪" --color "#10B981"
"$CMUX" set-progress 0.55 --label "Phase 4/6: Test"
```

`/test` 스킬의 프로세스를 실행합니다:
- 전체 테스트 스위트 실행
- 실패 시 디버깅 (Stop-the-Line)
- Spec 성공 기준과 대조

```bash
"$CMUX" workspace-memo append "### Phase 4: TEST ✅
- Unit: [n]/[n] ✅
- Integration: [n]/[n] ✅
- Coverage: [n]%
- Spec 성공 기준 충족 확인
---"
"$CMUX" set-progress 0.65 --label "Phase 4/6: Test ✅"
```

---

### 5. REVIEW — /review 호출

**progress 범위:** 0.65 ~ 0.80

```bash
"$CMUX" set-status phase "REVIEW" --icon "🔍" --color "#EC4899"
"$CMUX" set-progress 0.70 --label "Phase 5/6: Review"
```

`/review` 스킬의 프로세스를 실행합니다:
- 5축 자체 검토 (정확성/보안/성능/가독성/테스트)
- 이슈 발견 시 수정 후 재검증
- 변경 크기 확인

```bash
"$CMUX" workspace-memo append "### Phase 5: REVIEW ✅ (5축)
- 정확성: ✅
- 보안: ✅
- 성능: ✅
- 가독성: ✅
- 테스트: ✅
- 변경 크기: [n]줄
---"
"$CMUX" set-progress 0.80 --label "Phase 5/6: Review ✅"
```

---

### 6. SHIP — /ship 호출

**progress 범위:** 0.80 ~ 1.00

```bash
"$CMUX" set-status phase "SHIP" --icon "🚀" --color "#06B6D4"
"$CMUX" set-progress 0.90 --label "Phase 6/6: Ship"
```

`/ship` 스킬을 호출하여 커밋 → 푸시 → PR 생성:
- PR 본문에 dev-flow memo 내용 포함

```bash
"$CMUX" set-progress 1.0 --label "Shipped!"
"$CMUX" notify --title "Dev Flow 완료" --body "[기능명] shipped"
"$CMUX" workspace-memo append "### Phase 6: SHIP ✅
- PR: #[number]
- 완료: [날짜]"
"$CMUX" set-status phase "DONE" --icon "✅" --color "#22C55E"
```

---

### 7. FEEDBACK (선택) — /feedback 호출

ship 이후 피드백이 있을 때만 진입합니다. `/dev-flow 기능명 feedback`으로 명시 호출합니다.

```bash
"$CMUX" set-status phase "FEEDBACK" --icon "💬" --color "#F97316"
"$CMUX" set-progress 0.90 --label "Feedback: 수집 중"
```

`/feedback` 스킬의 프로세스를 실행합니다:
- PR 코멘트 + 사용자 입력으로 피드백 수집
- 유형(bug/requirement/design/polish/question)과 심각도(critical/important/minor) 분류
- 재진입점 결정 (spec/plan/build/test)

```bash
"$CMUX" workspace-memo append "### Iteration [N]: Feedback
- 소스: [PR 코멘트 / QA / 사용자 입력]
- 항목: [n]건 (critical: [n], minor: [n])
- 재진입: [phase]
---"
"$CMUX" set-progress 1.0 --label "Feedback: → [phase]로 재진입"
```

재진입 후에는 해당 phase부터 다시 ship까지 파이프라인을 진행합니다.
피드백이 없으면 "피드백 없음"으로 종료합니다.

---

## 단계 전환 규칙

1. **순방향만** — 단계를 건너뛸 수 없음 (spec 없이 build 불가)
2. **Gate 필수** — 각 유닛 스킬의 Gate를 통과해야 다음 단계 진입
3. **되돌림 허용** — 이후 단계에서 문제 발견 시 이전 단계로 (memo에 사유 기록)
4. **이어하기 가능** — phase 인자로 특정 단계부터 재개
5. **피드백 루프** — ship 이후 `/feedback`으로 재진입, iteration 번호로 회차 추적

## 유닛 스킬 독립 호출

각 스킬은 dev-flow 없이도 독립적으로 사용 가능합니다:

```
/spec "사용자 프로필 캐싱"    # 명세만 작성
/plan                        # 현재 컨텍스트에서 태스크 분해
/build                       # 태스크 기반 구현
/test                        # 전체 테스트 + 검증
/review                      # 현재 diff에 5축 검토
/ship                        # 커밋 → 푸시 → PR
/feedback                    # PR 피드백 수집 → 분류 → 재진입
```

독립 호출 시 각 스킬이 자체적으로 cmux status/progress/memo를 관리합니다.

## 중도 이탈 시

memo에 현재까지의 기록이 남아 있으므로,
다음 세션에서 `/dev-flow [기능명] [마지막 phase]`로 이어서 진행할 수 있습니다.
