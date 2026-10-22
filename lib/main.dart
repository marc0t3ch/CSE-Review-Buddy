import 'package:flutter/material.dart';
import 'learning.dart';
import 'buddy_analytics.dart';
import 'study_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await StudyNotifications.refresh(); } catch (_) { /* app still opens if notifications unavailable */ }
  runApp(const ReviewBuddyApp());
}

class ReviewBuddyApp extends StatelessWidget {
  const ReviewBuddyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CSE Review Buddy', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7257CB)), useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF9F7FE)),
    home: const LaunchScreen(),
  );
}

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});
  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}
class _LaunchScreenState extends State<LaunchScreen> {
  bool loading = true;
  bool setup = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { setup = prefs.getBool('setup') ?? false; loading = false; });
  }
  @override
  Widget build(BuildContext context) => loading ? const Scaffold(body: Center(child: CircularProgressIndicator())) : setup ? const Dashboard() : const Onboarding();
}

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}
class _OnboardingState extends State<Onboarding> {
  final name = TextEditingController();
  String level = 'Professional';
  DateTime? examDate;
  TimeOfDay start = const TimeOfDay(hour: 19, minute: 0);
  double hours = 2;
  bool saving = false;
  @override
  void dispose() { name.dispose(); super.dispose(); }
  Future<void> save() async {
    if (name.text.trim().isEmpty || examDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your name and select an exam date.')));
      return;
    }
    if (DateUtils.dateOnly(examDate!).isBefore(DateUtils.dateOnly(DateTime.now()))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose today or a future examination date.')));
      return;
    }
    setState(() => saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name.text.trim());
    await prefs.setString('level', level);
    await prefs.setString('examDate', examDate!.toIso8601String());
    await prefs.setInt('startMinutes', start.hour * 60 + start.minute);
    await prefs.setInt('studyMinutes', (hours * 60).round());
    await prefs.setBool('setup', true);
    try { await StudyNotifications.requestPermission(); await StudyNotifications.refresh(); } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Dashboard()));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set up your Study Buddy')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.school_rounded, size: 64, color: Color(0xFF7257CB)),
      const SizedBox(height: 12),
      Text('Your CSE journey starts here', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      TextField(controller: name, maxLength: 60, decoration: const InputDecoration(labelText: 'Your preferred name', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: level, decoration: const InputDecoration(labelText: 'Exam level', border: OutlineInputBorder()), items: ['Professional', 'Subprofessional'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => level = v!)),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: () async {
        final now = DateTime.now();
        final date = await showDatePicker(context: context, firstDate: DateUtils.dateOnly(now), lastDate: DateTime(now.year + 5), initialDate: examDate ?? now);
        if (date != null) setState(() => examDate = date);
      }, icon: const Icon(Icons.event), label: Text(examDate == null ? 'Choose examination date' : 'Exam: ${examDate!.year}-${examDate!.month.toString().padLeft(2, '0')}-${examDate!.day.toString().padLeft(2, '0')}')),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () async {
        final time = await showTimePicker(context: context, initialTime: start);
        if (time != null) setState(() => start = time);
      }, icon: const Icon(Icons.schedule), label: Text('Study starts: ${start.format(context)}')),
      const SizedBox(height: 12),
      Text('Daily study window: ${hours.toInt()} hour(s)'),
      Slider(value: hours, min: 1, max: 6, divisions: 5, label: '${hours.toInt()}h', onChanged: (v) => setState(() => hours = v)),
      const SizedBox(height: 20),
      FilledButton(onPressed: saving ? null : save, child: const Padding(padding: EdgeInsets.all(14), child: Text('Create my study plan'))),
      const SizedBox(height: 12),
      const Text('This prototype stores settings on your device. Settings are saved on this device. Study notifications require permission and may be delayed by Android power settings.', textAlign: TextAlign.center),
    ])),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}
class _DashboardState extends State<Dashboard> {
  String name = 'Buddy', level = 'Professional';
  DateTime? examDate;
  int startMinutes = 1140, studyMinutes = 120;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      name = prefs.getString('name') ?? 'Buddy'; level = prefs.getString('level') ?? 'Professional';
      examDate = DateTime.tryParse(prefs.getString('examDate') ?? '');
      startMinutes = prefs.getInt('startMinutes') ?? 1140; studyMinutes = prefs.getInt('studyMinutes') ?? 120;
    });
  }
  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final remaining = examDate == null ? null : DateUtils.dateOnly(examDate!).difference(today).inDays;
    final time = TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60).format(context);
    return Scaffold(appBar: AppBar(title: const Text('CSE Review Buddy')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Hello, $name! 👋', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8), Text('$level CSE preparation'), const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('EXAM COUNTDOWN'), const SizedBox(height: 10),
        Text(remaining == null ? 'Set an exam date' : remaining <= 0 ? 'Examination day has arrived' : '$remaining days remaining', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6), const Text('Keep building your confidence, one session at a time.'),
      ]))),
      Card(child: ListTile(leading: const Icon(Icons.alarm), title: const Text('Your daily study plan'), subtitle: Text('Starts $time • ${studyMinutes ~/ 60} hour(s)'), trailing: const Icon(Icons.alarm))),
      const SizedBox(height: 18),
      Text('Your learning spaces', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      for (final item in [('Review Library', Icons.menu_book), ('Practice Questions', Icons.quiz), ('My Progress', Icons.insights), ('Study Planner', Icons.alarm), ('My Study Buddy', Icons.auto_awesome)])
        Card(child: ListTile(leading: Icon(item.$2), title: Text(item.$1), subtitle: const Text('Open learning module'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.$1 == 'Study Planner' ? const StudyPlannerScreen() : item.$1 == 'My Study Buddy' ? BuddyHub(level: level, examDate: examDate) : LearningScreen(initialTab: item.$1 == 'Review Library' ? 0 : item.$1 == 'Practice Questions' ? 1 : 2, level: level))))),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: () async {
        final prefs = await SharedPreferences.getInstance(); await prefs.remove('setup');
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Onboarding()));
      }, child: const Text('Restart onboarding (keeps study history)')),
    ])));
  }
}
