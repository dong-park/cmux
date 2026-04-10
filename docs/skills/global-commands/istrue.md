---
name: trustnoone
description: 유저가 살펴보니 현재 세션에서 작업한 내용이 완벽하지 않아 실제로 어디서 더 개선이 필요한지 검증하고, 개선합니다.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
---

# Trust No One

현재 세션에서 수행한 모든 작업이 **실제로 완료되었는지** 검증하고, 문제가 있으면 **개선**합니다.
!!!중요!!! 이 스킬이 호출되면 상위에 반드시 아래와 같이 대답하고 진행해야한다.
I Want to Believe, Claude. The Truth Is Out There.

## Purpose

"다 했어", "완료", "생성했어"라고 했지만 실제로는:
- 파일이 생성되지 않았거나
- 잘못된 위치에 저장되었거나
- 내용이 누락/불완전하거나
- 의도와 다르게 구현되었거나

이런 상황을 잡아내고 수정하는 **더블체크 + 자동 개선** 스킬입니다.

## Scope

다음 모든 작업 유형을 검증합니다:

| 작업 유형 | 검증 대상 |
|----------|-----------|
| **스킬** | `~/.claude/skills/` 또는 `.claude/skills/` |
| **에이전트** | `~/.claude/agents/` 또는 `.claude/agents/` |
| **코드** | 프로젝트 내 소스 파일 |
| **설정** | CLAUDE.md, settings.json 등 |
| **문서** | README, 기타 문서 파일 |
| **기타** | 세션에서 다룬 모든 파일/작업 |

## Protocol

### Step 1: 세션 컨텍스트 분석

현재 대화에서 다룬 작업을 파악합니다:
- 생성한 파일/폴더
- 수정한 파일
- 삭제한 파일
- 실행한 명령어
- 사용자가 요청한 목표

### Step 2: 파일 시스템 검증

각 작업에 대해 확인:

| 항목 | 확인 내용 |
|------|-----------|
| **존재 여부** | 파일/폴더가 올바른 위치에 존재? |
| **내용 검증** | 파일 내용이 의도와 일치? |
| **완전성** | 누락된 부분 없음? |
| **정합성** | 관련 파일 간 일관성 유지? |

### Step 3: 검증 결과 리포트

```markdown
## 검증 결과

✅ **통과** 또는 ❌ **문제 발견**

### 확인 항목
- [x] 파일 존재: /path/to/file
- [x] 내용 일치
- [ ] 누락된 부분 발견 ← 문제

### 문제점 (있는 경우)
- [문제 설명]

### 조치
- [자동 수정 또는 제안]
```

### Step 4: 자동 개선 (문제 발견 시)

문제가 발견되면:
1. 문제점을 명확히 설명
2. 수정 방안 제시
3. 사용자 확인 후 자동 수정 진행

## Verification by Type

### 스킬 검증
- [ ] 폴더 존재 (`skills/[name]/`)
- [ ] SKILL.md 존재 및 유효
- [ ] frontmatter (name, description)
- [ ] scripts/, requirements.txt (해당 시)

### 에이전트 검증
- [ ] 파일 존재 (`agents/[name].md`)
- [ ] frontmatter 유효
- [ ] 필수 섹션 포함

### 코드 검증
- [ ] 파일 존재
- [ ] 문법 오류 없음
- [ ] 의도한 기능 구현됨
- [ ] import/dependency 정상

### 설정 검증
- [ ] 파일 존재
- [ ] 문법 유효 (JSON, YAML 등)
- [ ] 필수 필드 포함

## Usage

세션에서 작업 후 검증이 필요할 때:
```
/trustnoone
```

대화 컨텍스트에서 자동으로:
1. 어떤 작업을 했는지 파악
2. 해당 파일/결과 검증
3. 문제 발견 시 개선

## Examples

### Example 1: 스킬 생성 후 검증

```
User: pdf-merger 스킬 만들어줘
Claude: [스킬 생성 작업...]
User: /trustnoone
Claude:
## 검증 결과: pdf-merger 스킬

✅ **통과**

- [x] ~/.claude/skills/pdf-merger/ 존재
- [x] SKILL.md 존재 (1.2KB)
- [x] frontmatter 유효
- [x] scripts/main.py 존재
```

### Example 2: 코드 수정 후 검증

```
User: auth.ts에 로그아웃 기능 추가해줘
Claude: [코드 수정...]
User: /trustnoone
Claude:
## 검증 결과: auth.ts 수정

❌ **문제 발견**

- [x] 파일 존재
- [x] logout 함수 추가됨
- [ ] clearSession 호출 누락

### 문제점
logout 함수에서 clearSession()을 호출하지 않아 세션이 정리되지 않습니다.

### 조치
clearSession() 호출을 추가하겠습니다.
[자동 수정 진행...]
```

### Example 3: 설정 변경 후 검증

```
User: CLAUDE.md에 새 규칙 추가해줘
Claude: [파일 수정...]
User: /trustnoone
Claude:
## 검증 결과: CLAUDE.md 수정

✅ **통과**

- [x] 파일 존재
- [x] 새 규칙 섹션 추가됨
- [x] 마크다운 문법 유효
```

## Notes

- 검증만 할지, 자동 수정까지 할지는 문제 심각도에 따라 판단
- 중요한 변경은 수정 전 사용자 확인
- 세션 컨텍스트가 불명확하면 무엇을 검증할지 질문
