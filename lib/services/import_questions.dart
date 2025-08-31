import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'question_count_update.dart';

/// Firestore への問題インポートやファイル解析を行うサービス
class ImportQuestionsService {
  /// [context] は UI 表示用、[folderId] と [questionSetId] は対象のIDです。
  Future<void> pickFileAndImport(
      BuildContext context,
      String folderId,
      String questionSetId,
      ) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'], // xlsx のみ受け付ける
      withData: true,
    );
    if (result == null) return;

    PlatformFile file = result.files.first;
    final String? extension = file.extension?.toLowerCase();
    if (extension != 'xlsx') {
      print("Error: xlsxファイルのみ対応しています");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('xlsxファイルのみ対応しています')),
      );
      return;
    }

    final Uint8List? fileBytes = file.bytes;
    if (fileBytes == null) {
      print("Error: ファイルの読み込みに失敗しました");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ファイルの読み込みに失敗しました')),
      );
      return;
    }

    List<Map<String, dynamic>> questionsData = [];
    try {
      print("Debug: Excelファイルを読み込み開始");
      var excelDoc = excel.Excel.decodeBytes(fileBytes);
      if (excelDoc.tables.isEmpty) {
        print("Error: Excelファイルが空です");
        return;
      }
      // 対象のシートのみを処理する
      List<String> requiredSheets = ["正誤問題", "択一式問題", "フラッシュカード式問題"];
      for (String sheetName in requiredSheets) {
        if (!excelDoc.tables.containsKey(sheetName)) {
          print("Warning: シート '$sheetName' が存在しません。");
          continue;
        }
        var sheet = excelDoc.tables[sheetName];
        if (sheet == null || sheet.rows.isEmpty) {
          print("Warning: シート '$sheetName' は空です。");
          continue;
        }
        // 1行目をヘッダーとして取得
        List<String> header = sheet.rows.first.map((cell) {
          return cell?.value.toString().trim() ?? '';
        }).toList();
        print("Debug: シート '$sheetName' のExcelヘッダー: $header");
        for (int i = 1; i < sheet.rows.length; i++) {
          List<excel.Data?> row = sheet.rows[i];

          if (row.length != header.length) {
            print(
                "Warning: 列数不一致のためスキップ (シート: $sheetName, 行番号: ${i + 1}, データ長: ${row.length}, ヘッダー長: ${header.length})");
            continue;
          }

          Map<String, dynamic> data = {};
          for (int j = 0; j < header.length; j++) {
            String cellValue = row[j]?.value.toString() ?? '';
            data[header[j]] = cellValue.trim();
          }

          if (!data.containsKey('questionText') || data['questionText'].isEmpty) {
            print("Warning: 問題文が空のためスキップ (シート: $sheetName, 行番号: ${i + 1})");
            continue;
          }

          if (data.containsKey('examYear') && data['examYear'].isNotEmpty) {
            data['examYear'] = int.tryParse(data['examYear']) ?? null;
          } else {
            data['examYear'] = null;
          }

          // questionTags を「,」で分割して配列に変換
          if (data.containsKey('questionTags') && data['questionTags'].isNotEmpty) {
            data['questionTags'] =
                data['questionTags'].split(',').map((e) => e.trim()).toList();
          } else {
            data['questionTags'] = [];
          }

          // シート名に応じた questionType の設定
          if (sheetName == "正誤問題") {
            data['questionType'] = 'true_false';
            // 正誤問題の場合、正答に応じた誤答を自動設定
            String correct = data['correctChoiceText'] ?? '';
            if (correct == '正しい') {
              data['incorrectChoice1Text'] = '間違い';
            } else if (correct == '間違い') {
              data['incorrectChoice1Text'] = '正しい';
            } else {
              data['incorrectChoice1Text'] = '';
            }
          } else if (sheetName == "択一式問題") {
            data['questionType'] = 'single_choice';
            // ※ 誤答の各選択肢はシートに存在する前提
          } else if (sheetName == "フラッシュカード式問題") {
            data['questionType'] = 'flash_card';
          }

          // importKey がない場合は空文字とする
          if (!data.containsKey('importKey') || data['importKey'] == null) {
            data['importKey'] = '';
          }

          print("Debug: 読み込んだデータ (シート: $sheetName, 行番号: ${i + 1}): $data");
          questionsData.add(data);
        }
      }

      if (questionsData.isEmpty) {
        print("Error: データが正常に取得できませんでした。");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題のデータが見つかりませんでした')),
        );
        return;
      }

      await _importQuestions(context, folderId, questionSetId, questionsData);
    } catch (e) {
      print("Error processing file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ファイルの処理に失敗しました')),
      );
    }
  }

  /// Firestore へ問題データをインポートする
  Future<void> _importQuestions(
      BuildContext context,
      String folderId,
      String questionSetId,
      List<Map<String, dynamic>> questionsData,
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("Error: ログインが必要です");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    WriteBatch batch = FirebaseFirestore.instance.batch();
    CollectionReference questionsCol = FirebaseFirestore.instance.collection('questions');

    print("Debug: ${questionsData.length}件のデータをFirestoreにインポート");

    int addedCount = 0;

    for (var data in questionsData) {
      // importKey はフィールドとして保持（重複チェックは行わず、ドキュメントIDは自動生成）
      Map<String, dynamic> questionDoc = {
        'questionSetId': questionSetId, // IDとして保存
        'questionText': data['questionText'] ?? '',
        'questionType': data['questionType'] ?? 'single_choice',
        'correctChoiceText': data['correctChoiceText'] ?? '',
        'incorrectChoice1Text': data['incorrectChoice1Text'] ?? '',
        'incorrectChoice2Text': data['incorrectChoice2Text'] ?? '',
        'incorrectChoice3Text': data['incorrectChoice3Text'] ?? '',
        'examYear': data['examYear'],
        'explanationText': data['explanationText'] ?? '',
        'hintText': data['hintText'] ?? '',
        'isOfficial': false,
        'isDeleted': false,
        'isFlagged': false,
        'importKey': data['importKey'], // フィールドとして保持
        'questionTags': data['questionTags'] ?? [],
        'createdById': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ドキュメントIDは常に自動生成する
      DocumentReference docRef = questionsCol.doc();
      batch.set(docRef, questionDoc, SetOptions(merge: true));
      addedCount++;
    }

    try {
      await batch.commit();
      await questionCountsUpdate(folderId, questionSetId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題のインポートが完了しました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題のインポートに失敗しました')),
        );
      }
    }
  }
}
