---
id: BUG-2026-116
title: Командные события не собирают выбор каждого персонажа
status: fixed
severity: high
area: rules
reported: 2026-10-18
---

# BUG-2026-116 — Командные события не собирают выбор каждого персонажа

## Суть

Некоторые события требуют отдельного решения от каждого персонажа, но ожидание
выбора привязано только к игроку, которому вытянули карту. У остальных героев не
спрашивается выбор и не разрешаются их последствия. Для «Топот со всех сторон»
игрок с пустым рюкзаком может вообще не получить подвыбор, после чего событие
завершается, не затронув остальных героев.

## Среда

- Версия приложения / commit: локальная `main`, `1d4ba34`.
- Платформа и версия ОС / браузера: браузер; точная версия неизвестна.
- Устройство или размер окна, если важно: скриншот игрового экрана.
- Режим игры / состав партии / seed, если важно: событие «Топот со всех сторон»,
  в партии несколько персонажей.

## Подготовка и шаги воспроизведения

1. Начать раунд с несколькими живыми персонажами и картами в рюкзаках.
2. Вытянуть событие «Топот со всех сторон».
3. Выбрать «Бежать, сбросив лишний груз» и посмотреть, кому предлагается решить,
   сбрасывать ли рюкзак.
4. Повторить с событиями «Возгорание» и «Орда», где каждый персонаж должен выбрать
   один из двух вариантов.

Частота воспроизведения: всегда для перечисленных событий.

## Результат

- **Фактический:** событие разрешается для одного назначенного игрока; остальные
  герои не получают выбор и последствия. На приложенном скриншоте в результате
  «Топот со всех сторон» указано отсутствие изменений, затем уже показано
  следующее событие «Логово твари».
- **Ожидаемый:** одно окно показывает всех живых персонажей в ряд: портрет и
  доступные этому персонажу варианты под ним. Событие нельзя подтвердить, пока
  каждый участник не отметил выбор. После подтверждения применяются и
  подсчитываются последствия всех выборов; только затем показывается итог и
  открывается следующее событие.
- **Основание ожидания:** прямое требование пользователя от 2026-10-18. Текст
  исходных карт (`content/event_source_text_ru.json`) явно указывает «каждый игрок
  делает выбор» для `fire` и `monster-horde`, а `horde-carry` предписывает каждому
  сбросить карты либо получить урон. Спецификация `docs/rules-spec.md`, § «Фаза
  событий», требует исполнять последствия карты в указанном порядке; процедура
  общего выбора ранее не была уточнена и теперь задана пользователем.

## Влияние

- Что пользователь не может сделать или какое состояние портится: решения и
  последствия командной карты теряются для части партии; инвентарь и здоровье
  героев не соответствуют тексту карты.
- Масштаб / обходной путь: `horde-carry`, `fire`, `monster-horde`.

## Доказательства

- `/home/lamand/Изображения/Снимок экрана от 2026-10-18 18-09-36.png`
- В `content/event_source_text_ru.json` и `content/i18n/ru.json` сохранены
  формулировки командных карт.

## Границы проверки

- Подозреваемая область кода: запуск фазы событий в
  `packages/besprotoritsa_rules/lib/src/commands_reducer_part_8.dart`, разрешение
  выбора и последствий в `commands_reducer_part_7.dart`, модель и UI ожидающего
  решения в `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_5.dart`.
- Релевантные существующие тесты / спецификации:
  `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`,
  `packages/besprotoritsa_app/test/reported_gameplay_bugs_test.dart`,
  `docs/rules-spec.md`, § «Фаза событий».
- Аудит других командных событий: `meteor-stream` уже бросает кубик за каждого
  живого игрока; `asteroid-alert` отдельно обрабатывает каждого живого игрока в
  коридоре. `falling-beam` по исходному тексту относится к одному герою, хотя его
  данные имеют `kind: global`; сам `kind` не означает командный выбор.
