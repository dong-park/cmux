---
name: ship
description: 현재 브랜치의 변경사항을 커밋, 푸시하고 대상 브랜치로 PR을 생성합니다. 서브모듈 모노레포(zootopia 등)에서는 각 서브모듈별로 개별 커밋/푸시/PR을 생성합니다. 사용법 - /ship 또는 /ship test 또는 /ship main
tools: Bash, Read, Grep, Glob
---

# Ship - 커밋 → 푸시 → PR 자동화

현재 작업 내용을 커밋하고 대상 브랜치로 PR을 생성하는 스킬입니다.

## 사용법

```
/ship              # 기본 대상: test
/ship test         # test 브랜치로 PR
/ship main         # main 브랜치로 PR
```

## 동작 순서

### 1. 상태 확인
- `git status`로 변경사항 확인
- 서브모듈이 있는 경우 각 서브모듈의 변경사항도 확인
- 변경사항이 없으면 종료

### 2. 서브모듈 모노레포 감지
- `.gitmodules` 파일이 있고 서브모듈에 변경사항이 있으면 **서브모듈별로 개별 처리**
- 각 서브모듈에서: 브랜치 생성(현재 루트 브랜치명과 동일) → 변경사항 스테이징 → 커밋 → 푸시 → PR
- 서브모듈이 아닌 일반 레포면 루트에서 직접 처리

### 3. 커밋
- 변경된 파일을 분석하여 한국어 커밋 메시지 자동 생성
- 커밋 메시지 형식: `feat:`, `fix:`, `refactor:` 등 conventional commit
- Co-Authored-By 태그 포함
- 파일을 개별 지정하여 스테이징 (git add -A 사용 금지)

### 4. 푸시
- `origin`과 `github` 리모트 모두 확인
- `github` 리모트가 있으면 `github`으로 푸시 (GitHub PR 생성을 위해)
- 없으면 `origin`으로 푸시
- `-u` 플래그로 업스트림 설정

### 5. PR 생성
- `gh pr create`로 PR 생성
- base: 인자로 전달된 대상 브랜치 (기본값: test)
- 한국어 PR 제목 및 본문
- Summary + Test plan 형식

## cmux history 기록

ship 완료 후 전역 history에 기록합니다:

```bash
CMUX="$(command -v cmux-dev || command -v cmux)"
"$CMUX" history add --type phase --phase ship --summary "SHIP 완료: PR #[number]" --tags pr:[number]
```

## 주의사항

- `.env`, credentials 등 민감 파일은 절대 커밋하지 않음
- 이미 PR이 존재하면 새로 생성하지 않고 기존 PR URL을 반환
- 푸시 전 리모트 브랜치 존재 여부 확인
- 커밋 메시지는 변경 내용을 정확히 반영해야 함
