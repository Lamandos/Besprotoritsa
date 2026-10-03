---
id: BUG-2026-001
title: MVP quest resolves to an artwork file that is not bundled
status: fixed
severity: normal
area: app
reported: 2026-10-03
---

# BUG-2026-001 — MVP quest resolves to an artwork file that is not bundled

## Суть

The chapter's MVP quest ID (`chapter-1-awakening`) was converted into an asset
path even though only scanned quest IDs `quest-01` through `quest-29` have
artwork files. Rendering the journal attempted to load a nonexistent image.

## Среда

- Версия приложения / commit: PR #27, commit `0810388`; Linux CI, Flutter 3.47.6.
- Платформа и версия ОС / браузера: GitHub Actions Ubuntu 24.04.
- Устройство или размер окна, если важно: Flutter widget test viewport.
- Режим игры / состав партии / seed, если важно: opening chapter quest.

## Подготовка и шаги воспроизведения

1. Build the MVP game state with the opening `chapter-1-awakening` quest.
2. Open the shared journal, which displays the current quest card.
3. Let Flutter resolve the quest artwork.

Частота воспроизведения: всегда для this MVP quest.

## Результат

- **Фактический:** Flutter attempted to load
  `assets/images/card-art/quest-chapter-1-awakening.webp`, which does not exist.
- **Ожидаемый:** an MVP-only quest without a scanned card face uses the themed
  fallback and does not request an absent asset.
- **Основание ожидания:** card artwork is optional; the UI already has a
  fallback icon for cards without a scan.

## Влияние

- What the user cannot do or what state is corrupted: the shared journal widget
  test fails with an uncaught asset-loading exception; affected screens can
  report a missing image at runtime.
- Масштаб / обходной путь: every rendered instance of this quest requested the
  absent asset; no workaround was available in the UI.

## Доказательства

- Initial CI log for PR #27: <https://github.com/Lamandos/Besprotoritsa/actions/runs/37123258740>
- The log reports `Unable to load asset` for the exact path above during
  `mvp_screen_test.dart`.

## Границы проверки

- Подозреваемая область кода: `game_card_artwork.dart` quest path resolution.
- Релевантные существующие тесты / спецификации:
  `packages/besprotoritsa_app/test/mvp_screen_test.dart`, test
  `shared journal does not reveal personal task cards`.
- Что пока неизвестно: none for this failure.

## Регрессионный тест

- Тестовый файл и имя теста:
  `packages/besprotoritsa_app/test/mvp_screen_test.dart`,
  `shared journal does not reveal personal task cards`.
- Команда запуска: `flutter test test/mvp_screen_test.dart` from
  `packages/besprotoritsa_app`.
- **До исправления (красный):** CI reported an uncaught missing-asset exception
  for `quest-chapter-1-awakening.webp`; the test was marked failed.
- Результат и причина падения: unresolved quest asset path referenced a file
  that is not present in the bundled card art.
- **После исправления (зелёный):** the focused test passed as part of
  `flutter test test/responsive_layout_test.dart test/mvp_screen_test.dart`.
- Результат связанных проверок: `./tool/run_checks.sh` passed locally after the
  fix.

## Исправление

- Изменённые файлы: `packages/besprotoritsa_app/lib/src/cards/game_card_artwork.dart`.
- Краткое описание исправления: return no artwork path for quest/task IDs
  outside the bundled source-card sets; the existing fallback stays visible.
- Остаточные ограничения или связанные баги: story-only MVP quests still have
  no scanned art and use the fallback by design.
