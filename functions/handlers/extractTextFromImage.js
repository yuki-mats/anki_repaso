/* eslint-disable */
"use strict";

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { callGemini } = require("../lib"); // 先ほど修正した lib.js の callGemini をインポート

/**
 * extractTextFromImage
 * 画像（Base64）を Gemini-2.0-Flash に送り、
 * 「改行位置や記号を含めて正確に全文テキスト化せよ」というプロンプトと共に渡して OCR を行う。
 */
module.exports = onCall({ region: "us-central1" }, async (req) => {
  console.log("★★★ extractTextFromImage が呼ばれました ★★★");
  try {
    // 1) 認証チェック（必要なければ削除可）
    if (!req.auth) {
      throw new HttpsError("unauthenticated", "ログインが必要です。");
    }

    // 2) パラメータ検証
    const { base64Image = "", mimeType = "image/jpeg" } = req.data || {};
    if (!base64Image || typeof base64Image !== "string") {
      throw new HttpsError("invalid-argument", "base64Image が空、または不正です。");
    }

    // 3) Gemini-2.0-Flash 用の contents を組み立て
    //    – prompt: OCR 指示テキスト
    //    – inline_data: Base64 画像本体
    const contents = [
      {
        role: "user",
        parts: [
          {
            text:
              "以下の画像に写っている文章を OCR してください。\n\n" +
              "【出力ルール】\n" +
              "1. 見出し・タイトル・段落区切りなど、論理的に意味のある改行は保持してください。\n" +
              "2. 句読点「。」が出現するまで文章を区切らず、その一区切り（文）が終わるまで改行を行わないでください。\n" +
              "3. ページ幅による折り返し（行末が右端で切れて次行が続く場合）はすべて連結して、一続きの文として出力してください。\n" +
              "4. 句読点・記号・英字・数字を含め、誤字なく正確に転写してください。\n" +
              "5. ハイフネーションで単語が分割されている場合（例: trans-\\nlation）は語をつなげてください。\n" +
              "6. 出力はプレーンテキストのみとし、余計な説明やマークアップを入れないでください。"
          },
          {
            inline_data: {
              mime_type: mimeType,
              data:base64Image
            }
          }
        ]
      }
    ];

    // 4) callGemini 呼び出し
    //    – temperature は 0.0（OCR 用）
    //    – maxTokens は 2048 など、十分大きめ
    const { text: extractedText, finishReason } = await callGemini({
      contents,
      systemContext: "",
      temperature: 0.0,
      maxTokens: 2048,
      topP: 1.0,
      maxAttempts: 1
    });

    // 5) 空文字かチェック
    const trimmed = (extractedText || "").trim();
    if (!trimmed) {
      return { text: "" };
    }

    // 6) クライアントへ返却
    return { text: trimmed };
  } catch (err) {
    console.error("[extractTextFromImage] Error:", err);
    if (err instanceof HttpsError) throw err;
    if (err.response?.data) {
      throw new HttpsError(
        "internal",
        `Gemini response error: ${JSON.stringify(err.response.data)}`
      );
    }
    throw new HttpsError("internal", `Unknown exception: ${err.message}`);
  }
});
