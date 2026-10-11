---
id: BUG-2026-092
title: Награда личной задачи теряется у ожидающей замены после убийства растяжкой
status: fixed
severity: high
area: rules
reported: 2026-10-11
---

# BUG-2026-092 — Награда личной задачи теряется у ожидающей замены после убийства растяжкой

## Суть

Если погибший владелец растяжки уже выбрал героя из резерва, а убийство монстра
растяжкой завершает его личную задачу, награда в кредитах добавляется погибшему
`PlayerState`, но не в уже поставленного в очередь героя. При следующей активации
замены награда теряется.

## Среда

- Версия приложения / commit: PR #33, commit `1967a049eed9eee5b453d0618835b0db4438f9ca`.
- Платформа и версия ОС / браузера: rules-пакет, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: погибший владелец ловушки, выбранная замена, личная задача `hunter` с прогрессом 1 из 2 в текущем ходу.

## Подготовка и шаги воспроизведения

1. Игрок погибает и выбирает героя из резерва; замена находится в `queuedReplacements`.
2. У погибшего остаётся растяжка с монстром в её клетке.
3. Личная задача `hunter` имеет прогресс 1 из 2 за текущий ход.
4. Растяжка убивает монстра и завершает задачу; затем начинается активация замены.
5. Проверить кредиты активированного героя.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** `hunter` завершается, но 5 кредитов остаются на погибшем игроке и пропадают при активации замены.
- **Ожидаемый:** награда за завершённую личную задачу сохраняется в состоянии героя, уже выбранного на замену.
- **Основание ожидания:** `content/tasks.json` задаёт награду `hunter` в 5 кредитов; `docs/rules-spec.md`, раздел «Подготовка партии», говорит, что личные задачи принадлежат игровому игроку и не передаются/не обмениваются. Движок завершает задачу и выдаёт награду игровому `PlayerId`; очередь замены — состояние того же слота игрока.

## Влияние

- Игрок теряет награду за выполненную личную задачу, хотя задача становится завершённой.
- Масштаб / обходной путь: награда теряется, если выполнение личной задачи через растяжку происходит после выбора замены, но до её активации.

## Доказательства

Замечание последнего ревью PR #33: `discussion_r4241435595`.

## Границы проверки

- Подозреваемая область кода: `_triggerTripwire` в `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart` и `_recordPersonalTaskEvent` в `commands_reducer_part_10.dart`.
- Релевантные существующие тесты / спецификации: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`; `content/tasks.json`; `docs/rules-spec.md`, раздел «Подготовка партии».
- Что пока неизвестно: не выявлено.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart` — `BUG092 tripwire task reward survives queued replacement`.
- Команда запуска: `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG092 tripwire task reward survives queued replacement' --reporter expanded`.
- **До исправления (красный):** `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG092 tripwire task reward survives queued replacement' --reporter expanded` — assertion провалился: `Expected: <8>; Actual: <3>`.
- Результат и причина падения: задача завершилась, но активированный герой сохранил только исходные 3 кредита резерва; 5 кредитов награды остались на погибшем `PlayerState` и потерялись.
- **После исправления (зелёный):** `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG092 tripwire task reward survives queued replacement' --reporter expanded` — `All tests passed!`; у замены после активации 8 кредитов: исходные 3 и награда 5.
- Результат связанных проверок: `dart test packages/besprotoritsa_rules/test --reporter expanded` — 219 тестов прошли; `dart analyze packages/besprotoritsa_rules` — замечаний нет; `git diff --check` — без ошибок.

## Исправление

- Изменённые файлы: `docs/bugs/BUG-2026-092-tripwire-task-reward-lost-after-replacement.md`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_10.dart`, `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`.
- Краткое описание исправления: при завершении личной задачи с кредитной наградой reducer также начисляет её уже выбранному герою из очереди замен.
- Остаточные ограничения или связанные баги: нет.
