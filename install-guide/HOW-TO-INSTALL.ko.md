# Prompt Picker {{version}} 설치 방법

**18+.** Prompt Picker는 18세 이상을 위한 앱입니다. 처음 실행하면 "18세 이상입니까?"라고 묻습니다. 예는 이 PC에 기억되고 앱이 열립니다. 아니오는 앱을 닫습니다.

이 폴더의 그림은 단계를 보여주는 예시이며, 내 PC의 화면 캡처가 아닙니다.

Windows가 "Windows가 PC를 보호했습니다"라고 표시하는 이유는 이 앱에 코드 서명이 없기 때문입니다. 경고는 정상입니다. 파일이 바뀌었다는 뜻이 아닙니다. SmartScreen이나 Defender를 끄지 마세요.

## 1. 다운로드

`PromptPicker-Setup-{{version}}.exe`를 받거나 `PromptPicker-{{version}}-Windows.zip`을 열고 안의 설치 파일을 실행하세요. 릴리스 페이지의 `latest.yml`은 그대로 두세요. 설치된 앱이 그 파일로 업데이트를 확인합니다.

![다운로드](ko/01-download.png)

## 2. SmartScreen

설치 파일을 엽니다. Windows가 "Windows가 PC를 보호했습니다"라고 하면:

1. **추가 정보**(More info)를 클릭합니다.
2. **실행**(Run anyway)을 클릭합니다.

![SmartScreen](ko/02-smartscreen.png)

## 3. 설치

설치 프로그램이 Prompt Picker를 둘 폴더를 묻습니다. 만들 수 있으면 기본 폴더는 `C:\Prompt Picker`이고, 그렇지 않으면 사용자 프로필 안의 Prompt Picker 폴더입니다. 프로그램 파일은 고른 폴더에 들어갑니다. 바탕 화면 바로 가기만 만들고 시작 메뉴 바로 가기는 만들지 않으며, 예전 Prompt Picker 시작 메뉴 바로 가기는 지웁니다. 이미 Prompt Picker가 있으면 그 복사본 위에 설치합니다. 프롬프트는 `%APPDATA%\Prompt Picker\data`에 남습니다.

![설치](ko/03-installer.png)

## 4. 처음 실행

18세 이상인지 확인한 다음 프롬프트를 뽑습니다.

![처음 실행](ko/04-first-launch.png)

## 5. 업데이트

업데이트는 이미 고른 폴더에 설치됩니다. 폴더를 다시 묻지 않고, 프롬프트나 설정을 지우지 않습니다.

## 6. 제거

설정 > 기타에 두 가지 선택이 있습니다. Windows 설정 > 앱에도 같은 두 선택이 있습니다.

**제거하고 데이터 유지**는 앱, 바로 가기, 제거 항목, 임시 파일, 업데이트 캐시를 지웁니다. 프롬프트, 언어, 테마, 정렬, 힌트와 다른 환경설정은 남고, 고른 폴더와 바탕 화면 바로 가기 선택도 남습니다. 다음 설치는 그 폴더와 선택으로 채워지고, 앱이 설정을 자동으로 복원합니다. 사본이 필요하면 먼저 JSON 백업을 내보내세요(설정 > 백업 및 가져오기).

**제거하고 모두 지우기**는 앱, 프롬프트, 설정, 설치 폴더, 저장된 설치 선택을 지웁니다. 되돌릴 수 없습니다.

## 7. 연락

Discord가 선호하는 연락처이며 답장이 가장 빠릅니다: https://discord.gg/yH5AAdj5qY

Patreon: https://www.patreon.com/c/linekoaiart447658

X: https://x.com/lyht111222333

Telegram은 확인이 적습니다: https://t.me/linekoaiart
