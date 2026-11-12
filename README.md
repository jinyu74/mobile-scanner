# A4 스캐너 (mobile-scanner)

광고 없는 무료 A4 문서 스캐너 앱입니다. Flutter로 만들었으며 iOS와 Android를 지원합니다.

스캔은 각 OS에 내장된 무료 온디바이스 스캐너를 사용합니다
([`cunning_document_scanner`](https://pub.dev/packages/cunning_document_scanner) 플러그인).

- iOS: VisionKit `VNDocumentCameraViewController`
- Android: Google ML Kit Document Scanner

자동 테두리 인식, 모서리 수동 조정, 원근 보정이 기본으로 제공됩니다.

## 기능

- **스캔하기**: 스캐너 실행 → 스캔한 페이지를 그리드로 표시
- **저장 / 공유**
  - 사진첩에 저장: JPG 또는 PNG 선택, "A4 스캐너" 앨범에 저장
  - PDF로 저장: 모든 페이지를 A4(595×842pt) PDF 한 파일로 묶어 시스템 저장 창에서 위치 선택
    (iOS는 파일 앱, Android는 다운로드 등)
  - 텍스트 추출: 모든 쪽의 글자를 읽어 복사·공유·.txt 저장
    (iOS는 Apple Vision, Android는 ML Kit 한국어 모델, 모두 기기 안에서 처리)
  - 공유: PDF / 이미지(JPG) / 추출한 텍스트 중 골라 시스템 공유 창으로 보내기

광고·결제·추적 코드는 넣지 않습니다.

## 준비물

- Flutter (stable) — `brew install --cask flutter`
- iOS: Xcode(App Store에서 설치), iOS 16.0 이상 (한국어 텍스트 인식에 필요)
- Android: Android Studio(Android SDK 포함), Android 7.0(API 24) 이상

설치 상태는 `flutter doctor`로 확인하세요.

## 실행 방법

```bash
flutter pub get
flutter run            # 연결된 기기/시뮬레이터에서 실행
```

> 스캐너는 카메라를 사용하므로 실제 기기에서 테스트하는 것이 좋습니다.
> iOS 시뮬레이터에는 카메라가 없어 스캐너가 동작하지 않습니다.

## 검사 / 테스트

```bash
flutter analyze
flutter test
```
