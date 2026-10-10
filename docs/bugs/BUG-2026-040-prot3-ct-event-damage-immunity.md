---
id: BUG-2026-040
title: Иммунитет PROT3-CT не блокирует урон от событий
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-040 — Иммунитет PROT3-CT не блокирует урон от событий

## Суть

После активации PROT3-CT события наносят владельцу прямой урон, обходя общее
состояние иммунитета, хотя оно хранится до конца раунда.

## Среда

- Версия приложения / commit: PR #33, commit `1fc7a92`.
- Платформа и версия ОС / браузера: любой запуск rules-пакета.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: владелец PROT3-CT активировал его в текущем раунде до разрешения эффекта события.

## Подготовка и шаги воспроизведения

1. Экипировать и активировать PROT3-CT.
2. Разрешить эффект события `damage`, `damage_all_players`, `damage_roll_die` или `damage_each_player_roll_die`, направленный на владельца.

Частота воспроизведения: всегда для прямых путей урона события.

## Результат

- **Фактический:** урон события напрямую увеличивает `damage` владельца.
- **Ожидаемый:** пока действует иммунитет, владелец не получает урон от событий; урон другим игрокам разрешается как обычно.
- **Основание ожидания:** `docs/effects-vocabulary.md`, PROT3-CT — `damage.ignoreAnyUntilRoundEnd` («игнорировать любой урон до конца раунда»).

## Влияние

- Способность робота не защищает от части урона и может привести к ошибочной смерти персонажа.
- Масштаб / обходной путь: все прямые эффекты урона событий.

## Доказательства

Замечание ревью PR #33: `discussion_r4234584789`.

## Границы проверки

- Подозреваемая область кода: обработчики `damage*` в `commands_reducer_part_7.dart`.
- Релевантные существующие тесты / спецификации: `docs/effects-vocabulary.md`; `mvp_round_loop_test.dart`.
- Что пока неизвестно: конкретное событие в пользовательской партии неизвестно.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart` — `BUG040 PROT3-CT blocks direct event damage to its owner`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG040 PROT3-CT blocks direct event damage to its owner'` — assertion провалился: ожидаемый урон владельца `0`, фактический `7`.
- Результат и причина падения: четыре прямых обработчика событий обходят иммунитет PROT3-CT.
- **После исправления (зелёный):** `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG040 PROT3-CT blocks direct event damage to its owner'` — пройдено; владелец получил 0 урона, второй персонаж получил 5.
- Результат связанных проверок: `./tool/run_checks.sh` прошёл; `npm ci && npm test` в `packages/besprotoritsa_app/web` прошёл.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_7.dart`; тест в `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`.
- Краткое описание исправления: прямые и бросковые эффекты урона событий пропускают персонажа с активным иммунитетом; броски при этом остаются детерминированными.
- Остаточные ограничения или связанные баги: нет.
