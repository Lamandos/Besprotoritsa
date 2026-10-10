---
id: BUG-2026-081
title: Награда растяжки теряется при замене погибшего владельца
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-081 — Награда растяжки теряется при замене погибшего владельца

## Суть

Если растяжка убивает монстра с `defeatRewardDeckId`, когда владелец ловушки уже
погиб и ожидает героя из резерва, награда добавляется в состояние погибшего героя.
При активации замены это состояние заменяется новым, и предмет пропадает.

## Среда

- Версия приложения / commit: PR #33, commit `2390251d06c476216a8d25f6afcee9f2e7984b4c`.
- Платформа и версия ОС / браузера: rules-пакет, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: владелец растяжки погиб, выбран герой из резерва, монстр с наградой входит в клетку растяжки.

## Подготовка и шаги воспроизведения

1. Погибнуть владельцем растяжки и поставить героя из резерва на замену.
2. Оставить растяжку в клетке, принадлежащей погибшему игроку.
3. Убить на ней монстра с `defeatRewardDeckId`, затем активировать замену.
4. Проверить, сохранилась ли полученная награда у игрока.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** награда попадает в `PlayerState` погибшего героя и исчезает при активации резерва.
- **Ожидаемый:** награда, выданная за убийство растяжкой, сохраняется в состоянии соответствующего игрока после замены героя.
- **Основание ожидания:** `_triggerTripwire` выдаёт награду владельцу ловушки по контракту `defeatRewardDeckId` (BUG060); `docs/rules-spec.md`, раздел «Смерть персонажа и Беспокойный», описывает отложенную активацию выбранного героя из резерва.

## Влияние

- Игрок теряет уже выданный предмет-награду при смене героя.
- Масштаб / обходной путь: награда за любого монстра, убитого растяжкой погибшего игрока до активации резерва.

## Доказательства

Замечание последнего ревью PR #33: `discussion_r4238357875`.

## Границы проверки

- Подозреваемая область кода: выдача награды в `_triggerTripwire` и перенос состояния в `_activateQueuedReplacements`.
- Релевантные существующие тесты / спецификации: BUG060, `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`, раздел «Смерть персонажа и Беспокойный» в `docs/rules-spec.md`.
- Что пока неизвестно: отдельное правило о награде, полученной игроком между гибелью героя и появлением замены, явно не записано; проверяем сохранение награды, обещанной за убийство.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart` — BUG081 для награды монстра и трофеев Беспокойного.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG081' --reporter expanded`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG081' --reporter expanded` — оба теста упали по assertion.
- Результат и причина падения: награда монстра и трофей Беспокойного после активации резерва получили `Expected: contains 'medkit'; Actual: []`: предмет оставался у погибшего героя и был потерян.
- **После исправления (зелёный):** `cd packages/besprotoritsa_rules && dart test test/mvp_round_loop_test.dart --name 'BUG080|BUG081' --reporter expanded` — прошли все 3 целевых теста.
- Результат связанных проверок: `dart test packages/besprotoritsa_rules/test` из корня репозитория — 209 тестов прошли; `cd packages/besprotoritsa_rules && dart analyze` — замечаний нет.

## Исправление

- Изменённые файлы: `docs/bugs/BUG-2026-081-tripwire-reward-lost-after-owner-replacement.md`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`.
- Краткое описание исправления: награда за убийство растяжкой сохраняется в состоянии героя из резерва, если владелец ловушки уже погиб; та же передача применяется к трофеям Беспокойного.
- Остаточные ограничения или связанные баги: нет.

## Повторное замечание последнего ревью PR #33

Последнее ревью выявило ещё один порядок событий: если герой погибает в своей
клетке с растяжкой, `resolveHeroDeaths` сначала создаёт Беспокойного и немедленно
разрешает срабатывание ловушки, а выбор героя из резерва остаётся ожидающим.
Поэтому `queuedReplacements` ещё пуст, трофей Беспокойного сохраняется у уже
погибшего героя, а последующий выбор резерва его теряет. Тот же промежуток
затрагивает награду монстра при срабатывании старой ловушки.

- Доказательство: замечание ревью PR #33, `discussion_r4238449154`.
- Подготовка и шаги: экипировать погибающего героя роботом; разместить его в
  собственной клетке с растяжкой; нанести смертельный урон; выбрать героя из
  резерва; проверить сохранность экипировки, которую погибший передал
  Беспокойному, а растяжка вернула владельцу.
- Ожидаемый результат: награда принадлежит игровому слоту владельца и
  сохраняется после выбора резерва.
- Регрессионный тест: `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`
  — `BUG081 tripwire reward survives own-death spawn before replacement selection`.
- Команда: `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG081 tripwire reward survives own-death spawn before replacement selection' --reporter expanded`.
- **Красный результат:** `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG081 tripwire reward survives own-death spawn before replacement selection' --reporter expanded` — тест упал на проверке выбранной замены: `Expected: contains 'ghb-dtn'; Actual: []`.
- **Зелёный результат:** `dart test packages/besprotoritsa_rules/test/mvp_round_loop_test.dart --name 'BUG081 tripwire reward survives own-death spawn before replacement selection' --reporter expanded` — `All tests passed!`; награда сохранилась и в очереди, и после активации резерва.
- Результат связанных проверок: `dart test packages/besprotoritsa_rules/test` — 210 тестов прошли; `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart` — 37 тестов прошли.
- Изменённые файлы после повторного ревью: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_6.dart`, `packages/besprotoritsa_rules/lib/src/commands_reducer_part_8.dart`, `packages/besprotoritsa_rules/test/mvp_round_loop_test.dart`.
- Краткое описание исправления: при выборе героя из резерва его исходное состояние дополняется наградой, уже сохранённой у погибшего владельца до выбора.
- Остаточные ограничения или связанные баги: предмет, который не помещается в рюкзак выбранного резерва по обычным правилам вместимости, записывается как невыданная награда в журнале.
