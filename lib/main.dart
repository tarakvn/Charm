import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:torch_light/torch_light.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'spells_data.dart';
import 'spell_effects.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const HogwartsApp());
}

class HogwartsApp extends StatelessWidget {
  const HogwartsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _status = 'طلسم بگو...';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  // نمایش افکت طلسم روی صفحه با استفاده از Overlay (بدون نیاز به اینترنت)
  void _playEffect(Spell spell) {
    final overlayState = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => SpellEffectOverlay(
        color: spell.effectColor,
        secondaryColor: spell.secondaryColor,
        icon: spell.icon,
        style: spell.effectStyle,
        reverse: spell.reverse,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlayState.insert(entry);
  }

  // نرمال‌سازی متن انگلیسی برای مقایسه: حروف کوچک، حذف علائم نگارشی و فاصله‌های اضافه
  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // فاصله‌ی Levenshtein بین دو رشته (تعداد تغییرات لازم برای یکی‌شدن)
  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    List<int> prev = List<int>.generate(b.length + 1, (i) => i);
    List<int> curr = List<int>.filled(b.length + 1, 0);
    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1, // insert
          prev[j] + 1, // delete
          prev[j - 1] + cost, // substitute
        ].reduce((x, y) => x < y ? x : y);
      }
      prev = List<int>.from(curr);
    }
    return prev[b.length];
  }

  // شباهت دو رشته بین ۰ (کاملاً متفاوت) تا ۱ (کاملاً یکسان)
  double _similarity(String a, String b) {
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    return 1 - (_levenshtein(a, b) / maxLen);
  }

  void _castSpell(String text) async {
    final String normalizedText = _normalize(text);
    final words = normalizedText.split(' ');

    // برای دیباگ: ببین سیستم دقیقاً چی شنیده
    debugPrint('SHENIDE (recognized): "$normalizedText"');

    // مرحله ۱: تطبیق دقیق (سریع‌ترین حالت) با اسم اصلی یا هر کدام از aliasها
    for (var spell in allSpells) {
      final candidates = [spell.name, ...spell.aliases];
      for (final c in candidates) {
        if (normalizedText.contains(_normalize(c))) {
          _castConfirmed(spell);
          return;
        }
      }
    }

    // مرحله ۲: تطبیق فازی - اگر عین کلمه گفته‌نشده ولی خیلی شبیه اسم طلسم بود
    Spell? bestSpell;
    double bestScore = 0;
    const threshold = 0.72; // هر چقدر بالاتر، سخت‌گیرتر

    for (var spell in allSpells) {
      final candidates = [spell.name, ...spell.aliases];
      for (final c in candidates) {
        final normalizedC = _normalize(c);
        // شباهت با کل جمله‌ی شنیده‌شده
        final scoreWhole = _similarity(normalizedText, normalizedC);
        // شباهت با تک‌تک کلمات شنیده‌شده (برای طلسم‌های تک‌کلمه‌ای)
        double scoreWord = 0;
        for (final w in words) {
          final s = _similarity(w, normalizedC);
          if (s > scoreWord) scoreWord = s;
        }
        final score = scoreWhole > scoreWord ? scoreWhole : scoreWord;
        if (score > bestScore) {
          bestScore = score;
          bestSpell = spell;
        }
      }
    }

    if (bestSpell != null && bestScore >= threshold) {
      debugPrint('FUZZY MATCH: ${bestSpell.name} (score: ${bestScore.toStringAsFixed(2)})');
      _castConfirmed(bestSpell);
      return;
    }

    // نمایش متنی که واقعاً شنیده شده
    setState(() => _status = 'ناشناخته: "${normalizedText}"');
  }

  void _castConfirmed(Spell spell) async {
    _playEffect(spell);

    try {
      if (spell.id == 'lumos' || spell.id == 'lumos_maxima') {
        await TorchLight.enableTorch();
      } else if (spell.id == 'nox') {
        await TorchLight.disableTorch();
      } else if (spell.id == 'alohomora') {
        const AndroidIntent(action: 'android.settings.SECURITY_SETTINGS').launch();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _status = 'جادوی ${spell.name} اجرا شد!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFC9A227), fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () async {
                  bool available = await _speech.initialize();
                  if (available) {
                    _speech.listen(
                      localeId: 'en_US',
                      onResult: (res) {
                        if (res.finalResult) {
                          _castSpell(res.recognizedWords);
                        }
                      },
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC9A227), width: 2),
                    color: const Color(0xFFC9A227).withOpacity(0.2),
                  ),
                  child: const Icon(Icons.mic, size: 50, color: Color(0xFFC9A227)),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E0F32),
                  foregroundColor: const Color(0xFFC9A227),
                  side: const BorderSide(color: Color(0xFFC9A227)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SpellbookPage()),
                ),
                icon: const Icon(Icons.menu_book),
                label: const Text("کتاب طلسم‌ها"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpellbookPage extends StatelessWidget {
  const SpellbookPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("کتاب طلسم‌ها", style: TextStyle(color: Color(0xFFC9A227))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFC9A227)),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView.builder(
          itemCount: allSpells.length,
          itemBuilder: (context, index) {
            final spell = allSpells[index];
            return Card(
              color: const Color(0xFF1E0F32).withOpacity(0.8),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(spell.icon, color: spell.effectColor),
                title: Text(spell.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(spell.desc, style: const TextStyle(color: Colors.white70)),
              ),
            );
          },
        ),
      ),
    );
  }
}
