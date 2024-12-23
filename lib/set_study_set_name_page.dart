import 'package:flutter/material.dart';

class SetStudySetNamePage extends StatelessWidget {
  final String initialName;

  const SetStudySetNamePage({Key? key, required this.initialName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController(text: initialName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('セット名の編集'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, controller.text);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'セット名',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context, controller.text);
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}