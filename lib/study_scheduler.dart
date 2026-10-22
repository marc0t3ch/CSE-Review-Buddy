import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications are best-effort; Android power settings can delay delivery.
class StudyNotifications {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool ready = false;
  static Future<void> initialize() async {
    if (ready) return;
    tzdata.initializeTimeZones();
    try { tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone())); }
    catch (_) { tz.setLocalLocation(tz.UTC); } // Safe fallback; never assume the user's timezone.
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: android));
    ready = true;
  }
  static Future<bool> requestPermission() async {
    await initialize();
    return await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? false;
  }
  static Future<void> refresh() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    await plugin.cancelAll(); // Phase 3 owns all local notifications.
    if (!(prefs.getBool('remindersEnabled') ?? true)) return;
    final exam = DateTime.tryParse(prefs.getString('examDate') ?? '');
    if (exam == null) return;
    final start = prefs.getInt('startMinutes') ?? 1140;
    final duration = prefs.getInt('studyMinutes') ?? 120;
    final breakLength = prefs.getInt('breakMinutes') ?? 10;
    final weekdays = prefs.getStringList('studyWeekdays')?.map(int.tryParse).whereType<int>().toSet() ?? {1,2,3,4,5,6,7};
    final now = tz.TZDateTime.now(tz.local);
    const details = NotificationDetails(android: AndroidNotificationDetails(
      'study_routine', 'Daily study routine', channelDescription: 'CSE study, rest and session completion reminders',
      importance: Importance.max, priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      playSound: true, enableVibration: true,
      fullScreenIntent: true, ongoing: true, autoCancel: false));
    var id = 1000;
    for (var day = 0; day < 30; day++) {
      final d = DateTime(now.year, now.month, now.day + day); // Calendar days, safe across DST.
      if (d.isAfter(DateUtils.dateOnly(exam)) || !weekdays.contains(d.weekday)) continue;
      final begin = tz.TZDateTime(tz.local, d.year, d.month, d.day, start ~/ 60, start % 60);
      final end = begin.add(Duration(minutes: duration));
      final half = (duration - breakLength) ~/ 2;
      final events = <(tz.TZDateTime, String, String)>[
        (begin, 'Time to study, Buddy! 📚', 'Your CSE review session starts now.'),
        if (breakLength > 0 && half > 0) (begin.add(Duration(minutes: half)), 'Time for a break ☕', 'Stretch, hydrate and rest your eyes.'),
        if (breakLength > 0 && half > 0) (begin.add(Duration(minutes: half + breakLength)), 'Let’s resume! 💪', 'Ready for the second part of your review?'),
        (end, 'Study window complete! 🎉', 'Great effort! Enjoy your free time.'),
      ];
      for (final e in events) {
        if (!e.$1.isAfter(now)) continue;
        await plugin.zonedSchedule(id++, e.$2, e.$3, e.$1, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
      }
    }
  }
}

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});
  @override State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}
