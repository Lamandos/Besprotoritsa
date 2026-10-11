---
id: BUG-2026-032
title: Нельзя применить активные свойства карт из инвентаря
status: fixed
severity: high
area: app
reported: 2026-10-09
---

# BUG-2026-032 — Активные свойства карт нельзя использовать

## Суть

Из инвентаря доступны сброс и надевание карт, но не активные свойства карт. В частности, пользователь не может потратить кредиты через саквояж фельдшера, разместить растяжку или использовать препарат.

## Среда

- Версия приложения / commit: неизвестно.
- Платформа и версия ОС / браузера: неизвестно.
- Устройство или размер окна, если важно: нет.
- Режим игры / состав партии / seed, если важно: карта находится у активного героя; условия и цель применения доступны.

## Подготовка и шаги воспроизведения

1. Получить карту с активным свойством.
2. Открыть инвентарь карты.
3. Найти и запустить её печатное активное свойство, выбрав нужную цель/клетку, если это требуется.

Частота воспроизведения: по сообщению пользователя — свойство карты недоступно.

## Результат

- **Фактический:** Активные свойства карт нельзя применить; карта доступна только для удаления/сброса либо пассивного учёта.
- **Ожидаемый:** Для каждой карты с активным эффектом доступно корректное действие с указанной целью и оплатой, а одноразовая карта уходит в сброс только если это следует из её исходного свойства.
- **Основание ожидания:** Явное сообщение пользователя; формулировки и эффекты нужно сверять с `materials/колода предметов.pdf`, `materials/колода припасов.pdf` и действующими решениями в `docs/rules-spec.md`.

## Влияние

- Что пользователь не может сделать или какое состояние портится: значимая часть тактических свойств карт недоступна.
- Масштаб / обходной путь: карты с активными свойствами в предметах и припасах.

## Доказательства

Источник — сообщение пользователя от 2026-10-09; приведены примеры саквояжа фельдшера, растяжки и препарата.

## Границы проверки

- Подозреваемая область кода (если известна): `packages/besprotoritsa_rules/lib/src/effect_registry.dart`, reducer команд и `packages/besprotoritsa_app/lib/src/mvp/mvp_game_screen_part_4.dart`.
- Релевантные существующие тесты / спецификации: `packages/besprotoritsa_rules/test/effects_engine_test.dart`, `characters_inventory_test.dart`; `docs/rules-spec.md`; исходные карточные PDF.
- Подтверждённый объём: `content/effects_inventory.json` и определения карт выделяют используемые из инвентаря эффекты `health.restorePerCredit`, `monster.trapOnEnter`, `monster.killNonBoss`, `map.moveAirlock`, `map.forceMove`, `map.remoteExchange`, `map.revealAnyFragment`, `map.openCloseCorridor`, `robot.ignoreEnemyFeatures`, `robot.ready`, `damage.preventUntilRoundEnd`, `action.grant`, `economy.gainCredits`, `health.restore`, `health.restoreAll` и расход карт ради переброса. Пассивные свойства и автоматические боевые триггеры остаются на соответствующих окнах боя/проверки.
- Уточнение пользователя: R69-NIC3 и ALARM BOT влияют только на владельца; владелец игнорирует и блокировку прохода. Глобальные эффекты вроде движения монстров и появления Нарывов продолжают срабатывать.

## Регрессионный тест

- Тестовый файл: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`; R69-NIC3/ALARM BOT, штраф силы в бою, блокировка выходов, срок эффекта, боссы и глобальный Нарыв.
- Команда запуска: `dart test packages/besprotoritsa_rules/test/active_card_abilities_test.dart --reporter expanded`.
- **До исправления (красный):** 12 имеющихся тестов прошли; 3 новых упали ожидаемо. Статус: `red_verified`.
- Результат и причина падения: использование R69-NIC3 отклонено (`InventoryCommandRejected`); проверка не блокирует выход из клетки с Лихом (`PathBlocked` не получен); атака против монстра со свойством `reduces-combat-strength` нанесла 3 вместо 2 урона.
- Дополнительный UI regression test для саквояжа фельдшера до реализации тоже фиксировал отсутствие кнопки `Использовать`.
- **После исправления (зелёный):** `dart test packages/besprotoritsa_rules/test/active_card_abilities_test.dart --reporter expanded` — все 19 тестов пройдены; `cd packages/besprotoritsa_app && flutter test test/reported_gameplay_bugs_test.dart --name 'BUG032' --reporter expanded` — оба UI-сценария пройдены.
- Результат связанных проверок: весь rules-пакет — 157 тестов пройдены; весь Flutter-набор — 76 тестов пройдены; save-roundtrip и server пакеты пройдены; `dart analyze --fatal-infos .` и проверка форматирования прошли; валидаторы схем и контента прошли (10 схем, 280 MVP и 268 full).

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_2.dart`, `commands_reducer_part_4.dart`, `commands_reducer_part_5.dart`, `commands_reducer_part_11.dart`, `game_state_part_1.dart`, `commands_reducer_part_9.dart`, `game_state_part_6.dart`, `inventory_changes_part.dart`; `packages/besprotoritsa_data/lib/src/save_json_models.dart`; `packages/besprotoritsa_app/lib/src/game/projected_game_state_codec.dart`, `mvp/mvp_game_screen_part_4.dart`; `packages/besprotoritsa_server/lib/src/room_manager.dart`; `docs/rules-spec.md`, `docs/effects-vocabulary.md`, and the listed regression tests.
- Краткое описание исправления: добавлены доступные действия для лечения саквояжем фельдшера, расходников, растяжки, газового баллона, пульта дверей, баллона воздуха, энергоблока, роботов H3-AL/SC0-U7/GHB-DTN/GTU-B1C4/PROT2-CT/PROT3-CT, R69-NIC3 и ALARM BOT, обмена через C6 и метку контрабандиста, а также перебросов препаратов/дефибриллятора. R69/ALARM действует только на владельца до конца раунда, не затрагивает боссов и не отменяет глобальные эффекты. Добавлены штраф силы при атаке против соответствующих монстров и блокировка выхода из клетки с Лихом.
- Остаточные ограничения или связанные баги: уточнение пользователя задаёт владельца робота как единственную защищённую цель; глобальные эффекты монстров не отменяются.
