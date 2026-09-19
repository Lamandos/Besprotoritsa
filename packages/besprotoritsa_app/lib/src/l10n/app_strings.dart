// This resource facade intentionally exposes one getter per localized string.
// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Russian strings used by the player-facing application shell.
///
/// Keeping strings in one resource object makes it possible to add another
/// locale without coupling individual screens to a particular language.
class AppStrings {
  const AppStrings._(this._values);

  static const AppStrings ru = AppStrings._(_ruValues);

  final Map<String, String> _values;

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? ru;

  String get appTitle => _value('appTitle');
  String get newGame => _value('newGame');
  String get continueGame => _value('continueGame');
  String get loadGame => _value('loadGame');
  String get tutorial => _value('tutorial');
  String get rulesReference => _value('rulesReference');
  String get menuSubtitle => _value('menuSubtitle');
  String get rosterTitle => _value('rosterTitle');
  String get rosterSubtitle => _value('rosterSubtitle');
  String get startGame => _value('startGame');
  String get scientist => _value('scientist');
  String get guard => _value('guard');
  String get mechanic => _value('mechanic');
  String get healer => _value('healer');
  String get science => _value('science');
  String get strength => _value('strength');
  String get repair => _value('repair');
  String get medicine => _value('medicine');
  String get selected => _value('selected');
  String get selectionLimit => _value('selectionLimit');
  String get loadTitle => _value('loadTitle');
  String get autosave => _value('autosave');
  String get saveSlotOne => _value('saveSlotOne');
  String get saveSlotTwo => _value('saveSlotTwo');
  String get saveSlotThree => _value('saveSlotThree');
  String get emptySlot => _value('emptySlot');
  String get savedGame => _value('savedGame');
  String get noAutosave => _value('noAutosave');
  String get tutorialTitle => _value('tutorialTitle');
  String get tutorialComplete => _value('tutorialComplete');
  String get move => _value('move');
  String get inspect => _value('inspect');
  String get scienceCheck => _value('scienceCheck');
  String get fightGhoul => _value('fightGhoul');
  String get useMedkit => _value('useMedkit');
  String get next => _value('next');
  String get tutorialMoveHint => _value('tutorialMoveHint');
  String get tutorialInspectHint => _value('tutorialInspectHint');
  String get tutorialScienceHint => _value('tutorialScienceHint');
  String get tutorialCombatHint => _value('tutorialCombatHint');
  String get tutorialMedkitHint => _value('tutorialMedkitHint');
  String get rulesTitle => _value('rulesTitle');
  String get rulesMovementTitle => _value('rulesMovementTitle');
  String get rulesMovementBody => _value('rulesMovementBody');
  String get rulesChecksTitle => _value('rulesChecksTitle');
  String get rulesChecksBody => _value('rulesChecksBody');
  String get rulesCombatTitle => _value('rulesCombatTitle');
  String get rulesCombatBody => _value('rulesCombatBody');
  String get rulesHealthTitle => _value('rulesHealthTitle');
  String get rulesHealthBody => _value('rulesHealthBody');
  String get back => _value('back');
  String get mvpTitle => _value('mvpTitle');
  String get availableCommands => _value('availableCommands');
  String get eventLog => _value('eventLog');
  String get decisionRequired => _value('decisionRequired');
  String get reroll => _value('reroll');
  String get keepResult => _value('keepResult');
  String get dodge => _value('dodge');
  String get doNotBuy => _value('doNotBuy');
  String get eventOptionPrompt => _value('eventOptionPrompt');
  String get terminalPickPrompt => _value('terminalPickPrompt');
  String get replacementHeroPrompt => _value('replacementHeroPrompt');

  String roundStatus(int round, int actions) =>
      '${_value('roundPrefix')}$round · ${_value('actionsPrefix')}$actions';
  String animationStatus(String event) => '${_value('animationPrefix')}$event';
  String hexLabel(int q, int r) => '${_value('hexPrefix')} ($q, $r)';
  String heroLabel(String id, int q, int r) =>
      '${_value('heroPrefix')} $id ${_value('atPrefix')} ($q, $r)';
  String monsterLabel(String id, int q, int r) =>
      '${_value('monsterPrefix')} $id ${_value('atPrefix')} ($q, $r)';
  String moveCommand(int q, int r) => '${_value('movePrefix')}: $q, $r';
  String attackCommand(String id) => '${_value('attackPrefix')} $id';
  String buyCommand(String id) => '${_value('buyPrefix')}: $id';
  String chooseCommand(String id) => '${_value('choosePrefix')}: $id';
  String enteredEvent(String id, int q, int r) =>
      '$id ${_value('enteredSuffix')} ($q, $r)';
  String colocationEvent(String id) => '${_value('colocationPrefix')}: $id';
  String damageEvent(String id, int amount) =>
      '$id ${_value('damageSuffix')} $amount';
  String diedEvent(String id, String monster) =>
      '$id ${_value('diedSuffix')}; ${_value('appearedPrefix')} $monster';
  String conditionEvent(String id) => '${_value('conditionPrefix')}: $id';
  String questEvent(String id) => '${_value('questPrefix')}: $id';
  String dicePrompt(String dice) => '${_value('dicePrefix')}: $dice';
  String dodgePrompt(int successes) =>
      '${_value('dodgePromptPrefix')}: ${_value('requiredSuccessesPrefix')} $successes';

