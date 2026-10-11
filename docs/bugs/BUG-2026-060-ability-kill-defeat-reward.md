---
id: BUG-2026-060
title: Убийства способностями пропускают награду монстра
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-060 — Убийства способностями пропускают награду монстра

## Суть

Убийства Газовым баллоном и Растяжкой удаляют монстра, не выдавая награду,
указанную в `defeatRewardDeckId`. Обычный бой применяет это поле.

## Среда

- Версия приложения / commit: PR #33, commit `5839da3`.
- Платформа и версия ОС / браузера: rules package.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: монстр с `defeatRewardDeckId`; убийство Газовым баллоном или Растяжкой.

## Подготовка и шаги воспроизведения

1. Создать монстра с `defeatRewardDeckId: "supplies"` и карту в соответствующей колоде.
2. Убить монстра Газовым баллоном либо появлением на растяжке.
3. Проверить инвентарь убийцы и колоду наград.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** монстр удаляется, награда не берётся из колоды.
- **Ожидаемый:** карта награды выдаётся игроку, которому засчитывается убийство.
- **Основание ожидания:** поле `defeatRewardDeckId` применяется в `_resolveAttackRoll`; событие `hatch-scrape` задаёт дополнительную карту предмета после победы в `content/events.json` и `content/i18n/ru.json`.

## Влияние

- Игрок теряет предмет, обещанный сценарием события.
- Масштаб / обходной путь: оба пути убийства способностью пропускают награду.

## Доказательства

Замечание последнего ревью PR #33: `discussion_r4237282734`.

## Границы проверки

- Подозреваемая область кода: ветка `gas-cylinder` и `_triggerTripwire` в `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`.
- Релевантные существующие тесты / спецификации: обработка `defeatRewardDeckId` в `_resolveAttackRoll`; событие `hatch-scrape`.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart` — BUG060 для Газового баллона и Растяжки.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG060'`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG060|BUG061' --reporter expanded` — завершился провалом assertion в обоих тестах BUG060.
- Результат и причина падения: Газовый баллон и Растяжка удалили монстра, но ожиданный `medkit` отсутствовал в рюкзаке (`Expected: contains 'medkit'; Actual: []`).
- **После исправления (зелёный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG060|BUG061' --reporter expanded` — все три теста прошли; Газовый баллон и Растяжка выдали награду и опустошили колоду.
- Результат связанных проверок: `./tool/run_checks.sh` прошёл полностью, включая анализатор, валидацию, все rules/data/server и app/scenario тесты.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_4.dart`; `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`; `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`.
- Краткое описание исправления: извлечена общая детерминированная обработка награды из `defeatRewardDeckId`; её вызывают атака, Газовый баллон и Растяжка.
- Остаточные ограничения или связанные баги: нет.
