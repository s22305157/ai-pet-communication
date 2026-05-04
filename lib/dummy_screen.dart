import 'package:flutter/material.dart';

class DummyScreen extends StatelessWidget {
  const DummyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Text(
          '隔離測試：如果你看到藍色，代表引擎已啟動',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
