# Аудит среды разработки

Дата аудита: 18 сентября 2026 года.

Проверки выполнены командами `flutter doctor -v`, `flutter devices` и `flutter emulators`. Сторонние утилиты не устанавливались.

## Версии

| Компонент | Версия / состояние |
| --- | --- |
| Flutter SDK | 3.47.1 (stable), framework `6655482ec0` |
| Dart SDK | 3.13.1 |
| macOS | 26.6.2, build 25G83, Intel (`darwin-x64`) |
| Xcode | Полная установка отсутствует; выбран Command Line Tools (`/Library/Developer/CommandLineTools`) |
| Android SDK | 36.0.0 (`/Users/maksimandronov/Library/Android/sdk`) |
| Android Emulator | 37.1.11.0 |

## Целевые платформы первого релиза

| Платформа | Статус |
| --- | --- |
| Web | Готова: Chrome обнаружен Flutter. |
| macOS | Требуется полная установка Xcode; текущие Command Line Tools недостаточны для сборки macOS-приложения. |
| Android | SDK и эмулятор доступны. `flutter doctor` сообщает об отсутствующем компоненте `cmdline-tools` и неизвестном статусе лицензий; перед Android-сборкой потребуется их настроить. |

## Обнаруженные устройства

| Устройство | Идентификатор | Платформа / версия | Состояние |
| --- | --- | --- | --- |
| Chrome | `chrome` | Web, Google Chrome 153.0.8010.48 | Подключён |
| macOS desktop | `macos` | macOS 26.6.2 (25G83), `darwin-x64` | Подключён |
| Pixel 9 Pro API 35 | `Pixel_9_Pro_API_35` | Android, Google | Профиль эмулятора доступен, не запущен |
| 2201117PG | `PRYTZHEM9PO7GUHU` | Android 13 (API 33), `android-arm64` | Подключённое физическое устройство |

## Платформы вне объёма 0.1.0

- Windows — Отложены до этапа post-0.1.0, отсутствие компиляторов не блокирует разработку.
- Linux — Отложены до этапа post-0.1.0, отсутствие компиляторов не блокирует разработку.
- iOS — Отложены до этапа post-0.1.0, отсутствие компиляторов не блокирует разработку.
