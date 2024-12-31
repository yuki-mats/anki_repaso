import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用規約'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '利用規約',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              '第1条（適用）\n'
                  '本規約は、ユーザーが本アプリケーション（以下「本サービス」といいます）を利用する際の権利義務関係を定めるものです。'
                  'ユーザーは、本規約に同意した上で本サービスを利用するものとします。'
                  '本規約は、関連するルールや個別規約を包含し、これらが矛盾する場合には本規約が優先して適用されます。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '第2条（利用登録）\n'
                  'ユーザーは、本規約に同意し、所定の情報を提供することで利用登録を行います。\n'
                  '運営者は、以下の場合に利用登録を拒否または無効化する権利を有します。\n'
                  '- 登録内容に虚偽、誤記、または記載漏れがあった場合。\n'
                  '- 未成年者が適切な法的同意を得ていない場合。\n'
                  '- 反社会的勢力等に該当すると判断される場合。\n'
                  '- その他、運営者が不適切と判断した場合。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '第3条（プライバシーの保護）\n'
                  '本サービスは、個人情報保護法および関連法令を遵守し、ユーザー情報を適切に管理します。\n'
                  '収集する情報には以下が含まれます。\n'
                  '- ユーザー名、メールアドレス、生年月日、性別、居住地、学習履歴。\n'
                  '- サービス利用状況、デバイス情報、IPアドレス。\n'
                  '利用目的は以下の通りです。\n'
                  '- サービス提供および運営。\n'
                  '- 個別ユーザーにカスタマイズされたサービスの提供。\n'
                  '- ユーザーサポートのための連絡。\n'
                  '- 匿名化されたデータの統計分析。\n'
                  '本サービスは、Firebase Authenticationを用いて個人情報を管理し、セキュリティ対策を徹底しています。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            // 以下に他の条項を続けてください
            Text(
              '第4条（アカウントの管理）\n'
                  'ユーザーは、自身のアカウント情報を適切に管理する責任を負います。\n'
                  'パスワードの管理不足や不正使用による損害について、運営者は責任を負いません。\n'
                  'ユーザーがアカウントを削除した場合、関連するデータも削除されます。\n'
                  'アカウントは個人専用であり、第三者への譲渡や共有は禁止されています。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            // 他の条項も同様の形式で追加
          ],
        ),
      ),
    );
  }
}
