---
id: BUG-2026-036
title: В сетевой игре кнопки активных карт блокирует локальная проверка
status: fixed
severity: high
area: app
reported: 2026-10-10
---

# BUG-2026-036 — В сетевой игре кнопки активных карт блокирует локальная проверка

## Суть

В сетевой игре проекция состояния не содержит определения карт, но кнопка
использования способности всё равно проверяет команду локальным rules-движком.
Проверка отклоняет доступные способности до отправки команды авторитетному серверу.

## Среда

- Версия приложения / commit: PR #33, commit `1fc7a92`.
- Платформа и версия ОС / браузера: сетевая игра; точная платформа неизвестна.
- Устройство или размер окна, если важно: неизвестно.
- Режим игры / состав партии / seed, если важно: multiplayer; игрок имеет карту с активной способностью.

## Подготовка и шаги воспроизведения

1. Подключиться к сетевой партии, где сервер прислал проекцию без `cardDefinitions`.
2. Открыть инвентарь и выбрать карту с активной способностью.
3. Нажать «Использовать».

Частота воспроизведения: всегда при отсутствующем локальном определении карты.

## Результат

- **Фактический:** локальный `validate` отклоняет команду с сообщением о недоступной карте; команда не уходит на сервер.
- **Ожидаемый:** multiplayer-клиент отправляет допустимую по серверному состоянию команду серверу, не блокируя её локальной проверкой неполной проекции.
- **Основание ожидания:** контракт `MultiplayerGameController.validatesCommandsLocally == false` и серверная авторитетность сетевых команд.

## Влияние

- Игрок не может использовать активные способности карт в сетевой партии.
- Масштаб / обходной путь: затрагивает любые способности, локальная проверка которых требует определения карты.

## Доказательства

Замечание ревью PR #33: `discussion_r4234584760`.

## Границы проверки

- Подозреваемая область кода: `mvp_game_screen_part_4.dart`, `_InventoryActionButton`.
- Релевантные существующие тесты / спецификации: multiplayer transfer widget tests; `MultiplayerGameController.validatesCommandsLocally`.
- Что пока неизвестно: нет отдельного прогона теста на исходном поведении.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_app/test/multiplayer_transfer_validation_widget_test.dart` — `BUG036 authoritative multiplayer can submit a card ability from a partial projection`.
- Команда запуска: `cd packages/besprotoritsa_app && flutter test test/multiplayer_transfer_validation_widget_test.dart`.
- **До исправления (красный):** `cd packages/besprotoritsa_app && flutter test test/multiplayer_transfer_validation_widget_test.dart test/projected_game_state_codec_test.dart` — assertion провалился: у кнопки «Использовать» `onPressed` оказался `null`.
- Результат и причина падения: локальная валидация отключила доступную команду в проекции без определений карт.
- **После исправления (зелёный):** тот же `flutter test test/multiplayer_transfer_validation_widget_test.dart test/projected_game_state_codec_test.dart` — пройдено, 5 тестов.
- Результат связанных проверок: `./tool/run_checks.sh` прошёл; `npm ci && npm test` в `packages/besprotoritsa_app/web` прошёл.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_4.dart`; тест в `packages/besprotoritsa_app/test/multiplayer_transfer_validation_widget_test.dart`.
- Краткое описание исправления: сетевой контроллер пропускает локальную проверку UI-команды и отправляет её на авторитетную серверную валидацию.
- Остаточные ограничения или связанные баги: нет.
