---
command: "implement-from-tech-spec"
---

입력으로 전달되는 내용은 이미 작성된 "기술 기획서(Tech Spec)"입니다.
이 문서에 기반하여 백엔드 개발자가 즉시 구현을 시작할 수 있도록,
구체적인 작업 항목과 코드 스켈레톤을 생성합니다.

출력 형식은 아래 템플릿을 절대 벗어나지 않습니다.
섹션 제목/순서를 변경하거나 추가 텍스트(인사, 설명 등)를 절대 쓰지 마세요.

기획서를 보고 추가로 보강하고 싶거나 의심가는 영역이 있으면 가차없이 물어보시오.

## 1. Implementation Summary
- 이 기술 기획서를 바탕으로 구현해야 할 핵심 변경사항을 3~5줄로 요약합니다.
- 주요 엔드포인트, 핵심 로직, 데이터 변경 여부를 포함합니다.

## 2. Task Breakdown
- 실제 작업 티켓으로 쪼갤 수 있을 정도로 세분화된 할 일 목록을 작성합니다.
- 각 항목은 다음 형식을 따릅니다:
  - [범위] 설명 (예: `[BE] /admin/marketing/updateMarketing 컨트롤러 추가`)
- BE/FE/DB/ETC 등 범위를 명확히 표기합니다.

## 3. Backend Changes
### 3.1 라우터/컨트롤러
- 추가/수정해야 할 라우터, 컨트롤러 함수 목록을 bullet으로 나열합니다.
- 각 항목마다 다음 정보를 포함합니다:
  - 파일 경로 (추정 가능하면 명시, 예: `src/admin/router/marketing.route.js`)
  - 함수명
  - 주요 처리 단계(검증, 조회, 권한 체크, 업데이트, 응답 등)를 5~10줄 내로 정리

### 3.2 서비스/도메인 로직
- 새로 추가되거나 수정될 서비스/도메인 함수 목록을 bullet으로 작성합니다.
- 각 함수에 대해:
  - 입력 파라미터
  - 반환 값(또는 부수효과)
  - 핵심 로직(의사코드 수준)을 5~10줄로 정리합니다.

## 4. API Skeleton (Code)
- Tech Spec에 정의된 각 API에 대해, 실제 코드에 바로 붙여넣어 사용할 수 있는 수준의 스켈레톤을 제공합니다.
- 기본 스타일은 Tech Spec/Dev Notes에 드러난 예시를 따릅니다. (예: Express 기반 라우터, controller/service 분리 등)
- 각 API마다 다음 형식으로 작성합니다:

[API 명칭]
```javascript
// router
router.METHOD("/path", middleware..., controller.fnName);

// controller
async function fnName(req, res, next) {
  try {
    // 1. 파라미터 파싱 및 검증
    // 2. 서비스 호출
    // 3. 응답 반환
  } catch (err) {
    return next(err);
  }
}

// service
async function serviceFnName(params) {
  // 1. 기존 데이터 조회
  // 2. 비즈니스 검증
  // 3. DB 업데이트
  // 4. 결과 반환
}
