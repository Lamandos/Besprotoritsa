---
id: BUG-2026-074
title: Сброс робота сохраняет устаревшее истощение
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-074 — Сброс робота сохраняет устаревшее истощение

## Суть

При сбросе истощённого робота из экипировки карта уходит в сброс своей колоды,
но её ID остаётся в `PlayerState.exhaustedRobots` прежнего владельца.

## Среда

- Версия приложения / commit: PR #33, commit `f300bbb`.
- Платформа и версия ОС / браузера: rules-пакет, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: экипированный повёрнутый робот сбрасывается.

## Подготовка и шаги воспроизведения

1. Экипировать робота и активировать его способность, чтобы ID оказался в `exhaustedRobots`.
2. Сбросить этого робота командой `DiscardCardCommand`.
3. Проверить список `exhaustedRobots` бывшего владельца.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** ID сброшенного робота остаётся в `exhaustedRobots`.
- **Ожидаемый:** при удалении карты из владения игрока её маркер истощения удаляется вместе с ней.
- **Основание ожидания:** `docs/effects-vocabulary.md` описывает истощение и готовность как состояния робота; правила сброса удаляют карту из экипировки и отправляют её в сброс колоды. Маркер без принадлежащей игроку карты также может ошибочно переносить износ при повторном получении робота.

## Влияние

- Повторно полученный тем же игроком робот может остаться недоступным без Энергоблока; устаревший маркер также может быть принят за текущее состояние робота в сундуке.
- Масштаб / обходной путь: сброс истощённого робота и последующий возврат карты тому же игроку.

## Доказательства

Замечание последнего ревью PR #33: `discussion_r4238123772`.

## Границы проверки

- Подозреваемая область кода: `InventoryRules.discard` в `packages/besprotoritsa_rules/lib/src/inventory_changes_part.dart`.
- Релевантные существующие тесты / спецификации: `active_card_abilities_test.dart`, `docs/effects-vocabulary.md`, `docs/rules-spec.md`.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart` — `BUG074 discarding an exhausted robot clears its exhaustion`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG074' --reporter expanded`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG074' --reporter expanded`.
- Результат и причина падения: assertion очистки списка провалился: ожидался пустой `exhaustedRobots`, фактическое значение — `['h3-al']`; команда сброса и снятие робота с экипировки прошли.
- **После исправления (зелёный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG074' --reporter expanded` — прошёл; ID `h3-al` удалён из `exhaustedRobots`.
- Результат связанных проверок: полный `active_card_abilities_test.dart` прошёл; `dart test packages/besprotoritsa_rules --reporter expanded` из корня репозитория — 200 тестов прошли; анализ изменённых файлов rules-пакета — `No issues found!`.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/inventory_changes_part.dart`, `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`.
- Краткое описание исправления: любой успешный сброс карты удаляет совпадающий маркер истощения из состояния игрока.
- Остаточные ограничения или связанные баги: нет.
