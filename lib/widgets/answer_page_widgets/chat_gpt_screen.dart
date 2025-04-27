import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repaso/utils/app_colors.dart';

/// このファイルだけで完結する、Vertex AI チャット画面（Cloud Functions 経由）
class ChatGPTScreen extends StatefulWidget {
  const ChatGPTScreen({Key? key}) : super(key: key);

  @override
  State<ChatGPTScreen> createState() => _ChatGPTScreenState();
}

class _ChatGPTScreenState extends State<ChatGPTScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_Message> _messages = [
    _Message(
      text:
      "ご指摘いただきありがとうございます！\n問題文を修正しました🙇‍♂️\n\n<修正内容>\n全開時→全閉時",
      isUser: false,
      userName: "yuki",
      createdAt: DateTime(2025, 4, 20, 15, 18),
    ),
    _Message(
      text: "I",
      isUser: false,
      userName: "未設定",
      createdAt: DateTime(2025, 4, 21, 1, 10),
    ),
  ];
  bool _isSending = false;

  /// Firebase Functions の callVertexAI を呼び出し
  final HttpsCallable _callVertex =
  FirebaseFunctions.instance.httpsCallable('callVertexAI');

  Future<String> _sendToVertexAI(String userMessage) async {
    try {
      // 認証状態チェック（匿名ログイン等を済ませておくこと）
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return '未ログインのため利用できません';

      // Cloud Function をコール
      final result = await _callVertex.call(<String, dynamic>{
        'message': userMessage,
      });

      final data = result.data as Map<String, dynamic>;
      return data['reply'] as String;

    } on FirebaseFunctionsException catch (e) {
      // FirebaseFunctionsException の詳細をデバッグ出力
      debugPrint('=== FirebaseFunctionsException ===');
      debugPrint('code: ${e.code}');
      debugPrint('message: ${e.message}');
      debugPrint('details: ${e.details}');
      debugPrint('stackTrace: ${e.stackTrace}');
      return 'エラー(${e.code}): ${e.message}';

    } catch (e, st) {
      // その他の例外もスタックトレース付きで出力
      debugPrint('=== Unexpected Exception ===');
      debugPrint('error: $e');
      debugPrint('stackTrace: $st');
      return '予期せぬエラー: $e';
    }
  }


  /// 画面上の送信処理
  Future<void> _onSendPressed() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() {
      _messages.add(_Message(
        text: text,
        isUser: true,
        userName: '自分',
        createdAt: DateTime.now(),
      ));
      _isSending = true;
    });
    _controller.clear();

    final reply = await _sendToVertexAI(text);

    setState(() {
      _messages.add(_Message(
        text: reply,
        isUser: false,
        userName: 'Gemini',
        createdAt: DateTime.now(),
      ));
      _isSending = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildBubble(_Message m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(m.userName,
                  style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(_fmt(m.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            const SizedBox(height: 8),
            ..._buildTextWithMath(m.text),
            if (!m.isUser) ...[
              const SizedBox(height: 8),
              Row(children: [
                IconButton(
                  icon:
                  const Icon(Icons.copy, size: 16, color: Colors.black54),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: m.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('コピーしました')),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.thumb_up_alt_outlined,
                      size: 16, color: Colors.black54),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.thumb_down_alt_outlined,
                      size: 16, color: Colors.black54),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ],
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
          onPressed: () {},
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }

  List<Widget> _buildTextWithMath(String text) {
    return text.split('\n').map((line) {
      final t = line.trim();
      if (t.startsWith(r'$') && t.endsWith(r'$')) {
        return Math.tex(t.substring(1, t.length - 1),
            textStyle: const TextStyle(fontSize: 14, height: 1.4));
      } else {
        return Text(line, style: const TextStyle(fontSize: 14, height: 1.4));
      }
    }).toList();
  }

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title:
        const Text('AI解説（開発中）', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black, size: 22),
            onPressed: () => Navigator.pop(context),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.gray100, height: 1),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _messages.length,
          itemBuilder: (_, i) =>
              _buildBubble(_messages[_messages.length - 1 - i]),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  cursorColor: Colors.blue,
                  decoration: InputDecoration(
                    hintText: 'メッセージを入力',
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                            color: Colors.blue.shade300, width: 2)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                            color: Colors.blue.shade300, width: 2)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                            color: Colors.blue.shade500, width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isSending
                  ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : IconButton(
                icon: const Icon(Icons.arrow_circle_up_rounded,
                    size: 36, color: Colors.blue),
                onPressed: _onSendPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// メッセージモデル（このファイル内で完結）
class _Message {
  final String text;
  final bool isUser;
  final String userName;
  final DateTime createdAt;
  _Message({
    required this.text,
    required this.isUser,
    required this.userName,
    required this.createdAt,
  });
}