- Что пока неизвестно: нет; список командных выборов сверяется с текстами карт,
  отличными от событий с автоматически общими эффектами.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`,
  `BUG116 horde carry choice includes every living hero`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name BUG116 --reporter expanded`.
- **До исправления (красный):** команда завершилась провалом assertion.
- Результат и причина падения: тест ожидал, что командный выбор не связан с
  единственным `playerId`; фактически pending-решение содержит `playerId: 'ada'`.
  Это подтверждает, что запрос выбора сейчас привязан только к одному герою.
- **После исправления (зелёный):** `dart test test/mvp_round_loop_test.dart --name BUG116 --reporter expanded` из `packages/besprotoritsa_rules` — все 5 тестов BUG116 прошли.
- Результат связанных проверок:
  - `dart test packages/besprotoritsa_rules/test` — все 228 тестов прошли.
  - `dart test packages/besprotoritsa_data/test` — все 81 тест прошёл.
  - `flutter test` из `packages/besprotoritsa_app` — все 118 тестов прошли.
  - `dart test packages/besprotoritsa_server/test/server_room_test.dart` — все 13 тестов прошли.
  - `dart analyze packages/besprotoritsa_app packages/besprotoritsa_rules packages/besprotoritsa_data packages/besprotoritsa_server` — замечаний нет.
  - `dart run tool/validate_schemas.dart` — проверены 10 схем.
  - `dart run tool/validate_content.dart --content-set full` — проверены 268 записей полного набора; ссылки, переводы, схемы, эффекты и достижимость кампании корректны.
  - `git diff --check` — ошибок форматирования diff нет.
  - `flutter analyze` не запустился: Dart analysis server завершился с `FormatException: Unterminated string` на пути рабочего каталога с пробелом; вместо него выполнен `dart analyze` всех четырёх пакетов, успешно.

## Исправление

- Изменённые файлы:
  - `content/events.json`, `content/schemas/event.schema.json`;
  - `docs/rules-spec.md`, `docs/bugs/BUG-2026-116-global-event-choices-for-each-hero.md`;
  - `packages/besprotoritsa_app/lib/src/game/full_runtime_content.g.dart`, `packages/besprotoritsa_app/lib/src/game/multiplayer_game_controller.dart`, `packages/besprotoritsa_app/lib/src/game/projected_game_state_codec.dart`, `packages/besprotoritsa_app/lib/src/mvp/mvp_game_feedback.dart`, `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_5.dart`;
  - `packages/besprotoritsa_app/test/mvp_screen_test.dart`, `packages/besprotoritsa_app/test/save_system_test.dart`;
  - `packages/besprotoritsa_data/lib/src/game_state_json_codec.dart`, `packages/besprotoritsa_data/lib/src/save_json_helpers.dart`, `packages/besprotoritsa_data/lib/src/save_json_models.dart`;
  - `packages/besprotoritsa_rules/lib/src/commands_reducer_part_1.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_6.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_7.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_8.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_9.dart`, `packages/besprotoritsa_rules/lib/src/game_state_part_4.dart`, `packages/besprotoritsa_rules/lib/src/game_state_part_5.dart`, `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`;
  - `packages/besprotoritsa_server/lib/src/room_manager.dart`, `packages/besprotoritsa_server/test/server_room_test.dart`.
- Краткое описание исправления: `fire`, `monster-horde` и `horde-carry` собирают выбор каждого живого героя в одном окне с портретами, вариантами и индивидуальной информацией о проверке. Подтверждение доступно после всех выборов. Движок разрешает последствия по очереди, сохраняет прерванную проверкой очередь и показывает общий результат только после её завершения. В сетевой игре участник выбирает только за своего героя; сервер публикует результаты событий после разрешения, не отправляя остальной журнал. Проверены другие командные карты: `meteor-stream` и `asteroid-alert` автоматически применяются ко всем согласно тексту, `falling-beam` остаётся выбором одного героя.
- Остаточные ограничения или связанные баги: ограничений, выявленных при проверке, нет.

