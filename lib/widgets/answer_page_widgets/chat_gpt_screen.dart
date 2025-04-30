import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repaso/utils/app_colors.dart';

/// Vertex AI（Gemini）とチャットする画面
/// DraggableScrollableSheet 内で使う想定なので Scaffold は外し、
/// 代わりに Column でハンドル＋メッセージ＋入力欄を並べています。
class ChatGPTScreen extends StatefulWidget {
  /// 下部シートのスクロールを制御するコントローラ
  final ScrollController scrollController;

  /// 表示中の問題の ID（必須）
  final String questionId;

  /// 問題文・正答・解説（Gemini への前提知識として渡す）
  final String questionText;
  final String correctChoiceText;
  final String explanationText;

  /// すでに作成済みスレッドであれば memoId を渡す（省略可）
  final String? memoId;

  const ChatGPTScreen({
    super.key,
    required this.scrollController,
    required this.questionId,
    required this.questionText,
    required this.correctChoiceText,
    required this.explanationText,
    this.memoId,
  });

  @override
  State<ChatGPTScreen> createState() => _ChatGPTScreenState();
}

class _ChatGPTScreenState extends State<ChatGPTScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_Message> _messages = [];
  bool _isSending = false;

  final HttpsCallable _callVertex =
  FirebaseFunctions.instance.httpsCallable('callVertexAI');

  late String? _memoId;

  @override
  void initState() {
    super.initState();
    _memoId = widget.memoId;
  }

  String get _systemContext => '''
あなたは資格試験対策アプリの AI 解説者です。
以下の情報を前提として、ユーザーの問いに分かりやすく日本語で答えてください。

【問題文】
${widget.questionText}

【正解】
${widget.correctChoiceText}

【解説】
${widget.explanationText}
''';

  Future<String> _sendToVertexAI(String userMessage) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return '未ログインのため利用できません';

      final params = <String, dynamic>{
        'message': userMessage,
        'questionId': widget.questionId,
        'systemContext': _systemContext,
        if (_memoId != null) 'memoId': _memoId,
      };

      final result = await _callVertex.call(params);
      final data = Map<String, dynamic>.from(result.data);
      _memoId = data['memoId'] as String?;
      return data['reply'] as String;
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint('=== FirebaseFunctionsException ===\n$e\n$st');
      return 'エラー(${e.code}): ${e.message ?? '不明なエラー'}';
    } catch (e, st) {
      debugPrint('=== Unexpected Exception ===\n$e\n$st');
      return '予期せぬエラー: $e';
    }
  }

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            child: Icon(
              m.isUser ? Icons.person : Icons.smart_toy,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(m.userName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text(_fmt(m.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
                const SizedBox(height: 8),
                ..._buildTextWithMath(m.text),
                if (!m.isUser) ...[
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: Colors.black54),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: m.text));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('コピーしました')));
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTextWithMath(String text) {
    return text.split('\n').map((line) {
      final t = line.trim();
      if (t.startsWith(r'$') && t.endsWith(r'$')) {
        return Math.tex(
          t.substring(1, t.length - 1),
          textStyle: const TextStyle(fontSize: 14, height: 1.4),
        );
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
    return Column(
      children: [
        // ── メッセージリスト ──
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView.builder(
              controller: widget.scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildBubble(_messages[_messages.length - 1 - i]),
            ),
          ),
        ),

        // ── 入力欄＋注意文 ──
        Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
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
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide:
                            BorderSide(color: Colors.blue.shade300, width: 2)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide:
                            BorderSide(color: Colors.blue.shade300, width: 2)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide:
                            BorderSide(color: Colors.blue.shade500, width: 2)),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  'AI解説の回答は必ずしも正しいとは限りません。重要な情報は確認するようにしてください。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 内部用メッセージモデル
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
