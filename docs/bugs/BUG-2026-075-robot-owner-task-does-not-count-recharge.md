---
id: BUG-2026-075
title: Личное задание Robot Owner не считает восстановление робота
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-075 — Личное задание Robot Owner не считает восстановление робота

## Суть

Наблюдатель личных заданий не создаёт событие `robot_reloaded`, когда Энергоблок
снимает истощение с робота. Поэтому задание Robot Owner не получает прогресс и
не может выдать награду.

## Среда

- Версия приложения / commit: PR #33, commit `f300bbb`.
- Платформа и версия ОС / браузера: rules-пакет, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: игрок с заданием Robot Owner использует Энергоблок для готового к перезарядке робота.

## Подготовка и шаги воспроизведения

1. Назначить игроку личное задание с метрикой `robot_reloaded` и целью 2.
2. Использовать способность робота, чтобы повернуть его.
3. Сбросить Энергоблок, чтобы вернуть робота в готовность.
4. Повторить цикл и проверить прогресс, статус задания и награду.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** готовность робота меняется, но счётчик личного задания остаётся прежним.
- **Ожидаемый:** восстановление истощённого робота продвигает метрику `robot_reloaded`; после двух восстановлений задание завершается и выдаёт награду.
- **Основание ожидания:** `content/tasks.json` задаёт Robot Owner как цель `robot_reloaded` со значением 2 и наградой 5 кредитов; `content/i18n/en.json` описывает его как использование и перезарядку робота дважды. `docs/rules-spec.md` задаёт поворот робота при активации и восстановление Энергоблоком.

## Влияние

- Игрок не может выполнить назначенное личное задание или получить его 5-кредитную награду.
- Масштаб / обходной путь: все партии с заданием Robot Owner.

## Доказательства

Замечание последнего ревью PR #33: `discussion_r4238123778`.

## Границы проверки

- Подозреваемая область кода: `_personalTaskObservation` в `packages/besprotoritsa_rules/lib/src/commands_reducer_part_10.dart`.
- Релевантные существующие тесты / спецификации: `mvp_round_loop_test.dart`, `content/tasks.json`, `docs/rules-spec.md`, `docs/effects-vocabulary.md`.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart` — `BUG075 recharging a robot advances the Robot Owner task`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG075' --reporter expanded`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG075' --reporter expanded`.
- Результат и причина падения: после двух успешных циклов поворота и восстановления тест ожидал `QuestStatus.completed`, но получил `QuestStatus.active`; задание не засчитало перезарядки.
- **После исправления (зелёный):** `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG075' --reporter expanded` — прошёл; два восстановления завершили задание и выдали 5 кредитов.
- Результат связанных проверок: полный `mvp_round_loop_test.dart` прошёл; `dart test packages/besprotoritsa_rules --reporter expanded` из корня репозитория — 200 тестов прошли; анализ изменённых файлов rules-пакета — `No issues found!`.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_10.dart`, `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`.
- Краткое описание исправления: наблюдатель считает переход истощённого робота в готовность только если игрок по-прежнему владеет этим роботом; задание Robot Owner получает прогресс и награду.
- Остаточные ограничения или связанные баги: нет.
