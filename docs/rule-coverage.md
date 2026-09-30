# Покрытие сквозных правил

| Правило / результат | Интеграционный сценарий | Проверка |
| --- | --- | --- |
| Сюжетная цепочка 1–12 завершается победой | `victory_scenario_test.dart` | Фиксированный seed, реальные события `QuestEngine`, все `quest-01`…`quest-12` завершены, есть живые герои и показан `victory-screen`. |
| Достижимость длинной ветки графа до настоящей победы на задании 29 | `quest_graph_test.dart`; `integration_test/victory_e2e_scenario.dart` | Seed 226, герои Охранник и Астронавт, фиксированные броски; полный runtime проходит подготовку, задания и события реальными игровыми командами и журнал фиксирует `quest-completed:quest-29`. Задание 12 не завершено. Отдельный `defeat_scenario_test.dart` доводит партию до поражения. |
| Сюжетные цели и решения на игровом экране | `mvp_screen_test.dart`; `mvp_round_loop_test.dart` | Журнал показывает цель, условия и прогресс; личные задачи скрыты до раскрытия; pending event/terminal/reroll/replacement choices разрешаются через экран решения. |
| Смерть героя создаёт Беспокойного | `defeat_scenario_test.dart` | Каждый из двух героев получает смертельный урон от монстра, превращается в `RestlessMonster` в своей клетке. |
| Резерв и поражение | `defeat_scenario_test.dart` | Первый герой выбирает единственного резервного персонажа; после смерти второго резерв пуст, партия завершена и показан `defeat-screen`. |
| Условие прибытия при активации задания или возвращении героя | `mvp_round_loop_test.dart`; `integration_test/victory_e2e_scenario.dart` | Уже занятый целевой отсек и возвращение из резерва засчитывают прибытие; пустой финал закрывается и сохраняет статус `completed` в том же переходе. Решение внесено в `content/review_status.json`. |
| Раунд, PendingDecision и сохранение | `save_resume_scenario_test.dart` | После двух завершений хода игра находится в раунде 3; атака создаёт `AwaitingRerollChoice`. |
| Слот и продолжение без потери состояния | `save_resume_scenario_test.dart` | Снимок сохранён в `slot-1`, сессия полностью уничтожена, загруженный снимок побайтно равен исходному JSON и позволяет завершить решение и ход. |

Запуск всех сценариев:

```sh
flutter test \
  test/victory_scenario_test.dart \
  test/defeat_scenario_test.dart \
  test/save_resume_scenario_test.dart
```
