---
name: test
description: 전체 테스트 스위트 실행, 커버리지 확인, spec 성공 기준 대조를 수행합니다. 디버깅 및 실패 분석을 포함합니다. 사용법 - /test 또는 dev-flow에서 자동 호출
tools: Bash, Read, Grep, Glob
---

# Test - 작동 증명

전체 테스트 스위트로 통합 검증하고 spec의 성공 기준과 대조하는 스킬입니다.

## 사용법

```
/test                  # 전체 테스트 실행 + 검증
```

dev-flow에서 Phase 4로 자동 호출될 수도 있습니다.

## cmux 프로토콜

```bash
CMUX="$(command -v cmux-dev || command -v cmux)"

# 시작
"$CMUX" set-status phase "TEST" --icon "🧪" --color "#10B981"
"$CMUX" set-progress 0.0 --label "Test: 시작"

# 레이아웃: 테스트 결과 확인용 pane
"$CMUX" new-pane --type terminal --direction right

# 테스트 실행 후 결과 읽기
"$CMUX" read-screen --surface [test-surface] --lines 50

# 완료
"$CMUX" workspace-memo append "### Test 완료 ✅\n- Unit: [n]/[n]\n- Integration: [n]/[n]\n- Coverage: [n]%\n---"
"$CMUX" set-progress 1.0 --label "Test: 완료"
"$CMUX" notify --title "Test 완료" --body "전체 통과"

# history 기록 (전역 축적)
"$CMUX" history add --type phase --phase test --summary "TEST 완료: unit [n]/[n], integration [n]/[n]"
# 실패 발견 시:
"$CMUX" history add --type note --phase test --summary "테스트 실패: [테스트명] — [근본 원인]" --tags [관련 태그]
```

## 프로세스

### 1. 테스트 스위트 실행

프로젝트의 테스트 프레임워크를 감지하고 전체 테스트를 실행합니다.

```bash
"$CMUX" set-progress 0.2 --label "Test: 실행 중"
```

### 2. 결과 분석

```bash
"$CMUX" read-screen --surface [test-surface] --lines 50
"$CMUX" set-progress 0.5 --label "Test: 결과 분석"
```

- 통과/실패/스킵 수 확인
- 실패한 테스트가 있으면 → 디버깅 프로세스로 이동

### 3. 디버깅 (실패 시)

**Stop-the-Line Rule**: 실패가 발견되면 즉시 멈추고 원인을 파악합니다.

1. **재현** — 실패하는 테스트를 단독으로 실행하여 재현 확인
2. **격리** — 실패 원인을 가장 작은 범위로 좁힘
3. **근본 원인** — 증상이 아닌 원인을 찾음
4. **수정** — 최소한의 변경으로 수정
5. **가드** — 재발 방지 테스트 추가
6. **검증** — 전체 스위트 재실행

```bash
"$CMUX" workspace-memo append "⚠️ 테스트 실패: [테스트명]\n- 원인: [근본 원인]\n- 수정: [변경 내용]"
```

### 4. 커버리지 확인

```bash
"$CMUX" set-progress 0.7 --label "Test: 커버리지 확인"
```

### 5. Spec 대조

Spec의 성공 기준 목록을 하나씩 테스트 결과와 대조합니다.

```bash
"$CMUX" set-progress 0.9 --label "Test: Spec 대조"
```

### 테스트 피라미드 (참고)

```
        /  E2E  \        5% — 핵심 사용자 여정만
       /  통합   \       15% — 모듈 간 경계
      /   단위    \      80% — 함수/메서드 단위
```

### 테스트 품질 기준

- **DAMP > DRY** — 테스트는 약간 중복이 있어도 읽기 쉬운 게 낫다
- **이름은 행동 설명** — `test_cache()` ✗ → `test_returns_cached_value_within_ttl()` ✓
- **Arrange-Act-Assert** 패턴 준수
- **구현이 아닌 행동 검증** — 내부 구조 변경에 테스트가 깨지면 안 됨

## Gate

- [ ] 전체 테스트 통과?
- [ ] 새 코드에 테스트 존재?
- [ ] 엣지 케이스 테스트 존재? (spec 경계 조건 참조)
- [ ] 기존 테스트 회귀 없음?
- [ ] Spec의 성공 기준과 결과 대조 완료?

## 합리화 방지

| 합리화 | 반론 |
|--------|------|
| "수동으로 확인했으니 테스트 안 써도 돼" | 수동 확인은 1회성. 자동 테스트는 영구 가드레일 |
| "이건 테스트하기 어려워" | 테스트하기 어려운 코드는 설계가 잘못된 신호 |
| "커버리지 숫자만 채우면 되지" | 의미 없는 테스트 100개보다 핵심 경로 테스트 10개가 낫다 |
| "CI에서 돌리면 되니까 로컬에서 안 돌려도 돼" | CI 피드백은 느리다. 로컬에서 빠르게 확인하라 |
| "기존 테스트가 깨진 건 원래부터 불안정해서" | 불안정한 테스트를 방치하면 모든 실패를 무시하게 된다 |

## Red Flags

- 테스트 0개 추가 → 새 코드에 테스트가 없다
- 실패한 테스트를 skip/disable → 문제를 숨기는 것
- 테스트가 구현 세부사항에 의존 → 리팩토링마다 깨짐
- 모든 테스트가 happy path만 → 실패 경로, 경계값 누락
- 테스트 실행 시간이 비정상적으로 길어짐 → 테스트 설계 재검토
