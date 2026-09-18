import 'dart:convert';
import 'dart:io';

/// Builds the card-effect vocabulary before an effect executor is introduced.
///
/// This is deliberately source data rather than game logic.  `behaviorId`s are
/// stable names for future rules code; this tool does not interpret a card.
Future<void> main() async {
  final repository = Directory.current;
  final output = File('${repository.path}/content/effects_inventory.json');
  output.parent.createSync(recursive: true);
  final sourceTextByPage = await Future.wait(_sources.map(_extractSourceText));
  final inventory = <String, Object>{
    'schemaVersion': 1,
    'generatedBy': 'tool/inventory_effects.dart',
    'auditScope': <String, Object>{
      'method': 'visual PDF review with pdftotext cross-check',
      'sourceFiles': _sources,
      'sourceTextByPage': sourceTextByPage,
      'deckCardCounts': <String, int>{
        'items': 42,
        'supplies': 64,
        'specialItems': 7,
        'monsters': 48,
        'bosses': 4,
        'conditions': 50,
        'events': 88,
      },
      'notes': <String>[
        _joinText([
          'Repeated physical cards are represented by copies, ',
          'not duplicated rules.',
        ]),
        _joinText([
          'Monster deck count excludes four boss cards ',
          'and the Boil reference card.',
        ]),
        _joinText([
          'Event pages 1-6 contain 48 narrative cards; page 7 contains ',
          'eight global events; pages 8-11 contain 32 Invasion cards.',
        ]),
        _joinText([
          'PDF page 12 and final pages of other source PDFs ',
          'are blank backs and are not cards.',
        ]),
      ],
      'sourceConflicts': <Map<String, String>>[
        {
          'subject': 'Нарывы: Рой и Дрековац',
          'printedCards':
              'Рой масштабирует здоровье/урон; Дрековац уменьшает силу игрока. Нарывы на физических картах создают Гнездо, Леший и Чумной.',
          'rulesSpec':
              'docs/rules-spec.md называет Рой и смерть Дрековаца среди примеров появления Нарыва.',
          'decision': _joinText([
            'Реестр сохраняет буквальный текст карт; расхождение требует ',
            'отдельного решения правил.',
          ]),
        },
      ],
    },
    'lifecycleHooks': _hooks,
    'behaviors': _behaviors,
    'cards': _cards,
  };
  const encoder = JsonEncoder.withIndent('  ');
  _writeAtomically(output, '${encoder.convert(inventory)}\n');
  stdout.writeln('Generated ${output.path}.');
}

const _sources = <Map<String, Object>>[
  {'deck': 'items', 'file': 'materials/колода предметов.pdf', 'pages': 7},
  {'deck': 'supplies', 'file': 'materials/колода припасов.pdf', 'pages': 9},
  {'deck': 'specialItems', 'file': 'materials/особые предметы.pdf', 'pages': 2},
  {'deck': 'monsters', 'file': 'materials/монстры.pdf', 'pages': 10},
  {'deck': 'conditions', 'file': 'materials/состояния.pdf', 'pages': 4},
  {'deck': 'events', 'file': 'materials/события.pdf', 'pages': 12},
];

String _joinText(List<String> fragments) => fragments.join();

Future<Map<String, Object>> _extractSourceText(
  Map<String, Object> source,
) async {
  final file = source['file']! as String;
  final pageCount = source['pages']! as int;
  final result = await Process.run('pdftotext', ['-layout', file, '-']);
  if (result.exitCode != 0) {
    throw ProcessException(
      'pdftotext',
      ['-layout', file, '-'],
      result.stderr.toString(),
      result.exitCode,
    );
  }
  final pages = result.stdout.toString().split('\f');
  return <String, Object>{
    'deck': source['deck']!,
    'file': file,
    'pages': <Map<String, Object>>[
      for (var index = 0; index < pageCount; index++)
        <String, Object>{
          'page': index + 1,
          'text': index < pages.length ? pages[index].trim() : '',
        },
    ],
  };
}

