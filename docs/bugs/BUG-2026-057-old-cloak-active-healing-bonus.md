---
id: BUG-2026-057
title: Active healing ignores Old Cloak bonus
status: fixed
severity: normal
area: rules
reported: 2026-10-10
---

# BUG-2026-057 — Active healing ignores Old Cloak bonus

## Суть

Healing card abilities restore only their printed amount even when the hero has
Old Cloak equipped, so its healing bonus is omitted on this path.

## Среда

- Версия приложения / commit: `7bf5e19236249cf236eca200dc5338d962e7f951` (PR #33)
- Платформа и версия ОС / браузера: не зависит от платформы
- Устройство или размер окна, если важно: не важно
- Режим игры / состав партии / seed, если важно: локальный rules state; seed не влияет

## Подготовка и шаги воспроизведения

1. Экипировать Old Cloak и получить урон.
2. Использовать лечебную карту способностью, например `dry-rations` или `medkit`.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** урон уменьшается только на номинальное значение лечения.
- **Ожидаемый:** лечение восстанавливает на 1 здоровье больше, пока Old Cloak экипирован; итоговое здоровье не может превышать максимум.
- **Основание ожидания:** `content/i18n/ru.json`, описание `old-cloak`: «Любое лечение эффективнее на 1 ед. здоровья»; `docs/effects-vocabulary.md`, `health.healingBonus`.

## Влияние

- Герой восстанавливает меньше здоровья, чем разрешает экипированный предмет; это может повлиять на выживание и исход боя.
- Масштаб: активные лечебные способности расходников; связанные способности медика и робота также нужно покрыть общей логикой лечения.

## Доказательства

Замечание последнего ревью PR #33 от 2026-10-10: consumables subtract only their raw healing amount, ignoring Old Cloak. Ссылка: https://github.com/Lamandos/Besprotoritsa/pull/33.

## Границы проверки

- Подозреваемая область кода (если известна): `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`.
- Релевантные существующие тесты / спецификации: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`; `docs/effects-vocabulary.md`; текст Old Cloak в `content/i18n/ru.json`.
- Что пока неизвестно: неизвестно.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`, `BUG057 Old Cloak increases active healing`.
- Команда запуска: из `packages/besprotoritsa_rules`, `dart test test/active_card_abilities_test.dart --name 'BUG056|BUG057' --reporter expanded`.
- **До исправления (красный):** 2026-10-10, команда завершилась с кодом 1; `BUG057` упал на assertion.
- Результат и причина падения: `Expected: <0>; Actual: <1>` после лечения сухим пайком; активное лечение не учитывало Old Cloak. В том же тесте сценарии аптечки и H3-AL также проверяют недостающий бонус.
- **После исправления (зелёный):** та же команда — 4 теста прошли; сценарии покрывают сухой паёк, саквояж медика и H3-AL.
- Результат связанных проверок: `./tool/run_checks.sh` — успешно, включая полный набор тестов и `dart analyze --fatal-infos .`.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `commands_reducer_part_5.dart`, `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`.
- Краткое описание исправления: лечебные способности и `HealCommand` теперь добавляют бонус `health.healingBonus` цели к лечению с ограничением по оставшемуся урону.
- Остаточные ограничения или связанные баги: нет известных.
