---
id: BUG-2026-090
title: Продолжение GHB-DTN теряется при замене другого героя
status: fixed
severity: high
area: rules
reported: 2026-10-11
---

# BUG-2026-090 — Продолжение GHB-DTN теряется при замене другого героя

## Суть

Если Нарыв на промежуточном шаге GHB-DTN поражает нескольких героев, смерть
союзника и последующий выбор героя из резерва прерывают остаток пути перемещения.

## Среда

- Версия приложения / commit: PR #33, `3b71fcd`.
- Платформа и версия ОС / браузера: пакет правил, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: два героя, один из которых
  ожидает в промежуточном секторе; готовый GHB-DTN и герой в резерве.

## Подготовка и шаги воспроизведения

1. Открыть путь из начального сектора через коридор в отсек.
2. Поставить второго героя и Нарыв в коридор; оставить второму герою 1 здоровье.
3. Переместить первого героя с помощью GHB-DTN в отсек.
4. Успешно уклониться первым героем, затем провалить уклонение второго героя.
5. Выбрать запасного героя и проверить позицию первого героя.

Частота воспроизведения: всегда при указанном порядке кубиков.

## Результат

- **Фактический:** после выбора героя из резерва первый герой остаётся в
  промежуточном секторе и остаток пути не выполняется.
- **Ожидаемый:** после завершения очереди уклонений и выбора замены первый герой
  продолжает сохранённый остаток пути и прибывает в отсек назначения.
- **Основание ожидания:** `docs/rules-spec.md`, раздел «resolveColocation и
  Нарыв — закрытое решение» требует разрешать колокацию после каждого очка
  перемещения, в том числе принудительного. Уже закрытый BUG089 устанавливает,
  что успешное разрешение встречи продолжает остаток пути GHB-DTN. Замечание
  последнего ревью PR #33 уточняет, что это продолжение должно пережить выбор
  замены другого героя.

## Влияние

- Что пользователь не может сделать или какое состояние портится: принудительное
  движение обрывается после связанной смерти героя, хотя неразрешённый путь ещё
  должен быть пройден.
- Масштаб / обходной путь: перемещение GHB-DTN через сектор с Нарывом и другим
  героем; обходного пути нет.

## Доказательства

Замечание последнего ревью PR #33:
https://github.com/Lamandos/Besprotoritsa/pull/33#discussion_r4241301464.

## Границы проверки

- Подозреваемая область кода: передача `ghbDtnContinuation` между
  `AwaitingDodge` и `AwaitingHeroReplacement` в
  `packages/besprotoritsa_rules/lib/src/commands_reducer_part_6.dart`.
- Релевантные существующие тесты / спецификации:
  `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`, BUG089;
  `docs/rules-spec.md`, раздел «resolveColocation и Нарыв — закрытое решение».
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`
  — `BUG090 GHB-DTN continues after another hero is replaced`.
- Команда запуска: `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG090 GHB-DTN continues after another hero is replaced' --reporter expanded`.
- **До исправления (красный):** `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG090 GHB-DTN continues after another hero is replaced' --reporter expanded` — exit 1.
- Результат и причина падения: assertion ожидает `HexCoord(0, 2)`, фактически
  движущийся герой остаётся в `HexCoord(0, 1)` после выбора замены.
- **После исправления (зелёный):** та же целевая команда — exit 0; тест пройден.
- Результат связанных проверок: `dart test packages/besprotoritsa_rules/test --reporter expanded` — 217 тестов прошли; `dart test packages/besprotoritsa_data/test --reporter expanded` — 81 тест прошёл; `dart analyze packages/besprotoritsa_rules packages/besprotoritsa_data` — замечаний нет. Тест сохранения и загрузки проверяет поле продолжения в `AwaitingHeroReplacement`.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/game_state_part_4.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_6.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`, `packages/besprotoritsa_data/lib/src/save_json_models.dart`, `packages/besprotoritsa_data/test/save_roundtrip_test.dart`.
- Краткое описание исправления: продолжение GHB-DTN переносится из уклонения в решение замены, сохраняется при последовательных заменах и ожидании следующего урона, затем возобновляет оставшийся путь. Кодек сохранения сериализует и восстанавливает это продолжение.
- Остаточные ограничения или связанные баги: нет известных.
