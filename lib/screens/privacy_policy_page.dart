import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プライバシーポリシー'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'プライバシーポリシー',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              '1. 情報の収集\n'
                  '本アプリケーション（以下「本サービス」といいます）は、ユーザーの個人情報を含む利用者情報を以下の方法で収集します。\n\n'
                  'ユーザーから直接提供される情報\n\n'
                  '- 氏名、ニックネーム\n'
                  '- メールアドレス、生年月日、性別\n'
                  '- 居住地、職業\n'
                  '- その他、ユーザーが本サービス内のフォームに入力した情報\n\n'
                  'サービス利用を通じて収集される情報\n\n'
                  '- 学習履歴や成績、解答状況、復習の履歴\n'
                  '- ログ情報（アクセス日時、使用デバイス、IPアドレスなど）\n'
                  '- クッキーおよび匿名IDを使用した情報\n'
                  '- 位置情報（許可された場合）\n\n'
                  '他サービスとの連携による情報\n\n'
                  '- SNSアカウントとの連携を許可した場合に提供されるプロフィール情報',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '2. 情報の利用目的\n'
                  '収集した情報は、以下の目的で使用します。\n\n'
                  '- 本サービスの提供、運営、改善のため\n'
                  '- 学習履歴や進捗に基づくパーソナライズされたサービスの提供\n'
                  '- ユーザーサポートやお問い合わせ対応のため\n'
                  '- サービスに関する重要な通知やアップデート情報の提供\n'
                  '- マーケティング活動やプロモーションの実施\n'
                  '- スカウト機能を利用した個別オファーの提供\n'
                  '- 法令や規約の違反に対処するため\n'
                  '- 匿名化されたデータの統計分析および研究開発',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '3. 第三者への提供\n'
                  'ユーザーの個人情報は以下の場合を除き、第三者に提供することはありません。\n\n'
                  '- ユーザーの同意がある場合\n'
                  '- 法令に基づく場合\n'
                  '- サービス運営上必要な範囲で業務委託先に提供する場合\n'
                  '- 個人を特定できない形での統計データ提供の場合',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '4. 情報の管理\n'
                  '本サービスは、収集した情報を適切に管理し、不正アクセスや情報漏洩を防止するための措置を講じます。また、必要がなくなった情報は、法令に従い適切に廃棄または削除します。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '5. ユーザーの権利\n'
                  'ユーザーは以下の権利を有します。\n\n'
                  '- 自身の個人情報へのアクセスや訂正を求める権利\n'
                  '- 個人情報の削除や利用停止を求める権利\n'
                  '- データポータビリティを求める権利（法令に定めがある場合）\n\n'
                  '権利行使のための詳細な手続きについては、本ポリシーの末尾に記載する問い合わせ先までご連絡ください。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '6. プライバシーポリシーの変更\n'
                  '本ポリシーは必要に応じて改定されることがあります。改定後の内容は本サービス内または公式ウェブサイト上で通知されます。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '7. 問い合わせ先\n'
                  '本サービスにおけるプライバシーに関する問い合わせは以下の窓口までご連絡ください。\n\n'
                  'お問い合わせ窓口 メールアドレス: yuki.matsuda007@gmail.com\n'
                  '制定日: 2024年12月30日\n'
                  '最終改定日: 2024年12月30日',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
