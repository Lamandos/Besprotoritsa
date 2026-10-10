---
id: BUG-2026-089
title: GHB-DTN продолжает путь до разрешения встречи
status: fixed
severity: high
area: rules
reported: 2026-10-11
---

# BUG-2026-089 — GHB-DTN продолжает путь до разрешения встречи

## Суть

Если на промежуточном шаге GHB-DTN запускает встречу с окном уклонения, обработчик
немедленно перемещает героя дальше и применяет прибытие в конечный сектор, пока
решение по встрече ещё ожидается.

## Среда

- Версия приложения / commit: PR #33, `3e2a336`.
- Платформа и версия ОС / браузера: пакет правил, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: перемещение по пути длиной два
  шага, атакующий монстр или Нарыв на первом шаге.

## Подготовка и шаги воспроизведения

1. Экипировать готовый GHB-DTN; открыть путь длиной два шага до отсека с целью
   прибытия.
2. Поставить атакующего монстра на промежуточный сектор.
3. Переместить героя GHB-DTN в конечный отсек.
4. До разрешения уклонения проверить координату героя и прогресс прибытия.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** окно `AwaitingDodge` открывается на промежуточном секторе,
  но цикл перемещения сразу переносит героя в конечный сектор и засчитывает
  прибытие туда.
- **Ожидаемый:** перемещение приостанавливается на промежуточном секторе, пока
  встреча не разрешена; после выживания оставшийся путь продолжается, а при
  гибели герой умирает на секторе встречи.
- **Основание ожидания:** `docs/rules-spec.md`, раздел
  «resolveColocation и Нарыв»: колокация обязательна после каждого очка движения
  игрока. Замечание последнего ревью PR #33 указывает на необходимость сохранить
  оставшийся путь как продолжение и остановить цикл при открытии решения.

## Влияние

- Что пользователь не может сделать или какое состояние портится: встреча и
  последствия смертельного урона разрешаются уже после незаконного дальнейшего
  перемещения; цель прибытия может засчитаться раньше времени.
- Масштаб / обходной путь: GHB-DTN пересекает сектор с атакующим монстром или
  Нарывом; обходного пути нет.

## Доказательства

Замечание последнего ревью PR #33:
https://github.com/Lamandos/Besprotoritsa/pull/33#discussion_r4239367783.

## Границы проверки

- Подозреваемая область кода: цикл перемещения `ghb-dtn` в
  `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart` и
  возобновление отложенного решения в reducer.
- Релевантные существующие тесты / спецификации:
  `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`, BUG072 и BUG086;
  `docs/rules-spec.md`, раздел «resolveColocation и Нарыв».
- Что пока неизвестно: формат хранения продолжения пути следует выбрать в рамках
  существующей модели отложенных решений.

## Регрессионный тест

- Тестовый файл и имена тестов: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`
  — `BUG089 GHB-DTN pauses at an intermediate encounter` и
  `BUG089 lethal GHB-DTN encounter resolves at its intermediate sector`.
- Команда запуска: `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG089' --reporter expanded`.
- **До исправления (красный):** `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG089 GHB-DTN pauses at an intermediate encounter' --reporter expanded` — exit 1.
- Результат и причина падения: assertion ожидал координату промежуточного сектора `HexCoord(0, 1)`, фактически герой уже в конечном секторе `HexCoord(0, 2)` с незавершённым уклонением.
- **После исправления (зелёный):** `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG089' --reporter expanded` — оба теста прошли; успешное уклонение продолжает маршрут и засчитывает прибытие, смертельное оставляет Беспокойного на промежуточном секторе.
- Результат связанных проверок: `dart test packages/besprotoritsa_rules/test --reporter expanded` — все 216 тестов прошли; `dart test packages/besprotoritsa_data/test --reporter expanded` — все 81 тест прошёл; `dart analyze packages/besprotoritsa_rules packages/besprotoritsa_data` — замечаний нет.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_6.dart`, `packages/besprotoritsa_rules/lib/src/game_state_part_4.dart`, `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`, `packages/besprotoritsa_data/lib/src/save_json_helpers.dart`, `packages/besprotoritsa_data/lib/src/save_json_models.dart`, `packages/besprotoritsa_data/test/save_roundtrip_test.dart`.
- Краткое описание исправления: после каждого шага GHB-DTN останавливает маршрут на открывшемся решении уклонения, сохраняет остаток пути в решении и продолжает его после успешного уклонения; остаток маршрута сохраняется и загружается в формате игры.
- Остаточные ограничения или связанные баги: нет известных.
