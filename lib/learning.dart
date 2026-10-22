import 'dart:convert';
import 'package:flutter/material.dart';
import 'buddy_analytics.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningScreen extends StatefulWidget {
  final int initialTab;
  final String level;
  const LearningScreen({super.key, required this.initialTab, required this.level});
  @override State<LearningScreen> createState() => _LearningScreenState();
}
class _LearningScreenState extends State<LearningScreen> {
  Map<String, dynamic>? content;
  late int tab;
  Map<String, dynamic> history = {};
  @override void initState() { super.initState(); tab=widget.initialTab; load(); }
  Future<void> load() async {
    final raw=await rootBundle.loadString('assets/review_content.json');
    final prefs=await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {content=jsonDecode(raw) as Map<String,dynamic>; history=jsonDecode(prefs.getString('quiz_history')??'{}') as Map<String,dynamic>;});
  }
  List<Map<String,dynamic>> get subjects => (content?['subjects'] as List? ?? []).cast<Map<String,dynamic>>().where((s)=>(s['levels'] as List).contains(widget.level)).toList();
  List<Map<String,dynamic>> get questions => (content?['questions'] as List? ?? []).cast<Map<String,dynamic>>().where((q)=>(q['levels'] as List).contains(widget.level)).toList();
  List<Map<String,dynamic>> get lessons => (content?['lessons'] as List? ?? []).cast<Map<String,dynamic>>();
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Learning Center')),
    body: content==null ? const Center(child:CircularProgressIndicator()) : Column(children:[
      NavigationBar(selectedIndex:tab, onDestinationSelected:(v)=>setState(()=>tab=v), destinations:const [NavigationDestination(icon:Icon(Icons.menu_book),label:'Lessons'),NavigationDestination(icon:Icon(Icons.quiz),label:'Practice'),NavigationDestination(icon:Icon(Icons.insights),label:'Progress')]),
      Expanded(child:tab==2?progressView():ListView(padding:const EdgeInsets.all(16),children:[
        Text(tab==0?'Study by subject':'Choose a practice subject',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),
        for (final subject in subjects)
          Card(
            child: ListTile(
              title: Text(subject['title'] as String),
              subtitle: Text(subject['description'] as String),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final subjectId = subject['id'] as String;
                if (tab == 0) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => LessonList(
                      subject: subject,
                      lessons: lessons.where((l) => l['subjectId'] == subjectId).toList(),
                    ),
                  ));
                } else {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => QuizScreen(
                      subject: subject,
                      questions: questions.where((q) => q['subjectId'] == subjectId).toList(),
                      onFinish: (score, total) async {
                        final prefs = await SharedPreferences.getInstance();
                        final updated = Map<String, dynamic>.from(history);
                        updated[subjectId] = {
                          'score': score,
                          'total': total,
                          'date': DateTime.now().toIso8601String(),
                        };
                        await prefs.setString('quiz_history', jsonEncode(updated));
                        await AttemptStore.add(
                          mode: 'practice',
                          level: widget.level,
                          score: score,
                          total: total,
                          elapsedSeconds: 0,
                          subjectStats: {subjectId: [score, total]},
                        );
                        if (mounted) setState(() => history = updated);
                      },
                    ),
                  ));
                }
              },
            ),
          ),
        const SizedBox(height:14),
        const Text('Sample original content only. This is not an official CSC question bank.',style:TextStyle(fontSize:12)),
      ])),
    ]),
  );
  Widget progressView() => ListView(padding:const EdgeInsets.all(18),children:[
    Text('Latest practice results',style:Theme.of(context).textTheme.titleLarge),
    const SizedBox(height:10),
    if(history.isEmpty) const Text('No quiz attempts yet. Complete a practice set to see your results.'),
    for(final s in subjects) if(history.containsKey(s['id'])) Card(child:ListTile(title:Text(s['title'] as String),subtitle:Text('Latest score: ${history[s['id']]['score']} / ${history[s['id']]['total']}'),trailing:Text('${((history[s['id']]['score'] as num)/(history[s['id']]['total'] as num)*100).round()}%'))),
    const SizedBox(height:16),const Text('Results are stored locally on this device. Cloud sync and detailed analytics are planned for later phases.'),
  ]);
}
class LessonList extends StatelessWidget {
  final Map<String,dynamic> subject;
  final List<Map<String,dynamic>> lessons;
  const LessonList({super.key,required this.subject,required this.lessons});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(subject['title'] as String)),body:ListView(padding:const EdgeInsets.all(16),children:[
    if(lessons.isEmpty) const Text('Lessons for this subject are being prepared.'),
    for (final lesson in lessons)
      Card(
        child: ExpansionTile(
          title: Text(lesson['title'] as String),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson['body'] as String),
                  const SizedBox(height: 12),
                  Text(lesson['example'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
  ]));
}
class QuizScreen extends StatefulWidget {
  final Map<String,dynamic> subject;
  final List<Map<String,dynamic>> questions;
  final Future<void> Function(int,int) onFinish;
  const QuizScreen({super.key,required this.subject,required this.questions,required this.onFinish});
  @override State<QuizScreen> createState()=>_QuizScreenState();
}
class _QuizScreenState extends State<QuizScreen> {
  int index=0,score=0;
  int? selected;
  bool completed=false;
  @override Widget build(BuildContext context){
    if(widget.questions.isEmpty)return Scaffold(appBar:AppBar(title:Text(widget.subject['title'] as String)),body:const Center(child:Text('No questions available yet.')));
    if(completed)return Scaffold(appBar:AppBar(title:const Text('Quiz result')),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.emoji_events,size:72),Text('$score / ${widget.questions.length}',style:Theme.of(context).textTheme.displaySmall),const SizedBox(height:10),const Text('Your latest score has been saved on this device.'),const SizedBox(height:18),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Back to subjects'))]))));
    final q=widget.questions[index];final options=(q['options'] as List).cast<String>();final correct=q['correctIndex'] as int;
    return Scaffold(appBar:AppBar(title:Text(widget.subject['title'] as String)),body:SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
      Text('Question ${index+1} of ${widget.questions.length}',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:8),LinearProgressIndicator(value:(index+1)/widget.questions.length),const SizedBox(height:20),Text(q['prompt'] as String,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:18),
      for(var i=0;i<options.length;i++) Card(child:RadioListTile<int>(title:Text(options[i]),value:i,groupValue:selected,onChanged:selected==null?(v)=>setState(()=>selected=v):null)),
      if(selected!=null) Card(color:Theme.of(context).colorScheme.surfaceContainerHighest,child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(selected==correct?'Correct!':'Not quite. Correct answer: ${options[correct]}',style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:6),Text(q['explanation'] as String)]))),
      const SizedBox(height:18),FilledButton(onPressed:selected==null?null:() async {if(selected==correct)score++;if(index==widget.questions.length-1){await widget.onFinish(score,widget.questions.length);if(mounted)setState(()=>completed=true);}else{setState((){index++;selected=null;});}},child:Text(index==widget.questions.length-1?'Finish quiz':'Next question')),
    ])));
  }
}
