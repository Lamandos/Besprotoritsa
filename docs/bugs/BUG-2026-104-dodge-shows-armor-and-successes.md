---
id: BUG-2026-104
title: При уклонении не показаны броня персонажа и успехи для полного уклонения
status: fixed
severity: normal
area: app
reported: 2026-10-14
---

# BUG-2026-104 — При уклонении показать броню и число нужных успехов

## Суть

В окне уклонения показаны входящий урон и число кубиков ловкости, но не
показаны броня персонажа и число успехов, нужных для полного уклонения.

## Среда

- Версия приложения / commit: неизвестно.
- Платформа и версия ОС / браузера: браузерная версия; точные версии неизвестны.
- Устройство или размер окна, если важно: окно уклонения.
- Режим игры / состав партии / seed, если важно: персонаж получает атаку монстра.

## Подготовка и шаги воспроизведения

1. Экипировать персонажа бронёй.
2. Поместить атакующего монстра в его сектор или переместить монстра в сектор персонажа.
3. Открыть решение «Уклонение».

Частота воспроизведения: всегда при открытии такого решения.

## Результат

- **Фактический:** окно сообщает входящий урон и число кубиков ловкости, но не
  сообщает броню и число успехов, достаточное для полного уклонения.
- **Ожидаемый:** окно сообщает броню персонажа, число успехов для полного
  уклонения после применения брони и число кубиков ловкости. Если атакующий
  игнорирует защиту, броня не уменьшает входящий урон и это отражено в тексте.
- **Основание ожидания:** запрос владельца проекта от 2026-10-14; формула
  применения защиты перед уклонением закреплена в `docs/rules-spec.md`, раздел
  «Бой, урон и состояния».

## Влияние

- Что пользователь не может сделать или какое состояние портится: игрок не
  видит вклад брони и нужное число успехов для полного уклонения.
- Масштаб / обходной путь: все решения уклонения от атак монстров.

## Доказательства

Скриншоты игры от 2026-10-14 показывают окно уклонения/карточку монстра; отдельного
скриншота окна уклонения с бронёй нет.

## Границы проверки

- Подозреваемая область кода: `_decisionPrompt` в
  `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_6.dart`; поля
  `IncomingDamage` / `AwaitingDodge` и передача атакующего в интерфейс.
- Релевантные существующие тесты / спецификации: `docs/rules-spec.md`, раздел
  «Бой, урон и состояния»; `packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart`.
- Что пока неизвестно: пользовательский текст не задаёт точную формулировку;
  она будет выбрана без изменения игровых правил.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart` —
  `BUG104 dodge prompt shows armor and reduced successes`; проверить обычную атаку,
  уменьшаемую бронёй, и атаку монстра `mother`, которая игнорирует защиту.
- Команда запуска: `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart --name 'BUG104' --reporter expanded`.
- **До исправления (красный):**
  `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart --name 'BUG104' --reporter expanded` — оба теста упали на assertion, потому что окно не содержит `Броня персонажа: 2`.
- Результат и причина падения: widget-тесты создали решение уклонения после атаки Дрековаца (урон уже уменьшен с 3 до 1) и Матери (защита игнорируется, урон 4); оба обнаружили отсутствие отображаемой брони. Падение — проверяемый результат интерфейса, не ошибка компиляции.
- **После исправления (зелёный):**
  `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart --name 'BUG10[45]' --reporter expanded` — все три регрессионных теста BUG104/105 прошли.
- Результат связанных проверок: полный `reported_gameplay_bugs_test.dart` — все 56 тестов прошли; `packages/besprotoritsa_data/test/save_roundtrip_test.dart` — все 14 тестов прошли; `packages/besprotoritsa_rules/test/combat_colocation_test.dart` — все 18 тестов прошли; `packages/besprotoritsa_server/test/server_room_test.dart` из корня репозитория — все 12 тестов прошли; `projected_game_state_codec_test.dart` и `save_system_test.dart` — все 7 тестов прошли; `dart analyze` и `git diff --check` — без замечаний.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_5.dart`, `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_6.dart`, `packages/besprotoritsa_rules/lib/src/combat_models.dart`, `packages/besprotoritsa_rules/lib/src/game_state_part_4.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_4.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_7.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `packages/besprotoritsa_data/lib/src/save_json_models.dart`, `packages/besprotoritsa_app/lib/src/game/projected_game_state_codec.dart`, `packages/besprotoritsa_server/lib/src/room_manager.dart`, `packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart`.
- Краткое описание исправления: окно уклонения показывает значение защиты персонажа, при наличии — название брони, отметку об игнорировании брони атакующим, число успехов для полного уклонения и число кубиков ловкости. Идентификатор атакующего сохраняется в очереди урона, решении, сохранениях и сетевом снимке.
- Остаточные ограничения или связанные баги: для старого сохранённого решения без идентификатора атакующего текст не определяет особенность монстра; сохранённое число урона и порог успехов остаются корректными.
