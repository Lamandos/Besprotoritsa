---
id: BUG-2026-005
title: Legacy exchange fields bypass weapon capacity after vest removal
status: reported
severity: high
area: rules
reported: 2026-10-03
---

# BUG-2026-005 — Legacy-поля обмена обходят проверку оружейной вместимости

## Суть

Если сетевой `ExchangeCommand` передаёт экипированный load-bearing vest через legacy-поле `giveCardIds`/`receiveCardIds`, проверка оружейной вместимости выполняется до снятия этого предмета.

## Среда

- Версия приложения / commit: PR #27, review on `f23ae8025b287e2c309388d05a6ed0c685c4b994`
- Платформа и версия ОС / браузера: любая; также server-authoritative multiplayer
- Устройство или размер окна, если важно: не важно
- Режим игры / состав партии / seed, если важно: два персонажа в одной клетке; у передающего надет жилет и два оружия

## Подготовка и шаги воспроизведения

1. Экипировать `load-bearing-vest` и два оружия.
2. Отправить обмен с `giveCardIds: ['load-bearing-vest']`.
3. Проверить результат игрока.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** обмен может снять жилет и оставить два оружия при базовой вместимости в одно.
- **Ожидаемый:** после всех способов снятия передаваемых карт оружейная вместимость должна соблюдаться.
- **Основание ожидания:** `docs/rules-spec.md` § «Инвентарь и обмен» и правило `equipment.extraWeaponSlot`.

## Влияние

- Что пользователь не может сделать или какое состояние портится: передавающий игрок сохраняет лишнее экипированное оружие.
- Масштаб / обходной путь: legacy wire-поля в обмене; area-aware выбор в UI уже защищён.

## Доказательства

Последний review PR #27: комментарий о проверке перед удалением legacy exchange cards.

## Границы проверки

- Подозреваемая область кода: `_exchangePlayers` в `commands_reducer_part_3.dart`.
- Релевантные существующие тесты / спецификации: `trade_chest_decks_test.dart`, `docs/rules-spec.md`.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `trade_chest_decks_test.dart`, legacy exchange cannot leave excess equipped weapons.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/trade_chest_decks_test.dart`.
- **До исправления (красный):** `dart test test/trade_chest_decks_test.dart`.
- Результат и причина падения: `legacy exchange cannot leave excess equipped weapons` получил `null` вместо `InventoryCommandRejected`; обмен снял жилет после уже пройденной проверки.
- **После исправления (зелёный):** `dart test test/trade_chest_decks_test.dart` — все тесты прошли.
- Результат связанных проверок: `./tool/run_checks.sh` завершился с кодом 0; analyzer, content validation и все rule/app tests прошли.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_3.dart`, `packages/besprotoritsa_rules/test/trade_chest_decks_test.dart`.
- Краткое описание исправления: проверять вместимость после снятия area-aware и legacy передаваемых карт.
- Остаточные ограничения или связанные баги: нет.
