---
id: BUG-2026-085
title: В мультиплеере теряется выбранный источник переброса
status: fixed
severity: high
area: app
reported: 2026-10-11
---

# BUG-2026-085 — В мультиплеере теряется выбранный источник переброса

## Суть

При отправке сетевой команды переброса выбранный `sourceCardId` не попадает в JSON. Сервер поэтому использует первый источник из списка и может потратить другую карту, чем выбрал игрок.

## Среда

- Версия приложения / commit: PR #33, `87f12a6`.
- Платформа и версия ОС / браузера: мультиплеер, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: окно переброса с дефибриллятором и научным стимулятором; игрок выбирает стимулятор.

## Подготовка и шаги воспроизведения

1. Открыть мультиплеерную игру в состоянии проверки с доступными источниками `defibrillator` и `science-stimulant` именно в таком порядке.
2. Выбрать `science-stimulant` для переброса.
3. Дождаться подтверждения сервером.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** команда не сообщает выбранный источник, сервер расходует первый (`defibrillator`).
- **Ожидаемый:** сетевой протокол переносит `sourceCardId`, сервер сохраняет выбор и расходует `science-stimulant`, оставляя дефибриллятор.
- **Основание ожидания:** выбранный источник является частью `RerollChoice`; интерфейс и reducer уже поддерживают выбор и передают ID в команду. Замечание ревью PR #33 от 2026-10-10, review comment `4239261450`.

## Влияние

- Что пользователь не может сделать или какое состояние портится: в мультиплеере может быть потрачена не та карта, которую выбрал игрок.
- Масштаб / обходной путь: любой сетевой переброс при нескольких источниках; локальный режим не затронут.

## Доказательства

Замечание последнего ревью PR #33, comment ID `4239261450`.

## Границы проверки

- Подозреваемая область кода: `_choiceToJson` в `packages/besprotoritsa_app/lib/src/game/multiplayer_game_controller.dart` и `_choiceFromJson` в `packages/besprotoritsa_server/lib/src/room_manager.dart`.
- Релевантные существующие тесты / спецификации: `packages/besprotoritsa_app/test/multiplayer_flow_test.dart`; модель `RerollChoice` и существующие тесты выбора источника переброса. Это исправление переноса команды и не меняет правила игры.
- Что пока неизвестно: неизвестного, влияющего на ожидаемое поведение, нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_app/test/multiplayer_flow_test.dart` — `BUG085 multiplayer reroll preserves the selected source card`.
- Команда запуска: `cd packages/besprotoritsa_app && flutter test test/multiplayer_flow_test.dart --plain-name 'BUG085 multiplayer reroll preserves the selected source card'`.
- **До исправления (красный):** `cd packages/besprotoritsa_app && flutter test test/multiplayer_flow_test.dart --plain-name 'BUG085 multiplayer reroll preserves the selected source card'` — код завершения 1.
- Результат и причина падения: assertion `player.backpack contains 'defibrillator'` завершился ошибкой; фактический рюкзак — `['science-stimulant']`. Сервер получил переброс без выбранного ID и потратил первый источник `defibrillator`.
- **После исправления (зелёный):** та же команда — прошла, целевой тест зелёный.
- Результат связанных проверок: `cd packages/besprotoritsa_app && flutter test test/multiplayer_flow_test.dart` — 3 теста прошли; `dart test packages/besprotoritsa_server/test/server_room_test.dart` — 12 тестов прошли; `dart analyze packages/besprotoritsa_app packages/besprotoritsa_server` — замечаний нет.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_app/lib/src/game/multiplayer_game_controller.dart`, `packages/besprotoritsa_app/test/multiplayer_flow_test.dart`, `packages/besprotoritsa_server/lib/src/room_manager.dart`.
- Краткое описание исправления: клиент передаёт необязательный `sourceCardId` для переброса, а сервер декодирует его в `RerollChoice`, сохраняя совместимость с сообщениями старых клиентов без этого поля.
- Остаточные ограничения или связанные баги: нет известных.