  String rosterCount(int count) => '${_value('rosterCountPrefix')}$count/4';
  String tutorialRound(int round) => '${_value('tutorialRoundPrefix')}$round/3';
  String saveRound(int round) => '${_value('saveRoundPrefix')}$round';

  String _value(String key) => _values[key]!;
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ru';

  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture(AppStrings.ru);

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}

const Map<String, String> _ruValues = <String, String>{
  'appTitle': 'Беспроторица',
  'newGame': 'Новая игра',
  'continueGame': 'Продолжить',
  'loadGame': 'Загрузить партию',
  'tutorial': 'Обучение',
  'rulesReference': 'Справочник правил',
  'menuSubtitle': 'Локальная игра',
  'rosterTitle': 'Сформируйте отряд',
  'rosterSubtitle': 'Выберите от 2 до 4 персонажей для экспедиции.',
  'startGame': 'Начать игру',
  'scientist': 'Учёная',
  'guard': 'Охранник',
  'mechanic': 'Механик',
  'healer': 'Медик',
  'science': 'Наука',
  'strength': 'Сила',
  'repair': 'Ремонт',
  'medicine': 'Медицина',
  'selected': 'Выбран',
  'selectionLimit': 'В отряде должно быть от 2 до 4 героев.',
  'rosterCountPrefix': 'Героев: ',
  'loadTitle': 'Загрузить партию',
  'autosave': 'Последнее автосохранение',
  'saveSlotOne': 'Слот 1',
  'saveSlotTwo': 'Слот 2',
  'saveSlotThree': 'Слот 3',
  'emptySlot': 'Пусто',
  'savedGame': 'Сохранённая партия',
  'noAutosave': 'Автосохранение пока не найдено.',
  'tutorialTitle': 'Обучение: пробуждение',
  'tutorialComplete': 'Пролог пройден. Вы готовы к экспедиции!',
  'move': 'Сделать шаг',
  'inspect': 'Осмотреть отсек',
  'scienceCheck': 'Проверить науку',
  'fightGhoul': 'Сразиться с Упырём',
  'useMedkit': 'Применить аптечку',
  'next': 'Далее',
  'tutorialMoveHint':
      'Шаг открывает путь в соседний отсек и тратит одно действие.',
  'tutorialInspectHint':
      'Осмотр помогает найти предметы и понять, что происходит вокруг.',
  'tutorialScienceHint':
      'Наука позволяет безопасно работать со сложными системами корабля.',
  'tutorialCombatHint':
      'Упырь атакует вблизи. Нанесите попадание, чтобы отбросить его.',
  'tutorialMedkitHint': 'После боя восстановите здоровье аптечкой из рюкзака.',
  'tutorialRoundPrefix': 'Раунд ',
  'saveRoundPrefix': 'Раунд ',
  'rulesTitle': 'Справочник правил',
  'rulesMovementTitle': 'Движение',
  'rulesMovementBody':
      'Потратьте действие, чтобы перейти в соседний отсек через открытый выход.',
  'rulesChecksTitle': 'Проверки',
  'rulesChecksBody':
      'Бросьте кубики нужной характеристики. Успехи позволяют выполнить действие.',
  'rulesCombatTitle': 'Бой',
  'rulesCombatBody':
      'Атака требует действия. Наносите попадания Упырю, пока его здоровье не станет нулевым.',
  'rulesHealthTitle': 'Здоровье и предметы',
  'rulesHealthBody':
      'Аптечка снимает урон. Следите за здоровьем каждого героя.',
  'back': 'Назад',
  'mvpTitle': 'Беспроторица',
  'availableCommands': 'Доступные команды',
  'eventLog': 'Лог последних событий',
  'decisionRequired': 'Нужно решение',
  'reroll': 'Перебросить',
  'keepResult': 'Оставить результат',
  'dodge': 'Уклониться',
  'doNotBuy': 'Не покупать',
  'eventOptionPrompt': 'Выберите вариант события.',
  'terminalPickPrompt': 'Выберите припас в терминале.',
  'replacementHeroPrompt': 'Выберите героя на замену.',
  'roundPrefix': 'Раунд ',
  'actionsPrefix': 'действий: ',
  'animationPrefix': 'Анимация: ',
  'hexPrefix': 'Гекс',
  'heroPrefix': 'Герой',
  'monsterPrefix': 'Монстр',
  'atPrefix': 'на',
  'movePrefix': 'Ход',
  'attackPrefix': 'Атаковать',
  'buyPrefix': 'Купить',
  'choosePrefix': 'Выбрать',
  'enteredSuffix': 'вошёл в',
  'colocationPrefix': 'столкновение',
  'damageSuffix': 'получил урон',
  'diedSuffix': 'погиб',
  'appearedPrefix': 'появился',
  'conditionPrefix': 'получено состояние',
  'questPrefix': 'завершено задание',
  'dicePrefix': 'Кубики',
  'dodgePromptPrefix': 'Уклонение',
  'requiredSuccessesPrefix': 'нужно успехов',
};
