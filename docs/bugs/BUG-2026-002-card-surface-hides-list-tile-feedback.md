---
id: BUG-2026-002
title: Card surface can cover ListTile splash feedback
status: fixed
severity: normal
area: app
reported: 2026-10-03
---

# BUG-2026-002 — Card surface can cover ListTile splash feedback

## Суть

`GameCardSurface` placed a colored overlay between its decorated background and
interactive `ListTile` children without a nearer `Material` ancestor. Flutter
reported that the overlay could hide the list tile background and ink splash.

## Среда

- Версия приложения / commit: PR #27, commit `0810388`; Linux CI, Flutter 3.47.6.
- Платформа и версия ОС / браузера: GitHub Actions Ubuntu 24.04.
- Устройство или размер окна, если важно: responsive layout widget test.
- Режим игры / состав партии / seed, если важно: compact mobile layout.

## Подготовка и шаги воспроизведения

1. Pump the MVP screen at a phone portrait size.
2. Render interactive list tiles on decorated card surfaces.
3. Let Flutter check the overlay and ink layer during the widget test.

Частота воспроизведения: always in the affected widget tree.

## Результат

- **Фактический:** Flutter emitted the assertion that a `ListTile` wrapped in a
  colored `DecoratedBox` could have invisible background/splash effects; the
  responsive widget test failed due to the uncaught framework exception.
- **Ожидаемый:** card decoration remains behind the interactive Material and
  its ink feedback.
- **Основание ожидания:** Flutter's `ListTile` contract requires a `Material`
  ancestor above the decorated overlay so splash effects are painted visibly.

## Влияние

- Что пользователь не может сделать или какое состояние портится: tap feedback
  could be hidden on interactive card rows; the UI test suite failed.
- Масштаб / обходной путь: rows rendered inside the shared card surface.

## Доказательства

- Initial CI log for PR #27: <https://github.com/Lamandos/Besprotoritsa/actions/runs/37123258740>
- `responsive_layout_test.dart` logged `ListTile background color or ink
  splashes may be invisible` and failed with an unexpected framework
  exception.

## Границы проверки

- Подозреваемая область кода: `packages/besprotoritsa_app/lib/src/cards/game_card_surface.dart`.
- Релевантные существующие тесты / спецификации:
  `packages/besprotoritsa_app/test/responsive_layout_test.dart`, test
  `phone portrait keeps the board compact with a floating dock`.
- Что пока неизвестно: none for this failure.

## Регрессионный тест

- Тестовый файл и имя теста:
  `packages/besprotoritsa_app/test/responsive_layout_test.dart`,
  `phone portrait keeps the board compact with a floating dock`.
- Команда запуска: `flutter test test/responsive_layout_test.dart` from
  `packages/besprotoritsa_app`.
- **До исправления (красный):** the CI test reported the invisible splash
  assertion and failed on the unexpected framework exception.
- Результат и причина падения: card surface overlay sat above the default
  Material ink layer.
- **После исправления (зелёный):** the test passed as part of
  `flutter test test/responsive_layout_test.dart test/mvp_screen_test.dart`.
- Результат связанных проверок: `./tool/run_checks.sh` passed locally after the
  fix.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_app/lib/src/cards/game_card_surface.dart`.
- Краткое описание исправления: add a transparent `Material` inside the overlay
  and around card content so ink feedback paints above the decoration.
- Остаточные ограничения или связанные баги: none known.
