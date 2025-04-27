import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:repaso/utils/app_colors.dart';

class ChatGPTScreen extends StatefulWidget {
  const ChatGPTScreen({Key? key}) : super(key: key);

  @override
  _ChatGPTScreenState createState() => _ChatGPTScreenState();
}

class _ChatGPTScreenState extends State<ChatGPTScreen> {
  final TextEditingController _controller = TextEditingController();

  // ダミーのメッセージ一覧（初期表示用）
  final List<Message> _messages = [
    Message(
      text: "こんにちは！LLMを活用した機能を現在開発中です！\n楽しみにしていてください！",
      isUser: false,
    ),
    Message(
      text: "こちらが数式の例です：\n\n\$\\int_0^\\infty e^{-x} dx = 1\$",
      isUser: true,
    ),
    Message(
      text: "こちらが数式の例です：\n\n\$\\int_0^\\infty e^{-x} dx = 1\$　\n文章量を増やして間隔感を確認します。",
      isUser: false,
    ),
  ];

  /// メッセージ送信時の処理
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      // ユーザーからのメッセージを追加
      _messages.add(Message(text: text, isUser: true));
      // ダミーのChatGPTのメッセージを追加
      _messages.add(
        Message(
          text: "これはダミーの応答です。\n\nたとえば以下の式もあります：\n\n\$E = mc^2\$",
          isUser: false,
        ),
      );
    });
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// メッセージ内容＋（必要な場合）下部アイコンボタン群を構築するウィジェット
  /// ※ ユーザー側はアイコン行を表示せず、ChatGPT側のみ表示する
  Widget _buildBubbleContent(String text, {required bool includeIcons}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTextWithMath(text),
        if (includeIcons) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // コピーアイコン
              Container(
                height: 28,
                width: 28,
                child: IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Colors.black54),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    // コピー処理を実装
                  },
                ),
              ),
              const SizedBox(width: 4),
              // グッドアイコン
              Container(
                height: 28,
                width: 28,
                child: IconButton(
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.black54),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    // グッド処理を実装
                  },
                ),
              ),
              const SizedBox(width: 4),
              // バッドアイコン
              Container(
                height: 28,
                width: 28,
                child: IconButton(
                  icon: const Icon(Icons.thumb_down_alt_outlined, size: 16, color: Colors.black54),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    // バッド処理を実装
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 各メッセージを表示するウィジェット
  Widget _buildMessageBubble(Message message) {
    if (message.isUser) {
      // 自分のチャット：右寄せ、灰色背景、左80pxの余白、上下8pxの余白、アイコン行は不要
      return Container(
        margin: const EdgeInsets.only(left: 80, right: 16, top: 8, bottom: 8),
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildBubbleContent(message.text, includeIcons: false),
        ),
      );
    } else {
      // ChatGPTのチャット：左右16pxの余白、上下8pxの余白、アイコン行を表示
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: _buildBubbleContent(message.text, includeIcons: true),
        ),
      );
    }
  }

  /// テキスト内の行ごとに `$ ... $` があれば LaTeX をレンダリング
  /// 通常のテキストサイズは14pxに設定
  Widget _buildTextWithMath(String text) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.startsWith(r'$') && trimmed.endsWith(r'$')) {
          final formula = trimmed.substring(1, trimmed.length - 1);
          return Math.tex(
            formula,
            textStyle: const TextStyle(fontSize: 14, height: 1.4),
          );
        } else {
          return Text(
            line,
            style: const TextStyle(fontSize: 14, height: 1.4),
          );
        }
      }).toList(),
    );
  }

  /// 下部の入力欄（返信ページのコメント入力UIに合わせたデザイン）
  Widget _buildBottomInputArea() {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: TextField(
                    controller: _controller,
                    maxLines: null, // 複数行対応
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    cursorColor: Colors.blue,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "メッセージを入力…（使用できません）",
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_circle_up_rounded, size: 36, color: Colors.blue),
                onPressed: () => _sendMessage(_controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ← ここでresizeToAvoidBottomInsetをfalseに設定
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        // 左側のアイコンを非表示
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: const Text(
          "AI解説（現在開発中）",
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black, size: 22),
            onPressed: () => Navigator.pop(context),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.gray100, height: 1.0),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // テキストフィールド以外をタップしたらキーボードを閉じる
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // メッセージ一覧
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
          ],
        ),
      ),
      // 下部の入力欄をbottomNavigationBarとして固定
      bottomNavigationBar: _buildBottomInputArea(),
    );
  }
}

/// メッセージのモデルクラス
class Message {
  final String text;
  final bool isUser;
  Message({required this.text, required this.isUser});
}
