---
id: BUG-2026-132
title: Из трёх коридоров удаётся открыть только один
status: fixed
severity: normal
area: app
reported: 2026-10-25
---

# BUG-2026-132 — Из трёх коридоров удаётся открыть только один

## Суть

По сообщению пользователя, из трёх соседних коридоров кнопка открытия была только у одного, хотя оставалось два очка действий. Пользователь уточнил: персонаж стоял в отсеке; все соседние коридоры должны быть доступны для открытия, закрытия и перехода, независимо от совпадения портов.

## Среда

- Версия приложения / commit: локальная рабочая копия; commit не зафиксирован в отчёте.
- Платформа и версия ОС / браузера: неизвестно.
- Устройство или размер окна, если важно: неизвестно.
- Режим игры / состав партии / seed, если важно: неизвестно.

## Подготовка и шаги воспроизведения

1. Персонаж находится в отсеке, рядом с тремя коридорами.
2. При двух оставшихся очках действий выбрать один из коридоров.
3. Для двух остальных кнопки открытия не было.

Частота воспроизведения: по сообщению пользователя; точная частота неизвестна.

## Результат

- **Фактический:** Кнопка открытия была доступна только для одного из трёх соседних коридоров.
- **Ожидаемый:** Каждый соседний коридор можно открывать, закрывать и посещать из отсека; доступность не зависит от портов.
- **Основание ожидания:** Явное уточнение пользователя от 2026-10-25; спецификация обновляется этим решением.

## Влияние

- Что пользователь не может сделать или какое состояние портится: Потенциально мешает исследовать поле.
- Масштаб / обходной путь: сценарии, описанные выше; обходной путь неизвестен.

## Доказательства

/home/lamand/Рабочий стол/12.jpg

## Границы проверки

- Подозреваемая область кода (если известна): `packages/besprotoritsa_rules/lib/src/commands_reducer_part_2.dart` (`RevealTileCommand` требует совпадения выходов); `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_6.dart` строит доступные команды из результата `validate`.
- Релевантные существующие тесты / спецификации: docs/rules-spec.md; packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart.
- Что пока неизвестно: нужно подтвердить, что единое правило доступности не меняет маршруты монстров и принудительного перемещения; реализация регрессии ограничивается действиями экипажа.

## Регрессионный тест

- Тесты: `packages/besprotoritsa_rules/test/hex_movement_test.dart` — `BUG132 adjacent corridor actions do not depend on matching room ports`; `packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart` — `BUG132 each adjacent corridor shows an open action`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/hex_movement_test.dart --reporter expanded`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/hex_movement_test.dart --name 'BUG132' --reporter expanded` — упал на assertion.
- Результат и причина падения: `validate(RevealTileCommand(HexCoord(0, -1)))` вернул `PortMismatch`; закрытый соседний коридор недоступен, если порты не совпадают.
- **После исправления (зелёный):** `cd packages/besprotoritsa_rules && dart test test/hex_movement_test.dart --name 'BUG132' --reporter expanded` — тест правил прошёл; `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart --name 'BUG132' --reporter expanded` — кнопка открытия показана для каждого из трёх соседних коридоров.
- Результат связанных проверок: полный набор Flutter-тестов — 138 прошли; полный набор тестов правил `dart test packages/besprotoritsa_rules/test --reporter expanded` — 230 прошли; `dart analyze packages/besprotoritsa_app packages/besprotoritsa_rules` — замечаний нет.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_2.dart`; `packages/besprotoritsa_rules/test/hex_movement_test.dart`; `docs/rules-spec.md`.
- Краткое описание исправления: раскрытие любой соседней клетки разрешено без проверки портов; закрытие, открытие и перемещение между отсеком и соседним коридором также не зависят от портов.
- Остаточные ограничения или связанные баги: правила маршрутов монстров и принудительного перемещения не менялись.
