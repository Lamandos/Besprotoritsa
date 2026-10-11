---
id: BUG-2026-044
title: Особые исходы событий обходят иммунитет PROT3-CT
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-044 — Особые исходы событий обходят иммунитет PROT3-CT

## Суть

Исходы `horde|keep` и `asteroid_alert` увеличивают урон напрямую и не учитывают
активный иммунитет персонажа к любому урону.

## Среда

- Версия приложения / commit: PR #33, commit `80e07b4`.
- Платформа и версия ОС / браузера: любой запуск rules-пакета.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: иммунитет PROT3-CT активен в том же раунде.

## Подготовка и шаги воспроизведения

1. Активировать PROT3-CT.
2. Разрешить выбор `horde|keep` либо событие с эффектом `asteroid_alert`.

Частота воспроизведения: всегда для этих ветвей.

## Результат

- **Фактический:** урон напрямую прибавляется персонажу с активным иммунитетом.
- **Ожидаемый:** владелец PROT3-CT не получает этот урон до конца раунда; остальные персонажи обрабатываются независимо.
- **Основание ожидания:** `docs/effects-vocabulary.md`, эффект `damage.ignoreAnyUntilRoundEnd`; раздел «Смерть персонажа и Беспокойный» в `docs/rules-spec.md` не меняет применение иммунитета.

## Влияние

- PROT3-CT не защищает от этих эффектов событий и может допустить ошибочную смерть персонажа.
- Масштаб / обходной путь: особые исходы «Орда» и «Метеоритный поток».

## Доказательства

Замечание ревью PR #33: `discussion_r4234766395`.

## Границы проверки

- Подозреваемая область кода: `horde|keep` в `commands_reducer_part_7.dart` и `asteroid_alert` в том же файле.
- Релевантные существующие тесты / спецификации: `mvp_round_loop_test.dart`; `docs/effects-vocabulary.md`.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart` — `BUG044 horde keep respects PROT3-CT damage immunity`; `BUG044 asteroid alert respects PROT3-CT damage immunity`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG044 custom event damage respects PROT3-CT immunity'`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG044'` — оба теста завершились assertion-провалом: «Орда» нанесла 4 урона, астероид — 5 вместо 0.
- Результат и причина падения: обе специальные ветви увеличивают урон напрямую и обходят `_ignoresAnyDamage`.
- **После исправления (зелёный):** `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG044'` — пройдены оба теста; владелец PROT3-CT получил 0 урона.
- Результат связанных проверок: `./tool/run_checks.sh` прошёл, включая анализ, проверку содержимого и все Dart-тесты.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_7.dart`; `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`.
- Краткое описание исправления: `horde|keep` и `asteroid_alert` пропускают урон персонажу с активным иммунитетом, сохраняя броски и остальные эффекты.
- Остаточные ограничения или связанные баги: нет.
