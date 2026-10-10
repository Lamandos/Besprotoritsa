---
id: BUG-2026-050
title: Переброс любого количества кубиков автоматически перебрасывает все
status: fixed
severity: normal
area: app
reported: 2026-10-10
---

# BUG-2026-050 — Переброс любого количества кубиков автоматически перебрасывает все

## Суть

При проверке с дефибриллятором интерфейс предлагает только общий переброс, который
меняет все выпавшие кубики. Игрок не может выбрать любое количество кубиков, как
написано на карте.

## Среда

- Версия приложения / commit: PR #33, commit `92feacd`.
- Платформа и версия ОС / браузера: Flutter app; точная платформа неизвестна.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: проверка навыка с дефибриллятором в рюкзаке.

## Подготовка и шаги воспроизведения

1. Добавить дефибриллятор в рюкзак.
2. Начать проверку навыка, бросив несколько кубиков.
3. Выбрать переброс.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** нажатие «Перебросить» перебрасывает сразу все кубики.
- **Ожидаемый:** игрок выбирает любое подмножество кубиков для переброса.
- **Основание ожидания:** `content/i18n/ru.json` описывает дефибриллятор как переброс «любого количества кубиков»; тот же эффект записан как `dice.reroll.anyCountPerAttack` в `docs/effects-vocabulary.md`.

## Влияние

- Игрок не может сохранить нужные результаты и перебросить только выбранные кубики.
- Масштаб / обходной путь: отсутствует.

## Доказательства

Новое замечание ревью PR #33: `discussion_r4235287443`.

## Границы проверки

- Подозреваемая область кода: `_decisionActions` в `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_5.dart`.
- Релевантные существующие тесты / спецификации: `docs/effects-vocabulary.md`; текст дефибриллятора в `content/i18n/ru.json`; `RerollChoice.diceIndexes`.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart` — `BUG050 defibrillator lets the player select dice for a reroll`.
- Команда запуска: `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart --plain-name 'BUG050 defibrillator lets the player select dice for a reroll'`.
- **До исправления (красный):** `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart --plain-name 'BUG050 defibrillator lets the player select dice for a reroll'` — завершился провалом assertion.
- Результат и причина падения: после нажатия «Перебросить» ожидался диалог `Выберите кубики для переброса`, но найдено 0 виджетов; текущее действие сразу применяет переброс всех кубиков.
- **После исправления (зелёный):** `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart --plain-name 'BUG050 defibrillator lets the player select dice for a reroll'` — тест прошёл; переброшен только выбранный кубик, остальные значения сохранились.
- Результат связанных проверок: `./tool/run_checks.sh` — успешно; форматирование, анализатор, schema/content validation, тесты rules/data/server/app и сценарии победы/поражения/сохранения прошли.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_5.dart`; `packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart`.
- Краткое описание исправления: для карт с эффектом `dice.reroll.anyCountPerAttack` действие открывает выбор кубиков и отправляет явные индексы; другие эффекты переброса сохраняют прежнее поведение.
- Остаточные ограничения или связанные баги: нет.
