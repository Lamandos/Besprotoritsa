---
id: BUG-2026-061
title: PROT3-CT не блокирует урон владельцу от оружия
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-061 — PROT3-CT не блокирует урон владельцу от оружия

## Суть

PROT3-CT обещает игнорировать любой урон до конца раунда, но `_resolveAttackRoll`
безусловно добавляет владельцу самоурон пневмопушки.

## Среда

- Версия приложения / commit: PR #33, commit `5839da3`.
- Платформа и версия ОС / браузера: rules package.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: PROT3-CT активирован в текущем раунде; атака пневмопушкой на шестёрке.

## Подготовка и шаги воспроизведения

1. Экипировать PROT3-CT и пневмопушку.
2. Повернуть PROT3-CT.
3. Атаковать и выбросить шестёрку.

Частота воспроизведения: всегда при выпадении шестёрки.

## Результат

- **Фактический:** владелец получает самоурон от оружия.
- **Ожидаемый:** активный PROT3-CT отменяет этот урон до конца раунда.
- **Основание ожидания:** текст PROT3-CT в `content/i18n/ru.json`: «игнорировать любой урон до конца раунда»; поведение `damage.ignoreAnyUntilRoundEnd`.

## Влияние

- Защищённый персонаж может получить урон или погибнуть от собственного оружия.
- Масштаб / обходной путь: любой боевой бросок с эффектом урона владельцу.

## Доказательства

Замечание последнего ревью PR #33: `discussion_r4237282737`.

## Границы проверки

- Подозреваемая область кода: применение `roll.ownerDamage` в `_resolveAttackRoll` (`commands_reducer_part_4.dart`).
- Релевантные существующие тесты / спецификации: `packages/besprotoritsa_rules/test/effects_engine_test.dart`; текст и поведение PROT3-CT.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart` — `BUG061 PROT3-CT prevents pneumatic gun self-damage`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG061'`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG060|BUG061' --reporter expanded` — завершился провалом assertion.
- Результат и причина падения: после активации PROT3-CT атака пневмопушкой дала `damage == 1`, тест ожидал 0.
- **После исправления (зелёный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG060|BUG061' --reporter expanded` — все три теста прошли; урон владельцу от пневмопушки равен 0.
- Результат связанных проверок: `./tool/run_checks.sh` прошёл полностью, включая анализатор, валидацию, все rules/data/server и app/scenario тесты.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_4.dart`; `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`.
- Краткое описание исправления: `_resolveAttackRoll` отменяет самоурон броска, если для игрока действует защита от любого урона в текущем раунде.
- Остаточные ограничения или связанные баги: нет.
