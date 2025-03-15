import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'question_count.dart';

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
      allowedExtensions: ['csv', 'xls', 'xlsx'],
      withData: true,
    );
    if (result == null) return;

    PlatformFile file = result.files.first;
    final String? extension = file.extension?.toLowerCase();
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
      if (extension == 'csv') {
        print("Debug: CSVファイルを読み込み開始");

        String csvContent = utf8.decode(fileBytes).trim();
        if (csvContent.startsWith('\ufeff')) {
          print("Debug: BOMを削除");
          csvContent = csvContent.substring(1);
        }

        List<List<dynamic>> rows =
        const CsvToListConverter(eol: '\n').convert(csvContent);
        if (rows.isEmpty) {
          print("Error: CSVファイルが空です");
          return;
        }

        List<String> header =
        rows.first.map((h) => h.toString().trim()).toList();
        print("Debug: 修正後のCSVヘッダー: $header");

        for (int i = 1; i < rows.length; i++) {
          List<dynamic> row = rows[i];

          if (row.length != header.length) {
            print(
                "Warning: 列数不一致のためスキップ (行番号: $i, データ長: ${row.length}, ヘッダー長: ${header.length})");
            continue;
          }

          Map<String, dynamic> data = {};
          for (int j = 0; j < header.length; j++) {
            data[header[j]] = row[j]?.toString()?.trim() ?? '';
          }

          if (!data.containsKey('questionText') ||
              data['questionText']!.isEmpty) {
            print("Warning: 問題文が空のためスキップ (行番号: $i)");
            continue;
          }

          if (data.containsKey('examYear') && data['examYear']!.isNotEmpty) {
            data['examYear'] = int.tryParse(data['examYear']!) ?? null;
          } else {
            data['examYear'] = null;
          }

          print("Debug: 読み込んだデータ (行番号: $i): $data");
          questionsData.add(data);
        }
      } else if (extension == 'xls' || extension == 'xlsx') {
        print("Debug: Excelファイルを読み込み開始");
        var excelDoc = excel.Excel.decodeBytes(fileBytes);
        if (excelDoc.tables.isEmpty) {
          print("Error: Excelファイルが空です");
          return;
        }
        // シートは最初のものを対象とする
        String sheetName = excelDoc.tables.keys.first;
        var sheet = excelDoc.tables[sheetName];
        if (sheet == null || sheet.rows.isEmpty) {
          print("Error: Excelシートが空です");
          return;
        }
        // 1行目をヘッダーとして取得
        List<String> header = sheet.rows.first.map((cell) {
          return cell?.value.toString().trim() ?? '';
        }).toList();
        print("Debug: 修正後のExcelヘッダー: $header");

        for (int i = 1; i < sheet.rows.length; i++) {
          List<excel.Data?> row = sheet.rows[i];

          if (row.length != header.length) {
            print(
                "Warning: 列数不一致のためスキップ (行番号: $i, データ長: ${row.length}, ヘッダー長: ${header.length})");
            continue;
          }

          Map<String, dynamic> data = {};
          for (int j = 0; j < header.length; j++) {
            String cellValue = row[j]?.value.toString() ?? '';
            data[header[j]] = cellValue.trim();
          }

          if (!data.containsKey('questionText') ||
              data['questionText'].isEmpty) {
            print("Warning: 問題文が空のためスキップ (行番号: $i)");
            continue;
          }

          if (data.containsKey('examYear') && data['examYear'].isNotEmpty) {
            data['examYear'] = int.tryParse(data['examYear']) ?? null;
          } else {
            data['examYear'] = null;
          }

          print("Debug: 読み込んだデータ (行番号: $i): $data");
          questionsData.add(data);
        }
      } else {
        print("Error: サポートされていないファイル形式 ($extension)");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('サポートされていないファイル形式です')),
        );
        return;
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
  ///
  /// importKey が null または空欄の場合は重複チェックをせず、そのまま登録します。
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

    Set<String> seenImportKeys = {};
    // importKey が空欄の場合は重複チェック対象外とするため、既存キー取得は行うがチェックはしない
    List<String> existingImportKeys = await _fetchExistingImportKeys(questionSetId);

    int skippedFirestoreCount = 0;
    int skippedFileCount = 0;
    int addedCount = 0;

    for (var data in questionsData) {
      // importKey が null や "null" や空文字の場合は、空文字にする
      String rawKey = data['importKey']?.toString() ?? '';
      String importKey = (rawKey.trim().toLowerCase() == 'null' || rawKey.trim().isEmpty) ? '' : rawKey.trim();

      // importKey が空でない場合のみ重複チェックを実施
      if (importKey.isNotEmpty) {
        if (existingImportKeys.contains(importKey)) {
          print("Warning: Firestoreに既に存在するためスキップ (importKey: $importKey)");
          skippedFirestoreCount++;
          continue;
        }
        if (!seenImportKeys.add(importKey)) {
          print("Warning: ファイル内で重複のためスキップ (importKey: $importKey)");
          skippedFileCount++;
          continue;
        }
      }

      Map<String, dynamic> questionDoc = {
        'questionSetId': questionSetId, // DocumentReference ではなくIDとして保存
        'questionText': data['questionText'] ?? '',
        'questionType': data['questionType'] ?? 'single_choice',
        'correctChoiceText': data['correctChoiceText'] ?? '',
        'incorrectChoice1Text': data['incorrectChoice1Text'] ?? '',
        'incorrectChoice2Text': data['incorrectChoice2Text'] ?? '',
        'incorrectChoice3Text': data['incorrectChoice3Text'] ?? '',
        'examYear': data['examYear'],
        'explanationText': data['explanationText'] ?? '',
        'hintText': data['hintText'] ?? '',
        'isOfficialQuestion': false,
        'isDeleted': false,
        'isFlagged': false,
        'importKey': importKey,
        'createdById': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // importKey がある場合はその値をドキュメントIDとして利用、なければ自動生成
      DocumentReference docRef;
      if (importKey.isNotEmpty) {
        docRef = questionsCol.doc(importKey);
      } else {
        docRef = questionsCol.doc();
      }

      batch.set(docRef, questionDoc, SetOptions(merge: true));
      addedCount++;
    }

    try {
      await batch.commit();
      await updateQuestionCounts(folderId, questionSetId);
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

  /// Firestore から、指定された問題セットの importKey を取得する
  Future<List<String>> _fetchExistingImportKeys(String questionSetId) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('questionSetId', isEqualTo: questionSetId)
          .where('importKey', isGreaterThan: '')
          .get();

      return snapshot.docs.map((doc) => doc['importKey'] as String).toList();
    } catch (e) {
      print("Error fetching existing importKeys: $e");
      return [];
    }
  }
}
