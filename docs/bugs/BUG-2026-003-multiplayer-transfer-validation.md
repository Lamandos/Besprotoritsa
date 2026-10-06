---
id: BUG-2026-003
title: Multiplayer blocks chest and exchange transfers before server validation
status: fixed
severity: high
area: app
reported: 2026-10-03
---

# BUG-2026-003 — Multiplayer blocks inventory transfers locally

## Суть

The multiplayer projection omits card definitions. The shared inventory dialog validates transfer commands against that incomplete projection and disables confirmation even though the authoritative server can validate them.

## Среда

- Версия приложения / commit: PR #27, review on `1b595953cea17140a49d9b517fcdbd587d0bc49b`
- Платформа и версия ОС / браузера: multiplayer client
- Устройство или размер окна, если важно: любое
- Режим игры / состав партии / seed, если важно: сетевая игра; игрок у сундука или рядом с партнёром для обмена

## Подготовка и шаги воспроизведения

1. Подключиться к сетевой партии и открыть инвентарь у сундука либо рядом с игроком.
2. Выбрать карту для передачи.
3. Проверить кнопку подтверждения.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** кнопка подтверждения остаётся выключенной, так как локальная проверка не находит определения карт в проекции.
- **Ожидаемый:** клиент отправляет выбор серверу; сервер проверяет его по полной authoritative state.
- **Основание ожидания:** контракт сетевого контроллера и комментарий review PR #27; проекция предназначена для UI и не редуцирует команды на клиенте.

## Влияние

- Что пользователь не может сделать или какое состояние портится: игрок не может класть/брать карты из сундука или обмениваться картами в сети.
- Масштаб / обходной путь: все multiplayer-передачи затронуты; обходного пути в UI нет.

## Доказательства

Последний review PR #27: `validate(state, command)` получает состояние из `ProjectedGameStateCodec`, где нет `cardDefinitions`.

## Границы проверки

- Подозреваемая область кода: `mvp_game_screen_part_4.dart`, `GameSessionController`.
- Релевантные существующие тесты / спецификации: `multiplayer_flow_test.dart`; `docs/rules-spec.md` §§ обмен и сундук.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_app/test/multiplayer_transfer_validation_widget_test.dart`, тесты передачи через сундук и обмена.
- Команда запуска: `cd packages/besprotoritsa_app && flutter test test/multiplayer_transfer_validation_widget_test.dart`
- **До исправления (красный):** та же команда на родительской ревизии `1b59595` (`f23ae80^`) в отдельном временном worktree.
- Результат и причина падения: оба assertion завершились `Expected: not null; Actual: null` — кнопки подтверждения были отключены локальной проверкой неполной проекции.
- **После исправления (зелёный):** та же команда на текущей ревизии — 2 теста прошли.
- Результат связанных проверок: `./tool/run_checks.sh` — завершился с кодом 0; formatter, analyzer, content validation и все rule/app tests прошли.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_app/lib/src/game/game_controller.dart`, `multiplayer_game_controller.dart`, `mvp_game_screen_part_4.dart`, `test/multiplayer_flow_test.dart`, `test/multiplayer_transfer_validation_widget_test.dart`.
- Краткое описание исправления: UI сохраняет локальную проверку в одиночной игре и отдаёт команду на серверную проверку в multiplayer.
- Остаточные ограничения или связанные баги: сервер остаётся единственным источником принятия multiplayer-команды.