const _hooks = <Map<String, Object>>[
  {
    'id': 'onRoll',
    'meaning': 'A dice pool was rolled, before successes are consumed.',
    'evidence': ['Циркулярная пила', 'Шлем стрелка'],
  },
  {
    'id': 'onHit',
    'meaning': 'Attack hits have been counted, before damage resolution.',
    'evidence': ['Экзо-перчатки', '«Последний шанс»'],
  },
  {
    'id': 'onDamageTaken',
    'meaning': 'A target is about to receive damage.',
    'evidence': ['PROT3-CT', 'Протонный щит'],
  },
  {
    'id': 'onKill',
    'meaning': 'A monster was killed by an attack or card effect.',
    'evidence': ['Лазерный резак', 'Ультразвуковой молот'],
  },
  {
    'id': 'onRoundStart',
    'meaning':
        'Beginning of the monster round; supports start-of-turn monster text.',
    'evidence': ['Леший: «перед ходом оставляет 2 нарыва»'],
  },
  {
    'id': 'onMove',
    'meaning': 'A unit enters, leaves, or is forcibly moved to a sector.',
    'evidence': ['Растяжка', 'Дробовик'],
  },
  {
    'id': 'onColocation',
    'meaning': 'A player and a token/monster now share a sector.',
    'evidence': ['Нарыв'],
  },
  {
    'id': 'onDeath',
    'meaning': 'A unit dies and its death effects are resolved.',
    'evidence': ['Чумной', 'Дрековац'],
  },
];

Map<String, Object> _behavior(
  String id,
  String category,
  String cardText,
  List<String> sources, {
  List<String> hooks = const <String>[],
}) => <String, Object>{
  'behaviorId': id,
  'category': category,
  'cardText': cardText,
  'sources': sources,
  'lifecycleHooks': hooks,
};

