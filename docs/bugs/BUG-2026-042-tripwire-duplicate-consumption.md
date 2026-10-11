---
id: BUG-2026-042
title: Растяжка удаляет все копии карты из рюкзака
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-042 — Растяжка удаляет все копии карты из рюкзака

## Суть

При установке одной растяжки из рюкзака удаляются все карты с ID `tripwire`,
хотя ловушка создаётся только одна.

## Среда

- Версия приложения / commit: PR #33, commit `80e07b4`.
- Платформа и версия ОС / браузера: любой запуск rules-пакета.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: у персонажа две карты `tripwire`.

## Подготовка и шаги воспроизведения

1. Положить в рюкзак две физические копии `tripwire`.
2. Выполнить `UseCardAbilityCommand('tripwire')`.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** из рюкзака исчезают обе копии, создаётся одна ловушка.
- **Ожидаемый:** изымается ровно одна копия карты, вторая остаётся в рюкзаке.
- **Основание ожидания:** команда использует одну карту; это соответствует операции удаления одной копии при обмене и других действиях инвентаря.

## Влияние

- Теряется принадлежащая игроку карта без её использования.
- Масштаб / обходной путь: персонаж может потерять все одинаковые растяжки при установке одной.

## Доказательства

Замечание ревью PR #33: `discussion_r4234766378`.

## Границы проверки

- Подозреваемая область кода: обработчик `tripwire` в `commands_reducer_part_11.dart`.
- Релевантные существующие тесты / спецификации: `active_card_abilities_test.dart`; функция `_removeOne`.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart` — `BUG042 placing one tripwire consumes only one duplicate`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG042 placing one tripwire consumes only one duplicate'`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG042'` — assertion провалился: ожидался остаток `['tripwire']`, фактический рюкзак был пуст.
- Результат и причина падения: одна установка удаляет все одинаковые карты из рюкзака.
- **После исправления (зелёный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG042'` — пройдено.
- Результат связанных проверок: `./tool/run_checks.sh` прошёл, включая анализ, проверку содержимого и все Dart-тесты.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`; `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`.
- Краткое описание исправления: установка удаляет ровно одну копию `tripwire` из рюкзака.
- Остаточные ограничения или связанные баги: нет.