class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  int start = 1140, duration = 120, breakLength = 10;
  bool enabled = true, saving = false;
  Set<int> weekdays = {1,2,3,4,5,6,7};
  DateTime? exam;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { start=p.getInt('startMinutes')??1140; duration=p.getInt('studyMinutes')??120;
      breakLength=p.getInt('breakMinutes')??10; enabled=p.getBool('remindersEnabled')??true;
      weekdays=p.getStringList('studyWeekdays')?.map(int.tryParse).whereType<int>().toSet()??{1,2,3,4,5,6,7};
      exam=DateTime.tryParse(p.getString('examDate')??''); });
  }
  Future<void> _save() async {
    if (weekdays.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Choose at least one study day.'))); return; }
    setState(()=>saving=true);
    try {
      final p=await SharedPreferences.getInstance();
      await p.setInt('startMinutes',start);await p.setInt('studyMinutes',duration);
      await p.setInt('breakMinutes',breakLength);await p.setBool('remindersEnabled',enabled);
      await p.setStringList('studyWeekdays',weekdays.map((d)=>'$d').toList());
      if(exam!=null)await p.setString('examDate',exam!.toIso8601String());
      final permissionGranted = !enabled || await StudyNotifications.requestPermission();
      await StudyNotifications.refresh();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(permissionGranted ? 'Schedule saved. Upcoming study alarms scheduled.' : 'Schedule saved, but notifications are not permitted. Enable notifications in Android settings.')));
    } catch(e) { if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Unable to schedule reminders: $e'))); }
    finally { if(mounted)setState(()=>saving=false); }
  }
  @override Widget build(BuildContext context) {
    final t=TimeOfDay(hour:start~/60,minute:start%60);
    final end=TimeOfDay(hour:((start+duration)~/60)%24,minute:(start+duration)%60);
    return Scaffold(appBar:AppBar(title:const Text('My Study Planner')),
      body:SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
        Text('Your daily routine',style:Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height:10),SwitchListTile(title:const Text('Study alarms'),subtitle:const Text('Audible, high-priority study, break and finish alerts'),value:enabled,onChanged:(v)=>setState(()=>enabled=v)),
        Card(child:ListTile(leading:const Icon(Icons.schedule),title:const Text('Study starts'),subtitle:Text(t.format(context)),onTap:()async{final v=await showTimePicker(context:context,initialTime:t);if(v!=null)setState(()=>start=v.hour*60+v.minute);})),
        const SizedBox(height:10),Text('Study window: ${duration~/60}h ${duration%60}m'),
        Slider(min:30,max:360,divisions:11,value:duration.toDouble(),label:'$duration min',onChanged:(v)=>setState(()=>duration=v.round())),
        DropdownButtonFormField<int>(value:breakLength,decoration:const InputDecoration(labelText:'Break length (included in study window)',border:OutlineInputBorder()),items:[0,5,10,15,20].map((v)=>DropdownMenuItem(value:v,child:Text('$v minutes'))).toList(),onChanged:(v)=>setState(()=>breakLength=v??10)),
        const SizedBox(height:16),const Text('Study days'),
        Wrap(spacing:6,children:[for(var d=1;d<=7;d++) FilterChip(label:Text(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d-1]),selected:weekdays.contains(d),onSelected:(v)=>setState(()=>v?weekdays.add(d):weekdays.remove(d)))]),
        const SizedBox(height:10),Card(child:ListTile(leading:const Icon(Icons.event),title:const Text('Examination date'),subtitle:Text(exam==null?'Choose a date':'${exam!.year}-${exam!.month.toString().padLeft(2,'0')}-${exam!.day.toString().padLeft(2,'0')}'),onTap:()async{final now=DateUtils.dateOnly(DateTime.now());final v=await showDatePicker(context:context,initialDate:exam!=null&&!exam!.isBefore(now)?exam!:now,firstDate:now,lastDate:DateTime(now.year+5));if(v!=null)setState(()=>exam=v);})),
        const SizedBox(height:10),Text('Session ends at ${end.format(context)}. The break is part of the total window.'),
        const SizedBox(height:18),FilledButton.icon(onPressed:saving?null:_save,icon:const Icon(Icons.save),label:Text(saving?'Saving…':'Save schedule and alarms')),
        const SizedBox(height:12),const Text('Alarm-style alerts use sound, vibration and a full-screen intent request. Android may restrict full-screen display, sound or exact timing depending on permissions, device policy and battery settings. Alerts are scheduled for the next 30 days and refreshed when the app opens.',style:TextStyle(fontSize:12)),
        const SizedBox(height:16),const Divider(),
        Text('Study session timer',style:Theme.of(context).textTheme.titleLarge),
        const Text('Start or resume a timed study session; the countdown uses wall-clock time so it remains accurate after backgrounding.'),
        const SizedBox(height:8),SessionTimer(durationMinutes:duration),
      ])));
  }
}
class SessionTimer extends StatefulWidget {
  final int durationMinutes;
  const SessionTimer({super.key,required this.durationMinutes});
  @override State<SessionTimer> createState()=>_SessionTimerState();
}
class _SessionTimerState extends State<SessionTimer> with WidgetsBindingObserver {
  DateTime? deadline;
  Duration remaining=Duration.zero;
  Timer? ticker;
  bool completionSoundPlayed=false;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_restore();}
  Future<void> _restore() async {final p=await SharedPreferences.getInstance();final raw=p.getString('activeStudyDeadline');if(raw!=null){final d=DateTime.tryParse(raw);if(d!=null&&d.isAfter(DateTime.now())){deadline=d;_tick();_startTicker();}}}
  void _startTicker(){ticker?.cancel();ticker=Timer.periodic(const Duration(seconds:1),(_)=>_tick());}
  void _tick(){if(!mounted)return;final r=deadline?.difference(DateTime.now())??Duration.zero;if(r<=Duration.zero){ticker?.cancel();if(deadline!=null && !completionSoundPlayed){completionSoundPlayed=true;SystemSound.play(SystemSoundType.alert);SystemSound.play(SystemSoundType.alert);}}setState(()=>remaining=r>Duration.zero?r:Duration.zero);}
  Future<void> _start() async {completionSoundPlayed=false;deadline=DateTime.now().add(Duration(minutes:widget.durationMinutes));final p=await SharedPreferences.getInstance();await p.setString('activeStudyDeadline',deadline!.toIso8601String());_tick();_startTicker();}
  Future<void> _stop() async {ticker?.cancel();deadline=null;completionSoundPlayed=true;final p=await SharedPreferences.getInstance();await p.remove('activeStudyDeadline');if(mounted)setState(()=>remaining=Duration.zero);}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)_tick();}
  @override void dispose(){ticker?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override Widget build(BuildContext context){final s=remaining.inSeconds;return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[Text('${(s~/3600).toString().padLeft(2,'0')}:${((s%3600)~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}',style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.center,children:[FilledButton(onPressed:deadline==null?_start:null,child:const Text('Start session')),const SizedBox(width:12),OutlinedButton(onPressed:deadline!=null?_stop:null,child:const Text('Stop'))])])));}
}
