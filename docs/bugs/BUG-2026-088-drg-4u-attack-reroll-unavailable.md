---
id: BUG-2026-088
title: DRG-4U не даёт перебросить кубики атаки
status: fixed
severity: high
area: rules
reported: 2026-10-11
---

# BUG-2026-088 — DRG-4U не даёт перебросить кубики атаки

## Суть

Готовый экипированный DRG-4U даёт переброс всех кубиков проверки силы, но не
попадает в список источников переброса атаки, хотя описание карты распространяет
способность и на атаку.

## Среда

- Версия приложения / commit: PR #33, `3e2a336`.
- Платформа и версия ОС / браузера: пакет правил, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: атака монстра экипированным,
  неистощённым DRG-4U.

## Подготовка и шаги воспроизведения

1. Экипировать готовый DRG-4U.
2. Атаковать монстра.
3. Проверить доступные источники переброса.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** DRG-4U отсутствует среди источников переброса атаки и не
  истощается для этой способности.
- **Ожидаемый:** DRG-4U доступен как источник переброса всех кубиков атаки;
  использование источника истощает робота.
- **Основание ожидания:** описание `drg-4u` в `content/i18n/ru.json` разрешает
  истощить робота и перебросить все кубики «при проверке Силы или атаке»;
  `content/special_items.json` задаёт behavior ID `dice.reroll.all`.

## Влияние

- Что пользователь не может сделать или какое состояние портится: способность
  DRG-4U нельзя применить к атаке.
- Масштаб / обходной путь: атаки с экипированным DRG-4U; обходного пути нет.

## Доказательства

Замечание последнего ревью PR #33:
https://github.com/Lamandos/Besprotoritsa/pull/33#discussion_r4239367781.

## Границы проверки

- Подозреваемая область кода: `_attackRerollSources` в
  `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`.
- Релевантные существующие тесты / спецификации: тесты атак и перебросов в
  `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`;
  `content/special_items.json`; `content/i18n/ru.json`.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`
  — `BUG088 DRG-4U can reroll all attack dice`.
- Команда запуска: `dart test packages/besprotoritsa_rules/test/active_card_abilities_test.dart --name 'BUG088 DRG-4U can reroll all attack dice' --reporter expanded`.
- **До исправления (красный):** `dart test packages/besprotoritsa_rules/test/active_card_abilities_test.dart --name 'BUG088 DRG-4U can reroll all attack dice' --reporter expanded` — exit 1.
- Результат и причина падения: assertion ожидал `AwaitingRerollChoice`, фактический `pendingDecision` — `null`; источник переброса атаки отсутствует.
- **После исправления (зелёный):** та же целевая команда — exit 0, тест пройден; DRG-4U показан источником переброса всех кубиков и истощён после использования.
- Результат связанных проверок: `dart test packages/besprotoritsa_rules/test --reporter expanded` — все 216 тестов прошли; `dart test packages/besprotoritsa_data/test --reporter expanded` — все 81 тест прошёл; `dart analyze packages/besprotoritsa_rules packages/besprotoritsa_data` — замечаний нет.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`.
- Краткое описание исправления: `dice.reroll.all` добавлен в источники переброса всех кубиков атаки; имеющаяся обработка выбранного источника истощает экипированный робот.
- Остаточные ограничения или связанные баги: нет известных.
