import 'package:flutter/material.dart';

/// The screen the quick-exit button lands on.
///
/// Nothing in here uses the Kasat palette, typography, or copy — it must look
/// like a different, boring app if someone scrolls through it. It is also
/// deliberately interactive: a screen where nothing responds to a tap is a
/// screen that gives itself away.
///
/// The way back is a long-press on the "Notes" title, which then hands off to
/// the PIN screen. There is no visible control, because a visible control is
/// something a person standing over her shoulder can ask about.
class NotesDecoyView extends StatelessWidget {
  const NotesDecoyView({super.key, required this.onSecretUnlock});

  final VoidCallback onSecretUnlock;

  static const _notes = <(String, String, String)>[
    ('Groceries', 'teff flour, onions, berbere, cooking oil, soap', 'Yesterday'),
    ('Bus times', 'first one leaves 6:40, the later one is 7:15', 'Yesterday'),
    ('Rent', 'due on the 5th — ask about the water bill again', 'Sat'),
    ('Sara birthday', 'get the cake from the place near the roundabout', 'Fri'),
    ('Phone repair', 'screen quote was 1400, said two days', '12 Aug'),
    ('Recipe', 'soak the lentils overnight, then 20 min', '9 Aug'),
    ('Work shifts', 'Tue Thu Sat this week, swap with Meron next week', '4 Aug'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onLongPress: onSecretUnlock,
                    child: const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.more_horiz, color: Color(0xFFE8B93B), size: 26),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E9EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 18, color: Color(0xFF8E8E93)),
                    SizedBox(width: 6),
                    Text(
                      'Search',
                      style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _notes.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 12,
                  color: Color(0xFFE0E0E2),
                ),
                itemBuilder: (context, i) {
                  final (title, preview, stamp) = _notes[i];
                  return _NoteRow(
                    title: title,
                    preview: preview,
                    when: stamp,
                    first: i == 0,
                    last: i == _notes.length - 1,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _NoteDetail(title: title, body: preview),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Text(
                    '${_notes.length} Notes',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                  ),
                  const Spacer(),
                  const Icon(Icons.create_outlined, color: Color(0xFFE8B93B), size: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.title,
    required this.preview,
    required this.when,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final String title;
  final String preview;
  final String when;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(first ? 10 : 0),
            bottom: Radius.circular(last ? 10 : 0),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  when,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteDetail extends StatelessWidget {
  const _NoteDetail({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFFE8B93B)),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.ios_share, size: 20, color: Color(0xFFE8B93B)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF1C1C1E)),
            ),
          ],
        ),
      ),
    );
  }
}
