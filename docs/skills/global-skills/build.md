---
name: build
description: 태스크 목록을 기반으로 점진적 구현을 수행합니다. 수직 슬라이스 → 테스트 → 원자적 커밋 루프를 반복하고 cmux로 진행 상황을 추적합니다. 사용법 - /build 또는 dev-flow에서 자동 호출
tools: Bash, Read, Grep, Glob, Edit, Write
---

# Build - 점진적 구현

태스크 단위로 구현 → 테스트 → 커밋을 반복하는 스킬입니다.

## 사용법

```
/build                 # 현재 컨텍스트의 태스크 기반 구현
```

dev-flow에서 Phase 3으로 자동 호출될 수도 있습니다.

## cmux 프로토콜

```bash
CMUX="$(command -v cmux-dev || command -v cmux)"

# 시작
"$CMUX" set-status phase "BUILD" --icon "🔨" --color "#F59E0B"
"$CMUX" set-progress 0.0 --label "Build: 시작"

# 진행: task 완료마다 progress 갱신
"$CMUX" workspace-memo append "- [x] Task 1 ✅ (commit: [hash])"
"$CMUX" set-progress [n/total] --label "Build: Task [n]/[total]"

# 테스트 결과 확인
"$CMUX" read-screen --surface [test-surface] --lines 30

# 완료
"$CMUX" workspace-memo append "### Build 완료 ✅\n- Tasks: [n]/[n]\n- Commits: [n]\n---"
"$CMUX" set-progress 1.0 --label "Build: 완료"
"$CMUX" notify --title "Build 완료" --body "[n]개 태스크 구현"

# history 기록 (전역 축적) — task 완료마다:
"$CMUX" history add --type note --phase build --summary "task:[n] 완료 (commit: [hash])" --tags task:[n]
# build 완료 시:
"$CMUX" history add --type phase --phase build --summary "BUILD 완료: [n]개 태스크, [n]개 커밋"
```

## 프로세스

### 각 Task에 대해 반복:

#### 1. 구현

최소한의 코드로 task를 해결합니다.

- **수직 슬라이스**: 한 경로의 모든 레이어를 관통

```
❌ 수평 슬라이스 (피하라)          ✅ 수직 슬라이스 (이렇게)
├── 모든 DB 스키마 먼저           ├── 기능 A: DB + API + UI + 테스트
├── 모든 API 먼저                ├── 기능 B: DB + API + UI + 테스트
└── 모든 테스트 먼저              └── 기능 C: DB + API + UI + 테스트
```

#### 2. 테스트

Task의 수용 기준을 검증하는 테스트를 작성하고 실행합니다.

- **Red-Green-Refactor**: 실패하는 테스트 먼저 → 통과시키기 → 정리
- 테스트가 통과해야 다음으로 넘어감

```bash
# 테스트 실행 후 결과 확인
"$CMUX" read-screen --surface [test-surface] --lines 30
```

#### 3. 커밋

원자적 커밋을 생성합니다.

- **한 task = 한 커밋** (의미 있는 단위로 분할 가능)
- Conventional commit: `feat:`, `fix:`, `refactor:`, `test:`
- 각 커밋은 테스트가 통과하는 상태

#### 4. Memo 업데이트

```bash
"$CMUX" workspace-memo append "- [x] Task [n] ✅ (commit: [hash])"
```

### 문제 발견 시 되돌림

- Spec에 누락된 요구사항 → **Spec으로 되돌아감**, memo에 사유 기록
- Plan이 비현실적 → **Plan으로 되돌아감**, task 재조정
- 되돌림은 실패가 아니라 정상 프로세스

```bash
"$CMUX" workspace-memo append "⚠️ BUILD → SPEC 되돌림: [사유]"
```

## Gate

- [ ] 모든 task 체크 완료?
- [ ] 각 task마다 커밋 존재?
- [ ] 테스트 전부 통과?
- [ ] 되돌림이 있었다면 해결 후 재진행 완료?

## 합리화 방지

| 합리화 | 반론 |
|--------|------|
| "나중에 한꺼번에 테스트하면 돼" | 나중은 안 온다. 슬라이스마다 증명하라 |
| "이건 너무 작아서 커밋할 필요 없어" | 작은 커밋이 롤백을 쉽게 만든다 |
| "리팩토링도 같이 하면 효율적이야" | 기능 변경과 리팩토링은 별개 커밋. 리뷰어를 생각하라 |
| "테스트 깨진 건 나중에 고치면 돼" | 깨진 테스트는 전파된다. 지금 고쳐라 |
| "일단 동작하게 만들고 나중에 정리" | "나중에"는 기술 부채의 다른 이름. 지금 정리하라 |

## Red Flags

- Task 순서를 무시하고 뛰어넘기 → 의존성 위반 위험
- 한 커밋에 여러 task → 롤백 불가, 리뷰 어려움
- 테스트 없이 커밋 → 수용 기준 미검증
- "WIP" 커밋 → 깨진 상태를 히스토리에 남김
- 한 task가 예상보다 2배 이상 커짐 → Plan으로 되돌아가서 재분해
