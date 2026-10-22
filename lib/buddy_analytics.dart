import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttemptStore {
  static const key = 'attempt_log_v1';
  static Future<List<Map<String, dynamic>>> read() async {
    final p = await SharedPreferences.getInstance();
    try { return (jsonDecode(p.getString(key) ?? '[]') as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList(); }
    catch (_) { return []; }
  }
  static Future<void> add({required String mode, required String level,
      required int score, required int total, required int elapsedSeconds,
      required Map<String, List<int>> subjectStats}) async {
    final p = await SharedPreferences.getInstance();
    final rows = await read();
    rows.add({'mode':mode,'level':level,'score':score,'total':total,
      'elapsedSeconds':elapsedSeconds,'subjectStats':subjectStats,
      'at':DateTime.now().toIso8601String()});
    if(rows.length > 300) rows.removeRange(0,rows.length-300);
    await p.setString(key,jsonEncode(rows));
  }
}

class BuddyHub extends StatefulWidget {
  final String level;
  final DateTime? examDate;
  const BuddyHub({super.key,required this.level,this.examDate});
  @override State<BuddyHub> createState()=>_BuddyHubState();
}
class _BuddyHubState extends State<BuddyHub> {
  Map<String,dynamic>? content;
  List<Map<String,dynamic>> attempts=[];
  @override void initState(){super.initState();reload();}
  Future<void> reload() async {
    final raw=await rootBundle.loadString('assets/review_content.json');
    final log=await AttemptStore.read();
    if(mounted)setState((){content=jsonDecode(raw) as Map<String,dynamic>;attempts=log.where((a)=>a['level']==widget.level).toList();});
  }
  Map<String,List<int>> get stats {
    final result=<String,List<int>>{};
    for(final a in attempts){
      final parts=Map<String,dynamic>.from(a['subjectStats'] as Map? ?? {});
      for(final e in parts.entries){
        final values=(e.value as List).cast<num>();
        final current=result.putIfAbsent(e.key,()=>[0,0]);
        current[0]+=values[0].toInt();current[1]+=values[1].toInt();
      }
    }
    return result;
  }
  @override Widget build(BuildContext context){
    final s=stats;
    final subjects=(content?['subjects'] as List? ?? []).cast<Map<String,dynamic>>()
        .where((x)=>(x['levels'] as List).contains(widget.level)).toList();
    final ranked=subjects.where((x)=>s.containsKey(x['id']) && s[x['id']]![1]>0).toList()
      ..sort((a,b){final aa=s[a['id']]!,bb=s[b['id']]!;
        return (aa[0]/aa[1]).compareTo(bb[0]/bb[1]);});
    final days=widget.examDate==null?null:DateUtils.dateOnly(widget.examDate!).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    final totalCorrect=attempts.fold<int>(0,(v,a)=>v+(a['score'] as num).toInt());
    final totalQuestions=attempts.fold<int>(0,(v,a)=>v+(a['total'] as num).toInt());
    final dates=attempts.map((a)=>DateTime.tryParse(a['at'] as String? ?? '')).whereType<DateTime>()
        .map((d)=>DateUtils.dateOnly(d).toIso8601String().substring(0,10)).toSet();
    var streak=0;var day=DateUtils.dateOnly(DateTime.now());
    if(!dates.contains(day.toIso8601String().substring(0,10)))day=day.subtract(const Duration(days:1));
    while(dates.contains(day.toIso8601String().substring(0,10))){streak++;day=day.subtract(const Duration(days:1));}
    final advice=ranked.isEmpty?'Start with a short practice quiz. Your Buddy will recommend topics after collecting results.'
      :'Focus on ${ranked.first['title']} next: your recorded accuracy is ${(100*s[ranked.first['id']]![0]/s[ranked.first['id']]![1]).round()}%. Review the lesson, then retry practice.';
    return Scaffold(appBar:AppBar(title:const Text('My Study Buddy')),
      body:content==null?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Your Buddy says',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),Text(advice),
        if(days!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(days>7?'$days days to go. Keep a sustainable daily routine.':days>0?'Final week: revise key ideas, prepare requirements and protect sleep.':'Check your exam schedule and next steps.')),
      ]))),
      const SizedBox(height:12),Wrap(spacing:10,runSpacing:10,children:[
        Chip(label:Text('${attempts.length} completed attempts')),
        Chip(label:Text(totalQuestions==0?'Accuracy: —':'Accuracy: ${(100*totalCorrect/totalQuestions).round()}%')),
        Chip(label:Text('$streak-day practice streak')),
      ]),const SizedBox(height:16),Text('Subject performance',style:Theme.of(context).textTheme.titleLarge),
      for(final subject in subjects)Builder(builder:(_){final v=s[subject['id']];final pct=v==null||v[1]==0?null:v[0]/v[1];return Card(child:ListTile(
        title:Text(subject['title'] as String),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const SizedBox(height:7),LinearProgressIndicator(value:pct??0),const SizedBox(height:5),
          Text(pct==null?'No recorded mock exam or practice results':'${v![0]} correct / ${v[1]} questions'),
        ]),trailing:Text(pct==null?'—':'${(pct*100).round()}%')));}),
      const SizedBox(height:14),FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>MockExamScreen(level:widget.level))).then((_)=>reload()),icon:const Icon(Icons.timer),label:const Text('Take a timed mock exam')),
      const SizedBox(height:14),const Text('Readiness metrics are based only on available practice attempts. They do not predict CSC exam results. The sample bank is too small for a realistic full-length mock examination.',style:TextStyle(fontSize:12)),
    ]));
  }
}

