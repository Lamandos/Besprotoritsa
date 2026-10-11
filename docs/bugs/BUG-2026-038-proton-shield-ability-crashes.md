---
id: BUG-2026-038
title: Использование протонного щита падает после успешной проверки
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-038 — Использование протонного щита падает после успешной проверки

## Суть

Протонный щит проходит проверку доступности активной способности, но его
исполнение отсутствует в обработчике способностей и завершается исключением.

## Среда

- Версия приложения / commit: PR #33, commit `1fc7a92`.
- Платформа и версия ОС / браузера: любой запуск rules-пакета.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: активный персонаж держит протонный щит в рюкзаке.

## Подготовка и шаги воспроизведения

1. Иметь карту `proton-shield` в рюкзаке и неполное здоровье.
2. Выполнить `UseCardAbilityCommand('proton-shield')`.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** возникает `StateError('Validated unsupported card ability.')`.
- **Ожидаемый:** карта уходит в сброс, а персонаж получает иммунитет к урону до конца раунда.
- **Основание ожидания:** `docs/effects-vocabulary.md`, `damage.preventUntilRoundEnd` — «не получать урон до конца раунда»; также `proton-shield` уже признан известной способностью валидатором.

## Влияние

- Использование предмета прерывает обработку игры исключением.
- Масштаб / обходной путь: карта протонного щита.

## Доказательства

Замечание ревью PR #33: `discussion_r4234584777`.

## Границы проверки

- Подозреваемая область кода: `_validateCardAbility` и `_useCardAbility` в `commands_reducer_part_11.dart`.
- Релевантные существующие тесты / спецификации: `docs/effects-vocabulary.md`; `active_card_abilities_test.dart`.
- Что пока неизвестно: нет отдельного прогона теста на исходном поведении.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart` — `BUG038 proton shield activates without crashing and prevents damage`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart` — assertion `returnsNormally` провалился: выброшен `StateError: Validated unsupported card ability.`.
- Результат и причина падения: для `proton-shield` нет ветки выполнения после успешной валидации.
- **После исправления (зелёный):** тот же `dart test test/active_card_abilities_test.dart` — пройдено, 24 теста.
- Результат связанных проверок: `./tool/run_checks.sh` прошёл; `npm ci && npm test` в `packages/besprotoritsa_app/web` прошёл.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`; тест в `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`.
- Краткое описание исправления: щит уходит в сброс и устанавливает иммунитет до конца текущего раунда.
- Остаточные ограничения или связанные баги: нет.
