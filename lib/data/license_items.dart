/// 資格データとモデルを一元管理するファイル
class LicenseItem {
  final String name;
  final String furigana;
  final String katakana;
  final bool isOfficial;
  const LicenseItem({
    required this.name,
    required this.furigana,
    required this.katakana,
    this.isOfficial = false,
  });
}

/// ガス主任技術者を先頭にしたリスト
const List<LicenseItem> kLicenseList = [
  // ★ 公式問題がある資格を先頭に
  LicenseItem(
    name: 'ガス主任技術者',
    furigana: 'がすしゅにんぎじゅつしゃ',
    katakana: 'ガスシュニンギジュツシャ',
    isOfficial: true,
  ),
  LicenseItem(
    name: '液化石油ガス設備士',
    furigana: 'えきかせきゆがすせつびし',
    katakana: 'エキカセキユガスセツビシ',
  ),
  LicenseItem(
    name: 'エネルギー管理士',
    furigana: 'えねるぎーかんりし',
    katakana: 'エネルギーカンリシ',
  ),
  LicenseItem(
    name: 'ガス消費機器設置工事監督者',
    furigana: 'がすしょうひききせっちこうじかんとくしゃ',
    katakana: 'ガスショウヒキキセッチコウジカントクシャ',
  ),
  LicenseItem(
    name: '火薬類製造保安責任者',
    furigana: 'かやくるいせいぞうほあんせきにんしゃ',
    katakana: 'カヤクルイセイゾウホアンセキニンシャ',
  ),
  LicenseItem(
    name: '火薬類取扱保安責任者',
    furigana: 'かやくるいとりあつかいほあんせきにんしゃ',
    katakana: 'カヤクルイトリアツカイホアンセキニンシャ',
  ),
  LicenseItem(
    name: '計量士',
    furigana: 'けいりょうし',
    katakana: 'ケイリョウシ',
  ),
  LicenseItem(
    name: '競輪審判員',
    furigana: 'けいりんしんぱんいん',
    katakana: 'ケイリンシンパンイン',
  ),
  LicenseItem(
    name: '競輪選手',
    furigana: 'けいりんせんしゅ',
    katakana: 'ケイリンセンシュ',
  ),
  LicenseItem(
    name: '高圧ガス製造保安責任者',
    furigana: 'こうあつがすせいぞうほあんせきにんしゃ',
    katakana: 'コウアツガスセイゾウホアンセキニンシャ',
  ),
  LicenseItem(
    name: '高圧ガス販売主任者',
    furigana: 'こうあつがすはんばいしゅにんしゃ',
    katakana: 'コウアツガスハンバイシュニンシャ',
  ),
  LicenseItem(
    name: '公害防止管理者等',
    furigana: 'こうがいぼうしかんりしゃとう',
    katakana: 'コウガイボウシカンリシャトウ',
  ),
  LicenseItem(
    name: '航空検査技術者',
    furigana: 'こうくうけんさぎじゅつしゃ',
    katakana: 'コウクウケンサギジュツシャ',
  ),
  LicenseItem(
    name: '小型自動車競走審判員',
    furigana: 'こがたじどうしゃきょうそうしんぱんいん',
    katakana: 'コガタジドウシャキョウソウシンパンイン',
  ),
  LicenseItem(
    name: '小型自動車競走選手',
    furigana: 'こがたじどうしゃきょうそうせんしゅ',
    katakana: 'コガタジドウシャキョウソウセンシュ',
  ),
  LicenseItem(
    name: '採石業務管理者',
    furigana: 'さいせきぎょうむかんりしゃ',
    katakana: 'サイセキギョウムカンリシャ',
  ),
  LicenseItem(
    name: '砂利採取業務主任者',
    furigana: 'じゃりさいしゅぎょうむしゅにんしゃ',
    katakana: 'ジャリサイシュギョウムシュニンシャ',
  ),
  LicenseItem(
    name: '情報処理安全確保支援士',
    furigana: 'じょうほうしょりあんぜんかくほしえんし',
    katakana: 'ジョウホウショリアンゼンカクホシエンシ',
  ),
  LicenseItem(
    name: '情報処理技術者試験',
    furigana: 'じょうほうしょりぎじゅつしゃしけん',
    katakana: 'ジョウホウショリギジュツシャシケン',
  ),
  LicenseItem(
    name: 'ダム水路主任技術者',
    furigana: 'だむすいろしゅにんぎじゅつしゃ',
    katakana: 'ダムスイロシュニンギジュツシャ',
  ),
  LicenseItem(
    name: '中小企業診断士',
    furigana: 'ちゅうしょうきぎょうしんだんし',
    katakana: 'チュウショウキギョウシンダンシ',
  ),
  LicenseItem(
    name: '電気工事士',
    furigana: 'でんきこうじし',
    katakana: 'デンキコウジシ',
  ),
  LicenseItem(
    name: '電気主任技術者',
    furigana: 'でんきしゅにんぎじゅつしゃ',
    katakana: 'デンキシュニンギジュツシャ',
  ),
  LicenseItem(
    name: '特種電気工事資格者',
    furigana: 'とくしゅでんきこうじしかくしゃ',
    katakana: 'トクシュデンキコウジシカクシャ',
  ),
  LicenseItem(
    name: '認定電気工事従事者',
    furigana: 'にんていでんきこうじじゅうじしゃ',
    katakana: 'ニンテイデンキコウジジュウジシャ',
  ),
  LicenseItem(
    name: '弁理士',
    furigana: 'べんりし',
    katakana: 'ベンリシ',
  ),
  LicenseItem(
    name: 'ボイラー・タービン主任技術者',
    furigana: 'ぼいらー・たーびんしゅにんぎじゅつしゃ',
    katakana: 'ボイラー・タービンシュニンギジュツシャ',
  ),
];
