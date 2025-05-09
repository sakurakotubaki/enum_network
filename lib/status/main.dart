import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

// 状態によって表示するWidgetを切り替えるEnum
// タイマーの起動を管理する
enum StatusEnum {
  pending(title: '起動中'),
  start(title: 'スタート'),
  end(title: '終了');


  final String title;
  const StatusEnum({required this.title});

  StatusEnum get next {
    switch (this) {
      case StatusEnum.pending:
        return StatusEnum.start;
      case StatusEnum.start:
        return StatusEnum.end;
      case StatusEnum.end:
        return StatusEnum.pending;
    }
  }
}

// Statusによってテキストが変わるWidget
class StatusText extends StatelessWidget {
  const StatusText({super.key, required this.status});

  final StatusEnum status;

  @override
  Widget build(BuildContext context) {
    return Text(status.title);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StateEnum(),
    );
  }
}

class StateEnum extends StatefulWidget {
  const StateEnum({super.key});

  @override
  State<StateEnum> createState() => _StateEnumState();
}

class _StateEnumState extends State<StateEnum> {
  StatusEnum _status = StatusEnum.pending;

  // カウント用のタイマー
  double _count = 0;
  // タイマーオブジェクト
  Timer? _timer;
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // タイマーの開始
  void _startTimer() {
    setState(() {
      _status = StatusEnum.start;
      _count = 0; // カウントをリセット
    });
    
    // 0.1秒ごとにカウントを増やす
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _count += 0.1;
      });
    });

    // 5秒後にタイマーを終了
    Future.delayed(const Duration(seconds: 5), () {
      _timer?.cancel();
      setState(() {
        _status = StatusEnum.end;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Timer'),
      ),
      body: Center(
        child: Column(
          spacing: 20,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$_count'),
            StatusText(status: _status),
            ElevatedButton(
              onPressed: _status == StatusEnum.pending ? _startTimer : null,
              child: const Text('Start Timer'),
            ),
            // ステータスが終了の場合、リセットボタンを表示
            if (_status == StatusEnum.end)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _status = StatusEnum.pending;
                  });
                },
                child: const Text('Reset'),
              ),
          ],
        ),
      ),
    );
  }
}