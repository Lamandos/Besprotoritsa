---
id: BUG-2026-056
title: GTU-B1c4 banks a hit before combat
status: fixed
severity: major
area: rules
reported: 2026-10-10
---

# BUG-2026-056 — GTU-B1c4 banks a hit before combat

## Суть

GTU-B1c4 can be activated outside combat and stores a bonus on the player for an
unspecified later attack. Repeated activations can stack guaranteed hits on that
future attack.

## Среда

- Версия приложения / commit: `7bf5e19236249cf236eca200dc5338d962e7f951` (PR #33)
- Платформа и версия ОС / браузера: не зависит от платформы
- Устройство или размер окна, если важно: не важно
- Режим игры / состав партии / seed, если важно: локальный rules state; seed не влияет

## Подготовка и шаги воспроизведения

1. Экипировать GTU-B1c4; рядом с героем нет противника.
2. Выполнить `UseCardAbilityCommand('gtu-b1c4')`.
3. Позже начать атаку.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** команда допустима и навсегда до следующей атаки увеличивает `nextAttackBonusHits`.
- **Ожидаемый:** робот можно повернуть в бою, чтобы добавить попадание текущей цели; до боя способность не должна накапливать попадание для будущей встречи.
- **Основание ожидания:** `content/i18n/ru.json`, описание `gtu-b1c4`: «Можете повернуть в бою, чтобы добавить 1 попадание врагу»; `docs/effects-vocabulary.md`, `combat.addHit`.

## Влияние

- Игрок может использовать и перезаряжать робота до встречи с врагом, а затем получить несколько гарантированных попаданий одной атакой.
- Это меняет исход боя и расход ресурсов робота.

## Доказательства

Замечание последнего ревью PR #33 от 2026-10-10: активация вне атаки копит попадание до будущей атаки и позволяет накапливать бонус. Ссылка: https://github.com/Lamandos/Besprotoritsa/pull/33.

## Границы проверки

- Подозреваемая область кода (если известна): `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `commands_reducer_part_4.dart`.
- Релевантные существующие тесты / спецификации: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`; текст GTU-B1c4 в `content/i18n/ru.json`; `docs/effects-vocabulary.md`.
- Что пока неизвестно: на какой стадии боевого окна интерфейс должен разрешать активацию. Ревью требует привязать попадание к текущему бою, а не к будущей атаке.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`, `BUG056 GTU-B1c4 bonus is scoped to an active combat`.
- Команда запуска: из `packages/besprotoritsa_rules`, `dart test test/active_card_abilities_test.dart --name 'BUG056|BUG057' --reporter expanded`.
- **До исправления (красный):** 2026-10-10, команда завершилась с кодом 1; упали три теста `BUG056`.
- Результат и причина падения: способность принималась без монстра (`Expected: not null; Actual: <null>`), бонус оставался в поле игрока после начала атаки (`Expected: <0>; Actual: <1>`), повторное применение после энергоблока принималось вместо отказа (`Expected: not null; Actual: <null>`).
- **После исправления (зелёный):** та же команда — 4 теста прошли.
- Результат связанных проверок: `./tool/run_checks.sh` — успешно, включая полный набор тестов и `dart analyze --fatal-infos .`.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `commands_reducer_part_4.dart`, `commands_reducer_part_5.dart`, `commands_reducer_part_7.dart`, `commands_reducer_part_9.dart`, `game_state_part_4.dart`, `packages/besprotoritsa_data/lib/src/save_json_helpers.dart`, `packages/besprotoritsa_rules/test/active_card_abilities_test.dart` и `packages/besprotoritsa_data/test/save_roundtrip_test.dart`.
- Краткое описание исправления: применение требует врага в секторе и не допускает второго неподтверждённого бонуса; подготовленное попадание переносится в контекст конкретной атаки и теряется при уходе или завершении хода.
- Остаточные ограничения или связанные баги: нет известных.