final _behaviors = <Map<String, Object>>[
  _behavior(
    'dice.reroll.one',
    'diceModifier',
    'переброс одного кубика',
    ['Труба', 'Стимуляторы Н/Л/В/Р/С'],
    hooks: ['onRoll'],
  ),
  _behavior(
    'dice.reroll.twoPerAttack',
    'diceModifier',
    'до 2 перебросов одного кубика за атаку',
    ['Циркулярная пила'],
    hooks: ['onRoll'],
  ),
  _behavior(
    'dice.reroll.anyCountPerAttack',
    'diceModifier',
    'один переброс любого количества кубиков за атаку',
    ['Автомат'],
    hooks: ['onRoll'],
  ),
  _behavior(
    'dice.reroll.all',
    'diceModifier',
    'перебросить все кубики',
    ['SC13-NC3', 'F1T-B07', 'DRG-4U'],
    hooks: ['onRoll'],
  ),
  _behavior(
    'dice.reroll.allForSkill',
    'diceModifier',
    'перебросить все кубики при названной проверке',
    ['Трубный ключ', 'SC13-NC3', 'F1T-B07'],
    hooks: ['onRoll'],
  ),
  _behavior(
    'dice.successFace.3',
    'diceModifier',
    'результат броска 3 считается попаданием',
    ['Пневмопушка', 'Шлем стрелка'],
    hooks: ['onRoll'],
  ),
  _behavior(
    'dice.face6.damageBoth',
    'diceModifier',
    '6 наносит урон и врагу, и персонажу',
    ['Пневмопушка'],
    hooks: ['onRoll'],
  ),
  _behavior(
    'dice.equalPair.addHit',
    'diceModifier',
    'пара одинаковых значений добавляет 1 попадание',
    ['Экзо-перчатки'],
    hooks: ['onHit'],
  ),
  _behavior(
    'combat.addHit',
    'combat',
    'добавить 1 попадание',
    ['GTU-B1c4', 'Кустарный кастет'],
    hooks: ['onHit'],
  ),
  _behavior(
    'combat.selfDamageForHit',
    'combat',
    'нанести себе 2 урона, чтобы добавить 1 попадание',
    ['Кустарный кастет'],
    hooks: ['onHit', 'onDamageTaken'],
  ),
  _behavior(
    'combat.ignoreEnemyDefense',
    'combat',
    'игнорируйте защиту врага',
    ['Гвоздомет'],
    hooks: ['onHit'],
  ),
  _behavior(
    'combat.useScienceInsteadOfStrength',
    'combat',
    'в бою вместо силы использовать науку',
    ['Лазерный скальпель'],
    hooks: ['onRoll'],
  ),
  _behavior(
    'combat.damageAllEnemiesInSectorOnKill',
    'combat',
    'после убийства нанести 1 урон всем врагам в том же секторе',
    ['Лазерный резак'],
    hooks: ['onKill'],
  ),
  _behavior(
    'combat.noHit.takeDamage',
    'combat',
    'не нанеся попаданий за атаку, получить урон',
    ['Нож'],
    hooks: ['onHit', 'onDamageTaken'],
  ),
  _behavior(
    'combat.noHit.damageTarget',
    'combat',
    'не нанеся попаданий за атаку, нанести урон этому врагу',
    ['«Последний шанс»'],
    hooks: ['onHit'],
  ),
  _behavior(
    'combat.rechargeForCredits',
    'combat',
    'победив врага, повернуть 5 кредитов для перезарядки',
    ['Ультразвуковой молот'],
    hooks: ['onKill'],
  ),
  _behavior(
    'combat.pushUnkilledEnemy',
    'movement',
    'после атаки отодвинуть неубитого не-босса на 2 открытых поля',
    ['Дробовик'],
    hooks: ['onMove'],
  ),
  _behavior(
    'damage.ignoreAnyUntilRoundEnd',
    'damage',
    'игнорировать любой урон до конца раунда',
    ['PROT3-CT'],
    hooks: ['onDamageTaken'],
  ),
  _behavior(
    'damage.preventUntilRoundEnd',
    'damage',
    'не получать урон до конца раунда',
    ['Протонный щит'],
    hooks: ['onDamageTaken'],
  ),
  _behavior(
    'damage.ignoreBoil',
    'damage',
    'полностью игнорировать урон от нарывов',
    ['Маска чумного доктора'],
    hooks: ['onDamageTaken'],
  ),
  _behavior(
    'damage.ignoreArmor',
    'damage',
    'атаки игнорируют броню',
    ['Мать'],
    hooks: ['onDamageTaken'],
  ),
  _behavior('damage.apply', 'damage', 'получить/нанести фиксированный урон', [
    'События: провода, завал, пожар',
    'Газовый баллон',
  ]),
  _behavior(
    'damage.rollDie',
    'damage',
    'бросить кубик и получить выпавший урон',
    ['События: метеоритный поток, пожар'],
  ),
  _behavior('health.restore', 'health', 'восстановить указанное здоровье', [
    'Наноботы',
    'Аптечка',
    'H3-AL',
  ]),
  _behavior('health.restoreAll', 'health', 'восстановить всё здоровье', [
    'Аптечка',
    'Сухпай',
    'События: «Гулять, так гулять!»',
  ]),
  _behavior(
    'health.healingBonus',
    'health',
    'любое лечение эффективнее на 1 здоровье',
    ['Старый плащ'],
  ),
  _behavior(
    'stat.modify',
    'stat',
    '+/- к силе, защите, науке, ремонту, ловкости или выносливости',
    ['Одежда и броня', 'Состояния', 'Адреналин'],
  ),
  _behavior('action.grant', 'action', 'добавить действия', [
    'Адреналин',
    'Адреналин-Х',
    'События: выпивка',
  ]),
  _behavior(
    'action.reduceNextTurn',
    'action',
    'в следующий ход выполнять на одно действие меньше',
    ['События: люк, ловушка, алкоголь'],
  ),
  _behavior('action.spend', 'action', 'потратить действие', [
    'Воздушный баллон',
    'Растяжка',
    'Пульт от дверей',
  ]),
  _behavior('card.discardCost', 'card', 'сбросить карту как стоимость', [
    'Припасы',
    'События: «Кинуть газовый баллон»',
  ]),
  _behavior('card.preventMonsterLoot', 'card', 'враги не оставляют добычу', [
    'Огнемет',
  ]),
  _behavior('card.draw', 'deck', 'взять карту из колоды', [
    'События',
    'Лазерный резак',
  ]),
  _behavior(
    'card.drawFiltered',
    'deck',
    'взять оружие/робота/одежду/имплант из колоды',
    ['События: ящики, шкафчики, хлам'],
  ),
  _behavior('card.drawSpecific', 'deck', 'взять названную карту из колоды', [
    'События: Старый плащ, Швейцарский нож, DRG-4U',
  ]),
  _behavior(
    'card.chooseFromTopAndShuffleRest',
    'deck',
    'взять верхние карты, выбрать одну, остальные замешать',
    ['События: комната охраны', 'Терминал снабжения'],
  ),
  _behavior('card.returnAndShuffle', 'deck', 'вернуть в колоду и замешать', [
    'События: торговый бот, терминал снабжения',
  ]),
  _behavior('economy.gainCredits', 'economy', 'получить кредиты', [
    'Кредиты',
    'Заначка',
    'События',
  ]),
  _behavior(
    'economy.spendCredits',
    'economy',
    'потратить кредиты как стоимость',
    ['Пульт от дверей', 'Ультразвуковой молот'],
  ),
  _behavior('economy.buy', 'economy', 'купить карты, в том числе со скидкой', [
    'События: терминал снабжения, торговый бот',
  ]),
  _behavior('economy.sell', 'economy', 'продать предметы за полную стоимость', [
    'События: терминал снабжения, торговый бот',
  ]),
  _behavior('equipment.extraWeaponSlot', 'equipment', 'можно носить 2 оружия', [
    'Разгрузочный жилет',
  ]),
  _behavior(
    'equipment.extraRobotSlot',
    'equipment',
    'можно использовать двух роботов',
    ['Спецодежда инженера'],
  ),
  _behavior(
    'equipment.extraBackpackCapacity',
    'equipment',
    'носить на 2 предмета больше',
    ['DRG-4U'],
  ),
  _behavior(
    'equipment.implantRules',
    'equipment',
    'передаваемый имплант не занимает рюкзак, после использования '
        'неснимаем; максимум 2',
    ['Импланты Л/В/Р/Н/С'],
  ),
  _behavior(
    'robot.exhaust',
    'robot',
    'повернуть робота, чтобы применить его способность',
    ['Все роботы'],
  ),
  _behavior('robot.ready', 'robot', 'вернуть робота в положение готовности', [
    'Энергоблок',
  ]),
  _behavior(
    'robot.ignoreEnemyFeatures',
    'robot',
    'до конца раунда игнорировать особенности не-боссов',
    ['R69-NIC3', 'ALARM BOT'],
  ),
  _behavior('map.moveAirlock', 'movement', 'совершить переход между шлюзами', [
    'Воздушный баллон',
  ]),
  _behavior(
    'map.moveHullBetweenAirlocks',
    'movement',
    'перемещаться по обшивке между шлюзами',
    ['Скафандр'],
  ),
  _behavior(
    'map.forceMove',
    'movement',
    'передвинуть себя или союзника на 2 сектора',
    ['GHB-DTN'],
    hooks: ['onMove'],
  ),
  _behavior(
    'map.remoteExchange',
    'map',
    'обменяться предметами с игроком в любой части карты',
    ['C6-CAR «Курьер»'],
  ),
  _behavior('map.revealAnyFragment', 'map', 'открыть любой фрагмент карты', [
    'SC0-U7',
  ]),
  _behavior(
    'map.openCloseCorridor',
    'map',
    'дистанционно открыть или закрыть проход в коридор',
    ['Пульт от дверей'],
  ),
  _behavior(
    'map.closeCorridorsAndDisplace',
    'map',
    'закрыть все коридоры и передвинуть находящихся в них',
    ['Событие: астероид'],
    hooks: ['onMove'],
  ),
  _behavior(
    'map.freeRevealOnEntry',
    'map',
    'не тратить шаг на открытие фрагмента карты при входе',
    ['Фонарик'],
    hooks: ['onMove'],
  ),
  _behavior(
    'monster.spawn',
    'monster',
    'взять монстра, вступить в бой или разместить жетон',
    ['События', 'Вторжение'],
  ),
  _behavior(
    'monster.spawnClosedFallback',
    'monster',
    'если сектор не открыт, разместить карту в любом закрытом секторе',
    ['Вторжение'],
  ),
  _behavior(
    'monster.killNonBoss',
    'monster',
    'убить одного врага, кроме босса',
    ['Растяжка', 'Газовый баллон', 'Событие: ловушка'],
  ),
  _behavior(
    'monster.trapOnEnter',
    'monster',
    'выложить в свой сектор: убить не-босса, появившегося или зашедшего туда',
    ['Растяжка'],
    hooks: ['onMove'],
  ),
  _behavior(
    'monster.moveVentilation',
    'monster',
    'перемещаться по цветной вентиляции',
    ['Стая', 'Упырь', 'Ищущий'],
    hooks: ['onMove'],
  ),
  _behavior(
    'monster.targetLowestHealth',
    'monster',
    'охотится за игроками с наименьшим здоровьем',
    ['Ищущий'],
  ),
  _behavior(
    'monster.restoreHealthIfAliveThisTurn',
    'monster',
    'восстановить всё здоровье, если не убит за ход',
    ['Вурдалак'],
  ),
  _behavior(
    'monster.replaceAttackWithBoilSpread',
    'monster',
    'вместо атаки распространять Нарывы',
    ['Гнездо'],
    hooks: ['onRoundStart'],
  ),
  _behavior(
    'monster.blockExits',
    'monster',
    'блокирует проходы',
    ['Лихо'],
    hooks: ['onMove'],
  ),
  _behavior(
    'monster.scalePerPlayer',
    'monster',
    'здоровье и урон +1 за каждого игрока',
    ['Мать', 'Вий'],
  ),
  _behavior(
    'monster.scalePerAliveMonster',
    'monster',
    'здоровье и урон +1 за каждого живого противника',
    ['Рой'],
  ),
  _behavior(
    'monster.fleeAndSpawnBoils',
    'monster',
    'убегает от игроков; перед ходом оставляет 2 нарыва',
    ['Леший'],
    hooks: ['onRoundStart', 'onMove'],
  ),
  _behavior(
    'boil.spawnAdjacentOnDeath',
    'boil',
    'после смерти оставить по 1 нарыву на соседних полях',
    ['Чумной', 'Дрековац'],
    hooks: ['onDeath'],
  ),
  _behavior(
    'boil.explodeOnColocation',
    'boil',
    'в одной клетке с игроком лопается и умирает',
    ['Нарыв'],
    hooks: ['onColocation'],
  ),
  _behavior(
    'condition.applyOnDamage',
    'condition',
    'после урона получить карту состояния',
    ['Правила игры', 'Состояния'],
    hooks: ['onDamageTaken'],
  ),
  _behavior('event.choice', 'event', 'выбрать один из вариантов события', [
    'Все повествовательные события',
  ]),
  _behavior(
    'event.skillCheck',
    'event',
    'пройти проверку силы/науки/ремонта/выносливости/ловкости',
    ['Все повествовательные события'],
  ),
  _behavior(
    'event.successFailure',
    'event',
    'разрешить отдельные последствия успеха и провала',
    ['Все повествовательные события'],
  ),
];

