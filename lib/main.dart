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

  void _castSpell(String text) async {
    final String normalizedText = _normalize(text);

    // برای دیباگ: ببین سیستم دقیقاً چی شنیده
    debugPrint('SHENIDE (recognized): "$normalizedText"');

    for (var spell in allSpells) {
      // مقایسه با name (انگلیسی) چون تشخیص گفتار روی en_US است
      final String normalizedName = _normalize(spell.name);
      if (normalizedText.contains(normalizedName)) {
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
        return;
      }
    }

    // نمایش متنی که واقعاً شنیده شده
    setState(() => _status = 'ناشناخته: "${normalizedText}"');
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
