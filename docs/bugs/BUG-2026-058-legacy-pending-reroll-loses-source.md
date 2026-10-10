---
id: BUG-2026-058
title: Legacy pending reroll loses its source
status: fixed
severity: major
area: data
reported: 2026-10-10
---

# BUG-2026-058 — Legacy pending reroll loses its source

## Суть

Loading a legacy save with an unfinished robot reroll preserves the reroll count
but defaults its source list to empty. Resolving the saved reroll then fails to
exhaust the robot, allowing a once-per-readiness ability to be used again.

## Среда

- Версия приложения / commit: `7bf5e19236249cf236eca200dc5338d962e7f951` (PR #33)
- Платформа и версия ОС / браузера: не зависит от платформы
- Устройство или размер окна, если важно: не важно
- Режим игры / состав партии / seed, если важно: сохранение на этапе выбора переброса для робота, дающего переброс указанного навыка

## Подготовка и шаги воспроизведения

1. Создать сохранение на этапе `AwaitingRerollChoice` с экипированным готовым SC13-NC3, проверкой науки и `available_rerolls: 1`.
2. Удалить отсутствующее в старом формате поле `reroll_sources` и загрузить сохранение.
3. Разрешить переброс.

Частота воспроизведения: всегда для такого сохранения.

## Результат

- **Фактический:** переброс выполняется, но SC13-NC3 остаётся готовым.
- **Ожидаемый:** миграция восстанавливает доступный источник переброса, и разрешение выбора поворачивает робот.
- **Основание ожидания:** сохранение должно продолжать незавершённое действие, включая расход его источника; `docs/effects-vocabulary.md`, `dice.reroll.allForSkill` описывает поворот SC13-NC3 при проверке науки или ремонта.

## Влияние

- После загрузки игрок может повторно использовать робот без его перезарядки, нарушая сохранённое состояние готовности.
- Масштаб: старые сохранения, сделанные во время выбора переброса.

## Доказательства

Замечание последнего ревью PR #33 от 2026-10-10: старый документ содержит `available_rerolls`, но не содержит `reroll_sources`, поэтому источник расхода теряется. Ссылка: https://github.com/Lamandos/Besprotoritsa/pull/33.

## Границы проверки

- Подозреваемая область кода (если известна): `packages/besprotoritsa_data/lib/src/save_json_models.dart`; разрешение переброса в `packages/besprotoritsa_rules/lib/src/commands_reducer_part_6.dart`.
- Релевантные существующие тесты / спецификации: `packages/besprotoritsa_data/test/save_roundtrip_test.dart`; тесты перебросов `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`; `docs/effects-vocabulary.md`.
- Что пока неизвестно: как однозначно восстановить источник, если старое сохранение содержит несколько допустимых источников одного переброса. Для теста используется единственный готовый источник.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_data/test/save_roundtrip_test.dart`, `BUG058 restores a legacy pending robot reroll source`.
- Команда запуска: из `packages/besprotoritsa_data`, `dart test test/save_roundtrip_test.dart --name 'BUG058' --reporter expanded`.
- **До исправления (красный):** 2026-10-10, команда завершилась с кодом 1; `BUG058` упал на assertion.
- Результат и причина падения: `Expected: ['sc13-nc3']; Actual: []` при загрузке legacy-сохранения без `reroll_sources`.
- **После исправления (зелёный):** из `packages/besprotoritsa_data`, `dart test test/save_roundtrip_test.dart --reporter expanded` — 9 тестов прошли; регрессия подтверждает, что восстановленный SC13-NC3 поворачивается после разрешения переброса.
- Результат связанных проверок: `./tool/run_checks.sh` — успешно, включая тесты правил, данных, сервера и приложения и `dart analyze --fatal-infos .`.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_data/lib/src/game_state_json_codec.dart`, `packages/besprotoritsa_data/test/save_roundtrip_test.dart`.
- Краткое описание исправления: при отсутствии старого поля кодек выводит совместимые источники из активного броска и состояния игрока; список восстанавливается только при совпадении с сохранённым числом перебросов.
- Остаточные ограничения или связанные баги: при неоднозначном несовпадении число сохраняется, но кодек не выбирает источник наугад.