Map<String, Object> _card(
  String deck,
  String name,
  int copies,
  String sourceText,
  List<String> behaviors, {
  String? page,
}) => <String, Object>{
  'deck': deck,
  'name': name,
  'copies': copies,
  if (page != null) 'pdfPage': page,
  'sourceText': sourceText,
  'behaviorIds': behaviors,
};

final _cards = <Map<String, Object>>[
  ..._itemCards,
  ..._supplyCards,
  ..._specialCards,
  ..._monsterCards,
  ..._conditionCards,
  ..._eventCards,
];

final _itemCards = <Map<String, Object>>[
  _card(
    'items',
    'Циркулярная пила',
    1,
    'До 2 перебросов одного кубика за атаку.',
    ['dice.reroll.twoPerAttack'],
  ),
  _card(
    'items',
    'Лазерный резак',
    1,
    'После убийства противника наносит 1 урон всем врагам в том же секторе.',
    ['combat.damageAllEnemiesInSectorOnKill'],
  ),
  _card(
    'items',
    'Экзо-перчатки',
    1,
    'В бою любая пара одинаковых значений на кубиках добавляет 1 попадание.',
    ['dice.equalPair.addHit'],
  ),
  _card(
    'items',
    'Пневмопушка',
    1,
    '+1 к силе; 3 — попадание, 6 наносит урон врагу и персонажу.',
    ['stat.modify', 'dice.successFace.3', 'dice.face6.damageBoth'],
  ),
  _card('items', 'Гвоздомет', 1, 'Игнорируйте защиту врага.', [
    'combat.ignoreEnemyDefense',
  ]),
  _card('items', 'Огнемет', 1, '+3 к силе; враги не оставляют добычу.', [
    'stat.modify',
    'card.preventMonsterLoot',
  ]),
  _card(
    'items',
    'Нож',
    1,
    '+1 к силе; без попаданий за атаку получить 1 урон.',
    ['stat.modify', 'combat.noHit.takeDamage'],
  ),
  _card(
    'items',
    'Ультразвуковой молот',
    1,
    '+4 к силе; победив врага, повернуть 5 кредитов для перезарядки.',
    ['stat.modify', 'combat.rechargeForCredits'],
  ),
  _card(
    'items',
    'Скафандр',
    1,
    '+1 к защите; перемещаться по обшивке между шлюзами.',
    ['stat.modify', 'map.moveHullBetweenAirlocks'],
  ),
  _card('items', 'Сковорода', 1, '+1 к силе и защите.', ['stat.modify']),
  _card(
    'items',
    '«Последний шанс»',
    1,
    '+1 к силе; без попаданий за атаку нанести 1 урон этому врагу.',
    ['stat.modify', 'combat.noHit.damageTarget'],
  ),
  _card(
    'items',
    'Разгрузочный жилет',
    1,
    '+1 к защите; можно носить 2 оружия.',
    ['stat.modify', 'equipment.extraWeaponSlot'],
  ),
  _card(
    'items',
    'Спецодежда инженера',
    1,
    'Позволяет использовать двух роботов.',
    ['equipment.extraRobotSlot'],
  ),
  _card(
    'items',
    'Лазерный скальпель',
    1,
    '+1 к науке; в бою вместо силы использовать науку.',
    ['stat.modify', 'combat.useScienceInsteadOfStrength'],
  ),
  _card(
    'items',
    'Трубный ключ',
    1,
    '+1 к силе и ремонту; перебросить кубики при проверке ремонта.',
    ['stat.modify', 'dice.reroll.allForSkill'],
  ),
  _card('items', 'Костюм охранника', 1, '+1 к защите и силе.', ['stat.modify']),
  _card(
    'items',
    'Майка, камуфляж, рубашка, комбинезон, халат, футболка, форма '
        'грузчика, лабораторный костюм, бронежилет',
    9,
    'Постоянные модификаторы характеристик.',
    ['stat.modify'],
  ),
  _card('items', 'Шлем стрелка', 1, '3 в бою считается попаданием.', [
    'dice.successFace.3',
  ]),
  _card(
    'items',
    'Импланты Л/В/Р/Н/С',
    5,
    '+1 к названной характеристике; особые правила импланта.',
    ['stat.modify', 'equipment.implantRules'],
  ),
  _card(
    'items',
    'GHB-DTN',
    1,
    'Повернуть: передвинуть себя или союзника на 2 сектора.',
    ['robot.exhaust', 'map.forceMove'],
  ),
  _card(
    'items',
    'R69-NIC3, ALARM BOT',
    2,
    'Повернуть: игнорировать особенности всех не-боссов до конца раунда.',
    ['robot.exhaust', 'robot.ignoreEnemyFeatures'],
  ),
  _card('items', 'GTU-B1c4', 1, 'Повернуть в бою: добавить 1 попадание.', [
    'robot.exhaust',
    'combat.addHit',
  ]),
  _card(
    'items',
    'C6-CAR «Курьер»',
    1,
    'Повернуть: обменяться предметами с игроком в любой части карты.',
    ['robot.exhaust', 'map.remoteExchange'],
  ),
  _card('items', 'SC0-U7', 1, 'Повернуть: открыть любой фрагмент карты.', [
    'robot.exhaust',
    'map.revealAnyFragment',
  ]),
  _card(
    'items',
    'PROT2-CT',
    1,
    'Повернуть в бою: +1 к защите до конца раунда.',
    ['robot.exhaust', 'stat.modify'],
  ),
  _card(
    'items',
    'SC13-NC3',
    1,
    'При проверке науки или ремонта повернуть: перебросить все кубики.',
    ['robot.exhaust', 'dice.reroll.allForSkill'],
  ),
  _card(
    'items',
    'F1T-B07',
    1,
    'При проверке выносливости или ловкости повернуть: перебросить все кубики.',
    ['robot.exhaust', 'dice.reroll.allForSkill'],
  ),
  _card(
    'items',
    'PROT3-CT',
    1,
    'Повернуть: игнорировать любой урон до конца раунда.',
    ['robot.exhaust', 'damage.ignoreAnyUntilRoundEnd'],
  ),
  _card(
    'items',
    'H3-AL',
    1,
    'Повернуть: восстановить себе или союзнику 3 здоровья.',
    ['robot.exhaust', 'health.restore'],
  ),
];

