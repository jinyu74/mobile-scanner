# A4 스캐너 (mobile-scanner)

광고 없는 무료 A4 문서 스캐너 앱입니다. Flutter로 만들었으며 iOS와 Android를 지원합니다.

스캔은 각 OS에 내장된 무료 온디바이스 스캐너를 사용합니다
([`cunning_document_scanner`](https://pub.dev/packages/cunning_document_scanner) 플러그인).

- iOS: VisionKit `VNDocumentCameraViewController`
- Android: Google ML Kit Document Scanner

자동 테두리 인식, 모서리 수동 조정, 원근 보정이 기본으로 제공됩니다.

## 현재 단계

1단계(프로젝트 골격): 홈 화면의 **스캔하기** 버튼 → 스캐너 실행 → 스캔한 페이지를 그리드로 표시.
갤러리/PDF 저장은 다음 단계에서 추가합니다.

## 준비물

- Flutter (stable) — `brew install --cask flutter`
- iOS: Xcode(App Store에서 설치) + CocoaPods(`brew install cocoapods`), iOS 15.0 이상
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