class MockExamScreen extends StatefulWidget {
  final String level;
  const MockExamScreen({super.key,required this.level});
  @override State<MockExamScreen> createState()=>_MockExamScreenState();
}
class _MockExamScreenState extends State<MockExamScreen> with WidgetsBindingObserver {
  List<Map<String,dynamic>> questions=[];
  final answers=<String,int>{};
  DateTime? deadline,started;
  Timer? timer;
  int secondsRemaining=0,index=0;
  bool submitted=false,loading=true;
  static const weights = {'verbal':30,'analytical':35,'numerical':30,'general':5};
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)tick();}
  Future<void> load() async {
    final data=jsonDecode(await rootBundle.loadString('assets/review_content.json')) as Map<String,dynamic>;
    final bank=(data['questions'] as List).cast<Map<String,dynamic>>()
        .where((q)=>(q['levels'] as List).contains(widget.level)).toList();
    final rng=Random();
    // Professional blueprint: 20 questions = 6 verbal, 7 analytical,
    // 6 numerical, 1 general. Require sufficient unique items per subject.
    final items=<Map<String,dynamic>>[];
    if(widget.level=='Professional') {
      for(final entry in weights.entries){
        final pool=bank.where((q)=>q['subjectId']==entry.key).toList()..shuffle(rng);
        final count=entry.value~/5;
        if(pool.length<count){
          if(mounted)setState((){questions=[];loading=false;});
          return;
        }
        items.addAll(pool.take(count));
      }
      items.shuffle(rng);
    } else {
      // Subprofessional uses its own subject coverage, not the Professional blueprint.
      items.addAll(bank..shuffle(rng));
    }
    final now=DateTime.now();
    if(!mounted)return;
    setState((){questions=items;started=now;secondsRemaining=items.length*75;
      deadline=now.add(Duration(seconds:secondsRemaining));loading=false;});
    timer=Timer.periodic(const Duration(seconds:1),(_)=>tick());
  }
  void tick(){if(!mounted||submitted||deadline==null)return;
    final remaining=max(0,deadline!.difference(DateTime.now()).inSeconds);
    if(remaining==0){submit();return;}setState(()=>secondsRemaining=remaining);
  }
  Future<void> submit() async {
    if(submitted)return;timer?.cancel();
    var score=0;final stats=<String,List<int>>{};
    for(final q in questions){final id=q['id'] as String,subject=q['subjectId'] as String;
      final v=stats.putIfAbsent(subject,()=>[0,0]);v[1]++;
      if(answers[id]==q['correctIndex']){score++;v[0]++;}}
    await AttemptStore.add(mode:'weighted_mock',level:widget.level,score:score,total:questions.length,
      elapsedSeconds:DateTime.now().difference(started!).inSeconds,subjectStats:stats);
    if(mounted)setState(()=>submitted=true);
  }
  @override void dispose(){timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(questions.isEmpty)return Scaffold(appBar:AppBar(title:const Text('Sample mock exam')),body:const Center(child:Text('Not enough unique questions for this exam blueprint yet.')));
    if(submitted){final score=questions.where((q)=>answers[q['id']]==q['correctIndex']).length;
      return Scaffold(appBar:AppBar(title:const Text('Mock exam results')),body:ListView(padding:const EdgeInsets.all(20),children:[
        Text('$score / ${questions.length}',style:Theme.of(context).textTheme.displayMedium),
        const Text('Timed practice completed. Answers and explanations:'),const SizedBox(height:12),
        for(final q in questions)Card(child:ExpansionTile(title:Text(q['prompt'] as String),subtitle:Text(answers[q['id']]==q['correctIndex']?'Correct':'Incorrect or unanswered'),children:[Padding(padding:const EdgeInsets.all(14),child:Text('Correct answer: ${(q['options'] as List)[q['correctIndex']]}\n\n${q['explanation']}'))])),
        FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Back to Buddy')),
      ]));}
    final q=questions[index],opts=(q['options'] as List).cast<String>();
    return Scaffold(appBar:AppBar(title:const Text('Timed mock exam'),actions:[TextButton(onPressed:submit,child:const Text('Submit'))]),
      body:ListView(padding:const EdgeInsets.all(18),children:[
        Text('Time remaining: ${secondsRemaining~/60}:${(secondsRemaining%60).toString().padLeft(2,'0')}',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),LinearProgressIndicator(value:(index+1)/questions.length),const SizedBox(height:12),
        Text('Question ${index+1} of ${questions.length}',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:12),Text(q['prompt'] as String,style:Theme.of(context).textTheme.titleLarge),
        for(var i=0;i<opts.length;i++)RadioListTile<int>(title:Text(opts[i]),value:i,groupValue:answers[q['id']],onChanged:(v)=>setState(()=>answers[q['id'] as String]=v!)),
        const SizedBox(height:12),Row(children:[
          OutlinedButton(onPressed:index==0?null:()=>setState(()=>index--),child:const Text('Previous')),
          const Spacer(),FilledButton(onPressed:index==questions.length-1?submit:()=>setState(()=>index++),child:Text(index==questions.length-1?'Finish':'Next')),
        ]),const SizedBox(height:12),Text('${answers.length} of ${questions.length} answered'),
        const Text('Original practice simulation; Professional mock uses the requested 30/35/30/5 blueprint, not an independently verified official CSC distribution or time limit.',style:TextStyle(fontSize:12)),
      ]));
  }
}