final _supplyCards = <Map<String, Object>>[
  _card(
    'supplies',
    'Наноботы',
    4,
    'Сбросить: восстановить 1 здоровье и +1 к защите до конца раунда.',
    ['card.discardCost', 'health.restore', 'stat.modify'],
  ),
  _card(
    'supplies',
    'Воздушный баллон',
    5,
    'Сбросить: потратить действие и совершить переход между шлюзами.',
    ['card.discardCost', 'action.spend', 'map.moveAirlock'],
  ),
  _card(
    'supplies',
    'Адреналин',
    3,
    'В свой ход сбросить: добавить 1 действие.',
    ['card.discardCost', 'action.grant'],
  ),
  _card(
    'supplies',
    'Кредиты',
    3,
    'Немедленно сбросить и получить 5 кредитов.',
    ['card.discardCost', 'economy.gainCredits'],
  ),
  _card('supplies', 'Труба', 1, '1 переброс одного кубика в бою.', [
    'dice.reroll.one',
  ]),
  _card(
    'supplies',
    'Кустарный кастет',
    1,
    'При атаке нанести себе 2 урона: добавить 1 попадание.',
    ['combat.selfDamageForHit'],
  ),
  _card(
    'supplies',
    'Дефибриллятор',
    3,
    'Сбросить в свой ход для переброса любого количества кубиков.',
    ['card.discardCost', 'dice.reroll.anyCountPerAttack'],
  ),
  _card(
    'supplies',
    'Шлем, кустарная броня, сварочная маска, тесак',
    4,
    'Постоянные плюсы и минусы характеристик.',
    ['stat.modify'],
  ),
  _card(
    'supplies',
    'Заначка',
    2,
    'Немедленно сбросить и получить 10 кредитов.',
    ['card.discardCost', 'economy.gainCredits'],
  ),
  _card(
    'supplies',
    'Сухпай',
    3,
    'Сбросить в свой ход: восполнить 4 здоровья.',
    ['card.discardCost', 'health.restore'],
  ),
  _card(
    'supplies',
    'Растяжка',
    3,
    'Потратить действие, выложить в сектор: убить вошедшего/появившегося не-босса.',
    ['action.spend', 'monster.trapOnEnter'],
  ),
  _card(
    'supplies',
    'Газовый баллон',
    3,
    'Потратить действие и сбросить: убить не-босса в своём секторе.',
    ['action.spend', 'card.discardCost', 'monster.killNonBoss'],
  ),
  _card(
    'supplies',
    'Пульт от дверей',
    2,
    'Потратить действие и 2 кредита: открыть/закрыть проход в коридор.',
    ['action.spend', 'economy.spendCredits', 'map.openCloseCorridor'],
  ),
  _card(
    'supplies',
    'Фонарик',
    2,
    'Не тратить шаг для открытия фрагмента при входе.',
    ['map.freeRevealOnEntry'],
  ),
  _card(
    'supplies',
    'Аптечка',
    1,
    'Сбросить в свой ход: восполнить всё здоровье.',
    ['card.discardCost', 'health.restoreAll'],
  ),
  _card(
    'supplies',
    'Протонный щит',
    2,
    'В свой ход сбросить: не получать урон до конца раунда.',
    ['card.discardCost', 'damage.preventUntilRoundEnd'],
  ),
  _card('supplies', 'Вода', 3, 'Сбросить в свой ход: восполнить 3 здоровья.', [
    'card.discardCost',
    'health.restore',
  ]),
  _card(
    'supplies',
    'Рацион',
    2,
    'Сбросить в свой ход: восполнить 5 здоровья.',
    ['card.discardCost', 'health.restore'],
  ),
  _card(
    'supplies',
    'Адреналин-Х',
    2,
    'В свой ход сбросить: добавить 2 действия.',
    ['card.discardCost', 'action.grant'],
  ),
  _card(
    'supplies',
    'Энергоблок',
    5,
    'Сбросить в свой ход: вернуть робота в положение готовности.',
    ['card.discardCost', 'robot.ready'],
  ),
  _card(
    'supplies',
    'Стимуляторы Н/Л/В/Р/С',
    10,
    'При названной проверке сбросить: перебросить 1 кубик.',
    ['card.discardCost', 'dice.reroll.one'],
  ),
];

