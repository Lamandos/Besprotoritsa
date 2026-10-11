---
id: BUG-2026-083
title: Замена после награды растяжки теряет истощение робота
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-083 — Замена после награды растяжки теряет истощение робота

## Суть

Если растяжка убивает Беспокойного с истощённым роботом и у погибшего владельца уже выбрана замена, очередь замены сохраняет предмет, но теряет его состояние истощения.

## Среда

- Версия приложения / commit: PR #33, `bd4a937`.
- Платформа и версия ОС / браузера: rules-пакет, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: погибший владелец растяжки, выбранная замена, Беспокойный с истощённым роботом.

## Подготовка и шаги воспроизведения

1. У погибшего игрока есть выбранный герой из резерва в `queuedReplacements`.
2. В его клетке стоит растяжка; в эту клетку приходит Беспокойный с роботом в `exhaustedCarriedRobots`.
3. Растяжка убивает Беспокойного, затем начинается следующий ход и активируется замена.
4. Проверить `exhaustedRobots` у нового героя.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** робот переходит замене готовым.
- **Ожидаемый:** робот остаётся истощённым до восстановления энергоблоком или эффектом возвращения роботов в готовность.
- **Основание ожидания:** `docs/rules-spec.md`, разделы «Бой, урон и состояния» и «Смерть персонажа и Беспокойный»: использование робота истощает его до восстановления, а трофеи Беспокойного передаются победителю.

## Влияние

- Игрок может повторно использовать активную способность робота без восстановления.
- Масштаб / обходной путь: роботы, полученные наградой растяжки перед активацией замены.

## Доказательства

Замечание последнего ревью PR #33: `discussion_r4238543104`.

## Границы проверки

- Подозреваемая область кода: `ReserveHero`, `_storeTripwireOwnerReward`, `_activateQueuedReplacements` и JSON сохранения.
- Релевантные существующие тесты / спецификации: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`; `docs/rules-spec.md`, раздел о восстановлении и разделе «Смерть персонажа и Беспокойный».
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart` — `BUG083 tripwire replacement keeps exhausted Restless robot exhausted`; сохранение проверяется в `packages/besprotoritsa_data/test/save_roundtrip_test.dart` — `BUG083 saves exhaustion on a queued replacement robot`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG083' --reporter expanded`; `cd packages/besprotoritsa_data && dart test test/save_roundtrip_test.dart --name 'BUG083' --reporter expanded`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG083' --reporter expanded` — завершился с кодом 1.
- Результат и причина падения: assertion `exhaustedRobots contains 'r69-nic3'` провалился после активации замены; фактическое значение — `[]`.
- **После исправления (зелёный):** обе целевые команды завершились с `All tests passed!`.
- Результат связанных проверок: `dart test packages/besprotoritsa_rules/test` — 211 тестов прошли; `dart test packages/besprotoritsa_data/test` — 81 тест прошёл; `dart analyze` в rules, data и app — замечаний нет.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/game_state_part_2.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_6.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_8.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `packages/besprotoritsa_data/lib/src/save_json_models.dart`, `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`, `packages/besprotoritsa_data/test/save_roundtrip_test.dart`.
- Краткое описание исправления: маркер истощения хранится в `ReserveHero`, переносится при награде растяжки и активации замены, а также сохраняется в JSON.
- Остаточные ограничения или связанные баги: нет.
