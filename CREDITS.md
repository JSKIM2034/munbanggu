# 그림, 모델, 소리, 글꼴 출처

## 효과음
- 공격, 타격, 터짐, 레벨업, 진화 등 게임 효과음: `source/main.gd`의 코드로 직접 합성 (원작, 외부 음원 없음)
- 화면 버튼, 선택, 확인, 오류, 토글 소리: Kenney "Interface Sounds" (CC0 1.0, 출처 표기 의무 없음) — kenney.nl, `source/sfx/`

## 배경음악
- 8곡 모두 `tools/make_bgm.py`로 직접 작곡해 생성 (원작, 외부 음원 없음)

## 글꼴
- 주아체 (SIL Open Font License 1.1), `source/fonts/OFL.txt`

## 3D 모델과 그림 (AI 도구 사용)
- 캐릭터(친구들), 귀신, 대왕귀신, 소품, 배경(운동장, 문방구 등) 3D 모델과 텍스처: 개발자가 ChatGPT로 원화(그림)를 만들고, Meshy(meshy.ai)로 3D 모델로 바꾼 뒤 게임에 맞게 손봄 (`source/models/`)
- Model created with [Meshy](https://www.meshy.ai/) – [CC BY 4.0 License](https://creativecommons.org/licenses/by/4.0/) (무료 요금제로 만든 모델은 이 표기가 필요하고, 유료 요금제 모델은 표기 의무가 없지만 함께 적어 둠)
- 리깅(뼈대)과 자세: `tools/rig_kid.py` 등 직접 만든 스크립트

## AI 사용 안내 (스팀 등록용, 영어)
This game uses AI-generated content. Character, ghost, prop and background artwork was first drawn with ChatGPT image generation and converted to 3D models with Meshy, then edited by the developer. Game code was written with the help of an AI coding assistant (Claude). Sound effects and background music are synthesized by the game's own code and scripts (no AI-generated audio); UI sounds are Kenney CC0. Korean and English in-game text was written with AI assistance and reviewed by the developer.