final _specialCards = <Map<String, Object>>[
  _card(
    'specialItems',
    'Старый плащ',
    1,
    '+1 к защите; лечение эффективнее на 1 здоровье.',
    ['stat.modify', 'health.healingBonus'],
  ),
  _card(
    'specialItems',
    'Автомат',
    1,
    '+2 к силе; один переброс любого количества кубиков за атаку.',
    ['stat.modify', 'dice.reroll.anyCountPerAttack'],
  ),
  _card(
    'specialItems',
    'Дробовик',
    1,
    '+3 к силе; после атаки отодвинуть неубитого не-босса на 2 поля.',
    ['stat.modify', 'combat.pushUnkilledEnemy'],
  ),
  _card(
    'specialItems',
    'DRG-4U',
    1,
    '+2 места для предметов; при силе/атаке повернуть: перебросить все кубики.',
    ['equipment.extraBackpackCapacity', 'robot.exhaust', 'dice.reroll.all'],
  ),
  _card(
    'specialItems',
    'Швейцарский нож',
    1,
    '+1 ко всем пяти характеристикам.',
    ['stat.modify'],
  ),
  _card('specialItems', 'Экзоскелет', 1, '+2 к защите и +1 к ловкости.', [
    'stat.modify',
  ]),
  _card(
    'specialItems',
    'Маска чумного доктора',
    1,
    '+1 к защите; игнорировать урон от нарывов.',
    ['stat.modify', 'damage.ignoreBoil'],
  ),
];

