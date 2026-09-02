import 'dart:math';

/// Fixed pool of display identities for Vent Here.
///
/// A fresh pair is drawn for every new post. Within one thread, the same
/// person keeps the identity they were given for that post.
const ventIdentities = <String>[
  'Unihorse 🦄',
  'Foxling 🦊',
  'Owlet 🦉',
  'Fawn 🦌',
  'Panda cub 🐼',
  'Kit 🐱',
  'Pup 🐶',
  'Hatchling 🐣',
  'Cub 🐻',
  'Lamb 🐑',
  'Calf 🐮',
  'Foal 🐴',
  'Duckling 🦆',
  'Bunny 🐰',
  'Otterkit 🦦',
  'Sealpup 🦭',
  'Koala 🐨',
  'Sparrow 🐦',
  'Wren 🐦',
  'Dove 🕊️',
  'Finch 🐤',
  'Moth 🦋',
  'Firefly ✨',
  'Coral 🪸',
  'Pebble 🪨',
  'Moss 🌿',
  'Willow 🌳',
  'River 🌊',
  'Dusk 🌅',
  'Ember 🔥',
  'Cloudlet ☁️',
  'Starling ⭐',
  'Moonkit 🌙',
  'Dew 💧',
  'Seedling 🌱',
  'Honeybee 🐝',
  'Ladybird 🐞',
  'Cricket 🦗',
  'Snail 🐌',
  'Cygnet 🦢',
];

/// The AI companion. Never drawn from the animal pool, never pretends to be
/// a person who posted.
const kasatCompanionIdentity = 'Kasat 🌸';

String pickVentIdentity({String? otherThan, Random? random}) {
  final rng = random ?? Random();
  final pool = [
    for (final id in ventIdentities)
      if (id != otherThan) id,
  ];
  return pool[rng.nextInt(pool.length)];
}
