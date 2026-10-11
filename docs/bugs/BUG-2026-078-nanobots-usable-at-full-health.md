---
id: BUG-2026-078
title: Наноботы нельзя применить при полном здоровье
status: fixed
severity: high
area: rules
reported: 2026-10-10
---

# BUG-2026-078 — Наноботы нельзя применить при полном здоровье

## Суть

Общая проверка расходников для лечения отклоняет Наноботы, когда у героя нет
урона, хотя карта также даёт +1 к защите до конца раунда.

## Среда

- Версия приложения / commit: PR #33, commit `109b7698e08058a9d0e45f47cc1df60320b0896f`.
- Платформа и версия ОС / браузера: rules-пакет, все платформы.
- Устройство или размер окна, если важно: не важно.
- Режим игры / состав партии / seed, если важно: у героя есть Наноботы, урон равен 0.

## Подготовка и шаги воспроизведения

1. Дать герою Наноботы и оставить его здоровье полным.
2. Выполнить `UseCardAbilityCommand('nanobots')`.
3. Проверить результат команды и бонус защиты.

Частота воспроизведения: всегда.

## Результат

- **Фактический:** команда отклоняется с сообщением, что здоровье уже полное; карта не даёт бонус защиты.
- **Ожидаемый:** герой может сбросить Наноботы и получить +1 к защите до конца раунда, даже если восстановление здоровья не требуется.
- **Основание ожидания:** описание `content/i18n/ru.json`, `supply.nanobots`: сбросить карту, восстановить 1 здоровье и получить +1 к защите до конца раунда. `docs/rules-spec.md`, раздел «Бой, урон и состояния», описывает применение защиты героя к урону монстра.

## Влияние

- Игрок не может применить защитную часть эффекта Наноботов при полном здоровье.
- Масштаб / обходной путь: затрагивает каждое такое применение; обходного пути нет.

## Доказательства

Последнее ревью PR #33: `discussion_r4238268215`.

## Границы проверки

- Подозреваемая область кода: проверка `_cardAbilityRestoresHealth` в `commands_reducer_part_11.dart`.
- Релевантные существующие тесты / спецификации: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`, описание Наноботов в `content/i18n/ru.json`, раздел боя в `docs/rules-spec.md`.
- Что пока неизвестно: нет.

## Регрессионный тест

- Тестовый файл и имя теста: `packages/besprotoritsa_rules/test/active_card_abilities_test.dart` — тест `BUG078`.
- Команда запуска: `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG078' --reporter expanded`.
- **До исправления (красный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG078' --reporter expanded`.
- Результат и причина падения: assertion по ожидаемому результату упал — вместо `null` команда вернула `InventoryCommandRejected`, потому что здоровье героя полное.
- **После исправления (зелёный):** `cd packages/besprotoritsa_rules && dart test test/active_card_abilities_test.dart --name 'BUG078' --reporter expanded` — прошёл.
- Результат связанных проверок: rules — 206 тестов, data — 80 тестов, app — 83 теста и server — 15 тестов прошли; `dart analyze packages/besprotoritsa_rules packages/besprotoritsa_data packages/besprotoritsa_app packages/besprotoritsa_server` — замечаний нет.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_rules/lib/src/commands_reducer_part_11.dart`, `packages/besprotoritsa_rules/test/active_card_abilities_test.dart`.
- Краткое описание исправления: Наноботы больше не требуют отсутствующего урона; без фактического восстановления здоровья состояния героя не снимаются.
- Остаточные ограничения или связанные баги: нет.
