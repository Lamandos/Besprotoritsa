---
id: BUG-2026-084
title: Нельзя выбрать источник переброса
status: fixed
severity: high
area: app
reported: 2026-10-10
---

# BUG-2026-084 — Нельзя выбрать источник переброса

## Суть

Когда для проверки доступны несколько карт с разными ограничениями переброса, приложение автоматически расходует первый источник и не позволяет игроку выбрать другой.

## Среда

- Версия приложения / commit: PR #33, `bd4a937`.
- Платформа и версия ОС / браузера: Flutter MVP, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: проверка науки с дефибриллятором и научным стимулятором.

## Подготовка и шаги воспроизведения

1. Иметь в рюкзаке дефибриллятор и научный стимулятор.
2. Начать проверку науки.
3. Попытаться перебросить один кубик научным стимулятором.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** первым расходуется дефибриллятор, хотя игрок хотел использовать ограниченный переброс стимулятора.
- **Ожидаемый:** игрок выбирает источник, а reducer применяет лимит кубиков и расходует именно выбранную карту.
- **Основание ожидания:** поведение источников задано эффектами карт; существующая модель хранит отдельный список `rerollSources`, но выбор конкретного источника отсутствует. Отдельного правила о выборе в `docs/rules-spec.md` пока нет.

## Влияние

- Игрок теряет более гибкую карту даже при использовании допустимой способности другой карты.
- Масштаб / обходной путь: проверки с несколькими необязательными источниками переброса.

## Доказательства

Замечание последнего ревью PR #33: `discussion_r4238543110`.

## Границы проверки

- Подозреваемая область кода: `RerollChoice`, `_resolveReroll` и окно решения в `mvp_game_screen_part_5.dart`.
- Релевантные существующие тесты / спецификации: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`; `packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart`.
- Что пока неизвестно: отдельного нормативного раздела о выборе источника нет; лимиты берутся из поведения конкретных карт.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart` — `BUG084 player can choose the reroll source`.
- Команда запуска: `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart --plain-name 'BUG084 player can choose the reroll source'`.
- **До исправления (красный):** `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart --plain-name 'BUG084 player can choose the reroll source'` — завершился с кодом 1.
- Результат и причина падения: первоначальный widget assertion ожидал `reroll-source-selector`, но не нашёл ни одного; окно решения не позволяло выбрать источник.
- **После исправления (зелёный):** целевой widget-тест прошёл после выбора научного стимулятора: стимулятор израсходован, дефибриллятор остался доступен.
- Результат связанных проверок: `flutter test test/reported_gameplay_bugs_test.dart` — 38 тестов прошли; `dart test packages/besprotoritsa_rules/test` — 211 тестов прошли; `dart analyze` в rules, data и app — замечаний нет.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_1.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_4.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_6.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_7.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_5.dart`, `packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart`.
- Краткое описание исправления: игрок может выбрать отдельный источник переброса; reducer валидирует лимит кубиков выбранной карты и удаляет из списка именно её.
- Остаточные ограничения или связанные баги: нет.