final _monsterCards = <Map<String, Object>>[
  _card('monsters', 'Беспокойный', 16, 'Сила игрока в бою уменьшена на 1.', [
    'stat.modify',
  ]),
  _card('monsters', 'Волот', 2, 'Медленный, но сильный противник.', []),
  _card(
    'monsters',
    'Дрековац',
    2,
    'Сила игрока в бою уменьшена на 1.',
    ['stat.modify'],
  ),
  _card(
    'monsters',
    'Вурдалак',
    2,
    'Восстанавливает всё здоровье, если не убит за ход.',
    ['monster.restoreHealthIfAliveThisTurn'],
  ),
  _card(
    'monsters',
    'Чумной',
    3,
    'После смерти оставляет по 1 нарыву на соседних полях.',
    ['boil.spawnAdjacentOnDeath'],
  ),
  _card(
    'monsters',
    'Гнездо',
    4,
    'Неподвижный; вместо атаки распространяет Нарывы.',
    ['monster.replaceAttackWithBoilSpread'],
  ),
  _card('monsters', 'Лихо', 3, 'Неподвижный противник, блокирует проходы.', [
    'monster.blockExits',
  ]),
  _card('monsters', 'Стая', 4, 'Может перемещаться по вентиляции.', [
    'monster.moveVentilation',
  ]),
  _card('monsters', 'Волколак', 4, 'Сила игрока в бою уменьшена на 1.', [
    'stat.modify',
  ]),
  _card('monsters', 'Упырь', 4, 'Может перемещаться по вентиляции.', [
    'monster.moveVentilation',
  ]),
  _card(
    'monsters',
    'Ищущий',
    4,
    'Охотится за игроками с наименьшим здоровьем; может перемещаться '
        'по вентиляции.',
    ['monster.targetLowestHealth', 'monster.moveVentilation'],
  ),
  _card(
    'bosses',
    'Мать',
    1,
    'Атаки игнорируют броню; здоровье и урон +1 за каждого игрока.',
    ['damage.ignoreArmor', 'monster.scalePerPlayer'],
  ),
  _card('bosses', 'Вий', 1, 'Здоровье и урон +1 за каждого игрока.', [
    'monster.scalePerPlayer',
  ]),
  _card(
    'bosses',
    'Рой',
    1,
    'Здоровье и урон +1 за каждого живого противника.',
    ['monster.scalePerAliveMonster'],
  ),
  _card(
    'bosses',
    'Леший',
    1,
    'Убегает от игроков; перед ходом оставляет 2 нарыва в своей клетке.',
    ['monster.fleeAndSpawnBoils'],
  ),
  _card(
    'reference',
    'Нарыв',
    1,
    'В одной клетке с игроком лопается и умирает.',
    ['boil.explodeOnColocation'],
  ),
];

final _conditionCards = <Map<String, Object>>[
  _card('conditions', 'Недомогание', 9, '-1 к силе.', ['stat.modify']),
  _card('conditions', 'Контузия', 9, '-1 к ремонту.', ['stat.modify']),
  _card('conditions', 'Тошнота', 9, '-1 к науке.', ['stat.modify']),
  _card('conditions', 'Перелом', 9, '-1 к ловкости.', ['stat.modify']),
  _card('conditions', 'Одышка', 9, '-1 к выносливости.', ['stat.modify']),
  _card('conditions', 'Адреналин', 5, '+1 ко всем характеристикам.', [
    'stat.modify',
  ]),
];

final _eventCards = <Map<String, Object>>[
  _card(
    'events',
    'Повествовательные события, страницы 1-6',
    48,
    '48 карт: выбор варианта, проверка, последствия успеха/провала; награды, урон, бой, перемещение, сброс и торговля.',
    [
      'event.choice',
      'event.skillCheck',
      'event.successFailure',
      'card.draw',
      'card.drawFiltered',
      'card.drawSpecific',
      'card.chooseFromTopAndShuffleRest',
      'card.returnAndShuffle',
      'damage.apply',
      'health.restore',
      'action.grant',
      'action.reduceNextTurn',
      'monster.spawn',
      'monster.killNonBoss',
      'map.forceMove',
      'economy.gainCredits',
      'economy.buy',
      'economy.sell',
    ],
  ),
  _card(
    'events',
    'Глобальные события, страница 7',
    8,
    'Метеоритный поток, пожар, орда, астероид: бросок урона, выбор, '
        'сброс, закрытие коридоров, перемещение и появление монстров.',
    [
      'event.choice',
      'damage.rollDie',
      'damage.apply',
      'card.discardCost',
      'map.closeCorridorsAndDisplace',
      'monster.spawn',
    ],
  ),
  _card(
    'events',
    'Вторжение: 16 указанных секторов',
    32,
    'Взять монстра и разместить жетон в указанном секторе; закрытый '
        'сектор использует резервный закрытый сектор.',
    ['monster.spawn', 'monster.spawnClosedFallback'],
  ),
];

void _writeAtomically(File destination, String contents) {
  final temporary = File(
    '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
  )..createSync();
  try {
    temporary
      ..writeAsStringSync(contents, flush: true)
      ..renameSync(destination.path);
  } on Object {
    if (temporary.existsSync()) temporary.deleteSync();
    rethrow;
  }
}
